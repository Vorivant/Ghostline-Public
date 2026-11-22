#!/usr/bin/env bash
# Write this server's configuration for your domain:   ./configure.sh --domain mesh.example.org
# Creates config/config.yaml (from config/config.template.yaml), .env (for Caddy) and data/ (mode 0700).
# Safe to run again; it refuses to overwrite a config.yaml for a different domain unless you pass --force.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DOMAIN=""; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --domain) DOMAIN="${2:?--domain needs a name}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ "$DOMAIN" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]] \
  || { echo "--domain must be a DNS name you own, like mesh.example.org" >&2; exit 2; }
case "$DOMAIN" in *.example|*.example.com|*.example.org|*.example.net|*.invalid|*.local) echo "$DOMAIN is a placeholder; use your own domain." >&2; exit 2 ;; esac
CFG="$HERE/config/config.yaml"
if [ -f "$CFG" ] && ! grep -qx "server_url: https://$DOMAIN" "$CFG" && [ "$FORCE" != 1 ]; then
  echo "$CFG is set up for another domain; pass --force to replace it." >&2; exit 1
fi
sed "s#@DOMAIN@#$DOMAIN#g" "$HERE/config/config.template.yaml" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
printf 'GHOSTLINE_DOMAIN=%s\n' "$DOMAIN" > "$HERE/.env"
mkdir -p "$HERE/data" && chmod 0700 "$HERE/data"
echo "Wrote $CFG and .env for $DOMAIN."
echo "Next: point $DOMAIN (DNS A/AAAA) at this server, open TCP 80 and 443 and UDP 3478, then: docker compose up -d"
