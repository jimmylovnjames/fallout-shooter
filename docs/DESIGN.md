# WASTELAND (working title) — Technical & Systems Design

Status: living document. Owner: lead engineer (Claude). Last major revision: P0.
Anything marked **[PROPOSED]** is a placeholder awaiting the director's sign-off; anything
marked **[VERIFY]** is an engine/platform assumption not yet proven on the reference device.

---

## 1. Vision & pillars

A top-down / 3⁄4-isometric open-world post-apocalyptic RPG shooter for Android, built as a
spiritual homage to the *feel* of the 2010s open-world wasteland RPG — scavenging, crafting,
settlement building, consequential choices — with 100 % original IP.

| Pillar | What it means for engineering |
|---|---|
| **Readable combat from above** | Clarity beats fidelity: outlines, silhouettes, camera cut-aways, aim-assist tuned for thumbs. |
| **Scavenge → craft → build** | Every item is data; junk decomposes into components; the loop must scale with content, not code. |
| **Choices that stick** | A single world-state flag store drives NPCs, areas, factions and endings; everything persists. |
| **Mobile-first performance** | Every feature ships with a budget and a measurement. If it blows the budget, it gets cut or fixed. |

## 2. IP guardrails

Original IP only. The CI step `tools/check_ip.sh` greps `src/`, `data/`, `assets/` and
`translations/` for a denylist of distinctive franchise terms and fails the build on a hit.
Generic genre vocabulary (wasteland, raider, radiation-as-concept, scrap) is fine; distinctive
names, UI designs, factions, items and mechanics-as-presented are not.

### Glossary — our equivalents  **[PROPOSED — names are data, renaming is a string change]**

| Genre concept | Our term | Notes on how it differs |
|---|---|---|
| Wrist computer menu | **the Bracer** | Rugged salvaged field terminal; not a CRT, not green-monochrome. Visual design is an open art-direction question (§17). |
| 7 core attributes | **BRAWN, GRIT, REFLEX, SENSE, WITS, NERVE, CHARM** | No acronym gimmick, no Luck stat. See §6.2. |
| Slow-time limb targeting | **OVERCLOCK** | Time slows to ~15 % (never pauses); you drag across limb markers in real time; drains **Focus**. Different mechanic from a paused action-point queue. |
| Heavy power suit | **Exoframe** | Salvaged industrial load-lifter frame; burns **Frame Cells**. |
| Currency | **Scrip** | Printed by a trade faction; faction-dependent exchange rate is a possible hook. |
| Radiation | **Blight** | Contamination that suppresses max HP; cleansed with **Purge** consumables. |
| Chems | **Stims** | |
| Shelters | *none* | We do **not** use a numbered-shelter-company premise. Backstory is an open creative question. |

## 3. Technical constraints & budgets

| Item | Target |
|---|---|
| Engine | Godot **4.7.2-stable** (pinned in `tools/versions.env`), typed GDScript |
| Renderer | **Mobile** (Vulkan); automatic fallback to **Compatibility** (GLES3) on devices without usable Vulkan |
| Platform | Android arm64-v8a only, minSdk 24, targetSdk 36 (4.7 export defaults, verified from APK manifest) |
| Reference device | OnePlus 12 (Snapdragon 8 Gen 3 / Adreno 750, 1440p 120 Hz panel) |
| Frame rate | High preset: locked 60 fps. Low preset: ≥ 30 fps floor on mid-range (Adreno 6xx class) |
| Memory | < 1.5 GB process RSS (measured with `adb shell dumpsys meminfo`) |
| Draw calls | < 250 per frame **including shadow passes** (`RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`) |
| APK/AAB | < 150 MB base; additional regions as asset packs (P7) |
| Physics | Jolt (built into 4.7) |

### 3.1 Draw-call allocation (planning numbers, validated per phase in `docs/PERF.md`)

| Bucket | Budget | Technique |
|---|---:|---|
| Terrain (3×3 visible chunks) | 20 | 1–2 surfaces per chunk, splat shader |
| Static props | 50 | MultiMesh per (mesh, material) per chunk; merged static meshes |
| Actors (≤ 20 on screen) | 60 | body + weapon (+ outline pass on actors only). **P0 measurement: an outlined 2-surface actor costs 4 draws → 20 actors = 80.** P1 must merge actor surfaces and/or outline only hostiles/interactables in view |
| Settlement structures | 30 | build pieces batched into MultiMesh per piece type |
| Projectiles / VFX | 15 | one MultiMesh for all projectiles; pooled particles |
| Shadows (directional, 1–2 cascades) | 50 | shadow casters culled aggressively; props < 1 m don't cast |
| UI / HUD | 25 | single theme atlas |
| **Total** | **250** | |

