#!/usr/bin/env python3
import argparse
import base64
import hashlib
import json
import plistlib
import uuid
from datetime import datetime, timezone
from pathlib import Path


def now_iso():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def data_b64(value):
    if not value:
        return ""
    if isinstance(value, bytes):
        return base64.b64encode(value).decode("ascii")
    if isinstance(value, str):
        return base64.b64encode(value.encode("utf-8")).decode("ascii")
    raise TypeError(f"Unsupported data value: {type(value)!r}")


def int_value(settings, key, default=0):
    value = settings.get(key, default)
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def bool_value(settings, key, default=False):
    value = settings.get(key, default)
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value != 0
    if isinstance(value, str):
        return value.lower() in ("1", "true", "yes")
    return default


def host_address(raw, port, source, timestamp):
    if not raw:
        return None
    if ":" in raw and not raw.startswith("["):
        display = f"[{raw}]:{port or 47989}"
    elif port and int(port) != 47989:
        display = f"{raw}:{port}"
    else:
        display = raw
    return {
        "rawValue": display,
        "source": source,
        "lastResolvedAt": timestamp,
    }


def collect_addresses(settings, index, timestamp):
    candidates = [
        ("manualaddress", "manualport", "manual"),
        ("localaddress", "localport", "cached"),
        ("remoteaddress", "remoteport", "vpn"),
        ("ipv6address", "ipv6port", "cached"),
    ]
    addresses = []
    seen = set()
    for address_key, port_key, source in candidates:
        raw = settings.get(f"hosts.{index}.{address_key}")
        port = int_value(settings, f"hosts.{index}.{port_key}", 47989)
        address = host_address(raw, port, source, timestamp)
        if address and address["rawValue"] not in seen:
            seen.add(address["rawValue"])
            addresses.append(address)
    return addresses


def import_hosts(settings, timestamp):
    host_count = int_value(settings, "hosts.size")
    hosts = []
    app_snapshots = []

    for index in range(1, host_count + 1):
        qt_uuid = settings.get(f"hosts.{index}.uuid") or f"moonlight-qt-host-{index}"
        host_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"moonlight-qt:{qt_uuid}"))
        name = settings.get(f"hosts.{index}.hostname") or f"Moonlight Host {index}"
        addresses = collect_addresses(settings, index, timestamp)
        if not addresses:
            continue

        server_cert = settings.get(f"hosts.{index}.srvcert") or b""
        paired = bool(server_cert)
        max_width = int_value(settings, "width")
        max_height = int_value(settings, "height")
        max_fps = int_value(settings, "fps")

        host = {
            "id": host_id,
            "name": name,
            "addresses": addresses,
            "pairingState": "paired" if paired else "unpaired",
            "reachability": "unknown",
            "capabilities": {
                "supportsHDR": any(
                    bool_value(settings, f"hosts.{index}.apps.{app_index}.hdr")
                    for app_index in range(1, int_value(settings, f"hosts.{index}.apps.size") + 1)
                ),
                "supportsHEVC": False,
                "supportsAV1": False,
                "maxResolution": {"width": max_width, "height": max_height},
                "maxRefreshRate": max_fps,
            },
            "lastSeenAt": timestamp,
        }

        if paired:
            host["pinnedIdentity"] = {
                "certificateSHA256": hashlib.sha256(server_cert).hexdigest(),
                "serverCertificateDER": data_b64(server_cert),
                "pairedAt": timestamp,
            }

        hosts.append(host)

        apps = []
        app_count = int_value(settings, f"hosts.{index}.apps.size")
        for app_index in range(1, app_count + 1):
            app_id = settings.get(f"hosts.{index}.apps.{app_index}.id")
            app_name = settings.get(f"hosts.{index}.apps.{app_index}.name")
            if app_id is None or not app_name:
                continue
            apps.append({
                "id": str(app_id),
                "name": app_name,
                "supportsHDR": bool_value(settings, f"hosts.{index}.apps.{app_index}.hdr"),
            })

        if apps:
            app_snapshots.append({
                "hostID": host_id,
                "apps": sorted(apps, key=lambda app: app["name"].casefold()),
                "updatedAt": timestamp,
            })

    return hosts, app_snapshots


def import_settings(settings):
    width = int_value(settings, "width", 2560)
    height = int_value(settings, "height", 1440)
    fps = int_value(settings, "fps", 120)
    bitrate = int_value(settings, "bitrate", 80000)
    return {
        "discoveryEnabled": bool_value(settings, "mdns", True),
        "stream": {
            "width": width,
            "height": height,
            "frameRate": fps,
            "bitrateKbps": bitrate,
            "hdrEnabled": bool_value(settings, "hdr", True),
            "scaleMode": "fit",
        },
        "input": {
            "preferRelativeMouseMode": not bool_value(settings, "mouseacceleration", False),
            "captureSystemShortcuts": bool_value(settings, "capturesyskeys", True),
            "showVirtualController": False,
        },
        "continuity": {
            "audioContinuityEnabled": True,
            "pictureInPictureEnabled": True,
            "reduceRenderingInBackground": True,
        },
        "diagnosticsEnabled": True,
    }


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description="Import local Moonlight-qt pairing data into LuneX local test storage.")
    parser.add_argument(
        "--source",
        default=str(Path.home() / "Library/Preferences/com.moonlight-stream.Moonlight.plist"),
        help="Moonlight-qt preferences plist path",
    )
    parser.add_argument(
        "--output-dir",
        default=str(Path.home() / "Library/Application Support/LuneX"),
        help="LuneX Application Support directory",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print import summary without writing files")
    args = parser.parse_args()

    source = Path(args.source).expanduser()
    output_dir = Path(args.output_dir).expanduser()
    with source.open("rb") as handle:
        settings = plistlib.load(handle)

    timestamp = now_iso()
    hosts, app_snapshots = import_hosts(settings, timestamp)
    app_settings = import_settings(settings)

    identity_payload = {
        "uniqueID": settings.get("uniqueid"),
        "certificatePEM": data_b64(settings.get("certificate") or b""),
        "privateKeyPEM": data_b64(settings.get("key") or b""),
        "importedAt": timestamp,
        "source": str(source),
    }

    print(f"Source: {source}")
    print(f"Destination: {output_dir}")
    print(f"Hosts: {len(hosts)}")
    for host in hosts:
        apps = next((snapshot["apps"] for snapshot in app_snapshots if snapshot["hostID"] == host["id"]), [])
        print(f"- {host['name']}: {host['pairingState']}, {host['addresses'][0]['rawValue']}, apps={len(apps)}")

    if args.dry_run:
        return

    write_json(output_dir / "hosts.json", {"hosts": hosts, "updatedAt": timestamp})
    write_json(output_dir / "settings.json", app_settings)
    write_json(output_dir / "app_catalog.json", app_snapshots)
    write_json(output_dir / "moonlight_qt_identity.json", identity_payload)
    print("Wrote hosts.json, settings.json, app_catalog.json, moonlight_qt_identity.json")


if __name__ == "__main__":
    main()
