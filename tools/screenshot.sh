#!/usr/bin/env bash
# Renders a scene with the real (Mobile) renderer and saves a PNG for visual review.
#   tools/screenshot.sh [scene=res://src/world/proving_grounds/proving_grounds.tscn] [out.png] [preset=gfx_high]
source "$(dirname "$0")/lib/common.sh"
require_godot
can_render || die "no display and no xvfb-run (tools/setup_toolchain.sh --with-render)"

SCENE="${1:-res://src/world/proving_grounds/proving_grounds.tscn}"
OUT="${2:-$BUILD_DIR/screenshots/$(basename "${SCENE%.*}").png}"
PRESET="${3:-gfx_high}"
mkdir -p "$(dirname "$OUT")"
LOG="$BUILD_DIR/screenshot.log"
godot_render -- --scene="$SCENE" --preset="$PRESET" --screenshot="$(realpath -m "$OUT")" --frames=45 >"$LOG" 2>&1 \
  || { tail -30 "$LOG"; die "screenshot run failed"; }
fail_on_godot_errors "$LOG" "screenshot"
[[ -f "$OUT" ]] || die "no screenshot written"
ok "screenshot -> $OUT"
