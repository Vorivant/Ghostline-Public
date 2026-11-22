# Ghostline: source code

Ghostline is free and open source. The complete source of every release is:

- this repository, at the release tag (for example `v1.0.0`), and
- the file `Ghostline-<version>-source.tar.gz` published next to the downloads, which holds the same committed files.

The upstream software is not copied into this repository. Its exact versions are pinned in `upstream.json`, and the
build downloads them and checks them:

| Part | Upstream | Pinned at |
|---|---|---|
| Desktop daemon and command, Android network core | Tailscale client, BSD-3-Clause, https://github.com/tailscale/tailscale | tag `v1.104.5`, commit `73a48057aaf5f60e4f770b398e9b7af576b01dbe` |
| Android app | Tailscale Android client, BSD-3-Clause, https://github.com/tailscale/tailscale-android | tag `1.104.5-t788384763-gd8673104f`, commit `d8673104f600c05b8c20b64d0e70951ed670236a` |
| `wintun.dll` (Windows, unmodified) | WireGuard LLC, https://www.wintun.net | `wintun-0.14.1.zip`, SHA-256 `07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51`; amd64 DLL SHA-256 `e5da8447dc2c320edc0fc52fa01885c103de8c118481f683643cacc3220dafce` |
| Server (not redistributed, run from the publishers' images) | Headscale 0.29.7 and Caddy 2 | image digests in `server/docker-compose.yml` |
| Go toolchain | https://go.dev | Go 1.27.4 |

## Rebuild

1. Install git, python3, curl, unzip and Go 1.27.4 (and for Android a JDK 17+ and the Android SDK named in
   `android/build-app.sh`).
2. `./build.sh --target all` downloads the Tailscale client at the pinned commit, applies `rebrand/rules.json` to a
   copy with `rebrand/rebrand.py` and `brand.json`, and builds the three desktop targets into `dist/build/`.
   To see every change against upstream, compare `.work/src` with `.work/upstream`.
3. `android/build-app.sh --sdk <sdk> --work <dir>` builds the Android app.
4. `packaging/collect_go_licences.py` and `packaging/package.py` produce the release files with all licence texts
   (`.github/workflows/release.yml` runs the whole sequence).

Licences: Vorivant's files are under the BSD 3-Clause licence in `LICENSE`; each upstream part keeps its own licence
(`THIRD-PARTY-NOTICES.md`). Questions: ghostline@vorivant.com.
