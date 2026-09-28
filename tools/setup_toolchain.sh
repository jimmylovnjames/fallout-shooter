#!/usr/bin/env bash
# Idempotent toolchain install: pinned Godot + export templates, Android SDK pieces, editor
# settings, lint tools. Same script locally and in CI.
#   tools/setup_toolchain.sh               # everything needed for tests + APK export
#   tools/setup_toolchain.sh --with-render # also Xvfb + Mesa lavapipe (screenshots/bench), needs apt
source "$(dirname "$0")/lib/common.sh"

WITH_RENDER=0
for a in "$@"; do [[ "$a" == "--with-render" ]] && WITH_RENDER=1; done

DL="https://downloads.godotengine.org/?version=${GODOT_VERSION}&flavor=${GODOT_FLAVOR}"

install_godot() {
  if [[ -n "$GODOT_BIN" && -x "$GODOT_BIN" ]] && "$GODOT_BIN" --version 2>/dev/null | grep -q "^${GODOT_VERSION}.${GODOT_FLAVOR}"; then
    ok "Godot $GODOT_TAG at $GODOT_BIN"; return
  fi
  log "Installing Godot $GODOT_TAG -> $GODOT_HOME"
  mkdir -p "$GODOT_HOME"
  curl -fsSL -o "$GODOT_HOME/godot.zip" "${DL}&slug=linux.x86_64.zip&platform=linux.64"
  unzip -q -o "$GODOT_HOME/godot.zip" -d "$GODOT_HOME" && rm "$GODOT_HOME/godot.zip"
  GODOT_BIN="$GODOT_HOME/Godot_v${GODOT_TAG}_linux.x86_64"
  chmod +x "$GODOT_BIN"
  ok "Godot installed: $GODOT_BIN (export GODOT_BIN or add to PATH)"
}

install_templates() {
  if [[ -f "$TEMPLATES_DIR/android_debug.apk" && -f "$TEMPLATES_DIR/version.txt" ]]; then
    ok "export templates in $TEMPLATES_DIR"; return
  fi
  log "Downloading export templates (~1.3 GB, only Android + Linux are kept)"
  local tpz; tpz="$(mktemp -d)/templates.tpz"
  curl -fsSL -o "$tpz" "${DL}&slug=export_templates.tpz&platform=templates"
  mkdir -p "$TEMPLATES_DIR"
  unzip -q -o -j "$tpz" 'templates/android_*' 'templates/version.txt' 'templates/linux_*x86_64*' -d "$TEMPLATES_DIR"
  rm -f "$tpz"
  ok "templates installed"
}

install_android_sdk() {
  if [[ -x "$ANDROID_HOME/build-tools/$ANDROID_BUILD_TOOLS/apksigner" && -x "$ANDROID_HOME/platform-tools/adb" ]]; then
    ok "Android SDK at $ANDROID_HOME"; return
  fi
  log "Installing Android SDK pieces -> $ANDROID_HOME"
  local sdkm="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
  if [[ ! -x "$sdkm" ]]; then
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    local z; z="$(mktemp -d)/clt.zip"
    curl -fsSL -o "$z" "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip"
    unzip -q -o "$z" -d "$ANDROID_HOME/cmdline-tools"
    rm -rf "$ANDROID_HOME/cmdline-tools/latest"
    mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  fi
  yes | "$sdkm" --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true
  "$sdkm" --sdk_root="$ANDROID_HOME" "platform-tools" "build-tools;$ANDROID_BUILD_TOOLS" "platforms;$ANDROID_PLATFORM" >/dev/null
  ok "Android SDK ready"
}

check_java() {
  command -v java >/dev/null || die "JDK 17+ required (apt install openjdk-17-jdk-headless)"
  local major
  major="$(java -XshowSettings:properties -version 2>&1 | awk -F'= ' '/java.specification.version/ {print $2}')"
  [[ "${major%%.*}" -ge 17 ]] || die "JDK 17+ required, found $major"
  ok "Java $major"
}

configure_editor() {
  # Godot writes editor settings on first editor start; import creates them.
  if [[ ! -f "$EDITOR_SETTINGS" ]]; then
    log "Creating editor settings"
    "$GODOT_BIN" --headless --editor --quit --path "$ROOT" >/dev/null 2>&1 || true
  fi
  [[ -f "$EDITOR_SETTINGS" ]] || die "editor settings not created at $EDITOR_SETTINGS"
  local java_home="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
  set_editor_setting "export/android/android_sdk_path" "$ANDROID_HOME"
  set_editor_setting "export/android/java_sdk_path" "$java_home"
  ok "editor settings: android_sdk_path=$ANDROID_HOME java_sdk_path=$java_home"
}

set_editor_setting() {
  local key="$1" value="$2"
  if grep -q "^$key = " "$EDITOR_SETTINGS"; then
    sed -i "s|^$key = .*|$key = \"$value\"|" "$EDITOR_SETTINGS"
  else
    printf '%s = "%s"\n' "$key" "$value" >> "$EDITOR_SETTINGS"
  fi
}

install_lint() {
  if command -v gdlint >/dev/null; then ok "gdtoolkit $(gdlint --version | awk '{print $2}')"; return; fi
  log "Installing gdtoolkit"
  pip install -q "gdtoolkit==4.*"
}

install_render_deps() {
  if command -v xvfb-run >/dev/null && ls /usr/share/vulkan/icd.d/lvp_icd*.json >/dev/null 2>&1; then
    ok "Xvfb + lavapipe present"; return
  fi
  log "Installing Xvfb + Mesa lavapipe"
  local sudo=""; [[ $EUID -ne 0 ]] && sudo="sudo"
  $sudo apt-get update -q && DEBIAN_FRONTEND=noninteractive $sudo apt-get install -y -q xvfb mesa-vulkan-drivers libgl1 >/dev/null
}

install_godot
require_godot
install_templates
check_java
install_android_sdk
configure_editor
install_lint
[[ $WITH_RENDER -eq 1 ]] && install_render_deps
ok "toolchain ready"
