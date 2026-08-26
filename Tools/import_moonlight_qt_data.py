#!/usr/bin/env python3
import argparse
import base64
import hashlib
import json
import os
import plistlib
import re
import ssl
import subprocess
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path


PROTOCOL_UNIQUE_ID = "0123456789ABCDEF"
SWIFT_REFERENCE_DATE = datetime(2001, 1, 1, tzinfo=timezone.utc)


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


def certificate_der(value):
    if not value:
        return b""
    raw = value if isinstance(value, bytes) else value.encode("utf-8")
    if raw.startswith(b"-----BEGIN CERTIFICATE-----"):
        return ssl.PEM_cert_to_DER_cert(raw.decode("ascii"))
    return raw


def private_key_der(value, openssl="openssl"):
    if not value:
        return b""
    raw = value if isinstance(value, bytes) else value.encode("utf-8")
    if raw.startswith(b"-----BEGIN RSA PRIVATE KEY-----"):
        body = b"".join(
            line.strip()
            for line in raw.splitlines()
            if line and not line.startswith(b"-----")
        )
        return base64.b64decode(body, validate=True)
    if not raw.startswith(b"-----BEGIN PRIVATE KEY-----"):
        raise ValueError("Unsupported Moonlight-qt private key encoding")

    result = subprocess.run(
        [openssl, "pkey", "-inform", "PEM", "-outform", "DER", "-traditional"],
        input=raw,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0 or not result.stdout:
        raise ValueError("OpenSSL could not convert the Moonlight-qt private key")
    return result.stdout


def openssl_output(arguments, payload, failure_message, openssl="openssl"):
    result = subprocess.run(
        [openssl, *arguments],
        input=payload,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0 or not result.stdout:
        raise ValueError(failure_message)
    return result.stdout


def validate_client_identity(certificate, private_key, openssl="openssl"):
    certificate_public_key = openssl_output(
        ["x509", "-inform", "DER", "-pubkey", "-noout"],
        certificate,
        "OpenSSL could not parse the Moonlight-qt client certificate",
        openssl,
    )
    private_public_key = openssl_output(
        ["pkey", "-inform", "DER", "-pubout"],
        private_key,
        "OpenSSL could not parse the Moonlight-qt client private key",
        openssl,
    )
    if certificate_public_key != private_public_key:
        raise ValueError("Moonlight-qt client certificate and private key do not match")

    subject = openssl_output(
        ["x509", "-inform", "DER", "-subject", "-nameopt", "RFC2253", "-noout"],
        certificate,
        "OpenSSL could not read the Moonlight-qt client certificate subject",
        openssl,
    )
    subject_name = subject.decode("utf-8", errors="strict").strip().removeprefix("subject=")
    if not re.search(r"(?:^|,)CN=NVIDIA GameStream Client(?:,|$)", subject_name):
        raise ValueError("Moonlight-qt client certificate has an unexpected subject")


def import_client_identity(settings, timestamp):
    certificate = certificate_der(settings.get("certificate") or b"")
    private_key = private_key_der(settings.get("key") or b"")
    if not certificate or not private_key:
        raise ValueError("Moonlight-qt client certificate or private key is missing")
    validate_client_identity(certificate, private_key)

    identity_digest = hashlib.sha256(certificate).hexdigest()
    identity_id = uuid.uuid5(
        uuid.NAMESPACE_URL,
        f"moonlight-qt-client:{identity_digest}",
    )
    created_at = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    return {
        "certificateDER": base64.b64encode(certificate).decode("ascii"),
        "createdAt": (created_at - SWIFT_REFERENCE_DATE).total_seconds(),
        "id": str(identity_id).upper(),
        "privateKeyDER": base64.b64encode(private_key).decode("ascii"),
    }


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

        server_cert = certificate_der(settings.get(f"hosts.{index}.srvcert") or b"")
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
    path.parent.chmod(0o700)
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            delete=False,
        ) as handle:
            temporary_path = Path(handle.name)
            os.chmod(temporary_path, 0o600)
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_path, path)
        path.chmod(0o600)
    finally:
        if temporary_path and temporary_path.exists():
            temporary_path.unlink()


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
    parser.add_argument(
        "--include-client-identity",
        action="store_true",
        help="Explicitly import the Moonlight-qt client certificate/private key into the Debug file fallback",
    )
    parser.add_argument(
        "--identity-only",
        action="store_true",
        help=(
            "Do not rewrite hosts/settings/catalog; write client_identity.debug.json and remove the "
            "legacy plaintext identity file if present; requires --include-client-identity"
        ),
    )
    args = parser.parse_args()
    if args.identity_only and not args.include_client_identity:
        parser.error("--identity-only requires --include-client-identity")

    source = Path(args.source).expanduser()
    output_dir = Path(args.output_dir).expanduser()
    with source.open("rb") as handle:
        settings = plistlib.load(handle)

    timestamp = now_iso()
    hosts, app_snapshots = import_hosts(settings, timestamp)
    app_settings = import_settings(settings)
    client_identity = import_client_identity(settings, timestamp) if args.include_client_identity else None

    print(f"Source: {source}")
    print(f"Destination: {output_dir}")
    print(f"Hosts: {len(hosts)}")
    for host in hosts:
        apps = next((snapshot["apps"] for snapshot in app_snapshots if snapshot["hostID"] == host["id"]), [])
        print(f"- {host['name']}: {host['pairingState']}, {host['addresses'][0]['rawValue']}, apps={len(apps)}")
    if client_identity:
        print(
            "Client identity: ready for Debug fallback "
            f"(wire ID {PROTOCOL_UNIQUE_ID}, certificate/private key present)"
        )
    else:
        print("Client identity: not requested; private key will not be copied")

    if args.dry_run:
        return

    if not args.identity_only:
        write_json(output_dir / "hosts.json", {"hosts": hosts, "updatedAt": timestamp})
        write_json(output_dir / "settings.json", app_settings)
        write_json(output_dir / "app_catalog.json", app_snapshots)
    if client_identity:
        write_json(output_dir / "client_identity.debug.json", client_identity)
    legacy_identity_path = output_dir / "moonlight_qt_identity.json"
    if legacy_identity_path.exists():
        legacy_identity_path.unlink()
        print("Removed legacy plaintext moonlight_qt_identity.json")
    if args.identity_only:
        print("Wrote Debug client identity only (directory 0700, file 0600)")
    elif client_identity:
        print("Wrote hosts/settings/catalog and Debug client identity (directory 0700, files 0600)")
    else:
        print("Wrote hosts.json, settings.json, app_catalog.json (mode 0600); private key was not copied")


if __name__ == "__main__":
    main()
