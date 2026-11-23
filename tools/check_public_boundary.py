#!/usr/bin/env python3
"""Public-only source invariants. No private deployment values are stored here."""
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
# Construct known component signatures without embedding private markers in exported source.
SEGMENTS = ("privacy" + "-vpn", "tal" + "pid", "mull" + "vad-daemon",
            "ghostline" + "-vpnd", "mull" + "vad_daemon::", "libtailscale/mull" + "vad",
            "api.mull" + "vad.net", "personal-mull" + "vad")
NAME_PAT = re.compile(r"(?i)(?:^|[/_.-])(?:" + "|".join(re.escape(s) for s in SEGMENTS[:4]) +
                      r")(?:[/_.-]|$)")
BYTE_PAT = re.compile("|".join(re.escape(s) for s in SEGMENTS).encode(), re.I)
CRED_PAT = re.compile(r"(?i)(?:^|/)(?:\.env|ghostline\.config\.json|id_rsa|id_ed25519|"
                      r".*\.(?:p12|pfx|pem|jks|keystore))$")
TEXT = {".py", ".sh", ".ps1", ".go", ".json", ".yaml", ".yml", ".md", ".txt"}
SKIP = {".git", "dist", ".work", "__pycache__"}


def audit(root):
    errors = []
    brand = json.loads((root / "brand.json").read_text(encoding="utf-8"))
    if brand.get("DefaultControlURL") != "https://enter-your-server.invalid":
        errors.append("unexpected default coordination URL")
    if brand.get("DerpHostnames") != [] or brand.get("LogHost") or brand.get("UpdateBaseURL"):
        errors.append("public relay, log or update hosts configured")
    release = (root / ".github/workflows/release.yml").read_text(encoding="utf-8")
    if re.search(r"(?m)^\s+tags:\s*\[.v\*.\]", release):
        errors.append("automatic release tag trigger enabled")
    if "release-prerequisites:" not in release:
        errors.append("explicit release-readiness gate missing")
    for p in sorted(root.rglob("*")):
        rel = p.relative_to(root)
        if any(part in SKIP for part in rel.parts):
            continue
        path = rel.as_posix()
        if p.is_symlink():
            errors.append("symlink: " + path)
        elif p.is_file():
            if NAME_PAT.search(path) or CRED_PAT.search(path):
                errors.append("forbidden file name: " + path)
            if p.suffix.lower() in TEXT and path != "tools/check_public_boundary.py" and not path.endswith(".patch"):
                if BYTE_PAT.search(p.read_bytes()):
                    errors.append("forbidden component reference: " + path)
    return errors


if __name__ == "__main__":
    findings = audit(ROOT)
    for finding in findings:
        print("PUBLIC BOUNDARY:", finding, file=sys.stderr)
    print("Public boundary:", "FAIL" if findings else "PASS")
    sys.exit(bool(findings))
