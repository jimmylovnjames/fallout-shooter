class_name CameraRig
extends Node3D
## Gameplay camera: fixed-angle 3/4 top-down view that follows a target with smoothing and
## look-ahead toward the aim direction, and drives the occluder cut-away globals every frame.

@export_range(20.0, 89.0) var pitch_deg: float = 55.0
@export var yaw_deg: float = 35.0
@export var distance: float = 24.0
## Exponential follow sharpness (higher = snappier).
@export var follow_sharpness: float = 7.0
@export var look_ahead_m: float = 3.0
## Cut-away circle radius as a fraction of screen height (0 disables).
@export var cutaway_radius: float = 0.13

var target: Actor
var _focus := Vector3.ZERO

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.fov = 40.0
	camera.near = 0.5
	camera.far = 150.0
	camera.current = true
	_place()


func yaw_rad() -> float:
	return deg_to_rad(yaw_deg)


func follow(actor: Actor) -> void:
	target = actor
	snap_to_target()


func snap_to_target() -> void:
	if target != null:
		_focus = target.global_position
	_place()


func _process(delta: float) -> void:
	if target != null:
		var desired := target.global_position
		if target.alive:
			desired += target.intent.aim * look_ahead_m
		_focus = _focus.lerp(desired, 1.0 - exp(-follow_sharpness * delta))
	_place()
	_update_cutaway()


## World point on the plane y = height under a screen position (null if none).
func screen_to_ground(screen_pos: Vector2, height: float) -> Variant:
	return AimMath.ray_to_ground(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos), height)


func _place() -> void:
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, -deg_to_rad(pitch_deg)).rotated(Vector3.UP, yaw_rad())
	global_position = _focus
	if camera != null:
		camera.look_at_from_position(_focus + dir * distance, _focus, Vector3.UP)


func _update_cutaway() -> void:
	if target == null or not target.alive or cutaway_radius <= 0.0:
		RenderingServer.global_shader_parameter_set(&"cutaway_radius", 0.0)
		return
	var p := target.aim_point()
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var uv := camera.unproject_position(p) / size
	var depth := (p - camera.global_position).dot(-camera.global_basis.z)
	RenderingServer.global_shader_parameter_set(&"cutaway_center", uv)
	RenderingServer.global_shader_parameter_set(&"cutaway_radius", cutaway_radius)
	RenderingServer.global_shader_parameter_set(&"cutaway_depth", depth)
