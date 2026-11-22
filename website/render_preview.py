#!/usr/bin/env python3
"""Fill download.template.html with fake sample values into preview.html (stdlib only)."""
import pathlib, re

here = pathlib.Path(__file__).resolve().parent
html = (here / "download.template.html").read_text(encoding="utf-8")

values = {"VERSION": "1.0.0", "CORE_VERSION": "1.104.5", "RELEASE_DATE": "2026-01-01"}
files = {
    "windows_amd64": "Ghostline-1.0.0-windows-amd64.zip",
    "linux_amd64": "Ghostline-1.0.0-linux-amd64.tar.gz",
    "linux_arm64": "Ghostline-1.0.0-linux-arm64.tar.gz",
    "android": "Ghostline-1.0.0-android.apk",
    "server_kit": "Ghostline-1.0.0-server-kit.tar.gz",
    "source": "Ghostline-1.0.0-source.tar.gz",
}
for key, name in files.items():
    values["FILE_" + key] = name
    values["SIZE_" + key] = "0 MB"
    values["SHA256_" + key] = "0" * 64

out = re.sub(r"\{\{(\w+)\}\}", lambda m: values.get(m.group(1), m.group(0)), html)
left = re.findall(r"\{\{\w+\}\}", out)
if left:
    raise SystemExit("Unfilled placeholders: %s" % sorted(set(left)))
(here / "preview.html").write_text(out, encoding="utf-8")
print("Wrote", here / "preview.html")
