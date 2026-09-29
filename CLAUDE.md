# CLAUDE.md — working agreement for this repo

Godot **4.7.2** · typed GDScript · Mobile renderer · Android arm64 first. Original IP homage to the
open-world wasteland RPG genre. Read `docs/DESIGN.md` (architecture, schemas), `docs/ROADMAP.md`
(phase + exit criteria), `docs/DECISIONS.md` (why things are the way they are) before changing
architecture.

## Commands

```bash
tools/setup_toolchain.sh --with-render   # once per machine/container (idempotent)
tools/ci.sh                              # full pipeline: lint, IP check, import, tests, APK, screenshot, bench
tools/ci.sh --no-export --no-render      # fast inner loop (~10 s)
tools/export_android.sh                  # signed debug APK -> build/wasteland-debug.apk
tools/run_bench.sh gfx_high              # draw-call budget check under a real renderer
tools/screenshot.sh <res://scene.tscn> <out.png> [preset]   # look at what you built
godot --path . -- --autoplay --screenshot=build/x.png --frames=420   # combat screenshot (needs xvfb-run)
godot --headless --audio-driver Dummy -s addons/gut/gut_cmdln.gd   # tests only
```

In the cloud container: `export ANDROID_HOME=/opt/android-sdk` if it isn't set.
Look at screenshots after any visual change — lavapipe renders the real Mobile renderer.
FPS/memory from lavapipe are meaningless; only draw calls/primitives/objects are comparable.

## Layout

```
src/autoload/   EventBus, Settings, GameState, SaveManager — the ONLY autoloads (D005)
src/core/       static classes: ContentDB, Def, Log, PerfProbe, CliArgs, PhysicsLayers, save/SaveCodec, save/SaveMigrator
src/settings/   GraphicsPreset (Def)
src/main/       main.tscn: boot, world routing, CLI flags, HUD/touch/debug layers
src/input/      InputBindings, InputRouter, InputFrame (screen space), ActorIntent (world space), AimMath
src/combat/     WeaponDef/WeaponState/WeaponMount, HealthPool/HealthComponent, DamageInfo, Hitscan,
                ProjectileSystem, AimAssist, CombatServices
src/actors/     Actor base, ActorDef/EnemyArchetypeDef, ActorVisual, MeshMerge, player/, enemy/
src/ai/         AIBrain (utility HFSM + blackboard), AIState, Perception, states/
src/vfx/        MultiMeshPool, TracerPool, BurstPool (one draw call each)
src/world/      environments, camera (CameraRig), greybox kit, spawning, proving_grounds (P1 arena)
src/ui/         SafeAreaContainer, hud/, touch/, debug/PerfHud, debug/DevPanel
src/debug/      bench
src/shaders/    .gdshader files
data/           content Defs as .tres, by domain (data/settings/graphics/…)
translations/   strings.csv (all player-facing text is a key)
tests/unit, tests/integration, tests/fixtures
tools/          shell tooling (.gdignore'd)   docs/  (.gdignore'd)   keys/debug.keystore
```

## Conventions (enforced by CI where possible)

- **Typed GDScript everywhere.** `untyped_declaration` is an error, including loop variables
  (`for x: int in arr`). Prefer `:=` when the type is obvious.
- `gdformat --line-length 120` and `gdlint` must pass (`gdlintrc`). Run `gdformat --line-length 120 src tests` before committing.
- Files `snake_case.gd`; `class_name PascalCase` for reusable types; private members `_prefixed`;
  constants `UPPER_SNAKE`; signals past tense (`died`, `item_added`).
- **Signals up, calls down.** No `get_node("../..")`. Cross-system broadcasts go through `EventBus`.
- **Domain logic in `RefCounted` classes** (testable without scenes); Nodes are thin adapters.
- Actors are driven only through `ActorIntent` (D029). Level systems are injected
  (`CombatServices`, `WorldContext`, D031) — never looked up globally.
- Resources mutated per instance must be `resource_local_to_scene` / duplicated (D032).
- New `class_name` scripts need `godot --headless --import` before running scenes that use them.
- Soft cap 400 lines per script. No god scripts.
- Content = typed `Def` resources in `data/` with type-prefixed, lower_snake ids (`wpn_`, `arm_`,
  `perk_`, `gfx_`…). Heavy assets referenced by path. Every new Def type overrides `validate()`.
- Player-facing text: translation keys only (`tr("KEY")`), added to `translations/strings.csv`.
- Persistent state is plain data in `GameState` (no Objects). Changing the save schema means:
  bump `SaveMigrator.CURRENT_SCHEMA`, add a step, add a fixture under `tests/fixtures/saves/`.
- Tests: `tests/unit/test_<thing>.gd` (`extends GutTest`). GUT fails a test on any unexpected
  `push_error`/engine error — assert expected ones with `assert_push_error` / `assert_engine_error`.
- New scenes must load in `tests/integration/test_scripts_compile.gd` (automatic) and deserve a
  smoke test in `tests/integration/test_scenes.gd`.

## Performance rules (budgets in DESIGN §3)

- Measured on Mobile renderer: every shadow-casting `MeshInstance3D` costs **~2 draw calls**;
  outlined 2-surface actors cost **4**; the debug UI costs ~25. Batch props with MultiMesh.
- Anything repeated > ~10× on screen goes through MultiMesh or a pool.
- No allocations in hot loops; no per-frame string building outside debug UI.
- New feature ⇒ new bench stage or scenario when it affects rendering; `tools/run_bench.sh` must stay within budget.
- If a feature blows the budget: fix it or cut it, and log the cut in DECISIONS.md.

## IP rules

No franchise names, items, factions, UI designs or assets. `tools/check_ip.sh` greps a denylist
over `src/ data/ translations/ assets/`. Use the glossary in DESIGN §2. Only CC0/permissive assets,
each logged in `docs/ASSETS.md` with source URL + licence.

## Workflow

- Develop on the assigned branch; commit per milestone with clear messages; phase tags `p0`, `p1`…
  trigger a GitHub Release with the APK (`.github/workflows/ci.yml`).
- Each phase ends with: CI green, APK exported, tag, CHANGELOG entry with perf numbers, PERF.md row.
- Architecture change ⇒ DECISIONS.md entry in the same commit. Guessing an engine API ⇒ verify by
  running it (the 4.7 API can be dumped with `godot --headless --dump-extension-api-with-docs`).
- Ask the director only for irreversible or genuinely creative decisions (DESIGN §17).