### 3.2 Memory allocation (planning numbers)

Textures 450 MB · meshes 150 MB · audio 60 MB · engine + scripts + data 250 MB · headroom ~590 MB.

## 4. Architecture

### 4.1 Layers (dependencies point downward only)

```
Scenes            actors, world regions/chunks, UI screens           (.tscn + thin scripts)
Components        HealthComponent, Hurtbox, WeaponMount, AIBrain…    (Nodes; adapters only)
Domain            StatBlock, Inventory, Crafting, QuestTracker,      (RefCounted; no scene tree;
                  DialogueRunner, FactionLedger, DamageModel…         100 % unit-testable)
Autoloads         EventBus · Settings · GameState · SaveManager       (the only 4 globals)
Core (static)     ContentDB · Log · PerfProbe · Pool · Rng · SaveCodec · SaveMigrator
Engine            Godot 4.7
```

Rules:
1. **Domain logic lives in `RefCounted` classes** that know nothing about Nodes. Nodes wrap
   them. This is what makes the RPG math, inventory, crafting, quests and saves testable in
   GUT without spinning up scenes.
2. **Signals up, calls down.** A node may call methods on its children; it talks to parents and
   siblings via signals. Cross-system broadcasts go through `EventBus`.
3. **No god scripts.** Soft limit 400 lines per script; if a script needs a table of contents, split it.
4. **Only four autoloads**: `EventBus`, `Settings`, `GameState`, `SaveManager`. Everything else
   is either a static utility class (`class_name` + `static func`) or a node owned by a scene.

### 4.2 Autoload responsibilities

| Autoload | Owns | Must not |
|---|---|---|
| `EventBus` | Typed signal declarations only, grouped by domain | Contain logic or state |
| `Settings` | User preferences (`user://settings.cfg`), graphics preset application, audio bus volumes, device-tier detection | Know about gameplay |
| `GameState` | The authoritative persistent data model: profile, flags, quests, factions, world deltas, settlements, clock | Hold Node references |
| `SaveManager` | Slots, autosave cadence, Android lifecycle saves, encode/decode via `SaveCodec`, migration | Know how systems store their data internally |

### 4.3 Scene tree (runtime)

```
root
├─ EventBus / Settings / GameState / SaveManager          (autoloads)
└─ Main  (src/main/main.tscn)                             boot, scene routing, CLI flags, lifecycle
   ├─ World (Node3D)                                      hosts exactly one region OR one interior
   │  └─ Region_<id>  (region.tscn)
   │     ├─ Environment    WorldEnvironment · Sun · TimeOfDay · Weather (global shader uniforms)
   │     ├─ ChunkStreamer  threaded loads of chunk scenes around the focus point
   │     │  └─ Chunk_x_y   terrain · MultiMesh props · static colliders · NavigationRegion3D
   │     │                 · spawn markers · Persistent objects · WorldStateSwitch nodes
   │     ├─ Actors         player, companions, NPCs, enemies (pooled)
   │     ├─ Projectiles    data-oriented simulation, ONE MultiMeshInstance3D
   │     ├─ Vfx            pooled particles / decals
   │     └─ Settlements    runtime-built structures (batched)
   ├─ CameraRig            perspective, fixed yaw (optional 90° snaps), occluder cut-away
   ├─ AudioDirector        music layers, ambience beds, pooled 3D players
   ├─ InputRouter          touch sticks / gamepad / KBM  →  device-agnostic intents
   └─ UI (CanvasLayers)
      ├─ HUD            layer 10
      ├─ TouchControls  layer 20
      ├─ Bracer         layer 30   (wrist-device menu; world rendering throttled while open)
      ├─ Dialogue       layer 40
      ├─ Modal/Toasts   layer 50
      └─ Debug          layer 100  PerfHUD · DevPanel (stripped from release via feature tag)
```

### 4.4 Actor composition

```
Actor (CharacterBody3D)            actor.gd — wiring only
├─ Visual         model · AnimationTree · outline next_pass · per-instance uniforms (hit flash, dissolve)
├─ CollisionShape3D
├─ Stats          StatsComponent      → StatBlock (domain)
├─ Health         HealthComponent     → limb HP pools, damage resolution, died signal
├─ Hurtboxes      Area3D per limb group (head, torso, arms, legs)
├─ Inventory      InventoryComponent  → Inventory (domain)
├─ Equipment      EquipmentComponent  → weapon + layered armor slots
├─ WeaponMount    fires using WeaponDef + installed mods
├─ Controller     PlayerController | AIBrain
├─ Perception     (AI) sight cone, hearing, detection meter
├─ NavigationAgent3D
└─ Persistent     persist_id; save_state()/load_state()
```

