class_name TopDownCamera
extends Camera3D
## Fixed-angle 3/4 top-down camera looking at a target point. P1 turns this into the full rig
## (follow, zoom, occluder cut-away).

@export var target: Vector3 = Vector3.ZERO
@export_range(20.0, 89.0) var pitch_deg: float = 55.0
@export var yaw_deg: float = 35.0
@export var distance: float = 30.0


func _ready() -> void:
	fov = 40.0
	near = 0.5
	far = 150.0
	frame()


func frame() -> void:
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, -deg_to_rad(pitch_deg)).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	look_at_from_position(target + dir * distance, target, Vector3.UP)
