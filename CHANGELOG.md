# Changelog

Each phase tag gets an entry with what shipped, measured performance, and known gaps.
Device numbers are filled in when the director runs the in-app benchmark (docs/PERF.md).

## [p1] — 2026-09-29 — Core loop (greybox)

### Added
- **Input:** `InputRouter` merges keyboard/mouse (cursor aim), gamepad (twin-stick, RT or
  full-deflection fire) and touch into one frame; runtime `InputBindings`; device auto-switching.
- **Touch:** floating twin sticks (right stick aims and fires past 50 % deflection) + Reload /
  Swap / Use buttons, one multi-touch dispatcher (a thumb on a stick never blocks a button tap),
  shown only while touch is the active device; aim assist (14° cone, LOS-checked).
- **Actors:** intent-driven `Actor` shared by player and AI; merged single-surface greybox body
  with outline; hit flash + dissolve death via instance uniforms; player respawn (3 s) with 2 s
  spawn protection.
- **Camera:** follow rig with aim look-ahead and a dithered cut-away that keeps the player visible
  behind buildings (global shader uniforms).
- **Combat:** data-driven weapons (`wpn_service_pistol` hitscan, `wpn_rivet_carbine` projectile,
  `wpn_scav_repeater` enemy), spread, frame-rate-independent fire cadence, magazines, reload, swap;
  projectiles/tracers/impacts each rendered by one MultiMesh.
- **AI:** `enm_scavenger` with a utility-scored state machine (patrol / engage / investigate),
  FOV + line-of-sight + hearing, navmesh pathing, strafing at preferred range, burst fire with
  settling aim error, target leading; AI LOD (10 Hz near / 2 Hz far).
- **Arena:** proving grounds rebuilt as a playable block — batched props with colliders, navmesh
  baked from colliders, 10 pooled hunting enemies with respawn.
- **HUD:** health, weapon + ammo, reload progress, kill count, damage vignette, death banner.
- **Tooling:** `--autoplay` pilot; end-to-end combat soak test; `combat_p1` bench stage; CI now
  also renders a combat screenshot.
- Tests: 112 (unit + integration incl. real-physics combat, AI state transitions, soak).

### Fixed / learned (see DECISIONS D028–D036)
- Shared `NavigationMesh` resource baked concurrently by two level instances → AI without
  navmesh. Now local-to-scene + duplicated.
- Instance uniforms shared by a material and its outline pass must use the same slot → explicit
  `instance_index`.
- Enemies never hit a strafing player (slow, unled projectiles) → target leading.
- Enemies could engage from off-screen → sight 18 m, camera 24 m.
- Backlit sun made camera-facing walls black → sun now lights what the camera sees.

### Performance (CI, lavapipe software Vulkan, Mobile renderer, High preset, 1280×720)
| Scenario | Draw calls | Primitives |
|---|---:|---:|
| **bench `combat_p1`** (arena + 1 player + 10 enemies + 200 projectiles + FX) — target < 150 | **53** | 83 k |
| proving grounds gameplay incl. HUD + touch + debug UI | ~79 | 70 k |
| bench `target_scene` (P0 reference) | 143 | 210 k |

APK: **27.2 MB**. On-device FPS/RSS for the P1 exit criterion (60 fps High, 10 enemies +
200 projectiles): **pending** — run Dev → Run benchmark (includes `combat_p1`) and send the result.

### Known gaps
- Autopilot orbit heuristic can hug walls (demo/soak only).
- No off-screen threat indicators yet (P2).
- Enemy weapons have infinite reserve ammo; player reloads are free until P2 inventory.

## [p0] — 2026-09-28 — Setup

### Added
- Design docs: `docs/DESIGN.md` (architecture, data schemas, scene tree, budgets, risks),
  `docs/ROADMAP.md`, `docs/DECISIONS.md` (D001–D027), `docs/ASSETS.md`, `docs/PERF.md`, `CLAUDE.md`.
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
  `tools/release_notes.sh`; exported-PCK smoke test (Linux export boots headless and must load
  all content from the PCK); GitHub Actions workflow (APK artifact per push, Release per phase tag).
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
