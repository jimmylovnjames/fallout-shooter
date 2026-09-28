#!/usr/bin/env bash
# The whole pipeline, same locally and in GitHub Actions:
#   hygiene → lint → IP check → import → GUT tests → signed APK → (render) screenshot + bench
#   tools/ci.sh              # full run (render steps auto-skip without Xvfb)
#   tools/ci.sh --no-export  # skip APK export
#   tools/ci.sh --no-render  # skip screenshot/bench
source "$(dirname "$0")/lib/common.sh"

EXPORT=1; RENDER=1
for a in "$@"; do
  case "$a" in
    --no-export) EXPORT=0 ;;
    --no-render) RENDER=0 ;;
    *) die "unknown option $a" ;;
  esac
done

cd "$ROOT"
mkdir -p "$BUILD_DIR/test-results"
SUMMARY="$BUILD_DIR/ci-summary.md"
: > "$SUMMARY"
start=$(date +%s)

require_godot
ok "Godot $("$GODOT_BIN" --version | tail -1)"

log "Repo hygiene"
big="$(git ls-files -z | xargs -0 -I{} find {} -maxdepth 0 -type f -size +"${MAX_FILE_MB}"M 2>/dev/null || true)"
[[ -z "$big" ]] || die "files over ${MAX_FILE_MB} MB (DECISIONS D021): $big"
ok "no tracked file over ${MAX_FILE_MB} MB"

log "Lint"
if command -v gdlint >/dev/null; then
  gdlint src tests
  gdformat --check --line-length 120 src tests
else
  [[ -n "${CI:-}" ]] && die "gdtoolkit missing in CI"
  warn "gdtoolkit not installed — skipping lint (pip install 'gdtoolkit==4.*')"
fi

"$ROOT/tools/check_ip.sh"

log "Import"
godot_headless --import >"$BUILD_DIR/import.log" 2>&1 || { tail -30 "$BUILD_DIR/import.log"; die "import failed"; }
fail_on_godot_errors "$BUILD_DIR/import.log" "import"
ok "import clean"

log "Tests (GUT)"
set +e
godot_headless -s addons/gut/gut_cmdln.gd >"$BUILD_DIR/test.log" 2>&1
tcode=$?
set -e
sed -n '/Run Summary/,$p' "$BUILD_DIR/test.log" | sed 's/\x1b\[[0-9;]*m//g'
[[ $tcode -eq 0 ]] || die "tests failed (full log: build/test.log, JUnit: build/test-results/junit.xml)"
tests_line="$(sed 's/\x1b\[[0-9;]*m//g' "$BUILD_DIR/test.log" | awk '/^Tests /{t=$2} /^Passing Tests/{p=$3} /^Asserts/{a=$2} END{print p"/"t" tests, "a" asserts"}')"
echo "- Tests: $tests_line" >> "$SUMMARY"

log "Exported-PCK smoke test (Linux export runs the same PCK/remap code paths as Android)"
rm -rf "$BUILD_DIR/linux" && mkdir -p "$BUILD_DIR/linux"
godot_headless --export-debug "Linux Smoke" "$BUILD_DIR/linux/wasteland.x86_64" >"$BUILD_DIR/linux-export.log" 2>&1 \
  || { tail -30 "$BUILD_DIR/linux-export.log"; die "linux smoke export failed"; }
fail_on_godot_errors "$BUILD_DIR/linux-export.log" "linux smoke export"
timeout 120 "$BUILD_DIR/linux/wasteland.x86_64" --headless --audio-driver Dummy --quit-after 60 >"$BUILD_DIR/pck-smoke.log" 2>&1 \
  || { tail -30 "$BUILD_DIR/pck-smoke.log"; die "exported build crashed"; }
fail_on_godot_errors "$BUILD_DIR/pck-smoke.log" "exported build"
defs="$(sed -n 's/.*\[ContentDB\] loaded \([0-9]*\) defs.*/\1/p' "$BUILD_DIR/pck-smoke.log" | head -1)"
[[ "${defs:-0}" -gt 0 ]] || die "exported build loaded no content defs"
ok "exported build boots; ContentDB loaded $defs defs from the PCK"

if [[ $EXPORT -eq 1 ]]; then
  "$ROOT/tools/export_android.sh" "$APK_PATH"
  # shellcheck disable=SC1091
  source "$BUILD_DIR/apk-info.env"
  echo "- APK: ${apk_mb} MB, ${package}, versionCode ${version_code}, minSdk ${min_sdk}, targetSdk ${target_sdk}" >> "$SUMMARY"
fi

if [[ $RENDER -eq 1 ]] && can_render; then
  "$ROOT/tools/screenshot.sh" res://src/world/proving_grounds/proving_grounds.tscn "$BUILD_DIR/screenshots/proving_grounds_high.png" gfx_high
  "$ROOT/tools/run_bench.sh" gfx_high 1 2
  python3 - "$BUILD_DIR/bench-gfx_high.json" >> "$SUMMARY" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
print(f"- Bench ({r['device']['gpu']}, {r['preset']}): " + ", ".join(
    f"{s['name']} {s['draw_calls_max']} draws" for s in r['stages']))
PY
else
  warn "render steps skipped (no display/xvfb or --no-render)"
fi

echo "- CI wall time: $(( $(date +%s) - start ))s" >> "$SUMMARY"
log "Summary"
cat "$SUMMARY"
ok "CI passed"
