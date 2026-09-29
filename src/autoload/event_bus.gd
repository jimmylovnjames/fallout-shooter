extends Node
## Global typed signal hub: declarations only, no state, no logic (DESIGN §4.5).
## Emit with `EventBus.<signal>.emit(...)`. Group by domain; name signals in the past tense.
## Use it for broadcasts with unknown/many listeners; parent<->child talk uses direct signals.

@warning_ignore_start("unused_signal")

# --- App lifecycle -------------------------------------------------------------------------------
signal app_paused
signal app_resumed

# --- Settings ------------------------------------------------------------------------------------
signal graphics_preset_applied(preset: GraphicsPreset)
signal render_scale_changed(scale: float)
signal perf_hud_toggled(visible: bool)

# --- Game state / persistence --------------------------------------------------------------------
signal flag_changed(flag: StringName, value: Variant)
signal game_saved(slot: StringName, ok: bool)
signal game_loaded(slot: StringName)
signal game_state_reset

# --- Player / combat -----------------------------------------------------------------------------
signal player_spawned(player: Node3D)
signal player_health_changed(current: float, maximum: float)
signal player_damaged(amount: float, from_direction: Vector3)
signal player_died
signal player_respawned
signal weapon_equipped(name_key: String, in_mag: int, mag_size: int)
signal ammo_changed(in_mag: int, mag_size: int)
signal reload_started(duration: float)
signal enemy_killed(archetype_id: StringName)
## A loud event AI can hear (gunshots, explosions). source_id = instance_id of the emitter.
signal noise_made(position: Vector3, radius: float, source_id: int)

# --- Debug / perf --------------------------------------------------------------------------------
signal bench_started
signal bench_finished(results: Dictionary)

@warning_ignore_restore("unused_signal")
