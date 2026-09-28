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
