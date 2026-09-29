class_name AutoPilot
extends Node
## Scripted stand-in for a human (CLI `--autoplay`): strafes around the arena and shoots the
## nearest visible hostile. Used for soak tests, demo screenshots and on-device perf runs with
## repeatable load. Runs after PlayerController and overrides the intent it wrote.

const ENGAGE_RANGE_M := 24.0
const ORBIT_RADIUS_M := 9.0

var _player: Player
var _hostiles: Callable
var _t := 0.0
var _dir := 1.0
var _stuck_s := 0.0


func _ready() -> void:
	process_physics_priority = -5


func setup(player: Player, hostiles: Callable) -> void:
	_player = player
	_hostiles = hostiles
	player.controller.enabled = false


func _physics_process(delta: float) -> void:
	if _player == null or not _player.alive:
		return
	_t += delta
	var intent := _player.intent
	var pos := _player.global_position
	# Orbit the arena centre, flipping direction now and then or when wedged against geometry.
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	_stuck_s = _stuck_s + delta if speed < 0.5 else 0.0
	if fmod(_t, 9.0) < delta or _stuck_s > 0.6:
		_dir = -_dir
		_stuck_s = 0.0
	var radial := Vector3(pos.x, 0, pos.z)
	var tangent := Vector3(-radial.z, 0, radial.x).normalized() * _dir if radial.length() > 0.1 else Vector3.RIGHT
	var correction := -radial.normalized() * clampf((radial.length() - ORBIT_RADIUS_M) / 4.0, -1.0, 1.0)
	intent.move = (tangent + correction).limit_length(1.0)
	var target := _nearest_visible()
	intent.aim = AimMath.flat_dir(pos, target.global_position) if target != null else Vector3.ZERO
	intent.fire = target != null
	intent.reload = false
	intent.swap = fmod(_t, 14.0) < delta


func _nearest_visible() -> Actor:
	var best: Actor = null
	var best_d := ENGAGE_RANGE_M
	var space := _player.get_world_3d().direct_space_state
	for a: Actor in _hostiles.call():
		if not a.alive:
			continue
		var d := a.global_position.distance_to(_player.global_position)
		if d < best_d and Perception.has_line_of_sight(space, _player.aim_point(), a.aim_point()):
			best = a
			best_d = d
	return best
