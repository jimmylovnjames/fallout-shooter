class_name WeaponDef
extends Def
## Weapon definition (DESIGN §5.4). P1 subset: firing, magazine, ballistics. P3 adds mod slots,
## limb multipliers, skills, rarity.

enum WeaponClass { PISTOL, RIFLE, SHOTGUN, ENERGY, HEAVY, MELEE, THROWN }
enum FireMode { HITSCAN, PROJECTILE }

@export var name_key: String = ""
@export var weapon_class: WeaponClass = WeaponClass.PISTOL
@export var fire_mode: FireMode = FireMode.HITSCAN
@export var damage: float = 10.0
@export var damage_type: DamageInfo.Type = DamageInfo.Type.BALLISTIC
## Rounds per minute (fire interval = 60 / rpm).
@export var rpm: float = 300.0
@export var mag_size: int = 12
@export var reload_s: float = 1.2
@export var range_m: float = 30.0
## Half-angle of the random spread cone, degrees.
@export var spread_deg: float = 2.0
## Pellets per shot (shotguns); damage is per pellet.
@export var pellets: int = 1
@export var projectile_speed: float = 40.0
@export var tracer_color: Color = Color(1.0, 0.85, 0.5)


func fire_interval() -> float:
	return 60.0 / rpm


func validate() -> PackedStringArray:
	var errors := super()
	if not String(id).begins_with("wpn_"):
		errors.append("weapon ids must start with wpn_")
	if name_key.is_empty():
		errors.append("name_key is empty")
	if damage <= 0.0 or rpm <= 0.0 or mag_size <= 0 or reload_s < 0.0 or range_m <= 0.0 or pellets < 1:
		errors.append("damage, rpm, mag_size, range_m, pellets must be positive")
	if fire_mode == FireMode.PROJECTILE and projectile_speed <= 0.0:
		errors.append("projectile weapons need projectile_speed > 0")
	if spread_deg < 0.0 or spread_deg > 45.0:
		errors.append("spread_deg must be within 0..45")
	return errors
