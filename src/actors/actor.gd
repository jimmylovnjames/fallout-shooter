class_name Actor
extends CharacterBody3D
## Anything that walks, aims, shoots and dies. Controllers (PlayerController, AIBrain) write
## `intent`; the actor applies it every physics tick. Composition: Visual, Health, WeaponMount.

signal died(actor: Actor)
signal revived(actor: Actor)

const GRAVITY := 20.0
const DISSOLVE_S := 0.9

var def: ActorDef
var intent := ActorIntent.new()
var services: CombatServices
## Game-time seconds for this actor (scaled by Engine.time_scale).
var clock := 0.0
var alive := true
var move_speed_mult := 1.0

@onready var visual: ActorVisual = $Visual
@onready var health: HealthComponent = $Health
@onready var weapon: WeaponMount = $WeaponMount
@onready var _shape: CollisionShape3D = $CollisionShape3D


func setup(actor_def: ActorDef, combat: CombatServices, shot_mask: int) -> void:
	def = actor_def
	services = combat
	health.clock = func() -> float: return clock
	health.setup(def.max_hp)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	visual.set_tint(def.tint)
	weapon.setup(def.loadout, combat, self, shot_mask)


func _physics_process(delta: float) -> void:
	clock += delta
	if def == null:
		return
	if not alive:
		# Collider is disabled while dissolving: stay put instead of falling through the floor.
		velocity = Vector3.ZERO
		return
	var h := Vector3(velocity.x, 0.0, velocity.z)
	h = step_velocity(h, intent.move * def.move_speed * move_speed_mult, def.acceleration, def.deceleration, delta)
	_turn(delta)
	weapon.tick(intent, global_position, clock)
	velocity = Vector3(h.x, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, h.z)
	move_and_slide()


## Unit facing direction on the XZ plane.
func facing() -> Vector3:
	var f := -visual.global_basis.z
	f.y = 0.0
	return f.normalized()


## Chest position used for line-of-sight and aiming.
func aim_point() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func face_instantly(dir: Vector3) -> void:
	if dir != Vector3.ZERO:
		visual.rotation.y = yaw_for(dir)


func revive_at(pos: Vector3, grace_s: float = 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	intent.clear()
	alive = true
	_shape.set_deferred(&"disabled", false)
	health.revive(grace_s)
	visual.reset()
	for w in weapon.weapons:
		w.cancel_reload()
		w.in_mag = w.def.mag_size
	revived.emit(self)


## Pooling support: fully disable/enable an actor without freeing it.
func set_active(on: bool) -> void:
	visible = on
	set_physics_process(on)
	_shape.set_deferred(&"disabled", not on)
	if not on:
		alive = false
		intent.clear()


## Pure: accelerate current horizontal velocity toward target (unit-tested).
static func step_velocity(current: Vector3, target: Vector3, accel: float, decel: float, delta: float) -> Vector3:
	var rate := accel if target.length_squared() > 0.0001 else decel
	return current.move_toward(target, rate * delta)


## Pure: yaw (radians) that makes local -Z point along `dir`.
static func yaw_for(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _turn(delta: float) -> void:
	var dir := intent.aim
	if dir == Vector3.ZERO:
		dir = Vector3(intent.move.x, 0.0, intent.move.z)
	if dir.length_squared() < 0.0001:
		return
	visual.rotation.y = rotate_toward(visual.rotation.y, yaw_for(dir), deg_to_rad(def.turn_speed_deg) * delta)


func _on_damaged(applied: float, info: DamageInfo) -> void:
	visual.flash(clampf(applied / 20.0, 0.4, 1.0))
	_damaged(applied, info)


func _on_died(info: DamageInfo) -> void:
	alive = false
	intent.clear()
	_shape.set_deferred(&"disabled", true)
	visual.dissolve_out(DISSOLVE_S)
	_died(info)
	died.emit(self)


## Subclass hooks.
func _damaged(_applied: float, _info: DamageInfo) -> void:
	pass


func _died(_info: DamageInfo) -> void:
	pass
