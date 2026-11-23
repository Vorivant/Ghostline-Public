# Changelog

## 1.0.0 (initial public source publication; end-user release pending)

- The following describes intended distribution targets, not accepted installable release binaries.
- Ghostline for Windows 10/11 (x64), Linux (x86-64, ARM64) and Android 8.0+, built on the Tailscale client
  v1.104.5 (Android app tag 1.104.5-t788384763-gd8673104f).
- No server built in: sign in to your own server (`join.sh --login-server`, `join.ps1 -LoginServer`, or "Use an
  alternate server" in the Android app).
- Self-host server kit: Headscale 0.29.7 and Caddy with automatic HTTPS, the built-in relay and STUN on your own
  server, no third-party relays, a starting policy where each user's devices reach only each other.
- Compiled out: log upload, network flow logs, self-updater, debug handlers, serve/funnel, web client, outbound
  proxies, ACME, SSH server, Taildrop (desktop), peer relay server, posture checks, cloud and platform integrations,
  Wake-on-LAN, systray. The Android app keeps Taildrop for its sharing screens and leaves out captive-portal detection.
- No bootstrap DNS through third-party relays, and no update check.

Known limits: a publicly distributed, signed and installation-tested binary set is not available yet. Windows
executables have not been Authenticode-signed; Android build, signing and device acceptance have not been established;
macOS is not available. No public GitHub release existed as of 2026-11-23.
