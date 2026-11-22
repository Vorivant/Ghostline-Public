#!/usr/bin/env bash
# Build the Ghostline desktop clients (daemon `ghostlined` + command `ghostline`) from the pinned upstream source.
#
#   ./build.sh [--target linux-amd64|linux-arm64|windows-amd64|all]... [--out DIR] [--work DIR] [--upstream DIR]
#
# 1. Gets the upstream client source at the commit pinned in upstream.json (git clone, or --upstream DIR, an
#    existing checkout that must be at that commit) and copies it to a work directory.
# 2. Applies the Ghostline brand and privacy edits (rebrand/rebrand.py with brand.json and rebrand/rules.json) to
#    the copy, and stamps the Windows icon and version resources (rebrand/winres.go.txt).
# 3. Builds each target with CGO off, -trimpath and the privacy build tags below, and writes
#    OUT/<target>/ with the binaries, brand.json and the upstream licence and patent texts. Windows targets also get
#    the unmodified wintun.dll from the pinned official zip (SHA-256 checked) and its licence.
# Needs: bash, git, python3, curl (Windows targets), unzip and exactly the Go version in upstream.json
# (GOTOOLCHAIN=local: no automatic toolchain download).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
pin() { python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d=d[k]
print(d)' "$HERE/upstream.json" "$1"; }

TARGETS=(); OUT="$HERE/dist/build"; WORK="$HERE/.work"; UPSTREAM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGETS+=("${2:?--target needs a value}"); shift 2 ;;
    --out) OUT="${2:?}"; shift 2 ;;
    --work) WORK="${2:?}"; shift 2 ;;
    --upstream) UPSTREAM="${2:?}"; shift 2 ;;
    -h|--help) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
done
[ ${#TARGETS[@]} -gt 0 ] || TARGETS=(all)
if [ "${TARGETS[*]}" = all ]; then TARGETS=(linux-amd64 linux-arm64 windows-amd64); fi
for t in "${TARGETS[@]}"; do
  case "$t" in linux-amd64|linux-arm64|windows-amd64) ;; *) echo "unsupported target: $t" >&2; exit 2 ;; esac
done

export GOTOOLCHAIN=local CGO_ENABLED=0
GO_WANT="go$(pin go)"
[ "$(go env GOVERSION)" = "$GO_WANT" ] || { echo "need $GO_WANT, found $(go env GOVERSION)" >&2; exit 1; }
COMMIT="$(pin tailscale.commit)"
mkdir -p "$WORK" "$OUT"
WORK="$(cd "$WORK" && pwd)"; OUT="$(cd "$OUT" && pwd)"

echo "== upstream source $(pin tailscale.tag) ($COMMIT)"
if [ -z "$UPSTREAM" ]; then
  UPSTREAM="$WORK/upstream"
  if [ ! -d "$UPSTREAM/.git" ]; then
    git clone -q --depth 1 -b "$(pin tailscale.tag)" "$(pin tailscale.repo)" "$UPSTREAM"
  fi
fi
got="$(git -C "$UPSTREAM" rev-parse HEAD)"
[ "$got" = "$COMMIT" ] || { echo "upstream checkout is at $got, expected $COMMIT" >&2; exit 1; }
[ -z "$(git -C "$UPSTREAM" status --porcelain)" ] || { echo "upstream checkout $UPSTREAM has local changes" >&2; exit 1; }

SRC="$WORK/src"
rm -rf "$SRC"
mkdir -p "$SRC"
git -C "$UPSTREAM" archive --format=tar HEAD | tar -x -C "$SRC"
echo "== rebrand"
python3 -I "$HERE/rebrand/rebrand.py" --source "$SRC" --brand "$HERE/brand.json" --rules "$HERE/rebrand/rules.json"

eval "$(python3 -I - "$HERE/brand.json" <<'PY'
import json, re, shlex, sys
b = json.load(open(sys.argv[1], encoding="utf-8"))
for k in ("ProductName", "ServiceName", "CliName", "Company", "DefaultControlURL"):
    v = b.get(k, "")
    if not v or not re.fullmatch(r"[^\"\\\x00-\x1f]{1,100}", v):
        sys.exit("brand.json %s is missing or has quotes, backslashes or control characters" % k)
    print("B_%s=%s" % (k.upper(), shlex.quote(v)))
PY
)"

