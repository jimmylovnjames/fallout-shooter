# Changelog

Each phase tag gets an entry with what shipped, measured performance, and known gaps.
Device numbers are filled in when the director runs the in-app benchmark (docs/PERF.md).

## [p0] — 2026-09-28 — Setup

### Added
- Design docs: `docs/DESIGN.md` (architecture, data schemas, scene tree, budgets, risks),
  `docs/ROADMAP.md`, `docs/DECISIONS.md` (D001–D026), `docs/ASSETS.md`, `docs/PERF.md`, `CLAUDE.md`.
- Godot 4.7.2 project: Mobile renderer with GLES3 fallback, Jolt physics, ETC2/ASTC import,
  1280×720 canvas_items/expand scaling, sensor-landscape, typed GDScript enforced (untyped = error),
  physics layer names, audio bus layout (Master/Music/SFX/Ambience/UI/Voice), CSV localisation.
- Autoloads: `EventBus` (typed signals), `Settings` (persisted prefs, data-driven graphics presets,
  device-tier default, 1080-line-normalised render scale, bus volumes), `GameState` (plain-data flag
  store), `SaveManager` (slots, metadata, Android pause/focus-out/close saves).
- Core: `ContentDB` registry + `Def` base (export-safe directory walk, duplicate/validation
  reporting), `SaveCodec` (ZSTD + SHA-256 + atomic rename + `.bak`, object decoding refused),
  `SaveMigrator` (step chain), `PerfProbe`, `CliArgs`, `Log`.
- Graphics presets Low/Medium/High/Ultra as `.tres` data.
- Proving-grounds greybox scene (shared environment, sun rig, top-down camera, outlined actor
  stand-ins, MultiMesh debris), perf HUD (F3), touch dev panel (presets, render scale, HUD,
  benchmark, copy result), in-app benchmark with JSON + `BENCH_RESULT` logcat line.
- Tooling: `tools/setup_toolchain.sh`, `tools/ci.sh`, `tools/export_android.sh` (signature,
  ABI, size and SDK checks), `tools/run_bench.sh`, `tools/screenshot.sh`, `tools/check_ip.sh`,
  `tools/release_notes.sh`; GitHub Actions workflow (APK artifact per push, Release per phase tag).
- Tests: 66 GUT tests (unit + integration + permanent save fixture `schema_1.sav`).

### Performance (CI, lavapipe software Vulkan, Mobile renderer, High preset, 1280×720)
| Scenario | Draw calls | Primitives |
|---|---:|---:|
| bench `target_scene` (30 meshes + 3 000 MultiMesh + 20 outlined actors) | 141 | 210 k |
| bench `props_nodes_400` (unbatched, informational) | 708 | 8.5 k |
| bench `props_multimesh_4000` | 5 | 240 k |
| bench `actors_20_outlined` | 81 | 29 k |
| proving grounds incl. debug UI | 118 | 68 k |

APK: **27.0 MB**, arm64-v8a only, minSdk 24, targetSdk 36. On-device FPS/RSS: **pending** — run
the in-app benchmark on the OnePlus 12 (docs/PERF.md).

### Known gaps / risks surfaced
- No on-device profiling possible from the build container; device numbers depend on a manual run.
- 20 outlined actors already cost 80 draw calls (bucket was 60) → P1 must merge actor surfaces.
- "WASTELAND" is an existing game trademark → must be renamed before any public release.
