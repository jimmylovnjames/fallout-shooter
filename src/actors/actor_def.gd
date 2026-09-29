class_name ActorDef
extends Def
## Shared definition for anything that walks, shoots and dies (player, NPCs, enemies).

@export var name_key: String = ""
@export var max_hp: float = 100.0
@export var move_speed: float = 5.5
@export var acceleration: float = 40.0
@export var deceleration: float = 50.0
@export var turn_speed_deg: float = 900.0
@export var tint: Color = Color(0.9, 0.47, 0.17)
## Weapon ids carried, first is equipped.
@export var loadout: Array[StringName] = []


func validate() -> PackedStringArray:
	var errors := super()
	if not _id_prefix_ok():
		errors.append("%s ids must start with %s" % [get_def_type(), _id_prefix()])
	if name_key.is_empty():
		errors.append("name_key is empty")
	if max_hp <= 0.0 or move_speed <= 0.0 or acceleration <= 0.0 or deceleration <= 0.0:
		errors.append("max_hp, move_speed, acceleration, deceleration must be positive")
	for w in loadout:
		if not ContentDB.get_def(w) is WeaponDef:
			errors.append("loadout references unknown weapon '%s'" % w)
	return errors


func _id_prefix() -> String:
	return "act_"


func _id_prefix_ok() -> bool:
	return String(id).begins_with(_id_prefix())
