#!/usr/bin/env bash
# Exports the signed arm64 debug APK and verifies it.
#   tools/export_android.sh [output.apk]
# versionCode = git commit count, versionName = git describe (DECISIONS D012).
# Signed with the committed debug keystore (DECISIONS D011) so every build installs over the last.
source "$(dirname "$0")/lib/common.sh"
require_godot

OUT="${1:-$APK_PATH}"
PRESET="Android Debug"
mkdir -p "$(dirname "$OUT")"

VERSION_CODE="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"
VERSION_NAME="$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || echo dev)"

# Patch version into the preset for this export only; always restore.
cp "$ROOT/export_presets.cfg" "$BUILD_DIR/.export_presets.cfg.bak"
trap 'mv "$BUILD_DIR/.export_presets.cfg.bak" "$ROOT/export_presets.cfg"' EXIT
sed -i "s|^version/code=.*|version/code=$VERSION_CODE|; s|^version/name=.*|version/name=\"$VERSION_NAME\"|" "$ROOT/export_presets.cfg"

export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"

log "Exporting $PRESET -> $OUT (versionCode $VERSION_CODE, versionName $VERSION_NAME)"
rm -f "$OUT" "$OUT.idsig"
LOG="$BUILD_DIR/export.log"
godot_headless --export-debug "$PRESET" "$OUT" >"$LOG" 2>&1 || { tail -40 "$LOG"; die "export failed"; }
[[ -f "$OUT" ]] || { tail -40 "$LOG"; die "export produced no APK"; }
fail_on_godot_errors "$LOG" "Android export"

BT="$ANDROID_HOME/build-tools/$ANDROID_BUILD_TOOLS"
log "Verifying APK"
"$BT/apksigner" verify "$OUT" >/dev/null 2>&1 || die "apksigner verify failed"
apk_cert="$("$BT/apksigner" verify --print-certs "$OUT" 2>/dev/null | awk -F': ' '/certificate SHA-256 digest/ {print $2; exit}')"
key_cert="$(keytool -list -v -keystore "$DEBUG_KEYSTORE" -storepass android 2>/dev/null | awk '/SHA256:/ {print $2; exit}' | tr -d ':' | tr 'A-F' 'a-f')"
[[ -n "$apk_cert" && "$apk_cert" == "$key_cert" ]] || die "APK not signed with keys/debug.keystore ($apk_cert vs $key_cert)"
ok "signed with project debug key"

badging="$("$BT/aapt2" dump badging "$OUT" 2>/dev/null)"
abis="$(sed -n "s/^native-code: //p" <<<"$badging" | tr -d "'")"
[[ "$abis" == "arm64-v8a" ]] || die "unexpected ABIs: '$abis' (arm64-v8a only, DECISIONS D013)"
pkg="$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" <<<"$badging")"
target="$(sed -n "s/^targetSdkVersion:'\([0-9]*\)'.*/\1/p" <<<"$badging")"
min="$(sed -n "s/^minSdkVersion:'\([0-9]*\)'.*/\1/p" <<<"$badging")"
size_mb="$(awk "BEGIN {printf \"%.1f\", $(stat -c %s "$OUT") / 1048576}")"
awk "BEGIN {exit !($size_mb <= $APK_MAX_MB)}" || die "APK ${size_mb} MB exceeds ${APK_MAX_MB} MB budget"
ok "APK $OUT"
ok "  package $pkg · versionCode $VERSION_CODE · minSdk $min · targetSdk $target · ABI $abis · ${size_mb} MB"
printf 'apk_path=%s\napk_mb=%s\npackage=%s\nversion_code=%s\nversion_name=%s\nmin_sdk=%s\ntarget_sdk=%s\n' \
  "$OUT" "$size_mb" "$pkg" "$VERSION_CODE" "$VERSION_NAME" "$min" "$target" > "$BUILD_DIR/apk-info.env"
