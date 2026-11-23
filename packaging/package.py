#!/usr/bin/env python3
"""Assemble the release files of a Ghostline version from the build outputs.

    python3 -I packaging/package.py --build dist/build [--licences dist/licences] [--apk FILE] --out dist/release
        [--date YYYY-MM-DD] [--signing-pub FILE]

--build holds build.sh's per-target folders (linux-amd64, linux-arm64, windows-amd64; any that exist are packaged).
--licences holds collect_go_licences.py output per target (dist/licences/<target>/), copied into each download.
--apk is the signed Android app. --signing-pub is the public half of the SSH key that signs SHA256SUMS
(packaging/sign-release.sh); it is copied next to the files for the download page.

Writes into --out: Ghostline-<version>-<target>.tar.gz / .zip, Ghostline-<version>-android.apk,
Ghostline-<version>-server-kit.tar.gz, Ghostline-<version>-source.tar.gz (this repository's committed files),
SHA256SUMS, THIRD-PARTY-NOTICES.md, and the download page (download.html + assets/) filled in with the real names,
sizes and SHA-256 digests. Archives are reproducible: sorted entries, fixed owner and SOURCE_DATE_EPOCH times.
"""
import argparse
import datetime
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EPOCH = int(os.environ.get("SOURCE_DATE_EPOCH", "1767225600"))   # 2026-01-01 when not set
COMMON = ["LICENSE", "THIRD-PARTY-NOTICES.md"]


def human(n):
    return "%.1f MB" % (n / 1e6) if n >= 1e5 else "%d KB" % max(1, n // 1000)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def gather(target, build, licences):
    """[(name in archive, source path, executable)] for one desktop download."""
    os_name = target.split("-")[0]
    items = []
    for p in sorted((build / target).iterdir()):
        items.append((p.name, p, os.access(p, os.X_OK) or p.suffix in ("", ".exe")))
    if os_name == "linux":
        for n in ("install.sh", "uninstall.sh", "join.sh", "_brand.sh"):
            items.append((n, ROOT / "client/linux" / n, n.endswith(".sh") and not n.startswith("_")))
    else:
        for n in ("install.ps1", "uninstall.ps1", "join.ps1", "_brand.ps1", "_acl.ps1"):
            items.append((n, ROOT / "client/windows" / n, False))
    for n in COMMON:
        items.append((n, ROOT / n, False))
    items.append(("README.txt", ROOT / ("packaging/README-%s.txt" % os_name), False))
    lic = licences / target if licences else None
    if lic and lic.is_dir():
        for p in sorted(lic.rglob("*")):
            if p.is_file():
                items.append(("licenses/" + p.relative_to(lic).as_posix(), p, False))
    elif licences:
        sys.exit("no Go module licences for %s in %s" % (target, licences))
    names = [n for n, _, _ in items]
    if len(names) != len(set(names)):
        sys.exit("duplicate file in the %s download" % target)
    return items


def write_tar(dest, top, items):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w", format=tarfile.PAX_FORMAT) as t:
        for name, src, x in sorted(items, key=lambda i: i[0]):
            data = Path(src).read_bytes()
            info = tarfile.TarInfo(top + "/" + name)
            info.size, info.mtime, info.mode = len(data), EPOCH, 0o755 if x else 0o644
            info.uid = info.gid = 0
            info.uname = info.gname = "root"
            t.addfile(info, io.BytesIO(data))
    with open(dest, "wb") as f, gzip.GzipFile(fileobj=f, mode="wb", mtime=EPOCH, filename="") as g:
        g.write(buf.getvalue())


def write_zip(dest, top, items):
    stamp = datetime.datetime.fromtimestamp(EPOCH, datetime.timezone.utc).timetuple()[:6]
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for name, src, _ in sorted(items, key=lambda i: i[0]):
            info = zipfile.ZipInfo(top + "/" + name, stamp)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, Path(src).read_bytes())


