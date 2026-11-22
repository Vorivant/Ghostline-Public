#!/usr/bin/env bash
# Ghostline: join this Linux machine to YOUR OWN Ghostline server (Headscale).
#
#   sudo ./join.sh --login-server https://your-server.example [--authkey-file FILE] [--hostname NAME]
#                  [--operator USER] [--no-accept-dns] [--force-reauth]
#
# --login-server   required: the https address of your server (Ghostline has no server built in).
# --authkey-file   a pre-authentication key from your server (headscale preauthkeys create ...), in a file owned by
#                  root with mode 0600. Without it the command prints a sign-in link; open it and approve this
#                  device on your server (headscale auth register ...).
# --operator USER  let USER change mesh settings without sudo.
# --no-accept-dns  do not use the DNS settings (MagicDNS names) your server pushes.
# --force-reauth   sign in again, for example to move this machine to another server.
#
# Run sudo ./install.sh first.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_brand.sh
. "$HERE/_brand.sh"

LOGIN_SERVER=""; AUTHKEY_FILE=""; HOSTNAME_ARG=""; OPERATOR=""; ACCEPT_DNS=true; FORCE_REAUTH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --login-server) LOGIN_SERVER="${2:?--login-server needs a URL}"; shift 2 ;;
    --authkey|--auth-key) echo 'A key on the command line is visible to other users. Use --authkey-file.' >&2; exit 1 ;;
    --authkey-file) AUTHKEY_FILE="${2:?--authkey-file needs a path}"; shift 2 ;;
    --hostname) HOSTNAME_ARG="${2:?--hostname needs a value}"; shift 2 ;;
    --operator) OPERATOR="${2:?--operator needs a user}"; shift 2 ;;
    --no-accept-dns) ACCEPT_DNS=false; shift ;;
    --force-reauth) FORCE_REAUTH=1; shift ;;
    -h|--help) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
done
[ -n "$LOGIN_SERVER" ] || { echo 'Pass --login-server https://<your server>. Ghostline has no server built in.' >&2; exit 1; }
if ! python3 -I -c '
import sys
from urllib.parse import urlsplit
v = sys.argv[1]
u = urlsplit(v)
bad = (any(c.isspace() for c in v) or "\\" in v or u.scheme != "https" or not u.hostname or u.username is not None
       or u.password is not None or "?" in v or "#" in v or u.path not in ("", "/")
       or u.hostname.endswith(".invalid"))
try:
    u.port
except ValueError:
    bad = True
sys.exit(1 if bad else 0)
' "$LOGIN_SERVER"; then
  echo '--login-server must be the https address of your server, like https://mesh.example.org (no path, query or credentials).' >&2
  exit 1
fi
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0 ..." >&2; exit 1; }
[ "$OPERATOR" = root ] && OPERATOR=""
if [ -n "$AUTHKEY_FILE" ]; then
  [ -f "$AUTHKEY_FILE" ] && [ ! -L "$AUTHKEY_FILE" ] || { echo 'The key file must be a regular file, not a symlink.' >&2; exit 1; }
  [ "$(stat -c %a "$AUTHKEY_FILE")" = 600 ] && [ "$(stat -c %u "$AUTHKEY_FILE")" = 0 ] \
    || { echo 'The key file must be owned by root with mode 0600 (sudo chown root: FILE; sudo chmod 600 FILE).' >&2; exit 1; }
fi

CLI="/usr/local/bin/$GL_CLI"
[ -x "$CLI" ] || { echo "$GL_CLI is not installed. Run sudo ./install.sh first." >&2; exit 1; }
systemctl is-active --quiet "${GL_SERVICE}.service" || { echo "${GL_SERVICE}.service is not running (journalctl -u ${GL_SERVICE} -e)." >&2; exit 1; }

ARGS=(up "--login-server=$LOGIN_SERVER" "--accept-dns=$ACCEPT_DNS" "--operator=$OPERATOR")
[ -n "$AUTHKEY_FILE" ] && ARGS+=("--auth-key=file:$AUTHKEY_FILE")
[ -n "$HOSTNAME_ARG" ] && ARGS+=("--hostname=$HOSTNAME_ARG")
[ "$FORCE_REAUTH" = 1 ] && ARGS+=(--force-reauth)
echo "$CLI ${ARGS[*]}" | sed 's#--auth-key=file:[^ ]*#--auth-key=file:***#'
"$CLI" "${ARGS[@]}"
echo
"$CLI" status || true
echo "This device's mesh address: $("$CLI" ip -4 2>/dev/null || echo '(not assigned yet)')"
