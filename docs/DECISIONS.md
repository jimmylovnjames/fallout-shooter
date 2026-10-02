# Architecture Decision Log

Format: **ID — Decision** · Context · Consequences. Newest at the bottom. Superseded entries are
struck through and point to their replacement, never deleted.

---

**D001 — Pin Godot 4.7.2-stable.**
Latest stable on godotengine.org at project start (2026-09-28). Pinned in `tools/versions.env`;
upgrades are deliberate, tested in a branch, and logged here.
Consequence: GUT, export templates and CI all key off that one version string.

**D002 — Mobile renderer, Compatibility fallback, no Forward+-only features.**
Mobile (Vulkan) is the right renderer for tile-based GPUs. `rendering_device/fallback_to_opengl3`
keeps the game running on devices with broken Vulkan drivers. SDFGI, VoxelGI, SSAO, SSIL, SSR,
volumetric fog and FSR2 are unavailable, so the look is built from fog cards, baked AO, MSAA and FSR1.

**D003 — Jolt physics.**
Built into 4.7 (`physics/3d/physics_engine = "Jolt Physics"`); faster and more stable than
GodotPhysics3D for character controllers and many static colliders.

**D004 — Project lives at the repo root; non-game directories carry `.gdignore`.**
Simplest CLI (`--path .`). `docs/`, `tools/`, `keys/`, `build/` are excluded from import.

**D005 — Exactly four autoloads (EventBus, Settings, GameState, SaveManager). ContentDB, Log,
PerfProbe, SaveCodec, SaveMigrator are static classes.**
Static classes are global without a node, cannot hold scene references by accident, and are
trivially testable.

**D006 — Content = typed custom Resources (`*Def`) in text `.tres`; heavy assets by path.**
Typed + inspector-editable + diffable + CI-validated. Referencing meshes/textures by path keeps
the registry cheap to load. Registry walks with `ResourceLoader.list_directory`, which handles
export remaps (verified present in 4.7).

**D007 — Dialogue as a text DSL compiled by an import plugin (P5).**
Faster for a solo dev with AI help than a node-graph editor; diffs cleanly. Graph viewer later if wanted.

**D008 — Conditions/actions as `Expression` strings over a restricted context, parsed in CI.**
One mechanism for quests, dialogue, perks, recipes and world switches. Content is first-party,
so `Expression` is safe; the context object whitelists what scripts can touch.

**D009 — Save format: `var_to_bytes` (no objects) → SHA-256 → ZSTD file, atomic rename, `.bak`
rotation, migration chain with permanent fixtures.**
Plain-data decoding means tampered saves cannot execute code. Atomic rename + read-back
verification protects against Android killing the process mid-write.

**D010 — All player-facing strings are translation keys from day one.**
Renaming (glossary is still [PROPOSED]) becomes a CSV edit; localisation is free later.

**D011 — Debug keystore is committed (`keys/debug.keystore`, standard `android` passwords); the
release keystore never is.**
The build container is ephemeral; a fresh debug key per container would force uninstalling the
app before every update. A public debug key is only a risk for side-loaded dev builds.

**D012 — `versionCode` = `git rev-list --count HEAD`; `versionName` = `git describe`.**
Monotonic codes so each APK installs over the last.

**D013 — arm64-v8a only.**
All relevant devices are 64-bit; dropping armv7/x86 roughly halves the native library payload.
Measured APK baseline for an empty project: 28 MB.

**D014 — GUT 9.7.1 vendored in `addons/gut` (MIT), excluded from exports.**
Reproducible tests without network access at test time.

**D015 — CI renders with software Vulkan (Mesa lavapipe under Xvfb).**
Lets CI run the real Mobile renderer for screenshots and draw-call/primitive regression tracking.
FPS and memory numbers from lavapipe are meaningless and are never reported as device numbers.

**D016 — AI = utility-scored hierarchical state machine in GDScript (no GDExtension BT addon).**
GDExtension addons add per-platform binaries and engine-version coupling; a utility HFSM covers
patrol/investigate/flank/cover/flee and is easy to debug.

**D017 — Projectiles are data-oriented (packed arrays) and drawn by one MultiMesh.**
Constant draw calls and no node churn regardless of bullet count.

**D018 — Exteriors use dynamic sun + sky ambient (no LightmapGI); interiors use baked LightmapGI.**
Lightmaps conflict with a dynamic time of day and with streamed chunks. Baked lighting where it
pays: static interiors.

**D019 — Outlines via inverted-hull `next_pass` on actors/interactables only.**
Bounded extra draw calls; avoids a full-resolution post pass on tile-based GPUs.

**D020 — Quaternius CC0 animation libraries instead of Mixamo.**
The repo is public; Mixamo files may be used in games but not redistributed. Deviation from the
brief — revisit only if we move art to a private store.

**D021 — No Git LFS for now; CI rejects files > 50 MB.**
LFS bandwidth on a public repo with CI checkouts is a cost trap. Revisit at P6.

