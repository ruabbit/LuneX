#!/usr/bin/env python3
"""Reject secrets and machine-specific identifiers in protocol fixtures."""

from __future__ import annotations

import argparse
import ipaddress
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FIXTURE_ROOT = ROOT / "Tests" / "Fixtures" / "Moonlight"

TEXT_SUFFIXES = {".json", ".md", ".txt", ".xml", ".rtsp", ".hex"}
SECRET_PATTERNS = {
    "private key": re.compile(r"-----BEGIN (?:RSA |EC |)PRIVATE KEY-----"),
    "authorization header": re.compile(r"(?im)^authorization\s*:"),
    "credential field": re.compile(r'(?i)["\'](?:password|token|privatekey|rikey|pin)["\']\s*[:=]\s*["\'][^<][^"\']+'),
    "uuid": re.compile(r"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b"),
    "mac address": re.compile(r"(?i)\b(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}\b"),
    "long hex secret": re.compile(r"(?i)(?<![0-9a-f])[0-9a-f]{64,}(?![0-9a-f])"),
}
IP_PATTERN = re.compile(r"(?<![0-9.])(?:\d{1,3}\.){3}\d{1,3}(?![0-9.])")
ALLOWED_NETWORKS = tuple(
    ipaddress.ip_network(value)
    for value in ("192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24", "127.0.0.0/8", "0.0.0.0/32")
)


def validate_json_hex(path: Path, text: str) -> list[str]:
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        return [f"{path}: JSON fixture is invalid"]

    failures: list[str] = []

    def visit(current: object, key: str | None = None) -> None:
        if isinstance(current, dict):
            for child_key, child_value in current.items():
                visit(child_value, str(child_key))
        elif isinstance(current, list):
            for child_value in current:
                visit(child_value, key)
        elif isinstance(current, str):
            match = SECRET_PATTERNS["long hex secret"].search(current)
            if match and not (key == "sha256" and re.fullmatch(r"(?i)[0-9a-f]{64}", current)):
                failures.append(f"{path}: contains long hex secret")

    visit(value)
    return failures


def validate_text(path: Path, text: str) -> list[str]:
    failures: list[str] = []
    for label, pattern in SECRET_PATTERNS.items():
        if label == "long hex secret" and path.suffix.lower() == ".json":
            continue
        if pattern.search(text):
            failures.append(f"{path}: contains {label}")

    if path.suffix.lower() == ".json":
        failures.extend(validate_json_hex(path, text))

    for match in IP_PATTERN.finditer(text):
        try:
            address = ipaddress.ip_address(match.group(0))
        except ValueError:
            continue
        if not any(address in network for network in ALLOWED_NETWORKS):
            failures.append(f"{path}: contains non-documentation IPv4 address")
    return failures


def validate_tree(root: Path) -> list[str]:
    failures: list[str] = []
    if not root.is_dir():
        return [f"fixture root does not exist: {root}"]
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            failures.append(f"{path}: text fixture is not UTF-8")
            continue
        failures.extend(validate_text(path, text))
    return failures


def run_self_test() -> list[str]:
    failures: list[str] = []
    safe = 'host="example.invalid" address="192.0.2.10" token="<redacted>"'
    if validate_text(Path("safe.txt"), safe):
        failures.append("self-test rejected sanitized documentation data")
    safe_digest = '{"sha256":"' + ("a" * 64) + '"}'
    if validate_text(Path("safe.json"), safe_digest):
        failures.append("self-test rejected a public SHA-256 integrity digest")
    unsafe_cases = (
        "-----BEGIN PRIVATE KEY-----",
        "host=10.1.2.3",
        "Authorization: Basic abc",
        '"password":"secret"',
        "550e8400-e29b-41d4-a716-446655440000",
        '{"payload":"' + ("a" * 64) + '"}',
        '{"sha256":"' + ("a" * 65) + '"}',
    )
    for index, value in enumerate(unsafe_cases):
        if not validate_text(Path(f"unsafe-{index}.txt"), value):
            failures.append(f"self-test accepted unsafe case {index}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", type=Path, default=DEFAULT_FIXTURE_ROOT)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    failures = run_self_test() if args.self_test else []
    failures.extend(validate_tree(args.root))
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"Protocol fixtures validated: {args.root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
