# Ghostline

Ghostline connects your own devices (PCs, servers and an Android phone) into one private, encrypted network that
works from anywhere. Its mesh is called **Remota**. Devices talk to each other directly over WireGuard where they
can, and through your own server's relay where they cannot.

- **Your server, your network.** You run the coordination server yourself (Headscale, open source) with the
  server kit in [`server/`](server/SELF-HOST.md). No account with Vorivant, and no server is built into the apps.
- **Private by default.** Log upload, network flow logs, the self-updater, debug endpoints, the web client,
  serve/funnel, the SSH server and other unused features are compiled out. No relays run by anyone else are used.
- **Free and open source.** BSD 3-Clause for Vorivant's files; the upstream parts keep their licences
  ([THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)).

Ghostline is not an internet VPN: it does not hide your address from web sites. It connects your own devices.

## Download

Releases are published on the Vorivant website with a signed `SHA256SUMS`. Windows 10/11 (x64), Linux (x86-64,
ARM64, systemd) and Android 8.0 or newer. macOS is planned.

## Quick start

1. **Server.** On a small Linux server with Docker and a domain name pointing at it:
   `./configure.sh --domain mesh.example.org` then `docker compose up -d` in `server/`. Details: [SELF-HOST.md](server/SELF-HOST.md).
2. **Linux device.** Unpack the download, then `sudo ./install.sh` and
   `sudo ./join.sh --login-server https://mesh.example.org`.
3. **Windows device.** Unblock and unzip the download, open PowerShell as Administrator in the folder, then
   `powershell -ExecutionPolicy Bypass -File .\install.ps1` and
   `powershell -ExecutionPolicy Bypass -File .\join.ps1 -LoginServer https://mesh.example.org`.
4. **Android.** Install the APK, open the app's settings, choose "Use an alternate server" (under accounts) and enter
   `https://mesh.example.org`.
5. **Approve each device** on the server (the sign-in page shows the `headscale auth register ...` command), or
   create a pre-authentication key with `headscale preauthkeys create` and pass it to the join script.

## Build from source

| What | Command | Needs |
|---|---|---|
| Desktop clients | `./build.sh --target all` (or `linux-amd64`, `linux-arm64`, `windows-amd64`) | Linux or macOS, git, python3, curl, unzip, Go 1.27.4 |
| Android app | `android/build-app.sh --sdk ~/Android/Sdk --work /tmp/gl-android [--keystore ...]` | the above, JDK 17+, Android SDK (see the script header) |
| Release files | `packaging/package.py --build dist/build --licences dist/licences --apk ... --out dist/release` | python3 |

`build.sh` downloads the upstream Tailscale client at the commit pinned in [`upstream.json`](upstream.json), applies
[`rebrand/rules.json`](rebrand/rules.json) to a copy with [`rebrand/rebrand.py`](rebrand/rebrand.py) and
[`brand.json`](brand.json), and builds with CGO off and the privacy build tags listed in the script. Every edit is an
exact text replacement that must match, so an upstream change cannot silently skip one. GitHub Actions in
[`.github/workflows/`](.github/workflows) build the same way; `release.yml` produces the release files.

## Layout

| Path | What |
|---|---|
| `brand.json`, `upstream.json`, `VERSION` | product names (no server built in), pinned upstream inputs, release version |
| `rebrand/` | the rebrand tool, its rules and the Windows resource generator |
| `build.sh`, `android/` | desktop and Android builds |
| `client/linux/`, `client/windows/` | install, uninstall and join scripts shipped in the downloads |
| `server/` | the self-host server kit (Headscale + Caddy) |
| `packaging/` | release packaging, Go licence collection, checksum signing |
| `website/` | the download page template |
| `legal/` | source statement and third-party licence texts |

## Security

Report a vulnerability to ghostline@vorivant.com ([SECURITY.md](SECURITY.md)).

Tailscale is a trademark of Tailscale Inc. Ghostline is built on the open-source Tailscale client (BSD-3-Clause)
and is not affiliated with or endorsed by Tailscale Inc. WireGuard is a registered trademark of Jason A. Donenfeld.
