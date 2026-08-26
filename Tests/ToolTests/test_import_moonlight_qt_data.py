import base64
import json
import os
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
IMPORTER = REPOSITORY_ROOT / "Tools" / "import_moonlight_qt_data.py"


class MoonlightQtImporterTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.source = self.root / "Moonlight.plist"
        self.output = self.root / "LuneX"
        self.certificate = self.root / "certificate.pem"
        self.private_key = self.root / "private-key.pem"
        subprocess.run(
            [
                "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                "-subj", "/CN=NVIDIA GameStream Client", "-days", "1",
                "-keyout", str(self.private_key), "-out", str(self.certificate),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        with self.source.open("wb") as handle:
            plistlib.dump(
                {
                    "hosts.size": 0,
                    "certificate": self.certificate.read_bytes(),
                    "key": self.private_key.read_bytes(),
                },
                handle,
            )

    def tearDown(self):
        self.temporary_directory.cleanup()

    def run_importer(self, *arguments):
        return subprocess.run(
            [
                "python3", str(IMPORTER), "--source", str(self.source),
                "--output-dir", str(self.output), *arguments,
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    def test_default_import_does_not_copy_private_identity(self):
        result = self.run_importer()

        self.assertFalse((self.output / "client_identity.debug.json").exists())
        self.assertIn("private key was not copied", result.stdout)
        self.assertNotIn("BEGIN PRIVATE KEY", result.stdout)

    def test_explicit_identity_import_matches_swift_codable_and_permissions(self):
        first = self.run_importer("--include-client-identity")
        identity_path = self.output / "client_identity.debug.json"
        payload = json.loads(identity_path.read_text(encoding="utf-8"))
        first_id = payload["id"]

        self.assertGreater(len(base64.b64decode(payload["certificateDER"])), 700)
        self.assertGreater(len(base64.b64decode(payload["privateKeyDER"])), 1000)
        self.assertIsInstance(payload["createdAt"], (int, float))
        self.assertEqual(os.stat(self.output).st_mode & 0o777, 0o700)
        self.assertEqual(os.stat(identity_path).st_mode & 0o777, 0o600)
        self.assertIn("wire ID 0123456789ABCDEF", first.stdout)
        self.assertNotIn("BEGIN PRIVATE KEY", first.stdout)

        self.run_importer("--include-client-identity")
        repeated = json.loads(identity_path.read_text(encoding="utf-8"))
        self.assertEqual(repeated["id"], first_id)

    def test_explicit_identity_import_rejects_mismatched_key(self):
        mismatched_key = self.root / "mismatched-key.pem"
        subprocess.run(
            ["openssl", "genpkey", "-algorithm", "RSA", "-out", str(mismatched_key)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        with self.source.open("rb") as handle:
            settings = plistlib.load(handle)
        settings["key"] = mismatched_key.read_bytes()
        with self.source.open("wb") as handle:
            plistlib.dump(settings, handle)
        self.output.mkdir(parents=True)
        identity_path = self.output / "client_identity.debug.json"
        identity_path.write_text("existing-identity", encoding="utf-8")

        result = subprocess.run(
            [
                "python3", str(IMPORTER), "--source", str(self.source),
                "--output-dir", str(self.output), "--include-client-identity",
            ],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(identity_path.read_text(encoding="utf-8"), "existing-identity")
        self.assertNotIn("BEGIN PRIVATE KEY", result.stdout + result.stderr)

    def test_explicit_identity_import_requires_exact_client_common_name(self):
        unexpected_certificate = self.root / "unexpected-certificate.pem"
        unexpected_private_key = self.root / "unexpected-private-key.pem"
        subprocess.run(
            [
                "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                "-subj", "/CN=NVIDIA GameStream Client Extra", "-days", "1",
                "-keyout", str(unexpected_private_key), "-out", str(unexpected_certificate),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        with self.source.open("rb") as handle:
            settings = plistlib.load(handle)
        settings["certificate"] = unexpected_certificate.read_bytes()
        settings["key"] = unexpected_private_key.read_bytes()
        with self.source.open("wb") as handle:
            plistlib.dump(settings, handle)

        result = subprocess.run(
            [
                "python3", str(IMPORTER), "--source", str(self.source),
                "--output-dir", str(self.output), "--include-client-identity",
            ],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.output / "client_identity.debug.json").exists())
        self.assertIn("unexpected subject", result.stderr)
        self.assertNotIn("BEGIN PRIVATE KEY", result.stdout + result.stderr)

    def test_identity_only_preserves_existing_product_data(self):
        self.output.mkdir(parents=True)
        hosts_path = self.output / "hosts.json"
        legacy_identity_path = self.output / "moonlight_qt_identity.json"
        hosts_path.write_text("sentinel", encoding="utf-8")
        legacy_identity_path.write_text("legacy-private-identity", encoding="utf-8")

        result = self.run_importer("--include-client-identity", "--identity-only")

        self.assertEqual(hosts_path.read_text(encoding="utf-8"), "sentinel")
        self.assertTrue((self.output / "client_identity.debug.json").exists())
        self.assertFalse((self.output / "settings.json").exists())
        self.assertFalse((self.output / "app_catalog.json").exists())
        self.assertFalse(legacy_identity_path.exists())
        self.assertIn("identity only", result.stdout)


if __name__ == "__main__":
    unittest.main()
