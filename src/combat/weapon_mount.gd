class_name WeaponMount
extends Node3D
## Carries an actor's weapons and turns ActorIntent fire/reload/swap into shots through the
## level's CombatServices. Positioned at the muzzle height; shots leave from `muzzle_offset`
## along the aim direction.

signal equipped(state: WeaponState)
signal shot_fired(state: WeaponState)

@export var muzzle_forward: float = 0.75
@export var muzzle_height: float = 1.15

var weapons: Array[WeaponState] = []
var current: int = 0
var services: CombatServices
var shot_mask: int = PhysicsLayers.PLAYER_SHOTS
## Extra spread applied on top of the weapon's (AI inaccuracy), degrees.
var extra_spread_deg: float = 0.0
## Noise radius broadcast per shot so AI can hear it (0 = silent).
var noise_radius: float = 0.0

var _owner_body: CollisionObject3D


func setup(loadout: Array[StringName], combat: CombatServices, owner_body: CollisionObject3D, mask: int) -> void:
	services = combat
	_owner_body = owner_body
	shot_mask = mask
	weapons.clear()
	for id in loadout:
		var def := ContentDB.get_def(id) as WeaponDef
		if def == null:
			Log.error("WeaponMount", "unknown weapon '%s'" % id)
			continue
		weapons.append(WeaponState.new(def))
	current = 0
	if not weapons.is_empty():
		equipped.emit(weapons[0])


func active() -> WeaponState:
	return weapons[current] if current < weapons.size() else null


func swap(now: float) -> void:
	if weapons.size() < 2:
		return
	active().cancel_reload()
	current = (current + 1) % weapons.size()
	active().update(now)
	equipped.emit(active())


## Called every physics tick by the actor.
func tick(intent: ActorIntent, origin: Vector3, now: float) -> void:
	var w := active()
	if w == null:
		return
	# swap/reload are one-shot: consumed here so a held flag can't toggle every tick.
	if intent.swap:
		intent.swap = false
		swap(now)
		w = active()
	if intent.reload:
		intent.reload = false
		w.start_reload(now)
	w.update(now)
	if intent.fire and intent.aim != Vector3.ZERO and w.try_fire(now):
		_shoot(w, origin, intent.aim)


func _shoot(w: WeaponState, origin: Vector3, aim: Vector3) -> void:
	var muzzle := origin + Vector3(0, muzzle_height, 0) + aim * muzzle_forward
	var def := w.def
	var source_id := _owner_body.get_instance_id() if _owner_body else 0
	for p in def.pellets:
		var dir := Hitscan.spread_dir(aim, def.spread_deg + extra_spread_deg, services.rng)
		if def.fire_mode == WeaponDef.FireMode.HITSCAN:
			_hitscan(def, muzzle, dir, source_id)
		else:
			var rid := _owner_body.get_rid() if _owner_body else RID()
			services.projectiles.spawn(
				muzzle, dir * def.projectile_speed, def.damage, source_id, rid, shot_mask, def.range_m, def.tracer_color
			)
	services.bursts.spawn(muzzle, 0.55, def.tracer_color, 0.1)
	if noise_radius > 0.0:
		EventBus.noise_made.emit(muzzle, noise_radius, source_id)
	shot_fired.emit(w)


func _hitscan(def: WeaponDef, muzzle: Vector3, dir: Vector3, source_id: int) -> void:
	var exclude: Array[RID] = []
	if _owner_body != null:
		exclude.append(_owner_body.get_rid())
	var hit := Hitscan.cast(get_world_3d().direct_space_state, muzzle, dir, def.range_m, shot_mask, exclude)
	var end := muzzle + dir * def.range_m
	if not hit.is_empty():
		end = hit["position"]
		var health := Hitscan.health_of(hit["collider"])
		if health != null:
			health.apply_damage(DamageInfo.make(def.damage, source_id, end, dir))
		services.bursts.spawn(
			end, 0.48 if health != null else 0.32, Color(1, 0.28, 0.12) if health else Color(1, 0.72, 0.28), 0.16
		)
	services.tracers.spawn(muzzle, end, def.tracer_color)
