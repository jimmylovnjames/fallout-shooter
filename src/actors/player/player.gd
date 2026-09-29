class_name Player
extends Actor
## The player actor: wires PlayerController and relays state to EventBus for HUD/audio/quests.

const RESPAWN_GRACE_S := 2.0
const SHOT_NOISE_RADIUS := 26.0
const AIM_LINE_LENGTH := 7.0

@onready var controller: PlayerController = $PlayerController
@onready var aim_line: Node3D = $AimLine


func setup_player(
	actor_def: ActorDef, combat: CombatServices, router: InputRouter, rig: CameraRig, hostiles: Callable
) -> void:
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.ACTORS
	setup(actor_def, combat, PhysicsLayers.PLAYER_SHOTS)
	controller.setup(self, router, rig, hostiles)
	weapon.noise_radius = SHOT_NOISE_RADIUS
	health.changed.connect(func(c: float, m: float) -> void: EventBus.player_health_changed.emit(c, m))
	weapon.equipped.connect(_on_equipped)
	for w in weapon.weapons:
		w.ammo_changed.connect(func(n: int, m: int) -> void: EventBus.ammo_changed.emit(n, m))
		w.reload_started.connect(func(d: float) -> void: EventBus.reload_started.emit(d))
	if weapon.active() != null:
		_on_equipped(weapon.active())
	EventBus.player_spawned.emit(self)
	EventBus.player_health_changed.emit(health.pool.current, health.pool.maximum)


func respawn(pos: Vector3) -> void:
	revive_at(pos, RESPAWN_GRACE_S)
	if weapon.active() != null:
		_on_equipped(weapon.active())
	EventBus.player_respawned.emit()


func _process(_delta: float) -> void:
	var show := alive and intent.aim != Vector3.ZERO
	aim_line.visible = show
	if show:
		aim_line.global_rotation = Vector3(0.0, yaw_for(intent.aim), 0.0)


func _damaged(applied: float, info: DamageInfo) -> void:
	EventBus.player_damaged.emit(applied, info.direction)


func _died(_info: DamageInfo) -> void:
	EventBus.player_died.emit()


func _on_equipped(w: WeaponState) -> void:
	EventBus.weapon_equipped.emit(w.def.name_key, w.in_mag, w.def.mag_size)
