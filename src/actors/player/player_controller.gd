class_name PlayerController
extends Node
## Converts the device-level InputFrame into a world-space ActorIntent for the player, including
## camera-relative movement, cursor aiming (KBM) and aim assist (touch/gamepad).

const ASSIST_CONE_DEG := 14.0
const ASSIST_RANGE_M := 24.0
const ASSIST_STRENGTH_TOUCH := 0.6
const ASSIST_STRENGTH_PAD := 0.35

var enabled := true

var _actor: Actor
var _router: InputRouter
var _rig: CameraRig
## Returns Array[Actor] of current hostiles (for aim assist).
var _hostiles: Callable
var _candidates := PackedVector3Array()
var _candidate_actors: Array[Actor] = []


func _ready() -> void:
	# Run before the actor's own physics step so the intent applies this tick, not the next.
	process_physics_priority = -10


func setup(actor: Actor, router: InputRouter, rig: CameraRig, hostiles: Callable) -> void:
	_actor = actor
	_router = router
	_rig = rig
	_hostiles = hostiles


func _physics_process(_delta: float) -> void:
	if _actor == null or _router == null:
		return
	if not enabled:
		return  # another driver (AutoPilot, cutscene) owns the intent
	var f := _router.consume_frame()
	var intent := _actor.intent
	if not _actor.alive:
		intent.clear()
		return
	var yaw := _rig.yaw_rad() if _rig != null else 0.0
	intent.move = AimMath.screen_to_world(f.move.limit_length(1.0), yaw)
	intent.aim = _resolve_aim(f, yaw)
	intent.fire = f.fire
	intent.reload = f.reload_pressed
	intent.swap = f.swap_pressed


func _resolve_aim(f: InputFrame, yaw: float) -> Vector3:
	if f.aim_at_cursor:
		if _rig == null:
			return Vector3.ZERO
		var p: Variant = _rig.screen_to_ground(f.cursor_screen, _actor.global_position.y + 1.1)
		return AimMath.flat_dir(_actor.global_position, p) if p != null else Vector3.ZERO
	if f.aim == Vector2.ZERO:
		return Vector3.ZERO
	var dir := AimMath.screen_to_world(f.aim.normalized(), yaw)
	var strength := ASSIST_STRENGTH_TOUCH if f.device == InputFrame.Device.TOUCH else ASSIST_STRENGTH_PAD
	return _assist(dir, strength)


func _assist(dir: Vector3, strength: float) -> Vector3:
	if not _hostiles.is_valid():
		return dir
	_candidates.clear()
	_candidate_actors.clear()
	for a: Actor in _hostiles.call():
		if a.alive:
			_candidates.append(a.aim_point())
			_candidate_actors.append(a)
	var origin := _actor.aim_point()
	var idx := AimAssist.pick(origin, dir, _candidates, ASSIST_CONE_DEG, ASSIST_RANGE_M)
	if idx < 0:
		return dir
	var target := _candidates[idx]
	var exclude: Array[RID] = [_actor.get_rid()]
	var hit := Hitscan.cast(
		_actor.get_world_3d().direct_space_state,
		origin,
		(target - origin).normalized(),
		origin.distance_to(target),
		PhysicsLayers.SIGHT,
		exclude
	)
	if not hit.is_empty():
		return dir
	return AimAssist.bend(dir, AimMath.flat_dir(origin, target), strength)