def committed_files():
    r = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True)
    if r.returncode != 0:
        sys.exit("the source download needs a git checkout of this repository")
    return [n for n in r.stdout.decode().split("\0") if n]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--build", required=True, type=Path)
    ap.add_argument("--licences", type=Path)
    ap.add_argument("--apk", type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--date", default=datetime.datetime.fromtimestamp(EPOCH, datetime.timezone.utc).strftime("%Y-%m-%d"))
    ap.add_argument("--signing-pub", type=Path)
    ap.add_argument("--production", action="store_true", help="require every intended platform and a verified APK")
    ap.add_argument("--apksigner", type=Path, help="Android SDK apksigner binary, required with --production")
    ap.add_argument("--aapt2", type=Path, help="Android SDK aapt2 binary, required with --production")
    ap.add_argument("--android-cert-sha256", help="pinned APK signer certificate digest, required with --production")
    a = ap.parse_args()
    version = (ROOT / "VERSION").read_text().strip()
    core = json.loads((ROOT / "upstream.json").read_text())["tailscale"]["tag"].lstrip("v")
    if a.production:
        required = ("windows-amd64", "linux-amd64", "linux-arm64")
        missing_targets = [t for t in required if not (a.build / t).is_dir()]
        if missing_targets:
            sys.exit("production: missing desktop targets: " + ", ".join(missing_targets))
        if not a.licences or any(not (a.licences / t / "INDEX.md").is_file() for t in required):
            sys.exit("production: missing complete per-target Go licence inventory")
        if not a.apk or not a.apk.is_file():
            sys.exit("production: a signed Android APK is required")
        if not (a.apksigner and a.aapt2 and a.android_cert_sha256):
            sys.exit("production: --apksigner, --aapt2 and --android-cert-sha256 are required")
        expected = a.android_cert_sha256.lower().replace(":", "")
        if not re.fullmatch(r"[a-f0-9]{64}", expected):
            sys.exit("production: expected Android signer fingerprint must be 64 hex digits")
        verified = subprocess.run([str(a.apksigner), "verify", "--verbose", "--print-certs", str(a.apk)],
                                  capture_output=True, text=True)
        if verified.returncode:
            sys.exit("production: APK signature verification failed: " + verified.stderr[-500:])
        match = re.search(r"Signer #1 certificate SHA-256 digest:\s*([a-fA-F0-9:]+)", verified.stdout)
        if not match or match.group(1).lower().replace(":", "") != expected:
            sys.exit("production: APK certificate does not match reviewed fingerprint")
        badging = subprocess.run([str(a.aapt2), "dump", "badging", str(a.apk)],
                                 capture_output=True, text=True)
        if badging.returncode or not re.search(r"^package: name='com\.vorivant\.ghostline'(?:\s|$)", badging.stdout, re.M):
            sys.exit("production: APK package identity is incorrect or unreadable")
        if not (ROOT / "legal" / "ANDROID-LICENSES-VERIFIED.md").is_file():
            sys.exit("production: Android dependency and Go core license inventory has not been accepted")
    out = a.out
    if out.exists() and any(out.iterdir()):
        sys.exit("%s is not empty" % out)
    out.mkdir(parents=True, exist_ok=True)
    files = {}
    for target, key in (("windows-amd64", "windows_amd64"), ("linux-amd64", "linux_amd64"), ("linux-arm64", "linux_arm64")):
        if not (a.build / target).is_dir():
            continue
        top = "Ghostline-%s-%s" % (version, target)
        items = gather(target, a.build, a.licences)
        dest = out / (top + (".zip" if target.startswith("windows") else ".tar.gz"))
        (write_zip if target.startswith("windows") else write_tar)(dest, top, items)
        files[key] = dest
    if a.apk:
        if not a.apk.is_file():
            sys.exit("Android APK path does not exist")
        if a.apk.name.endswith("-unsigned.apk"):
            sys.exit("refusing to package an unsigned APK: Android cannot install it")
        dest = out / ("Ghostline-%s-android.apk" % version)
        shutil.copyfile(a.apk, dest)
        files["android"] = dest
    top = "Ghostline-%s-server-kit" % version
    kit = [(p.relative_to(ROOT / "server").as_posix(), p, os.access(p, os.X_OK))
           for p in sorted((ROOT / "server").rglob("*")) if p.is_file()]
    kit += [(n, ROOT / n, False) for n in COMMON] + [("LICENSE-headscale-BSD-3.txt", ROOT / "legal/LICENSE-headscale-BSD-3.txt", False)]
    files["server_kit"] = out / (top + ".tar.gz")
    write_tar(files["server_kit"], top, kit)
    top = "Ghostline-%s-source" % version
    files["source"] = out / (top + ".tar.gz")
    write_tar(files["source"], top, [(n, ROOT / n, os.access(ROOT / n, os.X_OK)) for n in committed_files()])

    shutil.copyfile(ROOT / "THIRD-PARTY-NOTICES.md", out / "THIRD-PARTY-NOTICES.md")
    if a.signing_pub:
        shutil.copyfile(a.signing_pub, out / "ghostline-release-signing.pub")
    sums = sorted(p for p in out.iterdir() if p.is_file())
    (out / "SHA256SUMS").write_text("".join("%s  %s\n" % (sha256(p), p.name) for p in sums))

    values = {"VERSION": version, "CORE_VERSION": core, "RELEASE_DATE": a.date}
    for key in ("windows_amd64", "linux_amd64", "linux_arm64", "android", "server_kit", "source"):
        p = files.get(key)
        values["FILE_" + key] = p.name if p else "#not-in-this-release"
        values["SIZE_" + key] = human(p.stat().st_size) if p else "not available"
        values["SHA256_" + key] = sha256(p) if p else "not available"
    page = (ROOT / "website/download.template.html").read_text(encoding="utf-8")
    page = re.sub(r"\{\{(\w+)\}\}", lambda m: values[m.group(1)], page)
    if "{{" in page:
        sys.exit("download page: a placeholder is left after filling it in")
    (out / "download.html").write_text(page, encoding="utf-8")
    shutil.copytree(ROOT / "website/assets", out / "assets")
    missing = [k for k in ("windows_amd64", "linux_amd64", "linux_arm64", "android") if k not in files]
    for p in sorted(out.iterdir()):
        print("%10s  %s" % (human(p.stat().st_size) if p.is_file() else "dir", p.name))
    if missing:
        print("NOTE: not in this release: " + ", ".join(missing) + " (the download page marks them unavailable)")


if __name__ == "__main__":
    main()