**D022 — Gameplay reads device-agnostic intents from `InputRouter`, never raw devices.**
Touch, gamepad and KBM are interchangeable; emulated-mouse-from-touch events are ignored by gameplay.

**D023 — Minimap/full map from a pre-baked region texture + UI markers; no second camera.**
A live top-down map camera would roughly double draw calls.

**D024 — Graphics presets are data (`GraphicsPreset` resources), applied by `Settings`.**
Scene-level features (fog cards, foliage density, outlines) listen to `EventBus.graphics_preset_applied`.

**D025 — Debug package id `com.jimmylovnjames.wasteland.dev`.**
Placeholder; the release application id is permanent once published and will be chosen with the
final title (P7). The `.dev` suffix lets dev and release builds coexist on one phone.

**D026 — Render scale is normalised to 1080 lines on the screen's short side.**
`effective = clamp(preset_scale × 1080 / short_side, 0.25, 1.0)`. A 1440p OnePlus 12 on High
(0.9) renders 972 lines instead of 1296 — the same cost as a 1080p phone. Raw fractions of native
resolution would make every preset ~1.8× more expensive on 1440p panels.

**D027 — Phase tags/releases can be created by the CI workflow (`workflow_dispatch`, input `release_tag`).**
The build container's git proxy accepts branch pushes but rejects tag pushes (observed at P0,
repeatable). Running the workflow with `release_tag: pN` tags the exact commit it built and
publishes the Release with the APK, so the tag always matches a green build. Pushing a `p*` tag
from a normal git client still works too.

**D028 — Input actions are registered at runtime from `InputBindings` (not `project.godot`).**
One typed, reviewable table of actions + default key/pad/mouse events; rebinding (P2) stores
overrides in Settings. `ensure_registered()` is idempotent and unit-tested.

**D029 — Actors are driven by `ActorIntent`; player and AI share one `Actor` class.**
`PlayerController` (input) and `AIBrain` (utility HFSM) only write intent (move/aim/fire/reload/
swap). Movement, facing, weapons and death are identical for both, so AI can't cheat and
autopilots/cutscenes can drive the player. One-shot intents (swap/reload) are consumed by the
weapon mount.

**D030 — Greybox actors are ONE merged surface with vertex colours; tint, hit flash and dissolve
are `instance uniform`s with explicit `instance_index`es shared by the outline pass.**
Measured: 11 actors + arena + 200 projectiles = 53 draw calls (P0's 2-surface actors cost 4 each).
Instance uniforms keep a single shared material; the engine requires passes of one instance to
agree on uniform slots, hence explicit indices.

**D031 — Level systems are injected, not looked up: `CombatServices` (projectiles, tracers,
bursts, RNG) and `WorldContext` (input router, CLI args).**
Main hands `WorldContext` to a world before it enters the tree; the world hands `CombatServices`
to actors it spawns. No hidden global lookups; tests build their own fixtures.

**D032 — Resources that get mutated per instance (navmesh bake) are `resource_local_to_scene`
and duplicated before use.**
Found in P1: two arena instances baking the same `NavigationMesh` concurrently → second bake
fails → AI has no navmesh. Same bug would hit a fast level reload.

**D033 — Enemies engage only inside what the camera shows; projectiles lead moving targets.**
Sight 18 m / preferred range 9 m with a 24 m camera distance. Slow (20 m/s) enemy projectiles stay
dodgeable, but `lead_skill` (0–1) aims at the first-order intercept so constant strafing isn't an
exploit (the soak test caught enemies never hitting a strafing player). Off-screen threat
indicators are a P2 HUD item.

**D034 — Arena spawns hunt: pooled enemies roam around the player's area instead of idling at
their spawn.** Keeps pressure in the P1 arena; open-world encounters (P6) will use schedules and
patrol routes instead.

**D035 — Sun direction favours readability: light travels roughly along the camera's view so
camera-facing walls are lit and shadows fall away from the player.** Supersedes P0's backlit sun.

**D036 — `--autoplay` scripted pilot for soak tests, demos and on-device perf runs.**
Gives repeatable combat load without a human; CI's soak test uses it to prove the full loop.

**D038 — Player and scavengers are different silhouettes on one material.** Director choice:
more detailed stylized shapes, player first, vivid high-contrast palette. The player is a wide
coat and square helmet with an amber lamp; scavengers are a round hood, junk pack and a long
pipe, tinted cyan. Both stay one merged surface plus the shared outline (D030).

**D037 — Stylized surface shaders stand in until P6 art.** Props, ground and building shells
share procedural spatial shaders (albedo breakup, contact darkening, per-material detail, a
`wetness` global) instead of flat colours. The arena road is painted into the ground shader so it
is not an extra shadow-casting slab. Buildings are one scaled MultiMesh; dust sheets and dry scrub
are one MultiMesh each and follow `fog_detail` / `foliage_density`. Batching rules are unchanged.
