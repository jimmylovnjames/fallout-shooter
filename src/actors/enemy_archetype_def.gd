class_name EnemyArchetypeDef
extends ActorDef
## Hostile archetype: ActorDef + perception and combat behaviour tuning (DESIGN §6.11).

@export_group("Perception")
@export var sight_range_m: float = 22.0
@export var fov_deg: float = 140.0
## Gunshots within (noise radius × this) are heard.
@export var hearing_mult: float = 1.0
@export var reaction_s: float = 0.45

@export_group("Combat")
@export var preferred_range_m: float = 11.0
## Aim error cone (deg) when first engaging; shrinks toward aim_error_min over settle time.
@export var aim_error_deg: float = 9.0
@export var aim_error_min_deg: float = 3.0
@export var aim_settle_s: float = 2.5
## How well projectile shots lead a moving target (0 = aim at current position, 1 = perfect).
@export_range(0.0, 1.0) var lead_skill: float = 0.7
@export var burst_shots: int = 3
@export var burst_pause_min_s: float = 0.7
@export var burst_pause_max_s: float = 1.4

@export_group("Movement")
@export var patrol_speed_mult: float = 0.45
@export var patrol_radius_m: float = 8.0
## Seconds to keep investigating a lost target before giving up.
@export var give_up_s: float = 8.0


func _id_prefix() -> String:
	return "enm_"


func validate() -> PackedStringArray:
	var errors := super()
	if fov_deg <= 0.0 or fov_deg > 360.0:
		errors.append("fov_deg must be within 0..360")
	if burst_shots < 1 or burst_pause_min_s > burst_pause_max_s:
		errors.append("burst_shots >= 1 and burst_pause_min_s <= burst_pause_max_s required")
	if aim_error_min_deg > aim_error_deg:
		errors.append("aim_error_min_deg must be <= aim_error_deg")
	return errors
