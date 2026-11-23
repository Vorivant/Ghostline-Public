#!/usr/bin/env python3
"""Public-only invariants. This deliberately contains no private deployment identifiers.
Check the public repository before packaging or publishing; reject private components,
unsafe defaults, accidental credentials and non-isolated release triggers.
"""
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_NAMES = re.compile(
    r"(?i)(?:^|[/_.-])(?:privacy-vpn|talpid|mullvad-daemon|ghostline-vpnd)(?:[/_.-]|$)"
)
FORBIDDEN_SOURCE = re.compile(
    r"(?i)api\.mullvad\.net|mullvad_daemon::|libtailscale/mullvad|"
    r"ghostline-vpnd|personal-mullvad|privacy-vpn"
)
SENSITIVE_NAMES = re.compile(
    r"(?i)(?:^|/)(?:\.env|ghostline\.config\.json|id_rsa|id_ed25519|"
    r".*\.(?:p12|pfx|pem|jks|keystore))$"
)
TEXT_SUFFIXES = {".py", ".sh", ".ps1", ".go", ".json", ".yaml", ".yml", ".md", ".txt"}
EXCLUDED = {".git", "dist", ".work", "__pycache__"}
EXACTLY_ALLOWED_CONTROL = "https://enter-your-server.invalid"


def audit(root):
    errors = []
    brand = json.loads((root / "brand.json").read_text(encoding="utf-8"))
    if brand.get("DefaultControlURL") != EXACTLY_ALLOWED_CONTROL:
        errors.append("brand: control URL is not the public reserved placeholder")
    if brand.get("DerpHostnames") != [] or brand.get("LogHost") or brand.get("UpdateBaseURL"):
        errors.append("brand: public relay, log or update hosts configured")
    release = (root / ".github/workflows/release.yml").read_text(encoding="utf-8")
    if re.search(r"(?m)^\s+tags:\s*\[.v\*.\]", release):
        errors.append("release: an automatic tag trigger is enabled")
    if "release-prerequisites:" not in release:
        errors.append("release: an explicit acceptance preflight is missing")
    for p in sorted(root.rglob("*")):
        rel = p.relative_to(root)
        if any(part in EXCLUDED for part in rel.parts):
            continue
        path = rel.as_posix()
        if p.is_symlink():
            errors.append("symlink: " + path)
            continue
        if not p.is_file():
            continue
        if FORBIDDEN_NAMES.search(path) or SENSITIVE_NAMES.search(path):
            errors.append("forbidden filename: " + path)
        if p.suffix.lower() in TEXT_SUFFIXES and not path.endswith(".patch"):
            raw = p.read_bytes()
            if FORBIDDEN_SOURCE.search(raw):
                errors.append("forbidden private component: " + path)
    return errors


def main():
    problems = audit(ROOT)
    for issue in problems:
        print("PUBLIC BOUNDARY:", issue, file=sys.stderr)
    if problems:
        print(f"Public boundary: FAIL ({len(problems)} findings)", file=sys.stderr)
        return 1
    print("Public boundary: PASS (generic source and release invariants)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
