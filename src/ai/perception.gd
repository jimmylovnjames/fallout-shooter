class_name Perception
extends RefCounted
## Sight checks (DESIGN §6.11). Geometry test is pure; LOS needs a physics space.


## True when `target` is within `range_m` and inside the horizontal view cone around `forward`.
static func in_view_cone(pos: Vector3, forward: Vector3, target: Vector3, fov_deg: float, range_m: float) -> bool:
	var to := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	var dist := to.length()
	if dist > range_m:
		return false
	if dist < 0.001 or fov_deg >= 360.0:
		return true
	return forward.dot(to / dist) >= cos(deg_to_rad(fov_deg * 0.5))


## Unobstructed straight line between two points (static world geometry only).
static func has_line_of_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.SIGHT)
	return space.intersect_ray(q).is_empty()
