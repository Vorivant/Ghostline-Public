#!/usr/bin/env python3
"""Offline production packaging precondition tests; no signing credentials required."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "packaging" / "package.py"


class PackageGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.build = self.base / "build"
        self.licenses = self.base / "licences"
        self.out = self.base / "release"

    def execute(self, *extra):
        return subprocess.run(
            [sys.executable, "-I", str(SCRIPT), "--production", "--build", str(self.build),
             "--licences", str(self.licenses), "--out", str(self.out), *extra],
            cwd=ROOT, text=True, capture_output=True,
        )

    def make_targets(self):
        for t in ("windows-amd64", "linux-amd64", "linux-arm64"):
            (self.build / t).mkdir(parents=True)

    def make_license_indices(self):
        for t in ("windows-amd64", "linux-amd64", "linux-arm64"):
            d = self.licenses / t
            d.mkdir(parents=True)
            (d / "INDEX.md").write_text("Test inventory only")

    def test_refuses_incomplete_target_matrix(self):
        r = self.execute()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("missing desktop targets", r.stderr + r.stdout)

    def test_refuses_missing_licenses(self):
        self.make_targets()
        r = self.execute()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("license inventory", (r.stderr + r.stdout).replace("licence", "license"))

    def test_refuses_missing_android_apk(self):
        self.make_targets()
        self.make_license_indices()
        r = self.execute()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("signed Android APK", r.stderr + r.stdout)

    def test_refuses_unpinned_android_certificate(self):
        self.make_targets()
        self.make_license_indices()
        apk = self.base / "Android.apk"
        apk.write_bytes(b"not-a-real-apk")
        r = self.execute("--apk", str(apk))
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("android-cert-sha256", r.stderr + r.stdout)

    def test_rejects_invalid_certificate_pin(self):
        self.make_targets()
        self.make_license_indices()
        apk = self.base / "Android.apk"
        apk.write_bytes(b"not-a-real-apk")
        r = self.execute("--apk", str(apk), "--apksigner", "/missing",
                         "--aapt2", "/missing", "--android-cert-sha256", "unknown")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("64 hex digits", r.stderr + r.stdout)


if __name__ == "__main__":
    unittest.main()