### 4.5 Events

`EventBus` declares typed signals by domain (`app_*`, `settings_*`, `game_*`, `combat_*`,
`inventory_*`, `quest_*`, `world_*`). Emitters call `EventBus.<signal>.emit(...)`. EventBus is for
broadcasts with unknown/many listeners (UI, audio, quests, achievements). A parent listening to its
own child uses the child's signal directly.

## 5. Data-driven content

### 5.1 Format

- **Definitions are typed custom `Resource` classes** (suffix `Def`) saved as text `.tres` under
  `data/<domain>/`. Typed, inspector-editable, diffable, validated in CI.
- **Heavy assets are referenced by path** (`@export_file`), never by direct resource reference,
  so indexing a definition never drags meshes/textures into memory.
- **IDs** are globally unique `StringName`s with a type prefix: `wpn_`, `mod_`, `arm_`, `frm_`,
  `con_`, `junk_`, `cmp_`, `ammo_`, `perk_`, `skill_`, `attr_`, `rcp_`, `bld_`, `loot_`, `enc_`,
  `fac_`, `qst_`, `dlg_`, `cpn_` (companion), `npc_`, `loc_`, `reg_`, `gfx_`.
- **Dialogue** is authored in a text DSL (`.dlg`) compiled to `DialogueDef` by an
  `EditorImportPlugin` (P5). Text scales better than a node graph for a solo dev + AI authoring,
  and diffs cleanly. A read-only graph visualiser can come later.
- **JSON** is used only for interchange/debug (save inspector dump, external tooling).
- All player-facing strings are **translation keys** (`tr("ITEM_WPN_PIPE_PISTOL_NAME")`) in
  `translations/*.csv` from day one; renaming anything is a data change.

### 5.2 Registry — `ContentDB` (static class, not an autoload)

```gdscript
ContentDB.load_all("res://data")                  # at boot; walks with ResourceLoader.list_directory (export-safe)
ContentDB.get_def(&"wpn_pipe_pistol") -> Def
ContentDB.get_all(&"WeaponDef") -> Array[Def]
ContentDB.validate_all() -> PackedStringArray      # run in CI: every def validates; ids unique; refs resolve
```

Base class:

```gdscript
class_name Def extends Resource
@export var id: StringName
func get_def_type() -> StringName        # e.g. &"WeaponDef"
func validate() -> PackedStringArray     # subclass appends errors; CI fails on any
```

### 5.3 Conditions & actions

Quests, dialogue, perks, recipes and world switches share two tiny script forms:

```
condition: flag("met_mayor") and rep("fac_b") >= 20 and skill("skill_speech") >= 40
action:    set_flag("mayor_trusts_you", true); add_rep("fac_b", 10); give("con_purge", 1)
```

Evaluated by Godot's `Expression` against a **restricted `ScriptContext` object** exposing only
whitelisted query/mutation methods. Parsed once and cached. Every expression in `data/` is parsed
in CI, so a typo fails the build instead of a quest.

### 5.4 Schemas (fields abbreviated; all `@export`, typed)

**Items**

| Def | Key fields |
|---|---|
| `ItemDef` (base) | `id, name_key, desc_key, icon: path, mesh: path, weight_kg: float, value: int, rarity: Rarity, tags: Array[StringName], stack_max: int` |
| `WeaponDef` | `weapon_class (PISTOL,RIFLE,SHOTGUN,ENERGY,HEAVY,MELEE,THROWN), fire_mode (HITSCAN,PROJECTILE,MELEE,THROWN), damage, damage_type, rpm, mag_size, reload_s, range_m, spread_deg, recoil, projectile_speed, ammo_id, skill_id, crit_mult, limb_mult: Dictionary, mod_slots: Array[ModSlot]` |
| `WeaponModDef` | `slot (BARREL,SIGHT,MAG,STOCK,RECEIVER), compatible_classes, modifiers: Array[StatModifier], mesh: path, attach_point: StringName, requires: RequirementSet` |
| `ArmorDef` | `layer (UNDER, PLATE), limb (HEAD,TORSO,ARM_L,ARM_R,LEG_L,LEG_R, or ALL for underlayers), resist: Dictionary[damage_type→float], mod_slots` |
| `ExoframePartDef` | `limb, durability, resist, cell_drain_mult, mesh` + `ExoframeDef`: `base_speed, carry_bonus, cell_drain_per_s, sprint_drain_mult` |
| `ConsumableDef` | `effects: Array[EffectDef], use_time_s, addiction_chance` |
| `JunkDef` | `components: Dictionary[cmp_id→int]` |
| `AmmoDef`, `ComponentDef` | trivial |
| `AffixDef` | legendary affix: `modifiers, proc: EffectDef, proc_chance, allowed_classes, weight` |

