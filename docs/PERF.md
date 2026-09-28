# Performance log

Budgets (DESIGN §3): **60 fps High / ≥30 fps Low** on device · **< 250 draw calls** · **< 1.5 GB RSS** ·
**APK < 150 MB**.

## How numbers are produced

| Metric | Source | Trustworthy on CI? |
|---|---|---|
| Draw calls, primitives, objects | `Performance.RENDER_TOTAL_*` via `src/debug/bench` | **Yes** — renderer-driven, same on lavapipe and device (± driver-specific passes) |
| Pipeline compilations | `Performance.PIPELINE_COMPILATIONS_*` | Yes (counts), not timings |
| FPS / frame times | bench `avg_ms`, `p95_ms` | **No** — device only |
| Process RSS | `adb shell dumpsys meminfo com.jimmylovnjames.wasteland.dev` | Device only |
| VRAM / static memory | `Performance.RENDER_VIDEO_MEM_USED`, `MEMORY_STATIC` | Indicative only |
| APK size | `tools/export_android.sh` | Yes |

### Running the benchmark on the phone
1. Install the APK, launch, open the **Dev** panel (top right) → **Run benchmark** (~20 s).
2. Results show in the panel. **Copy result** puts the summary JSON on the clipboard — paste it
   into a message to me. Without a PC that's the whole workflow. With adb:
   `adb logcat -s godot | grep BENCH_RESULT`. (The full JSON lives in the app's private storage,
   `user://bench/`, which a file manager cannot reach.)
3. Memory: `adb shell dumpsys meminfo com.jimmylovnjames.wasteland.dev | grep -E "TOTAL (PSS|RSS)"`.
4. Paste the BENCH_RESULT line + meminfo TOTAL into the table below (or send it to me).

## Measured engine facts (P0, Mobile renderer, 1280×720, High preset)

- A shadow-casting `MeshInstance3D` costs **~2 draw calls** (color + shadow pass); without sun
  shadows it costs 1. 400 unbatched boxes → **708** draw calls; the same budget holds **4 000**
  MultiMesh instances in **5** draw calls.
- An outlined actor with 2 surfaces (body + weapon) costs **4** draw calls → 20 actors = 80.
  The actor bucket (60) in DESIGN §3.1 is too tight for 20 outlined actors; P1 must merge actor
  surfaces or outline only relevant actors. Tracked.
- Debug UI (perf HUD + dev panel) costs ~**24** canvas draw calls; hidden during the benchmark.
- Top-down camera distance is ~constant, so exponential depth fog acts as a uniform veil; haze
  must come from height fog + fog cards (environment retuned in P0).

## Results

| Phase | Build | Device / GPU | Preset | Scene | Draws (max) | Prims | FPS avg / p95 ms | RSS | APK |
|---|---|---|---|---|---:|---:|---|---|---:|
| P0 | CI | llvmpipe (software) | High | bench `target_scene` (30 meshes, 3 000 MM, 20 actors) | 141 | 210 k | n/a | n/a | 27.0 MB |
| P0 | CI | llvmpipe (software) | High | proving grounds (with debug UI) | 118 | 68 k | n/a | n/a | |
| P0 | device | OnePlus 12 / Adreno 750 | High | bench | _pending: director run_ | | | | |
| P0 | device | mid-range | Low | bench | _pending_ | | | | |
