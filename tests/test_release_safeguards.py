#!/usr/bin/env python3
"""Static release-safeguard regression checks. No signing keys or network needed."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ReleaseSafeguards(unittest.TestCase):
    def test_proxy_strips_untrusted_source_ip(self):
        caddy = (ROOT / "server/Caddyfile").read_text()
        self.assertIn("header_up -True-Client-IP", caddy)
        self.assertIn("header_up X-Forwarded-For {remote_host}", caddy)
        self.assertIn("header_up X-Real-IP {remote_host}", caddy)

    def test_release_fails_closed_without_signing(self):
        release = (ROOT / ".github/workflows/release.yml").read_text()
        self.assertIn('echo "::error::Android signing secrets are required for a release"', release)
        self.assertIn('echo "::error::RELEASE_SIGNING_KEY is required"', release)
        self.assertIn("test -s dist/release/SHA256SUMS.sig", release)
        self.assertIn("test -s dist/release/ghostline-release-signing.pub", release)
        self.assertIn("apksigner\" verify --verbose --print-certs", release)

    def test_release_does_not_auto_publish(self):
        release = (ROOT / ".github/workflows/release.yml").read_text()
        self.assertNotIn("gh release create", release)
        self.assertNotIn("pages deploy", release)


if __name__ == "__main__":
    unittest.main()