**Stats & progression**

| Def | Key fields |
|---|---|
| `AttributeDef` | `id, name_key, min 1, max 10, derived: Array[StatModifier]` (e.g. GRIT → +10 max_hp per point) |
| `SkillDef` | `id, governing_attribute, xp_curve: Curve, use_events: Dictionary[event→xp]` |
| `PerkDef` | `id, ranks, requires: RequirementSet (attribute thresholds, level, skill, other perks), effects_per_rank: Array[Array[StatModifier]]` |
| `StatModifier` | `stat: StringName, op (ADD, MUL, OVERRIDE), value: float, condition: String` |
| `RequirementSet` | `attributes, skills, perks, level, flags_condition: String` — reused by perks, recipes, dialogue checks, build pieces |
| `EffectDef` | status effects: `duration_s, modifiers, tick_damage, tick_type, stacks` |

**Crafting / building / loot**

| Def | Key fields |
|---|---|
| `RecipeDef` | `station (WEAPONS, ARMOR, CHEM, COOKING), inputs, outputs, requires, craft_time_s` |
| `BuildPieceDef` | `category, scene: path, cost, sockets (snap types), power (+produce/−draw), defense, food, water, beds, happiness, budget_cost` |
| `LootTableDef` | `entries: Array[{item_or_table, weight, count_min, count_max, level_min, level_max, condition}]`, `rolls` |

**World & AI**

| Def | Key fields |
|---|---|
| `RegionDef` | `chunk_size_m = 64, grid: Vector2i, chunk_path_pattern, locations, encounter_tables, map_texture: path` |
| `LocationDef` | `id, name_key, position, discover_radius, fast_travel: bool, interior_scene: path` |
| `EncounterTableDef` | `entries (archetypes + counts), level scaling, time-of-day mask, cooldown` |
| `EnemyArchetypeDef` | `stats, faction_id, loadout: LootTableDef, ai: AIProfileDef, scene: path` |
| `AIProfileDef` | `aggression, courage, preferred_range_m, flank_tendency, sight_range_m, fov_deg, hearing_mult, tick_hz_near/far` |
| `ScheduleDef` | settler/NPC daily blocks: `[from_h, to_h, activity, location_tag]` |

**Narrative**

| Def | Key fields |
|---|---|
| `FactionDef` | `id, name_key, default_relations: Dictionary[fac→int], rep_thresholds (hostile/neutral/friendly/allied)` |
| `QuestDef` | `stages: Array[{id, objectives: [{text_key, condition, marker_target}], on_enter, on_complete}], outcomes` |
| `DialogueDef` | compiled graph: nodes `{speaker, text_key, choices: [{text_key, check, condition, action, next, tags}]}` |
| `CompanionDef` | `npc_id, approval_by_tag: Dictionary[tag→int], thresholds, barks, command_set` |
| `EndingDef` | `priority, condition, slides` |

## 6. Systems

### 6.1 Character creation (P2)
- Base mesh with **blendshapes** for face shape; body presets drive skeleton scale (height, build).
  Candidate source: MakeHuman exports (CC0 output) — **[VERIFY]** blendshape count vs mobile cost.
- Top-down camera means faces are ~40 px tall in play. Face sliders pay off only in the creator and
  the 3D inventory preview; in-world we use a lower LOD. Budget accordingly.
- Profile persisted in `GameState.profile` (appearance params are plain numbers → tiny save footprint).

### 6.2 Stats & progression (P2)
- 7 attributes (1–10, start at 5 each + 5 free points at creation).
  **BRAWN** melee dmg, carry · **GRIT** max HP, Blight resist, stamina · **REFLEX** Focus pool,
  reload/swap speed · **SENSE** detection range, aim-assist cone, OVERCLOCK hit chance ·
  **WITS** skill XP rate, crafting/hacking · **NERVE** crit chance, intimidation, suppression resist ·
  **CHARM** persuasion, prices, settler/companion caps.
- 15 skills (0–100) that **level by use**: Sidearms, Longguns, Heavy, Energy, Melee, Explosives,
  Stealth, Locks, Circuits, Medicine, Speech, Survival, Gunsmith, Armorer, Chemistry.
