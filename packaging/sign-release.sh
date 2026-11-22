#!/usr/bin/env bash
# Sign a release's SHA256SUMS with an SSH signing key (ssh-keygen -Y sign), and check the signature.
#
#   packaging/sign-release.sh --key FILE --dir dist/release [--identity release@vorivant.com]
#
# Make the key once, on your own computer, and keep the private half offline:
#   ssh-keygen -t ed25519 -C release@vorivant.com -f ghostline-release-signing
# Publish ghostline-release-signing.pub on the download page (package.py --signing-pub copies it next to the files).
# Users check with:
#   echo "release@vorivant.com $(cat ghostline-release-signing.pub)" > allowed_signers
#   ssh-keygen -Y verify -f allowed_signers -I release@vorivant.com -n file -s SHA256SUMS.sig < SHA256SUMS
set -euo pipefail
KEY=""; DIR=""; ID="release@vorivant.com"
while [ $# -gt 0 ]; do
  case "$1" in
    --key) KEY="${2:?}"; shift 2 ;;
    --dir) DIR="${2:?}"; shift 2 ;;
    --identity) ID="${2:?}"; shift 2 ;;
    -h|--help) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ -f "$KEY" ] && [ -f "$DIR/SHA256SUMS" ] || { echo "need --key FILE and --dir with SHA256SUMS" >&2; exit 2; }
rm -f "$DIR/SHA256SUMS.sig"
ssh-keygen -Y sign -f "$KEY" -n file "$DIR/SHA256SUMS" >/dev/null
PUB="$(ssh-keygen -y -f "$KEY")"
if [ -f "$DIR/ghostline-release-signing.pub" ] && [ "$(cut -d' ' -f1,2 "$DIR/ghostline-release-signing.pub")" != "$(printf '%s' "$PUB" | cut -d' ' -f1,2)" ]; then
  echo "the key does not match $DIR/ghostline-release-signing.pub" >&2; exit 1
fi
T="$(mktemp)"; trap 'rm -f "$T"' EXIT
printf '%s %s\n' "$ID" "$PUB" > "$T"
ssh-keygen -Y verify -f "$T" -I "$ID" -n file -s "$DIR/SHA256SUMS.sig" < "$DIR/SHA256SUMS"
(cd "$DIR" && sha256sum -c SHA256SUMS --quiet)
echo "signed and verified $DIR/SHA256SUMS"
