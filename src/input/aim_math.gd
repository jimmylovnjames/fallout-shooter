class_name AimMath
extends RefCounted
## Screen <-> world conversions for a top-down camera. Pure functions (unit-tested).


## Screen-space stick vector (+y down) -> world XZ vector, relative to the camera's yaw.
## Stick "up" means "away from the camera", which is world -Z rotated by the camera yaw.
static func screen_to_world(v: Vector2, camera_yaw: float) -> Vector3:
	return Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, camera_yaw)


## Intersects a ray with the horizontal plane y = height. Returns null when parallel/behind.
static func ray_to_ground(origin: Vector3, dir: Vector3, height: float) -> Variant:
	if absf(dir.y) < 0.0001:
		return null
	var t := (height - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


## Flattened unit direction from `from` to `to` on the XZ plane (zero if coincident).
static func flat_dir(from: Vector3, to: Vector3) -> Vector3:
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	return d.normalized() if d.length_squared() > 0.000001 else Vector3.ZERO


## Radial deadzone with rescale so output ramps smoothly from 0 at the deadzone edge to 1.
static func apply_deadzone(v: Vector2, deadzone: float) -> Vector2:
	var l := v.length()
	if l <= deadzone:
		return Vector2.ZERO
	var scaled := minf((l - deadzone) / (1.0 - deadzone), 1.0)
	return v / l * scaled