- Character level from XP (kills, quests, discovery, crafting); 1 perk point per level.
  Perk tree gated by attribute thresholds + level (+ occasional skill gates).
- Stat aggregation: `final = (base + Σadd) × Π(1 + mul)`, overrides last; cached and invalidated
  on equipment/effect change (never recomputed per frame).
- Respec item (**Rewire serum** [PROPOSED]) refunds perks and allows attribute redistribution.

### 6.3 Combat (P1 core, P3 depth)
- **Hitscan**: `PhysicsDirectSpaceState3D.intersect_ray` with spread cone; **projectiles**: one
  manager with packed arrays (pos/vel/ttl/owner/def) swept by raycasts each physics tick and drawn
  by a single `MultiMeshInstance3D` → constant draw calls regardless of bullet count.
- **Melee**: shape cast arc on animation event. **Throwables**: pooled RigidBody3D with fuse.
- **Aim assist** (touch): target selection within a cone (angle + distance weighted, stickiness,
  line-of-sight check), plus gentle rotation magnetism. Gamepad: slowdown near targets. KBM: off.
- **Limbs**: head/torso/arms/legs with separate HP pools; crippling effects via `EffectDef`.
- **Damage**: `dmg_after = dmg × 100 / (100 + max(0, resist − penetration))` per armor layer on the
  hit limb; tunable per damage type.
- **Cover**: `CoverPoint` markers (auto-generated from nav-mesh edges near low geometry + hand-placed).
  In cover: reduced hit chance from the protected arc; context button toggles cover.
- **Stealth**: per-AI detection meter (0–1) from light level, distance, movement noise, crouch,
  facing. Noise events broadcast via a spatial `NoiseSystem`.
- **OVERCLOCK**: `Engine.time_scale ≈ 0.15` (player input and UI unaffected), limb markers with
  hit %; each shot drains Focus. Audio pitch-shift + desaturation post via Environment adjustments.

### 6.4 Weapons & armor (P3)
- Modular attachments: each `WeaponModDef` contributes `StatModifier`s and a mesh at an attach point.
  Weapon instance stats are recomputed on mod change only.
- Layered armor: an underlayer (full body) + plates per limb, each with resistances and mod slots.
- **Exoframe**: a separate equipment state. Entered at a frame station; per-limb parts with
  durability; Frame Cells drain over time/sprint; out of cells → heavy slow mode; repair at bench.
- Rarity tiers **[PROPOSED]**: Scrap · Standard · Refined · Masterwork · Relic. Relic items roll
  1 legendary `AffixDef` (seeded RNG → deterministic from item uid).

### 6.5 Loot & inventory (P2)
- Stackables are `(def_id, count)`; uniques (weapons/armor with mods, condition, affixes) are
  `ItemInstance {uid, def_id, mods, affix, condition}`.
- Weight-based encumbrance; favorites map to an 8-slot radial; sort by type/weight/value/value-per-kg;
  compare tooltip = stat-aggregation diff vs equipped.
- Junk decomposes into components (scrap at bench or auto-consumed by recipes).

### 6.6 Crafting (P3)
Workbench stations (weapons, armor, chem, cooking) list `RecipeDef`s filtered by station and
`RequirementSet`. Crafting and scrapping are pure domain operations on `Inventory` (unit-tested).

### 6.7 Base building (P4)
- Claimable `SettlementZone`s (bounded area + build budget).
- Placement: **socket snapping** (wall edges, floor corners, roof ridges) with 0.5 m grid fallback,
  validity checks (overlap, support, zone bounds).
- **Batching is mandatory**: placed pieces render through a MultiMesh per (piece type, material)
  per settlement; colliders merged per piece type. 300 individually drawn walls would blow the
  draw-call budget alone.
- Power: generators/consumers + wires form a graph; networks solved with union-find on change.
- Settlers: jobs (farm, water, guard, scavenge, vendor), schedules, happiness =
  f(food, water, beds, defense, power, recent raids).
- Raids: periodic roll weighted by settlement value vs defense. Player present → live raid
  spawned at zone edge. Player absent → resolved abstractly (defense vs attack roll) with
  consequences written to `GameState`.
- Navigation: built pieces carve via `NavigationObstacle3D` / async re-bake of the settlement
  nav region **[VERIFY]** cost on device.

### 6.8 Quests, dialogue & choices (P5)
- `.dlg` DSL → `DialogueDef` (import plugin). Choice checks: attribute/skill thresholds (shown with
  odds or pass/fail), persuasion via CHARM + Speech.