NEEDS_WIN=0
for t in "${TARGETS[@]}"; do case "$t" in windows-*) NEEDS_WIN=1 ;; esac; done
if [ "$NEEDS_WIN" = 1 ]; then
  echo "== Windows icon and version resources"
  VERSION="$(tr -d ' \r\n' < "$SRC/VERSION.txt")"
  COPYRIGHT="Copyright (c) $(date -u +%Y) $B_COMPANY. Based on Tailscale (BSD-3-Clause, (c) Tailscale Inc & contributors)."
  GEN="$SRC/cmd/ghostline-winres"
  mkdir -p "$GEN"; cp "$HERE/rebrand/winres.go.txt" "$GEN/main.go"
  for pair in "cmd/tailscaled:$B_SERVICENAME.exe:$B_PRODUCTNAME service" "cmd/tailscale:$B_CLINAME.exe:$B_PRODUCTNAME command-line client"; do
    d="${pair%%:*}"; rest="${pair#*:}"; exe="${rest%%:*}"; desc="${rest#*:}"
    (cd "$SRC" && GOOS= GOARCH= go run ./cmd/ghostline-winres -manifest "$d/windows-manifest.xml" \
      -ico "$HERE/assets/ico/ghostline.ico" -product "$B_PRODUCTNAME" -company "$B_COMPANY" -desc "$desc" \
      -exe "$exe" -version "$VERSION" -copyright "$COPYRIGHT" -out "$d")
  done
  rm -rf "$GEN"
  echo "== wintun $(pin wintun.url)"
  WZIP="$WORK/wintun.zip"
  [ -f "$WZIP" ] || curl -fsSL --retry 3 -o "$WZIP" "$(pin wintun.url)"
  echo "$(pin wintun.zip_sha256)  $WZIP" | sha256sum -c - >/dev/null || { echo "wintun zip SHA-256 mismatch" >&2; exit 1; }
  rm -rf "$WORK/wintun"; unzip -q -o "$WZIP" -d "$WORK"
fi

# Privacy and attack-surface omissions (the same set for every target): no log upload, network flow logs,
# self-updater, debug handlers, serve/funnel and web client, outbound proxies, ACME, SSH server, Taildrop, peer relay
# server, posture checks, cloud metadata, Kubernetes and other platform integrations, Wake-on-LAN or systray.
TAGS=ts_omit_logtail,ts_omit_netlog,ts_omit_clientupdate,ts_omit_debug,ts_omit_serve,ts_omit_webclient,ts_omit_outboundproxy,ts_omit_acme,ts_omit_ssh,ts_omit_taildrop,ts_omit_relayserver,ts_omit_posture,ts_omit_cloud,ts_omit_aws,ts_omit_kube,ts_omit_synology,ts_omit_oauthkey,ts_omit_identityfederation,ts_omit_wakeonlan,ts_omit_ace,ts_omit_flashappliance,ts_omit_tap,ts_omit_bird,ts_omit_systray
export TS_VERSION_LONG="$(pin tailscale.version_long)" TS_VERSION_GIT_HASH="$COMMIT"
MKV="$(cd "$SRC" && GOOS= GOARCH= go run -buildvcs=false ./cmd/mkversion)"
mkv() { printf '%s\n' "$MKV" | sed -n "s/^$1=\"\{0,1\}\([^\"]*\)\"\{0,1\}\$/\1/p" | head -n1; }
VLONG="$(mkv VERSION_LONG)"; VSHORT="$(mkv VERSION_SHORT)"
[ -n "$VLONG" ] && [ -n "$VSHORT" ] || { echo "mkversion gave no version" >&2; exit 1; }
LDFLAGS="-s -w -X tailscale.com/version.longStamp=$VLONG -X tailscale.com/version.shortStamp=$VSHORT"

for t in "${TARGETS[@]}"; do
  os="${t%-*}"; arch="${t#*-}"; ext=""; [ "$os" = windows ] && ext=".exe"
  dest="$OUT/$t"; rm -rf "$dest"; mkdir -p "$dest"
  echo "== build $t ($VLONG)"
  (cd "$SRC" && GOOS="$os" GOARCH="$arch" go build -buildvcs=false -tags "$TAGS" -trimpath -ldflags "$LDFLAGS" \
      -o "$dest/$B_SERVICENAME$ext" ./cmd/tailscaled)
  (cd "$SRC" && GOOS="$os" GOARCH="$arch" go build -buildvcs=false -tags "$TAGS" -trimpath -ldflags "$LDFLAGS" \
      -o "$dest/$B_CLINAME$ext" ./cmd/tailscale)
  cp "$HERE/brand.json" "$dest/brand.json"
  cp "$SRC/LICENSE" "$dest/LICENSE-tailscale-BSD-3.txt"
  cp "$SRC/PATENTS" "$dest/PATENTS-tailscale.txt"
  if [ "$os" = windows ]; then
    dll="$WORK/wintun/bin/$arch/wintun.dll"
    echo "$(pin "wintun.dll_sha256.$arch")  $dll" | sha256sum -c - >/dev/null || { echo "wintun.dll SHA-256 mismatch" >&2; exit 1; }
    cp "$dll" "$dest/wintun.dll"
    cp "$WORK/wintun/LICENSE.txt" "$dest/LICENSE-wintun.txt"
  fi
  # Checks: the brand's control URL is compiled in (the upstream name stays only in comparisons, never as the
  # default), and every privacy tag is in the build info.
  grep -aqF "$B_DEFAULTCONTROLURL" "$dest/$B_CLINAME$ext" || { echo "$B_DEFAULTCONTROLURL is not in $B_CLINAME$ext: rebrand missing" >&2; exit 1; }
  for bin in "$B_SERVICENAME$ext" "$B_CLINAME$ext"; do
    tags="$(go version -m "$dest/$bin" | sed -n 's/.*-tags=//p')"
    for tag in ${TAGS//,/ }; do
      grep -qF "$tag" <<< "$tags" || { echo "$bin was built without $tag" >&2; exit 1; }
    done
  done
  if [ "$t" = "$(go env GOHOSTOS)-$(go env GOHOSTARCH)" ]; then "$dest/$B_CLINAME" version | head -n1; fi
  (cd "$dest" && ls -l)
done
echo "== done: $OUT"
