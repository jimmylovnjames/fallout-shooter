class_name DamageInfo
extends RefCounted
## One hit. Plain data passed from weapons/projectiles to health components.

enum Type { BALLISTIC, ENERGY, FIRE, BLIGHT, MELEE, EXPLOSIVE }

var amount: float = 0.0
var type: Type = Type.BALLISTIC
## instance_id of the attacker (0 = world/unknown). An id, not a reference: attackers may be freed.
var source_id: int = 0
var position := Vector3.ZERO
## Direction the hit travelled (unit), for knockback/VFX.
var direction := Vector3.ZERO


static func make(dmg: float, from_id: int, at: Vector3, dir: Vector3) -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = dmg
	d.source_id = from_id
	d.position = at
	d.direction = dir
	return d
