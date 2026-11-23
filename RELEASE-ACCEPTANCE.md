# Production release acceptance gates

Status: **BLOCKED**. The first published Git commit is source publication, not an accepted binary release.

## Non-negotiable prerequisites

- [ ] Public and private review PRs have passed public CI, private allowlist-export/strict scan, gitleaks, and recorded owner-local private-identifier scan.
- [ ] Main is protected by an enforced review, CODEOWNERS and CI policy; `v*` tags are protected; the release environment requires a reviewer other than the author.
- [ ] The release workflow has isolated unsigned builds and signing jobs; signing keys are never made available to application builds, source checkout, Gradle, arbitrary repository scripts or unpacked untrusted executables on signing runners.
- [ ] All Windows executables have valid Authenticode signatures matching the accepted publisher certificate and the signed archive passes Defender/SmartScreen checks.
- [ ] Android APK passes `apksigner verify --verbose --print-certs` with the reviewed certificate SHA-256, expected `com.vorivant.ghostline` package identity, supported ABIs, monotonic versionCode, and device upgrade compatibility.
- [ ] Android Gradle runtime artifacts and Android-linked Go modules have resolved license/NOTICE inventories, included required notices and reviewed SPDX or CycloneDX SBOM. The signoff file `legal/ANDROID-LICENSES-VERIFIED.md` may be committed only with actual evidence; never create a placeholder to bypass the package gate.
- [ ] Production packaging uses `packaging/package.py --production` and verifies all three desktop targets, actual signed APK, verified license inventories, verified digests and complete expected archive names.
- [ ] Release signing private/public key pair matches the independently established publisher fingerprint, and `ssh-keygen -Y verify` validates the manifest. Never trust a signing key solely because it is hosted beside the artifacts.
- [ ] The signed archives and unmodified source link to the exact reviewed commit; first-class provenance records pinned Go/Android/Wintun/Headscale/Caddy inputs and image digest reviews.
- [ ] Live server/relay and device tests verify no unauthorized control-plane, relay, DNS bootstrap, log-upload or updater egress. Save scrubbed network traces; deny private infrastructure leakage.

## Acceptance matrix: record evidence, not promises

| Device | Clean install | Self-host login | Peer direct | Relay fallback | Restart | Upgrade | Uninstall | Negative egress |
|---|---|---|---|---|---|---|---|---|
| Windows 10 x64 | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Windows 11 x64 | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Linux x86-64 systemd | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Linux ARM64 systemd | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Android 8 ARMv7 | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Android modern ARM64 | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

For every row record: exact source SHA, workflow URL, archive checksum, verified signing identity, OS patch level and device type, completed UTC time, sanitized installation logs, packet-capture summary, signer and reviewer. Include interrupted-install, stale ACL, insufficient-disk and conflicting official-client negative tests.

## Planned signing isolation design

1. **Source/build:** pull reviewed commit and build binaries, including unsigned APK, on secretless workers. Verify pinned upstream hashes and compile-time removal tags.
2. **Android signing:** an independent, clean, reviewer-gated runner reads exactly one unsigned APK as data and signs it with the Android release key; validate certificate continuity.
3. **Packaging:** secretless runner validates all target files, licenses, APK identity and cryptographic signature, plus acceptance evidence.
4. **Windows acceptance:** a native Windows runner checks actual Authenticode chain on both executables with pinned publisher identity.
5. **Manifest signing:** a fresh isolated, reviewer-gated runner signs SHA256SUMS, verifies the signature and key fingerprint, and returns a private candidate artifact. Publication remains a separate, explicitly approved operation.

## Gate policy

The present `.github/workflows/release.yml` is intentionally **fail-closed** at `release-prerequisites`. Do not remove that gate merely to produce a binary. Replace it only when the isolated signing architecture and acceptance requirements above are implemented and independently validated. Missing Android credentials, a missing signer fingerprint, an unsigned Windows executable, missing Android license evidence or failed native acceptance must each fail production automatically.

No release tag, GitHub Release, public website change, or signed distribution may be created without separate explicit authorization.
