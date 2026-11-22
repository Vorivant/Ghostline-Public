# shellcheck shell=bash
# Sourced by install.sh, uninstall.sh and join.sh: reads brand.json next to the scripts (the unpacked download).
_GL_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }
GL_BRAND_FILE="$_GL_HERE/brand.json"
[ -f "$GL_BRAND_FILE" ] || { echo "brand.json not found next to the scripts" >&2; exit 1; }
gl_brand() { python3 -I -c 'import json,sys; v=json.load(open(sys.argv[1],encoding="utf-8")).get(sys.argv[2]); print("" if v is None else v)' "$GL_BRAND_FILE" "$1"; }
GL_SERVICE="$(gl_brand ServiceName)"
GL_CLI="$(gl_brand CliName)"
GL_PRODUCT="$(gl_brand ProductName)"
if ! [[ "$GL_SERVICE" =~ ^[A-Za-z][A-Za-z0-9]*$ && "$GL_CLI" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
  echo "brand.json: ServiceName and CliName must be letters and digits" >&2; exit 1
fi
# Fixed by the rebrand rules (socket and state paths of the Linux daemon).
GL_STATE_DIR_NAME="ghostline"
GL_SOCKET="/run/ghostline/ghostlined.sock"
GL_PORT=41641
