#!/usr/bin/env bash
# Build the Ghostline Android app from the open-source Android client
# (github.com/tailscale/tailscale-android, BSD-3-Clause, at the tag pinned in ../upstream.json) on the same
# rebranded network core as the desktop builds.
#
#   android/build-app.sh --sdk DIR --work DIR [--out DIR] [--upstream DIR]
#                        [--keystore FILE --keystore-pass-file FILE [--key-alias ghostline]]
#
# What it changes against upstream: app.patch (names, icons, own application ID com.vorivant.ghostline, no log
# upload to Tailscale Inc., no Google DNS fallback), app_texts.py (this project's links and texts instead of Tailscale
# Inc.'s admin, privacy, support and help pages), the core built with the desktop builds' privacy build tags
# (Taildrop stays, the app's sharing screens need it, and captive-portal detection is left out), and no server built
# in: in the app choose "Use an alternate server" and enter your own server's address.
# Without --keystore the APK is unsigned (Android will not install it; sign it with apksigner).
# Needs git, python3, the Go version in ../upstream.json, JDK 17+, and an Android SDK with platforms;android-36,
# build-tools;36.0.0 and ndk;23.1.7779620. Gradle downloads its own dependencies.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
pin() { python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d=d[k]
print(d)' "$ROOT/upstream.json" "$1"; }
APP_ID=com.vorivant.ghostline
VERSION_NAME="$(tr -d ' \r\n' < "$ROOT/VERSION")"
# versionCode: major*10^7 + minor*10^5 + patch*10^3, times 10 (upstream adds a platform digit).
VERSION_CODE_BASE="$(python3 -I -c 'import sys; a,b,c=(int(x) for x in sys.argv[1].split(".")); print((a*10**7+b*10**5+c*10**3)*10)' "$VERSION_NAME")"

SDK= WORK= OUT= KEYSTORE= PASSFILE= ALIAS=ghostline UPSTREAM=
while [ $# -gt 0 ]; do
  case "$1" in
    --sdk) SDK="$2"; shift 2 ;;
    --work) WORK="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --upstream) UPSTREAM="$2"; shift 2 ;;
    --keystore) KEYSTORE="$2"; shift 2 ;;
    --keystore-pass-file) PASSFILE="$2"; shift 2 ;;
    --key-alias) ALIAS="$2"; shift 2 ;;
    -h|--help) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$WORK" ] && [ -n "$SDK" ] || { echo "need --sdk and --work (see --help)" >&2; exit 2; }
[ -z "$KEYSTORE" ] || [ -n "$PASSFILE" ] || { echo "--keystore needs --keystore-pass-file" >&2; exit 2; }
NDK="$SDK/ndk/23.1.7779620"; BT="$SDK/build-tools/36.0.0"
for p in "$SDK/platforms/android-36" "$BT/apksigner" "$NDK"; do [ -e "$p" ] || { echo "Android SDK is missing $p" >&2; exit 1; }; done
export GOTOOLCHAIN=local
[ "$(go env GOVERSION)" = "go$(pin go)" ] || { echo "need go$(pin go), found $(go env GOVERSION)" >&2; exit 1; }
mkdir -p "$WORK"; WORK="$(cd "$WORK" && pwd)"; OUT="${OUT:-$WORK/out}"; mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"

DESKTOP_TAGS="$(sed -n 's/^TAGS=//p' "$ROOT/build.sh")"
[ -n "$DESKTOP_TAGS" ] || { echo "no TAGS= line in build.sh" >&2; exit 1; }
TAGS="not_tailscale_go ts_omit_cachenetmap ts_omit_captiveportal $(printf '%s' "$DESKTOP_TAGS" | tr ',' '\n' | grep -vx ts_omit_taildrop | tr '\n' ' ')"
CONTROL_URL="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["DefaultControlURL"])' "$ROOT/brand.json")"
case "$CONTROL_URL" in https://*) ;; *) echo "brand.json DefaultControlURL must be an https URL" >&2; exit 1 ;; esac
case "$CONTROL_URL" in *'#'*|*'"'*|*'\'*) echo "brand.json DefaultControlURL has an unsupported character" >&2; exit 1 ;; esac

echo "== core: rebranded copy of the upstream client $(pin tailscale.tag)"
if [ -z "$UPSTREAM" ]; then
  UPSTREAM="$WORK/upstream"
  [ -d "$UPSTREAM/.git" ] || git clone -q --depth 1 -b "$(pin tailscale.tag)" "$(pin tailscale.repo)" "$UPSTREAM"
fi
[ "$(git -C "$UPSTREAM" rev-parse HEAD)" = "$(pin tailscale.commit)" ] || { echo "upstream checkout is not at the pinned commit" >&2; exit 1; }
rm -rf "$WORK/core" "$WORK/app"; mkdir -p "$WORK/core"
git -C "$UPSTREAM" archive --format=tar HEAD | tar -x -C "$WORK/core"
python3 -I "$ROOT/rebrand/rebrand.py" --source "$WORK/core" --brand "$ROOT/brand.json" --rules "$ROOT/rebrand/rules.json"

