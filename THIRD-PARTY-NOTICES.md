# Ghostline: third-party notices

This file ships inside the Windows zip, the Linux tarballs and the self-host server kit. The Android APK carries it, with the licence texts of `legal/`, in `assets/licenses/`; it is also published next to the download, and the app's licences link opens it. It lists the software that Ghostline includes or builds on, who owns it, which licence applies, and where the full licence text is in your download.

In the source repository and the source download, the licence texts named below are in `legal/` (`LICENSE-tailscale-BSD-3.txt`, `PATENTS-tailscale.txt`, `LICENSE-tailscale-android-BSD-3.txt`, `LICENSE-headscale-BSD-3.txt`, `LICENSE-wintun.txt`).

Ghostline is made by Vorivant. Contact: ghostline@vorivant.com.

**Remota** is Ghostline's own mesh client. It is built from the open-source Tailscale client and renamed. Tailscale is named in this file only to give credit, to meet licence conditions, and to say what Remota is built from.

Nothing in this file is legal advice. It is a factual list. Where a licence text is produced by the build instead of being written out here, this file says so plainly.

---

## 1. What is in which download

| Download | Contents that carry third-party licences |
|---|---|
| Windows zip (amd64) | `ghostlined.exe` (the Remota daemon) and `ghostline.exe` (the command-line tool), both built from the Tailscale client source and statically linked with the Go standard library and Go modules; `wintun.dll` (prebuilt, unmodified); install, uninstall and join scripts written by Vorivant |
| Linux tarballs (amd64, arm64) | the same daemon and command-line tool; install, uninstall and join shell scripts written by Vorivant |
| Android APK | the Ghostline app, built from the Tailscale Android app source with Vorivant's changes; the Remota core compiled with gomobile; AndroidX, Jetpack Compose, Kotlin and other Gradle libraries |
| Self-host server template | configuration files and a `docker-compose` file written by Vorivant; the file `config.yaml` is derived from Headscale's example configuration. The Headscale and Caddy container images are **not** included: the compose file names them and Docker downloads them from their publishers |
| All downloads | Ghostline logo and icons, owned by Vorivant |

## 2. Component list

"Text in this download" names the file that holds the full licence text. Files named `LICENSE-*.txt` sit next to this file. The folder `licenses/` is described in section 4.

