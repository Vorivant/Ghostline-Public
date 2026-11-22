#!/usr/bin/env bash
# Ghostline: remove the mesh daemon and command. Needs root.
#
#   sudo ./uninstall.sh [--purge]
#
# --purge also deletes this machine's mesh identity (/var/lib/ghostline, /var/cache/ghostline) and
# /etc/default/ghostlined, so it joins as a new device next time. Remove the device on your server too:
#   headscale nodes list ; headscale nodes delete -i <ID>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_brand.sh
. "$HERE/_brand.sh"
PURGE=0
case "${1:-}" in --purge) PURGE=1 ;; "") ;; -h|--help) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0 ;; *) echo "unknown option: $1" >&2; exit 1 ;; esac
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }
if systemctl list-unit-files "${GL_SERVICE}.service" 2>/dev/null | grep -q "^${GL_SERVICE}.service"; then
  systemctl disable --now "${GL_SERVICE}.service" || true
fi
rm -f "/etc/systemd/system/${GL_SERVICE}.service"
systemctl daemon-reload
rm -f "/usr/local/bin/$GL_SERVICE" "/usr/local/bin/$GL_CLI"
echo "Removed the service and the binaries."
if [ "$PURGE" = 1 ]; then
  case "$GL_STATE_DIR_NAME" in ""|*/*|.|..) echo "Refusing to purge: invalid state directory name." >&2; exit 1 ;; esac
  rm -rf "/var/lib/$GL_STATE_DIR_NAME" "/var/cache/$GL_STATE_DIR_NAME" "/etc/default/${GL_SERVICE}"
  echo "Deleted this machine's mesh identity and /etc/default/${GL_SERVICE}."
else
  echo "Kept /var/lib/$GL_STATE_DIR_NAME and /etc/default/${GL_SERVICE} (use --purge to delete them)."
fi
