#!/usr/bin/env bash
# Shared helpers for tools/*.sh. Source it; don't run it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../versions.env
source "$ROOT/tools/versions.env"

GODOT_TAG="${GODOT_VERSION}-${GODOT_FLAVOR}"
GODOT_HOME="${GODOT_HOME:-$HOME/.local/opt/godot-$GODOT_TAG}"
if [[ -z "${GODOT_BIN:-}" ]]; then
  if [[ -x "$GODOT_HOME/Godot_v${GODOT_TAG}_linux.x86_64" ]]; then
    GODOT_BIN="$GODOT_HOME/Godot_v${GODOT_TAG}_linux.x86_64"
  else
    GODOT_BIN="$(command -v godot || true)"
  fi
fi
ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
export ANDROID_HOME
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_FLAVOR}"
EDITOR_SETTINGS="$HOME/.config/godot/editor_settings-${GODOT_VERSION%.*}.tres"
BUILD_DIR="$ROOT/build"
DEBUG_KEYSTORE="$ROOT/keys/debug.keystore"
APK_PATH="$BUILD_DIR/wasteland-debug.apk"

log()  { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m ok %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m !! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m xx %s\033[0m\n' "$*" >&2; exit 1; }

require_godot() {
  [[ -n "$GODOT_BIN" && -x "$GODOT_BIN" ]] || die "Godot not found. Run tools/setup_toolchain.sh"
  local v
  v="$("$GODOT_BIN" --version 2>/dev/null | tail -1)"
  [[ "$v" == "${GODOT_VERSION}.${GODOT_FLAVOR}"* ]] || die "Godot $v found, $GODOT_TAG required (tools/versions.env)"
}

# Runs Godot headless against the project.
godot_headless() {
  "$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" "$@"
}

# Runs Godot with a real renderer. Without a display it uses Xvfb; with no GPU, Mesa lavapipe
# provides Vulkan in software (DECISIONS D015). Only draw calls/primitives are meaningful there.
godot_render() {
  local args=(--audio-driver Dummy --path "$ROOT" --resolution 1280x720 "$@")
  if [[ -n "${DISPLAY:-}" ]]; then
    "$GODOT_BIN" "${args[@]}"
  else
    command -v xvfb-run >/dev/null || die "xvfb-run missing (tools/setup_toolchain.sh --with-render)"
    xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" "${args[@]}"
  fi
}

can_render() {
  [[ -n "${DISPLAY:-}" ]] || command -v xvfb-run >/dev/null
}

# Fails when Godot output contains script/engine errors (headless import does not fail on them).
fail_on_godot_errors() {
  local logfile="$1" what="$2"
  if grep -E '^(SCRIPT ERROR|ERROR):' "$logfile" >/dev/null; then
    grep -E -A2 '^(SCRIPT ERROR|ERROR):' "$logfile" | head -40 >&2
    die "$what produced errors (full log: $logfile)"
  fi
}
