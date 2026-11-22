# Ghostline download page

Assets for the Ghostline download page, to be placed on vorivant.com. Before publishing, make `og:image` and `twitter:image` in the template absolute URLs (`https://vorivant.com/.../assets/og-image.png`).

## Files

- `download.template.html`: the page. One self-contained file. Inline CSS, no external fonts, scripts or trackers. Works with JavaScript off. A tiny inline script only highlights the card for the visitor's OS and points the hero button at it.
- `assets/ghostline-icon-256.png`: logo shown in the hero (app icon, works on light and dark).
- `assets/favicon-32.png`, `assets/apple-touch-icon.png` (180x180): icons.
- `assets/og-image.png`: 1200x630 social preview (lockup on dark).
- `render_preview.py`: fills the template with fake sample values into `preview.html` (git-ignored). Run `python3 render_preview.py`.
- `.gitignore`: ignores `preview.html`.

## Placeholders

The packaging script replaces these with plain text substitution:

- `{{VERSION}}`, `{{CORE_VERSION}}`, `{{RELEASE_DATE}}`
- For each key in `windows_amd64, linux_amd64, linux_arm64, android, server_kit, source`:
  `{{FILE_<key>}}` (file name), `{{SIZE_<key>}}` (like "18.2 MB"), `{{SHA256_<key>}}` (hex digest).

The script should write the result as `index.html` or `download.html` next to the release files, and fail if any `{{...}}` is left over (`render_preview.py` does this check).

Fixed relative links (not placeholders): `SHA256SUMS`, `SHA256SUMS.sig`, `ghostline-release-signing.pub`, `THIRD-PARTY-NOTICES.md`, and the `assets/` folder.

## To publish

1. Run the packaging script to produce the filled page.
2. Upload into one folder on the site: the filled page, `assets/`, all six release files, `SHA256SUMS`, `SHA256SUMS.sig`, `ghostline-release-signing.pub` and `THIRD-PARTY-NOTICES.md`.
3. Make `og:image` and `twitter:image` absolute, for example `https://vorivant.com/ghostline/assets/og-image.png`.
4. Once Windows code signing is in place, delete the element with `id="unsigned-note"`.
5. If your site serves `.md` files as downloads, check that `THIRD-PARTY-NOTICES.md` opens or downloads cleanly.

## Notes on content

- The page promises no Vorivant-hosted server, no account, no telemetry. Keep it that way unless the product changes.
- The only mention of the upstream client is the footer attribution line.
- Quick start uses `-ExecutionPolicy Bypass` on Windows (downloaded scripts are blocked by default).

## Test checklist before publishing

- [ ] No `{{` left in the filled page.
- [ ] Every download link, `SHA256SUMS`, `.sig`, `.pub` and notices link opens the right file (no 404).
- [ ] Sizes and SHA-256 values on the page match `SHA256SUMS`.
- [ ] The verify commands work on a real download (signature says "Good signature").
- [ ] Page looks right at 1280px and 390px, in light and dark mode, with no sideways scrolling.
- [ ] Works with JavaScript disabled.
- [ ] Keyboard: Tab reaches every link and FAQ item, focus ring is visible.
- [ ] Browser dev tools Network tab shows no requests to other domains.
- [ ] `og:image` is absolute and the share preview shows the image.
- [ ] Unsigned note removed if Windows is signed (or kept if not).
- [ ] Search the page for forbidden words: the upstream client name may appear only in the footer.
