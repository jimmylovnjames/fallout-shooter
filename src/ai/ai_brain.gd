class_name AIBrain
extends Node
## Utility-scored state machine + blackboard for one enemy (DESIGN §6.11, DECISIONS D016).
## Thinks at 10 Hz near the player and 2 Hz far away (AI LOD); steers every physics frame so
## movement stays smooth between thinks.

signal state_changed(state: StringName)

const THINK_NEAR_S := 0.1
const THINK_FAR_S := 0.5
const NEAR_M := 28.0
const HYSTERESIS := 0.15
const ARRIVE_M := 0.8

var enemy: Enemy
var def: EnemyArchetypeDef
var target: Actor
var rng := RandomNumberGenerator.new()
var states: Array[AIState] = [PatrolState.new(), EngageState.new(), InvestigateState.new()]
var current: AIState

## Arena behaviour: patrol roams around the target's area instead of home (keeps pressure on).
var hunting := false

# --- Blackboard ----------------------------------------------------------------------------------
var home := Vector3.ZERO
var target_visible := false
var last_seen_at := -1000.0
var last_alert_at := -1000.0
var last_known := Vector3.ZERO
var has_last_known := false
var aim_target := Vector3.ZERO
var aim_target_valid := false
var moving := false
var direct_move := Vector3.ZERO
var engaged_at := 0.0
var burst_left := 0
var next_burst_at := 0.0
var strafe_until := -1.0
var strafe_sign := 1.0
var next_wander_at := 0.0
var look_until := -1.0
var look_origin_yaw := 0.0

var _think_accum := 0.0
var _nav: NavigationAgent3D
var _nav_goal := Vector3.INF


func setup(e: Enemy, archetype: EnemyArchetypeDef, hostile: Actor, seed_value: int) -> void:
	enemy = e
	def = archetype
	target = hostile
	rng.seed = seed_value
	_nav = e.nav
	enemy.weapon.shot_fired.connect(_on_shot_fired)
	EventBus.noise_made.connect(_on_noise)


func reset(at: Vector3) -> void:
	home = at
	target_visible = false
	has_last_known = false
	last_seen_at = -1000.0
	last_alert_at = -1000.0
	burst_left = 0
	stop_moving()
	_switch(states[0])
	_think_accum = rng.randf() * THINK_NEAR_S  # desync brains so they don't all think on one frame


func now() -> float:
	return enemy.clock


func target_valid() -> bool:
	return target != null and target.alive


## Centre of patrol wandering: the target's area while hunting, else home.
func patrol_center() -> Vector3:
	return target.global_position if hunting and target_valid() else home


func state_name() -> StringName:
	return current.state_name() if current else &""


# --- Movement API used by states -----------------------------------------------------------------


func go_to(p: Vector3) -> void:
	moving = true
	direct_move = Vector3.ZERO
	if _nav_goal.distance_squared_to(p) > 0.25:
		_nav_goal = p
		_nav.target_position = p


func move_direct(v: Vector3) -> void:
	moving = false
	direct_move = v


func stop_moving() -> void:
	moving = false
	direct_move = Vector3.ZERO
	_nav_goal = Vector3.INF


func arrived() -> bool:
	return _nav.is_navigation_finished() or enemy.global_position.distance_to(_nav_goal) < ARRIVE_M


# --- Tick ----------------------------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	if enemy == null or not enemy.alive:
		return
	_think_accum += delta
	var far := not target_valid() or enemy.global_position.distance_to(target.global_position) > NEAR_M
	var interval := THINK_FAR_S if far else THINK_NEAR_S
	if _think_accum >= interval:
		_think(_think_accum)
		_think_accum = 0.0
	_steer()


func _think(dt: float) -> void:
	_perceive()
	var best := current
	var best_score := current.score(self) + HYSTERESIS if current else -1.0
	for s in states:
		if s == current:
			continue
		var sc := s.score(self)
		if sc > best_score:
			best = s
			best_score = sc
	if best != current:
		_switch(best)
	current.think(self, dt)


func _switch(s: AIState) -> void:
	if current != null:
		current.exit(self)
	current = s
	current.enter(self)
	state_changed.emit(current.state_name())


func _perceive() -> void:
	target_visible = false
	if not target_valid():
		return
	var eye := enemy.aim_point()
	var tp := target.aim_point()
	if not Perception.in_view_cone(eye, enemy.facing(), tp, def.fov_deg, def.sight_range_m):
		return
	if not Perception.has_line_of_sight(enemy.get_world_3d().direct_space_state, eye, tp):
		return
	target_visible = true
	last_seen_at = now()
	_alert(target.global_position)


func _steer() -> void:
	var intent := enemy.intent
	if moving:
		if arrived():
			intent.move = Vector3.ZERO
		else:
			intent.move = AimMath.flat_dir(enemy.global_position, _nav.get_next_path_position())
	else:
		intent.move = direct_move
	var aim_at := aim_target
	if aim_target_valid and target_visible and target_valid():
		aim_at = lead_point(enemy.aim_point(), target.aim_point(), target.velocity, _projectile_speed(), def.lead_skill)
	intent.aim = AimMath.flat_dir(enemy.aim_point(), aim_at) if aim_target_valid else Vector3.ZERO


## Pure: where to aim so a projectile of `speed` meets a target moving at `vel` (first-order
## intercept), scaled by `skill`. Hitscan (speed <= 0) aims at the target directly.
static func lead_point(from: Vector3, to: Vector3, vel: Vector3, speed: float, skill: float) -> Vector3:
	if speed <= 0.0 or skill <= 0.0:
		return to
	var t := from.distance_to(to) / speed
	return to + Vector3(vel.x, 0.0, vel.z) * t * skill


func _projectile_speed() -> float:
	var w := enemy.weapon.active()
	if w == null or w.def.fire_mode != WeaponDef.FireMode.PROJECTILE:
		return 0.0
	return w.def.projectile_speed


func _alert(at: Vector3) -> void:
	last_known = at
	has_last_known = true
	last_alert_at = now()


# --- Events --------------------------------------------------------------------------------------


func on_damaged(info: DamageInfo) -> void:
	if target_valid() and info.source_id == target.get_instance_id():
		_alert(target.global_position)
		# Turn toward the shooter so the next perception tick can see them.
		enemy.face_instantly(AimMath.flat_dir(enemy.global_position, target.global_position))


func _on_noise(pos: Vector3, radius: float, source_id: int) -> void:
	if enemy == null or not enemy.alive or not target_valid() or source_id != target.get_instance_id():
		return
	if enemy.global_position.distance_to(pos) <= radius * def.hearing_mult:
		_alert(target.global_position)


func _on_shot_fired(_w: WeaponState) -> void:
	if burst_left > 0:
		burst_left -= 1
		if burst_left == 0:
			enemy.intent.fire = false
			next_burst_at = now() + rng.randf_range(def.burst_pause_min_s, def.burst_pause_max_s)