- **Global flag store** (`GameState.flags: Dictionary[StringName, Variant]`) is the single source
  of world truth. `WorldStateSwitch` nodes in chunks toggle/replace content by condition
  (NPC dead → corpse or absent; settlement hostile → guards aggro; area altered → alternate subscene).
- 4 factions with reputation (−100…100) and an inter-faction relation matrix; AI hostility derives
  from faction relations plus personal aggro.
- Endings: ordered `EndingDef`s; first whose condition passes wins.
- Journal: quests/stages/objectives with markers resolved to world positions via persist ids.

### 6.9 Companions (P5)
≥ 2 companions. Choices and actions carry **tags** (`generous`, `cruel`, `lawful`, `greedy`, …);
each `CompanionDef` maps tags → approval deltas, with thresholds unlocking/ending arcs.
Commands via radial: follow, wait, move here, attack target, loot/pick up, use.

### 6.10 World (P1 camera → P6 region)
- **Region ≈ 1 km²** = 16 × 16 chunks of 64 m. Stream radius: 3 × 3 active, 5 × 5 prefetch via
  `ResourceLoader.load_threaded_request`. Top-down camera footprint is ~50 × 35 m, so no far-LOD
  terrain is needed — a big structural advantage of the camera choice.
- Interiors/dungeons are separate scenes swapped into `World`; the region is unloaded
  (deltas saved) to stay within memory.
- **Day/night**: sun rotation + environment gradients driven by `Curve`/`Gradient` resources;
  global shader uniforms (`time_of_day`, `wetness`, `wind_dir`, `wind_strength`) shared by all materials.
- **Weather**: rain (wetness uniform + streak particles + ripples), dust storms (fog density +
  particle cards), overcast (sun energy/sky).
- Random encounters rolled on chunk activation outside settlements, with cooldowns.
- Fast travel between discovered `LocationDef`s; advances the clock; blocked in combat.
- **Minimap/full map**: a pre-baked orthographic texture per region (tool script renders it offline)
  plus UI-drawn markers. No second live camera (it would double draw calls).

### 6.11 AI (P1 basic → P5 full)
- **Utility-scored hierarchical state machine** in GDScript: Idle, Patrol, Investigate, Engage
  {Shoot, TakeCover, Flank, Advance, Reload}, Search, Flee, plus Schedule for NPCs.
  Each state scores itself from blackboard facts; highest score with hysteresis wins.
- Perception at 5 Hz (sight cone raycasts), hearing via `NoiseSystem`.
- Squad coordinator per encounter assigns flank/suppress roles.
- **AI LOD**: 10 Hz within 25 m, 2 Hz up to chunk edge, frozen in inactive chunks.
- Faction relations decide hostility; settlers follow `ScheduleDef`s.

### 6.12 Save / load (P0 core, P2 full world)

**Envelope** (`SaveCodec`, implemented in P0):

```
file  = FileAccess.open_compressed(path, WRITE, COMPRESSION_ZSTD).store_var({
          "magic": "WLSV", "format": <codec format int>,
          "schema": <GameState schema version>, "sha256": <hex of payload bytes>,
          "payload": var_to_bytes(<Dictionary>) })
```

- **Plain data only**: `var_to_bytes` / `bytes_to_var` — never the `_with_objects` variants, so a
  tampered save cannot instantiate scripts.
- **Atomic writes**: write `slot.sav.tmp` → verify by reading back → rotate existing to `.bak` →
  rename tmp into place. Load falls back to `.bak` on hash/decompression failure.
- **Versioned**: `SaveMigrator` applies `vN → vN+1` steps on the raw Dictionary. Every schema bump
  adds a fixture under `tests/fixtures/saves/` that must keep loading forever.
- **Slot metadata** (`slot.meta`, small ConfigFile: name, level, location, play time, thumbnail path)
  is separate so the load screen never decompresses full saves.
- **World persistence = deltas vs authored content**: killed/removed persist ids, container
  contents, moved items, built structures, flag store. Untouched content costs zero bytes.
- **Android lifecycle**: on `NOTIFICATION_APPLICATION_PAUSED` / `FOCUS_OUT` / `WM_CLOSE_REQUEST`
  → synchronous autosave to a dedicated rotating slot. Normal autosaves (zone change, interval,
  quest stage) serialise on the main thread (plain data, fast) and write on a worker thread.
- Slots: 10 manual + 3 rotating autosaves + 1 quicksave + 1 lifecycle ("suspend") save.