| Component | Version | Licence | Copyright line (copied from the source file named) | Text in this download |
|---|---|---|---|---|
| Tailscale client (basis of the Remota daemon and command-line tool) | v1.104.5 | BSD-3-Clause | `Copyright (c) 2020 Tailscale Inc & contributors.` (file `LICENSE`); source files carry `Copyright (c) Tailscale Inc & contributors` | `LICENSE-tailscale-BSD-3.txt` |
| Tailscale Android app (basis of the Ghostline Android app) | tag `1.104.5-t788384763-gd8673104f` | BSD-3-Clause | `Copyright (c) 2020 Tailscale & AUTHORS. All rights reserved.` (file `LICENSE` of that repository) | `LICENSE-tailscale-android-BSD-3.txt` |
| Wintun (`wintun.dll`, Windows only) | 0.14.1 | Wintun "Prebuilt Binaries License" from WireGuard LLC (not an open-source licence) | `Copyright (C) 2018-2021 WireGuard LLC. All Rights Reserved.` (file `include/wintun.h` in the official zip); the licence file itself says the software "is owned and copyrighted by WireGuard LLC" | `LICENSE-wintun.txt` |
| Headscale (server template only; not included, only referenced and used as the base of one configuration file) | v0.29.7 | BSD-3-Clause | `Copyright (c) 2020, Juan Font` (file `LICENSE`) | `LICENSE-headscale-BSD-3.txt` |
| Go standard library and runtime (compiled into every Go binary) | Go 1.27.4 | BSD-3-Clause | `Copyright 2009 The Go Authors` (first line of the `LICENSE` file of the Go toolchain; see the note on the Go row below) | `licenses/go-standard-library@go1.27.4/LICENSE` (and `PATENTS`), copied per build |
| Go modules linked into the binaries (several dozen modules per target, filtered by build tags) | as pinned in `go.mod` of the Tailscale source | mostly BSD-3-Clause, MIT, Apache-2.0, with a few BSD-2-Clause, ISC and 0BSD (per Tailscale's own lists) | one line per module, from each module's own licence file | `licenses/`, generated per build |
| In-tree copy of cobra shell-completion code (inside the Tailscale source, `tempfork/spf13/cobra`, compiled into the command-line tool) | as in the Tailscale v1.104.5 tree | Apache-2.0 | `Copyright 2013-2023 The Cobra Authors` (header of `cobra.go`) | `licenses/tailscale.com_tempfork_spf13_cobra/LICENSE.txt` (copy of `tempfork/spf13/cobra/LICENSE.txt`) |
| In-tree copies of code from the Go project (inside the Tailscale source, `tempfork/acme`, `tempfork/heap`, `tempfork/httprec`) | as in the Tailscale v1.104.5 tree | BSD-style, the Go licence | file headers such as `Copyright 2015 The Go Authors. All rights reserved.` | the Go `LICENSE` in `licenses/go-standard-library@go1.27.4/LICENSE` |
| Android libraries (AndroidX, Jetpack Compose, Kotlin, kotlinx, Coil, ZXing core, Vico, Accompanist and the libraries they pull in) | as resolved by Gradle for the release build | Apache-2.0 expected for the named projects; **UNVERIFIED** (section 5) | taken from each library's own metadata | section 5 |
| Ghostline scripts, configuration, rules and documentation | 1.0.0 | BSD-3-Clause | `Copyright (c) 2026 Vorivant` | `LICENSE` |
| Ghostline logo and icons | n/a | Owned by Vorivant; see section 6 | n/a | this file |

Notes on the rows above.

- **Tailscale rows.** The two BSD-3-Clause texts are not identical. The desktop text names "the copyright holder" in its third condition. The Android text names "Tailscale Inc." in its third condition. Both are shipped as received, each next to the code it covers.
- **Wintun row.** The file `LICENSE-wintun.txt` is a verbatim copy of `LICENSE.txt` from `wintun-0.14.1.zip` as downloaded from `https://www.wintun.net/builds/wintun-0.14.1.zip`. The SHA-256 of that zip is `07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51`. The SHA-256 of `wintun/bin/amd64/wintun.dll` inside it is `e5da8447dc2c320edc0fc52fa01885c103de8c118481f683643cacc3220dafce`. The `wintun.dll` in the Windows zip is that file, unmodified. Its licence is not BSD or MIT: it lets you use the DLL under stated conditions and restricts changing it and passing it on. Read the file.
- **Headscale row.** Headscale source code and binaries are not in any download. The licence is shipped because the server template's `config.yaml` is derived from Headscale's `config-example.yaml`.
- **Go row.** The Go licence text and patent grant are copied from the toolchain that built the release (Go 1.27.4) into `licenses/go-standard-library@go1.27.4/` at build time.
- **Go modules row.** The size is an estimate from Tailscale's own dependency lists (`licenses/tailscale.md` has 93 entries and `licenses/windows.md` has 58). The exact list for each Ghostline binary is generated, not copied from those lists.

## 3. Full copyright and licence statements for the main components

### 3.1 Remota (built from the Tailscale client)

Remota's daemon and command-line tool are the Tailscale client source, version v1.104.5, with Vorivant's changes. The changes are made by the rules in `rebrand/rules.json` of the Ghostline source (see `SOURCE-OFFER.md`): the product and file names are changed and some features are removed or turned off. Tailscale's copyright notices in the source files are kept.

> Copyright (c) 2020 Tailscale Inc & contributors.
> Licence: BSD 3-Clause. Full text: `LICENSE-tailscale-BSD-3.txt`.

Tailscale's source tree also ships a patent grant in a file called `PATENTS`. It is shipped next to the licence texts as `PATENTS-tailscale.txt`.

### 3.2 Ghostline Android app

> Copyright (c) 2020 Tailscale & AUTHORS. All rights reserved.
> Licence: BSD 3-Clause. Full text: `LICENSE-tailscale-android-BSD-3.txt`.

The Android app's Remota core is compiled from the same Tailscale v1.104.5 client source as the desktop builds, so section 3.1 also applies to the APK.

### 3.3 Wintun (Windows only)

> Copyright (C) 2018-2021 WireGuard LLC. All Rights Reserved.
> Licence: Wintun Prebuilt Binaries License. Full text: `LICENSE-wintun.txt`.

`wintun.dll` is WireGuard LLC's work, passed on unmodified. Ghostline's programs use it only through its published programming interface (`wintun.h`). Do not edit, repack or rename the DLL. Under its licence, the use of the names of WireGuard LLC, the WireGuard project or the Wintun project to endorse or promote products is not allowed without written consent.

### 3.4 Headscale (server template)

> Copyright (c) 2020, Juan Font
> Licence: BSD 3-Clause. Full text: `LICENSE-headscale-BSD-3.txt`.

## 4. Licences that are generated for each build

Some licence texts depend on the exact build. They are produced by the build and are **not** written out here, because writing them from memory would risk getting them wrong.

| Folder or file | How it is produced | What it contains |
|---|---|---|
| `licenses/<module>@<version>/` (one folder per Go module linked into the binaries of that download) | `packaging/collect_go_licences.py`, which runs `go list -deps` on `./cmd/tailscaled` and `./cmd/tailscale` for that target with the release build tags and copies each module's `LICENSE*`, `COPYING*`, `NOTICE*` and `PATENTS*` files from the module cache | each module's licence file, and its `NOTICE` file where it has one |
| `licenses/go-standard-library@go1.27.4/` | copied by the same script from the Go toolchain that built the release | the Go `LICENSE` and `PATENTS` |
| `licenses/tailscale.com_tempfork_*` | copied by the same script from the client source | the licences of code vendored inside the client source, such as the Apache-2.0 text of the in-tree cobra code |
| `licenses/INDEX.md` | written by the same script | module, version and licence file names |

The build fails if any linked module has no licence file, so a release cannot ship without one.

## 5. Android Gradle libraries

The Android build's libraries are listed in the upstream app's `android/gradle/libs.versions.toml`. The production libraries named there include AndroidX core, fragment, browser, security-crypto, work, Room, lifecycle, activity-compose and navigation; Jetpack Compose (material3, ui, animation, material-icons-core); Kotlin standard library and reflection; kotlinx serialization and coroutines; Accompanist (permissions, system UI controller); Coil; ZXing core; and Vico. Libraries used only for tests (JUnit, Mockito, Espresso, UI Automator, one-time-password and commons-codec) are not part of the APK.

A per-library licence report for the APK is not generated yet (**UNVERIFIED**). Until it is, the libraries and their licences are those listed by the upstream app (`android/gradle/libs.versions.toml` of the pinned tag), and this file is published next to the download. The Go modules of the Android core (gomobile, `libtailscale`) are not yet collected by `packaging/collect_go_licences.py` either (**UNVERIFIED**); they are the client's modules plus `golang.org/x/mobile` and the app repository's own Go dependencies.

## 6. Ghostline's own work

Scripts, configuration files, rules, patches, build tooling and documentation written by Vorivant for Ghostline: Copyright (c) 2026 Vorivant, licensed under the BSD 3-Clause licence in `LICENSE`. The upstream text inside the rules and patches (each rule's `old` text and a patch's context and removed lines) is Tailscale's, under its BSD 3-Clause licence (section 3).

The Ghostline logo, mark and icons (files under `assets/` and `website/assets/` in the source, and the icons inside the apps) belong to Vorivant. They may be copied together with the unmodified download; no licence is given to use the Ghostline or Remota names or logos for any other product or service.

## 7. Trademarks and no endorsement

- Tailscale is a trademark of Tailscale Inc. Ghostline and Remota are not affiliated with, endorsed by, or sponsored by Tailscale Inc.
- WireGuard is a registered trademark of Jason A. Donenfeld. Ghostline and Remota are not affiliated with, endorsed by, or sponsored by Jason A. Donenfeld or WireGuard LLC. Remota uses the WireGuard protocol, and Windows builds use Wintun, which is distributed by WireGuard LLC.
- Headscale is a project of its own authors. Ghostline is not affiliated with it.
- Other names belong to their owners. Android is a trademark of Google LLC. Docker and Caddy are named only to say which images the server template uses.
- The names of the copyright holders and contributors above are not used to endorse or promote Ghostline. That is a condition of the BSD 3-Clause licences and of the Wintun licence.

## 8. No warranty

Each licence above disclaims warranties in its own words, and those words apply to the part of the software it covers. Ghostline is provided as is. 

## 9. Source code

The source of Ghostline, and the instructions to rebuild it, are described in `SOURCE-OFFER.md`.
