#!/usr/bin/env bash
# Ghostline: install the mesh daemon and command on Linux as a systemd service. Needs root.
#
#   sudo ./install.sh [--firewall-mode nftables|iptables|auto] [--force]
#
# 1. Refuses to run next to an active official Tailscale service (both use the interface tailscale0); --force stops
#    and disables it (its state is not deleted).
# 2. Installs ghostlined and ghostline (next to this script) to /usr/local/bin.
# 3. Writes /etc/default/ghostlined (only if absent) and /etc/systemd/system/ghostlined.service, then starts it.
# Then join your server: sudo ./join.sh --login-server https://<your server>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_brand.sh
. "$HERE/_brand.sh"

FW_MODE="auto"; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --firewall-mode) FW_MODE="${2:?needs a value}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
done
case "$FW_MODE" in nftables|iptables|auto) ;; *) echo "--firewall-mode must be nftables, iptables or auto" >&2; exit 1 ;; esac
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }
command -v systemctl >/dev/null || { echo "This installer needs systemd." >&2; exit 1; }
for f in "$GL_SERVICE" "$GL_CLI"; do [ -x "$HERE/$f" ] || { echo "$HERE/$f is missing; unpack the whole download." >&2; exit 1; }; done
BIN_DIR=/usr/local/bin
UNIT="/etc/systemd/system/${GL_SERVICE}.service"
ENVFILE="/etc/default/${GL_SERVICE}"

if systemctl list-unit-files tailscaled.service 2>/dev/null | grep -q '^tailscaled.service' \
   && { systemctl is-active --quiet tailscaled.service || systemctl is-enabled --quiet tailscaled.service 2>/dev/null; }; then
  echo "The official Tailscale service (tailscaled.service) is installed and active or enabled."
  echo "It cannot run next to $GL_SERVICE: both use the network interface tailscale0."
  if [ "$FORCE" = 1 ]; then
    systemctl disable --now tailscaled.service
    echo "Stopped and disabled tailscaled.service (its state in /var/lib/tailscale was not deleted)."
  else
    echo "Re-run with --force to stop and disable it, or remove it first." >&2; exit 1
  fi
fi

if systemctl is-active --quiet "${GL_SERVICE}.service"; then
  echo ">> Stopping ${GL_SERVICE}.service for the upgrade"
  systemctl stop "${GL_SERVICE}.service"
fi
install -d -m 0755 "$BIN_DIR"
install -m 0755 "$HERE/$GL_SERVICE" "$BIN_DIR/$GL_SERVICE"
install -m 0755 "$HERE/$GL_CLI" "$BIN_DIR/$GL_CLI"
command -v restorecon >/dev/null 2>&1 && restorecon -F "$BIN_DIR/$GL_SERVICE" "$BIN_DIR/$GL_CLI" || true
echo ">> Installed $BIN_DIR/$GL_SERVICE and $BIN_DIR/$GL_CLI"

if [ ! -f "$ENVFILE" ]; then
  {
    echo "# Environment for ${GL_SERVICE}.service. Restart the service after editing."
    echo "# Extra daemon flags, for example --verbose=1 :"
    echo 'FLAGS=""'
    echo "# Firewall backend for the daemon's own rules: nftables | iptables | auto."
    echo "TS_DEBUG_FIREWALL_MODE=$FW_MODE"
    echo "# Log upload is compiled out of this build; this also tells the daemon not to try."
    echo "TS_NO_LOGS_NO_SUPPORT=true"
  } > "$ENVFILE"
  chmod 0644 "$ENVFILE"
  echo ">> Wrote $ENVFILE"
else
  echo ">> Keeping existing $ENVFILE"
fi

cat > "$UNIT" <<UNITEOF
[Unit]
Description=${GL_PRODUCT} mesh node agent (${GL_SERVICE})
Wants=network-pre.target
After=network-pre.target NetworkManager.service systemd-resolved.service

[Service]
EnvironmentFile=-${ENVFILE}
ExecStart=${BIN_DIR}/${GL_SERVICE} --state=/var/lib/${GL_STATE_DIR_NAME}/${GL_SERVICE}.state --socket=${GL_SOCKET} --port=${GL_PORT} --tun=tailscale0 \$FLAGS
ExecStopPost=${BIN_DIR}/${GL_SERVICE} --cleanup
Restart=always
RestartSec=2
RuntimeDirectory=ghostline
RuntimeDirectoryMode=0755
StateDirectory=${GL_STATE_DIR_NAME}
StateDirectoryMode=0700
CacheDirectory=${GL_STATE_DIR_NAME}
CacheDirectoryMode=0750
Type=notify

[Install]
WantedBy=multi-user.target
UNITEOF
chmod 0644 "$UNIT"
systemctl daemon-reload
systemctl enable --now "${GL_SERVICE}.service"
for _ in $(seq 1 20); do [ -S "$GL_SOCKET" ] && break; sleep 0.5; done
if systemctl is-active --quiet "${GL_SERVICE}.service"; then
  echo
  echo "Installed. ${GL_SERVICE}.service is running."
  echo "Next: sudo ./join.sh --login-server https://<your server>"
  echo "Allow UDP $GL_PORT in your host firewall for direct (not relayed) connections."
else
  echo "ERROR: ${GL_SERVICE}.service did not start. Check: journalctl -u ${GL_SERVICE}.service -e" >&2
  exit 1
fi
