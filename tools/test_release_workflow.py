#!/usr/bin/env python3
"""Textual fail-closed release invariants; checks before workflows are allowed to run."""
import re
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def sections():
    data = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
    chunks = re.split(r"(?m)^  ([a-z][a-z-]+):\s*$", data)
    return data, {chunks[i]: chunks[i + 1] for i in range(1, len(chunks) - 1, 2)}


class ReleaseGuards(unittest.TestCase):
    def test_manual_only(self):
        full, _ = sections()
        self.assertRegex(full, r"(?m)^on:\n  workflow_dispatch:")
        self.assertNotRegex(full, r"(?m)^  push:")
        self.assertNotRegex(full, r"(?m)^\s+tags:\s*\[.*v\*")

    def test_required_jobs_present(self):
        _, jobs = sections()
        self.assertGreaterEqual(len(jobs), 7)
        for name in ("release-prerequisites", "desktop", "android", "android-sign",
                     "package", "windows-acceptance", "manifest-sign"):
            self.assertIn(name, jobs)

    def test_no_secret_bearing_build_jobs(self):
        _, jobs = sections()
        for name in ("desktop", "android", "package"):
            self.assertNotIn("environment: release", jobs[name])
            self.assertNotIn("secrets.", jobs[name])
        self.assertIn("environment: release", jobs["android-sign"])
        self.assertIn("environment: release", jobs["manifest-sign"])

    def test_isolated_android_signer(self):
        _, jobs = sections()
        text = jobs["android-sign"]
        for required in ("ANDROID_KEYSTORE_B64", "ANDROID_KEYSTORE_PASSWORD",
                         "ANDROID_SIGNING_CERT_SHA256", "apksigner", "verify --verbose --print-certs"):
            self.assertIn(required, text)
        self.assertNotIn("actions/checkout@", text)
        self.assertNotIn("./gradlew", text)
        self.assertNotIn("gomobile", text)

    def test_windows_publisher_gate(self):
        _, jobs = sections()
        text = jobs["windows-acceptance"]
        self.assertIn("Get-AuthenticodeSignature", text)
        self.assertIn("WINDOWS_SIGNING_CERT_THUMBPRINT", text)
        self.assertIn("Status -ne 'Valid'", text)

    def test_manifest_signer_isolated(self):
        _, jobs = sections()
        text = jobs["manifest-sign"]
        self.assertIn("ssh-keygen -Y sign", text)
        self.assertIn("ssh-keygen -Y verify", text)
        self.assertIn("RELEASE_SIGNING_KEY", text)
        self.assertNotIn("actions/checkout@", text)
        self.assertNotIn("packaging/sign-release.sh", text)

    def test_package_must_be_production_mode(self):
        _, jobs = sections()
        self.assertIn("packaging/package.py --production", jobs["package"])
        self.assertIn("needs: [desktop, android-sign]", jobs["package"])

    def test_release_gate_cannot_succeed_unconditionally(self):
        _, jobs = sections()
        self.assertIn("exit 1", jobs["release-prerequisites"])


if __name__ == "__main__":
    unittest.main()