echo "== app: $(pin tailscale_android.repo) at $(pin tailscale_android.tag)"
git clone -q --depth 1 -b "$(pin tailscale_android.tag)" "$(pin tailscale_android.repo)" "$WORK/app"
[ "$(git -C "$WORK/app" rev-parse HEAD)" = "$(pin tailscale_android.commit)" ] || { echo "upstream app tag moved" >&2; exit 1; }
git -C "$WORK/app" apply --whitespace=nowarn "$HERE/app.patch"
GRADLE="$WORK/app/android/build.gradle.kts"
grep -q "applicationId = \"$APP_ID\"" "$GRADLE" || { echo "application ID not applied" >&2; exit 1; }
MANIFEST="$WORK/app/android/src/main/AndroidManifest.xml"
STRINGS="$WORK/app/android/src/main/res/values/strings.xml"
sed -i 's#android:label="Remota"#android:label="Ghostline"#' "$MANIFEST"
sed -i -e 's#<string name="app_name" translatable="false">Remota</string>#<string name="app_name" translatable="false">Ghostline</string>#' \
       -e 's#<string name="tile_name" translatable="false">Remota</string>#<string name="tile_name" translatable="false">Ghostline</string>#' "$STRINGS"
grep -q 'android:label="Ghostline"' "$MANIFEST" && grep -q '>Ghostline</string>' "$STRINGS" || { echo "app name not applied" >&2; exit 1; }

RES="$WORK/app/android/src/main/res"; PNG="$ROOT/assets/png"
rm -rf "$RES/mipmap-anydpi-v26" "$RES/drawable/ic_launcher_foreground.xml"
for pair in mdpi:48 hdpi:96 xhdpi:96 xxhdpi:192 xxxhdpi:192; do
  d="${pair%%:*}"; px="${pair##*:}"
  rm -f "$RES/mipmap-$d"/ic_launcher*.webp
  cp "$PNG/app-icon-$px.png" "$RES/mipmap-$d/ic_launcher.png"
  cp "$PNG/app-icon-$px.png" "$RES/mipmap-$d/ic_launcher_round.png"
done
mkdir -p "$RES/drawable-nodpi"; cp "$PNG/mark-256.png" "$RES/drawable-nodpi/remota_mark.png"
python3 -I "$HERE/app_texts.py" "$WORK/app" "$CONTROL_URL"   # control URL, this project's links, public texts
# The licence notices travel inside the APK (assets/licenses/).
ASSETS="$WORK/app/android/src/main/assets/licenses"
mkdir -p "$ASSETS"
cp "$ROOT/LICENSE" "$ASSETS/LICENSE-ghostline.txt"
cp "$ROOT/THIRD-PARTY-NOTICES.md" "$ROOT"/legal/LICENSE-*.txt "$ROOT"/legal/PATENTS-*.txt "$ASSETS/"
UPC="$(pin tailscale_android.commit)"
printf 'VERSION_LONG="%s"\nVERSION_SHORT="%s"\nVERSION_GIT_HASH="%s"\nVERSION_EXTRA_HASH=""\n' \
  "$VERSION_NAME" "$VERSION_NAME" "$UPC" > "$WORK/app/tailscale.version"
printf 'sdk.dir=%s\n' "$SDK" > "$WORK/app/android/local.properties"

echo "== network core for Android (gomobile), tags: $TAGS"
export ANDROID_HOME="$SDK" ANDROID_SDK_ROOT="$SDK" ANDROID_NDK_HOME="$NDK"
export GOBIN="$WORK/app/android/build/go/bin"
mkdir -p "$GOBIN" "$WORK/app/android/libs"
(cd "$WORK/app" && go install golang.org/x/mobile/cmd/gomobile golang.org/x/mobile/cmd/gobind)
(cd "$WORK/app" && PATH="$GOBIN:$PATH" gomobile bind -target android/arm64,android/arm -androidapi 26 -tags "$TAGS" \
  -ldflags "-linkmode=external -extldflags=-Wl,-z,max-page-size=16384 -X tailscale.com/version.longStamp=$VERSION_NAME -X tailscale.com/version.shortStamp=1.104.5 -X tailscale.com/version.gitCommitStamp=$UPC" \
  -o android/libs/libtailscale.aar ./libtailscale)

echo "== app (Gradle)"
(cd "$WORK/app/android" && ./gradlew --no-daemon -Dorg.gradle.internal.repository.max.retries=10 \
  -Dorg.gradle.internal.repository.initial.backoff=1000 -PVERSION_CODE_BASE="$VERSION_CODE_BASE" assembleRelease)
UNSIGNED="$WORK/app/android/build/outputs/apk/release/android-release-unsigned.apk"
NAME="Ghostline-$VERSION_NAME-android"
if [ -n "$KEYSTORE" ]; then
  "$BT/zipalign" -f -p 4 "$UNSIGNED" "$WORK/aligned.apk"
  "$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass "file:$PASSFILE" --ks-key-alias "$ALIAS" --out "$OUT/$NAME.apk" "$WORK/aligned.apk"
  "$BT/apksigner" verify --print-certs "$OUT/$NAME.apk" | grep -E 'SHA-256'
  APK="$OUT/$NAME.apk"
else
  "$BT/zipalign" -f -p 4 "$UNSIGNED" "$OUT/$NAME-unsigned.apk"
  APK="$OUT/$NAME-unsigned.apk"
  echo "NOTE: unsigned; Android installs only signed APKs (android/README.md)"
fi
"$BT/aapt2" dump badging "$APK" | grep -E "^package:|^application-label:" || true
echo "== done: $APK"
