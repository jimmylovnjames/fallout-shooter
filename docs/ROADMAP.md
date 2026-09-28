# Roadmap

Every phase ends with: all tests green · signed debug APK exported · git tag `pN` · CHANGELOG
entry with measured perf numbers (CI draw calls + on-device FPS/RSS when available).
If a feature blows the budget it is fixed or cut, and the cut is recorded in `DECISIONS.md`.

| Phase | Tag | Goal | Exit criteria |
|---|---|---|---|
| **P0 Setup** | `p0` | Repo, docs, toolchain, CI, export pipeline, core scaffolding | `tools/ci.sh` green end-to-end from a clean container; APK installs and runs on device showing the proving-grounds scene with PerfHUD, preset switching and the in-app benchmark |
| **P1 Core loop (greybox)** | `p1` | Movement, twin-stick touch + gamepad + KBM via `InputRouter`, camera rig with cut-away, hitscan + projectile shooting, one enemy archetype (patrol/engage), health, death/respawn, HUD | 60 fps High on reference device with 10 enemies + 200 projectiles in flight; < 150 draw calls in the combat bench |
| **P2 RPG spine** | `p2` | Character creator, attributes/skills/perks, XP/levels, inventory + loot, Bracer v1, save/load of player + world deltas, slots + autosave + lifecycle save | Save → kill app → relaunch restores state; content validation covers all P2 defs |
| **P3 Gear depth** | `p3` | Weapon mods (stats + visuals), layered armor, Exoframe with cell/durability loop, rarity + affixes, crafting benches, scrapping | Mod swap updates stats + visuals; crafting fully unit-tested |
| **P4 Base building** | `p4` | Settlement zones, socket placement, power graph, settlers with jobs/happiness, raids (live + abstract) | 300-piece settlement stays within the settlement draw-call bucket (30) |
| **P5 Narrative engine** | `p5` | `.dlg` DSL + importer, flags, factions/reputation, companions with approval + commands, quest journal + markers, one quest line with 3 divergent outcomes | All 3 outcomes reachable by automated script tests; world-state switches verified in integration tests |
| **P6 Vertical slice** | `p6` | ~1 km² region: 1 town, 1 settlement, 3 dungeons, 10 quests; final lighting, shaders, VFX, audio | Director sign-off on look & feel; perf budgets met on reference device; Low preset ≥ 30 fps on mid-range |
| **P7+ Ship track** | `p7…` | More regions via asset packs, perf hardening, AAB + Play signing, content rating, store assets | Internal-testing track upload succeeds |

## P0 breakdown (this phase)

- [x] `docs/DESIGN.md`, `docs/ROADMAP.md`, `docs/DECISIONS.md`, `docs/ASSETS.md`, `docs/PERF.md`, `CLAUDE.md`
- [x] Godot 4.7.2 project: Mobile renderer + GL fallback, Jolt, stretch/aspect, typed-GDScript warnings as errors
- [x] Autoloads: `EventBus`, `Settings`, `GameState`, `SaveManager`
- [x] Core: `ContentDB`, `Def`, `Log`, `PerfProbe`, `SaveCodec`, `SaveMigrator`
- [x] Data-driven graphics presets (Low/Medium/High/Ultra) + device-tier default
- [x] Proving-grounds greybox scene, PerfHUD, DevPanel (preset switch, render-scale, bench)
- [x] In-app benchmark with JSON results (+ logcat line)
- [x] GUT vendored; unit + integration tests
- [x] `tools/setup_toolchain.sh`, `tools/ci.sh`, `tools/export_android.sh`, `tools/run_bench.sh`, `tools/screenshot.sh`, `tools/check_ip.sh`
- [x] GitHub Actions workflow mirroring `ci.sh`; releases on `p*` tags
- [x] Signed debug APK, tag `p0`

## Parking lot (not scheduled)
- Full-screen depth-edge outline on Ultra (needs device numbers)
- Dialogue graph visualiser for `.dlg`
- Play Asset Delivery integration (P7)
- Cloud saves (Play Games Services) — post-P7, only if wanted