### 6.13 UI (P1 HUD → P2 Bracer)
- Base resolution 1280 × 720, stretch `canvas_items`, aspect `expand` → works 16:9 to 21:9.
- `SafeAreaContainer` applies `DisplayServer.get_display_safe_area()` margins (notches, cutouts).
- Min touch target 48 dp. One `Theme` resource. All text via translation keys.
- **Touch**: left virtual stick (floating origin), right stick aims (release = stop firing; fire on
  hold with auto-fire threshold), context button, OVERCLOCK button, radial (hold) for
  weapons/items (time slows to ~20 % while open).
- **Input abstraction**: `InputRouter` turns any device into intents (`move: Vector2`,
  `aim: Vector2`, `fire: bool`, …). Gameplay only reads intents. Emulated mouse events from touch
  (`DEVICE_ID_EMULATION`) are ignored by gameplay to avoid double input.
- The Bracer: tabs STATUS / GEAR / JOURNAL / MAP / DATA / RADIO. The 3D inventory preview uses a
  small `SubViewport` rendered only while the tab is open; world rendering is throttled behind the menu.

### 6.14 Audio (P1 buses → P6 content)
- Bus layout: Master → {Music, SFX, Ambience, UI, Voice}. Music ducked by Voice (sidechain compressor).
- `AudioDirector` crossfades explore/tension/combat layers by an intensity value derived from
  EventBus combat events (number of alerted enemies, damage taken).
- Pooled `AudioStreamPlayer3D`s with per-category polyphony caps. OGG for music (streamed),
  compressed WAV for SFX.

## 7. Rendering direction ("best achievable on mobile")

Mobile-renderer facts that shape the look (Godot 4.x Mobile does **not** support SDFGI, VoxelGI,
SSAO, SSIL, SSR, volumetric fog or FSR2 — all Forward+-only):

| Goal | Technique on Mobile |
|---|---|
| Dusty volumetric feel | **Height fog** (ground haze) + animated noise "fog card" meshes with depth-fade, dust motes, light-shaft cards at golden hour. Depth fog stays minimal: with a top-down camera the camera-to-ground distance is ~constant, so exponential depth fog is a uniform grey veil (measured in P0) |
| GI / lighting | **Exteriors**: dynamic sun + sky ambient (no lightmaps — they conflict with dynamic time of day and chunk streaming); baked AO in textures/vertex colour. **Interiors**: `LightmapGI` fully baked + `ReflectionProbe`s. |
| Surface richness | One uber world shader: PBR + triplanar rust/grime mask + global `wetness` (darken, roughness↓, puddle mask) |
| Foliage | Vertex wind (global uniform), MultiMesh, alpha-scissor, density by preset |
| Readability | Inverted-hull outline pass on actors/interactables only (bounded draw calls). Full-screen depth-edge outline only if Ultra can afford it **[VERIFY]** |
| Feedback | `instance uniform` hit-flash and dissolve (per-instance → no material duplication, batching intact) |
| AA | MSAA (cheap on tile-based GPUs) by preset |
| Upscaling | Resolution scale 0.6–1.0 with FSR1 (bilinear on Low) |
| Shader stutter | Warm-up pass on loading screens; track `PIPELINE_COMPILATIONS_*` monitors in bench |
| Occlusion | Camera cut-away (dither-fade roofs/walls between camera and player). `OccluderInstance3D` culling used only in dense towns/interiors — from a top-down camera little is occluded, so it rarely pays |

### Graphics presets (data: `data/settings/graphics/*.tres`)

| | Low | Medium | High | Ultra |
|---|---|---|---|---|
| Render scale / upscaler | 0.6 bilinear | 0.75 FSR1 | 0.9 FSR1 | 1.0 native |
| FPS cap | 30 | 30 | 60 | 60 |
| MSAA | off | 2× | 2× | 4× |
| Sun shadows | off | 1024 | 2048 | 4096 |
| Mesh LOD threshold | 4 px | 2 px | 1 px | 1 px |
| Glow | off | on | on | on |
| Fog detail (cards/particles) | 0 | 1 | 2 | 3 |
| Foliage density | 0.3 | 0.6 | 1.0 | 1.0 |
| Actor outlines | on | on | on | on (+full-screen edges if affordable) |

First launch picks a preset from a device-tier heuristic (GPU name, core count, RAM, active renderer).

## 8. Performance strategy
- Every phase adds scenarios to the bench (`src/debug/bench`); CI records draw calls/primitives/
  objects/pipeline compiles under software Vulkan (lavapipe) and fails on regression beyond budget.
  **FPS and RSS are only meaningful on device** and are recorded manually in `docs/PERF.md`.
