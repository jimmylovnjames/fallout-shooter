#!/usr/bin/env bash
# Prints release notes for a phase tag: its CHANGELOG section + the CI summary of this build.
#   tools/release_notes.sh p0
source "$(dirname "$0")/lib/common.sh"
TAG="${1:?tag required}"
awk -v tag="$TAG" '
  /^## / { if (found) exit; if (index($0, "[" tag "]")) found=1 }
  found { print }
' "$ROOT/CHANGELOG.md"
if [[ -f "$BUILD_DIR/ci-summary.md" ]]; then
  printf '\n### This build (CI)\n'
  cat "$BUILD_DIR/ci-summary.md"
fi
printf '\nInstall: download the APK on the phone and open it (allow installs from this source), or\n`adb install -r wasteland-%s-debug.apk`.\n' "$TAG"
