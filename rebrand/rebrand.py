#!/usr/bin/env python3
"""Apply the Ghostline brand to a COPY of the upstream Tailscale client source.

    python3 -I rebrand/rebrand.py --source WORK_COPY [--brand brand.json] [--rules rebrand/rules.json]
    python3 -I rebrand/rebrand.py --source WORK_COPY --verify

rules.json lists exact text replacements ("old" -> "new") in named files of the upstream tree. "new" may use
{{Variable}} placeholders filled from brand.json (and the derived ControlURL, ControlHost and NrptRuleGuid). A rule
with "when" applies only if that brand value is set; a rule with "optional" may find nothing. Every other "old" text
must be present, so an upstream change cannot silently skip a privacy edit. The tool refuses to touch a tree that
was already rebranded and writes a stamp (.ghostline-rebrand-stamp) last; --verify checks that stamp.
Standard library only.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
STAMP = ".ghostline-rebrand-stamp"
NAME_RE = re.compile(r"[A-Za-z][A-Za-z0-9_-]{0,63}")
WORD_RE = re.compile(r"[A-Za-z][A-Za-z0-9]*")
CONTROL_RE = re.compile(r"https://[A-Za-z0-9.-]+(?::[0-9]{1,5})?")
HOST_RE = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?")
UPDATE_URL_RE = re.compile(r"https://[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?(?::[0-9]{1,5})?(?:/[A-Za-z0-9._~-]+)*")
GUID_RE = re.compile(r"\{[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\}")
# Characters that could end or escape a Go string literal: brand values are substituted into Go source.
UNSAFE_VALUE = re.compile(r'["\\`\x00-\x1f]')
NRPT_NAMESPACE = uuid.UUID("9e8099f5-cdf6-49f4-ac6e-d8531a20ce00")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def canonical(obj):
    return sha256(json.dumps(obj, sort_keys=True, separators=(",", ":")).encode())


def load_brand(path):
    brand = json.loads(Path(path).read_text(encoding="utf-8"))
    for key in ("ProductName", "DataDirName", "ServiceName", "CliName"):
        v = brand.get(key)
        if not isinstance(v, str) or not NAME_RE.fullmatch(v) or "tailscale" in v.lower():
            raise ValueError("brand.json %s must be a plain name (and not the upstream product name)" % key)
    for key in ("ServiceName", "CliName"):
        if not WORD_RE.fullmatch(brand[key]):
            raise ValueError("brand.json %s must be letters and digits only" % key)
    if not CONTROL_RE.fullmatch(brand.get("DefaultControlURL", "")):
        raise ValueError("brand.json DefaultControlURL must be https://host[:port] with no path")
    if not GUID_RE.fullmatch(brand.get("WintunGuid", "")):
        raise ValueError("brand.json WintunGuid is not a {GUID}")
    if brand.get("LogHost") and not HOST_RE.fullmatch(brand["LogHost"]):
        raise ValueError("brand.json LogHost must be empty or a bare host name")
    if brand.get("UpdateBaseURL") and not UPDATE_URL_RE.fullmatch(brand["UpdateBaseURL"]):
        raise ValueError("brand.json UpdateBaseURL must be empty or an https URL")
    brand["ControlURL"] = brand["DefaultControlURL"]
    brand["ControlHost"] = brand["ControlURL"].removeprefix("https://")
    brand["NrptRuleGuid"] = "{%s}" % uuid.uuid5(NRPT_NAMESPACE, brand["ProductName"] + "/" + brand["DataDirName"])
    return brand


def target(root, rel):
    p = Path(rel)
    if p.is_absolute() or ".." in p.parts or "\\" in rel:
        raise ValueError("unsafe path in rules.json: " + rel)
    full = root / p
    for c in (full, *full.parents):
        if c == root:
            break
        if c.is_symlink():
            raise ValueError("symbolic link in a rebrand target: " + rel)
    return full


def plan(root, brand, rules):
    """{relative path: new bytes} for every file the rules change."""
    edits = {}
    for rule in rules:
        if rule.get("when") and not brand.get(rule["when"]):
            continue
        if not rule.get("old"):
            raise ValueError("rule with an empty 'old' text")
        files = list(rule.get("files", []))
        if rule.get("glob"):
            files += [p.relative_to(root).as_posix() for p in sorted(root.glob(rule["glob"]))
                      if p.is_file() and not p.name.endswith("_test.go")]
        for rel in files:
            path = target(root, rel)
            if not path.is_file():
                raise ValueError("missing file in the source copy: " + rel)
            text = edits.get(rel) or path.read_bytes().decode("utf-8")
            if rule["old"] not in text:
                if rule.get("optional"):
                    continue
                raise ValueError("text not found in %s: %s" % (rel, rule["old"][:60]))

            def value(m):
                v = brand.get(m[1])
                if not isinstance(v, str) or UNSAFE_VALUE.search(v):
                    raise ValueError("brand value %s is missing or unsafe for Go source" % m[1])
                return v
            edits[rel] = text.replace(rule["old"], re.sub(r"\{\{(\w+)\}\}", value, rule["new"]))
    return {rel: t.encode("utf-8") for rel, t in edits.items()}


def apply(root, brand_path, rules_path):
    root = Path(root).resolve()
    if not (root / "ipn" / "prefs.go").is_file():
        raise ValueError("%s is not the upstream client source" % root)
    if (root / STAMP).exists():
        raise ValueError("%s is already rebranded; start from a fresh copy" % root)
    brand = load_brand(brand_path)
    rules_doc = json.loads(Path(rules_path).read_text(encoding="utf-8"))
    edits = plan(root, brand, rules_doc["rules"])
    for rel, data in edits.items():
        target(root, rel).write_bytes(data)
    (root / STAMP).write_text(json.dumps({
        "format": 1,
        "brand_sha256": canonical(json.loads(Path(brand_path).read_text(encoding="utf-8"))),
        "rules_sha256": canonical(rules_doc),
        "files": {rel: sha256(data) for rel, data in sorted(edits.items())},
    }, indent=1) + "\n")
    return len(edits)


def verify(root, brand_path, rules_path):
    root = Path(root).resolve()
    try:
        stamp = json.loads((root / STAMP).read_text())
    except (OSError, ValueError):
        return ["no rebrand stamp: this copy was not (completely) rebranded"]
    problems = []
    if stamp.get("brand_sha256") != canonical(json.loads(Path(brand_path).read_text(encoding="utf-8"))):
        problems.append("brand.json changed since the rebrand")
    if stamp.get("rules_sha256") != canonical(json.loads(Path(rules_path).read_text(encoding="utf-8"))):
        problems.append("rules.json changed since the rebrand")
    for rel, digest in stamp.get("files", {}).items():
        try:
            if sha256(target(root, rel).read_bytes()) != digest:
                problems.append("changed after the rebrand: " + rel)
        except (OSError, ValueError):
            problems.append("missing after the rebrand: " + rel)
    return problems


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", required=True, type=Path)
    ap.add_argument("--brand", type=Path, default=ROOT / "brand.json")
    ap.add_argument("--rules", type=Path, default=HERE / "rules.json")
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()
    try:
        if a.verify:
            problems = verify(a.source, a.brand, a.rules)
            for p in problems:
                print("NOT REBRANDED: " + p, file=sys.stderr)
            return 1 if problems else 0
        n = apply(a.source, a.brand, a.rules)
        print("rebranded %d files in %s" % (n, a.source))
        return 0
    except (OSError, ValueError) as e:
        print("rebrand: " + str(e), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