- Pools: projectiles (data-oriented), VFX, audio players, enemies (per archetype), damage numbers.
- No per-frame allocations in hot paths (reuse arrays, avoid string building in `_process`).
- `_physics_process` only where needed; AI ticks via timers with LOD.
- Textures: ETC2/ASTC VRAM compression for mobile (`import_etc2_astc`), atlases for UI and props,
  mipmaps on, max 2048² except terrain splat.

## 9. Build, test & delivery pipeline
- `tools/setup_toolchain.sh` — idempotent install of pinned Godot, export templates, Android SDK
  pieces; configures editor settings. Same script in CI and locally.
- `tools/ci.sh` — import → gdlint → IP check → GUT (unit + integration, JUnit XML) → Android export
  (arm64 debug, signed with the committed debug keystore) → APK checks (signature fingerprint,
  size budget, ABI) → optional bench + screenshot under lavapipe.
- `.github/workflows/ci.yml` — runs `ci.sh` on every push; uploads the APK as an artifact; on tags
  (`p*`) publishes a GitHub Release with the APK attached.
- `versionCode` = git commit count (monotonic → every APK installs over the previous one).

## 10. Testing strategy
| Layer | What | Where |
|---|---|---|
| Unit | domain classes, codec, migrations, settings presets | `tests/unit` |
| Content | every `Def` loads + validates, ids unique, refs resolve, expressions parse | `tests/unit/test_content_*.gd` |
| Integration | scenes instantiate headless without errors; save→load round trips; lifecycle saves | `tests/integration` |
| Perf smoke | bench draw calls / primitives under budget (lavapipe) | `tools/run_bench.sh` |
| Visual | deterministic screenshots of test scenes for review | `tools/screenshot.sh` |

## 11. Risks (blunt)

| Risk | Severity | Mitigation |
|---|---|---|
| **Scope.** The feature list is AAA-sized. A solo dev + AI can build every *system* to greybox quality; *content volume* (10 polished quests, 3 dungeons, a shippable-looking region) is the real cost. | High | Data-driven everything; content tooling before content; P6 scope reviewed at P5 exit. |
| **Art coherence from CC0 sources.** Kenney/Quaternius are stylized low-poly; Poly Haven/ambientCG are photoreal scans. Mixed naively they clash. "Stylized-realistic PBR" needs a deliberate choice. | High | Art-direction fork question to the director (§17). Greybox until decided. |
| **Mixamo in a public repo.** Mixamo's licence permits use in games but not redistribution of the raw files; this repo is public. | Medium | Use Quaternius' CC0 animation libraries instead; if Mixamo is required, keep those files out of git (private asset store). |
| **Realistic customizable humans under CC0** are scarce (face blendshapes especially). | Medium | MakeHuman-derived base mesh (outputs are CC0) — spike in P2. Otherwise stylized faces. |
| **"WASTELAND" is an existing game trademark** (inXile / Microsoft). | High for release, nil for dev | Must be renamed before any public release/store listing. Package id is a neutral dev id. |
| **No on-device profiling from CI.** The build machine has no phone. | Medium | Device-side perf HUD + in-app benchmark + logcat output; director runs it, numbers go into PERF.md. CI tracks draw calls only. |
| LightmapGI baking needs a GPU; the container only has software Vulkan. | Medium | Interiors only; bake via lavapipe (slow) or on the director's PC **[VERIFY in P6]**. |
| Play Store: AAB requires Gradle build + NDK; Play Asset Delivery needs a plugin; targetSdk must stay current. | Medium | Addressed in P7; APK debug path for P0–P6. |
| Swappy frame pacing + `Engine.max_fps` interaction on Android. | Low | **[VERIFY]** on device in P1. |
| Git repo growth from binary assets (no LFS: LFS bandwidth quota is a cost trap on public CI). | Low now | 50 MB per-file cap in CI; revisit at P6. |

## 12–16. Reserved for per-phase detailed designs (added as phases start).

## 17. Open creative questions for the director
1. **Title** — "WASTELAND" can't ship (existing trademark). Want candidates?
2. **Art-direction fork** — (a) stylized low-poly + strong lighting/fog (Quaternius/Kenney-coherent,
   cheapest, best perf) vs (b) stylized-realistic PBR (Poly Haven/ambientCG materials on simple
   geometry, harder to keep coherent, more texture memory).
3. **Bracer look** — e.g. amber e-ink on taped industrial casing, or projected holo over a cracked
   phone, or analog dials + paper-roll printer.
4. **Four factions** — names, ideologies, and how they relate. Placeholder ids `fac_a…fac_d`.
5. **Companions** — at least two; who are they?
6. **Tone** — grim-sincere vs darkly satirical.
7. Sign-off on attribute names (§6.2) and glossary (§2).
