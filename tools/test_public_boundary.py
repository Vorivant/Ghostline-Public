#!/usr/bin/env python3
"""Fast offline regression tests for the public-only boundary gate."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

CHECK = Path(__file__).with_name("check_public_boundary.py")
spec = importlib.util.spec_from_file_location("check_public_boundary", CHECK)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class BoundaryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / ".github/workflows").mkdir(parents=True)
        (self.root / ".github/workflows/release.yml").write_text("on:\n  workflow_dispatch:\njobs:\n  release-prerequisites:\n", encoding="utf-8")
        self.brand = {
            "DefaultControlURL": "https://enter-your-server.invalid",
            "DerpHostnames": [],
            "LogHost": "",
            "UpdateBaseURL": "",
        }
        self.save_brand()

    def save_brand(self):
        (self.root / "brand.json").write_text(json.dumps(self.brand), encoding="utf-8")

    def test_clean_source(self):
        self.assertEqual(gate.audit(self.root), [])

    def test_unapproved_control_host_is_rejected(self):
        self.brand["DefaultControlURL"] = "https://host.example.test"
        self.save_brand()
        self.assertTrue(gate.audit(self.root))

    def test_external_relay_or_telemetry_hosts_are_rejected(self):
        self.brand["LogHost"] = "logging.example.test"
        self.save_brand()
        self.assertTrue(gate.audit(self.root))

    def test_automatic_tag_release_is_rejected(self):
        (self.root / ".github/workflows/release.yml").write_text(
            "on:\n  push:\n    tags: ['v*']\njobs:\n  release-prerequisites:\n", encoding="utf-8")
        self.assertTrue(gate.audit(self.root))

    def test_env_and_credentials_are_rejected(self):
        (self.root / ".env").write_text("TOKEN=fake", encoding="utf-8")
        self.assertTrue(gate.audit(self.root))

    def test_unsafe_symlink_rejected(self):
        target = self.root / "note.txt"
        target.write_text("okay")
        (self.root / "linked.txt").symlink_to(target)
        self.assertTrue(gate.audit(self.root))


if __name__ == "__main__":
    unittest.main()
