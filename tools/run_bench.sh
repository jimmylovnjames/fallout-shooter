#!/usr/bin/env bash
# Runs the in-app benchmark with a real renderer and enforces the draw-call budget.
#   tools/run_bench.sh [preset=gfx_high] [warmup_s=1] [sample_s=3]
# On a machine without a GPU this uses lavapipe: draw calls/primitives are valid, fps is not.
source "$(dirname "$0")/lib/common.sh"
require_godot
can_render || die "no display and no xvfb-run (tools/setup_toolchain.sh --with-render)"

PRESET="${1:-gfx_high}"; WARMUP="${2:-1}"; SAMPLE="${3:-3}"
OUT="$BUILD_DIR/bench-$PRESET.json"
LOG="$BUILD_DIR/bench-$PRESET.log"
mkdir -p "$BUILD_DIR"
log "Benchmark preset=$PRESET warmup=${WARMUP}s sample=${SAMPLE}s"
set +e
godot_render -- --bench --preset="$PRESET" --bench-warmup="$WARMUP" --bench-sample="$SAMPLE" --bench-out="$OUT" >"$LOG" 2>&1
code=$?
set -e
fail_on_godot_errors "$LOG" "benchmark"
[[ -f "$OUT" ]] || { tail -30 "$LOG"; die "benchmark wrote no results"; }
python3 - "$OUT" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
print(f"  gpu={r['device']['gpu']} renderer={r['device']['renderer']} preset={r['preset']} scale={r['render_scale']:.2f}")
print(f"  {'stage':24} {'draws(max)':>10} {'prims(avg)':>11} {'objs':>6} {'fps*':>6} {'budget':>7}")
for s in r['stages']:
    print(f"  {s['name']:24} {s['draw_calls_max']:>10} {int(s['primitives_avg']):>11} {int(s['objects_avg']):>6} {s['fps_avg']:>6.1f} {'ok' if s['within_budget'] else 'OVER':>7}")
print("  * fps is only meaningful on real hardware")
PY
[[ $code -eq 0 ]] || die "draw-call budget exceeded (see $OUT)"
ok "bench within budget -> $OUT"
