class_name Hitscan
extends RefCounted
## Instant ray weapons and shared spread math. Pure static helpers over a physics space.


## Returns a unit direction randomly deviated inside a cone of half-angle `spread_deg` around
## `dir` (kept on the horizontal plane: top-down shots never go into the ground or sky).
static func spread_dir(dir: Vector3, spread_deg: float, rng: RandomNumberGenerator) -> Vector3:
	if spread_deg <= 0.0:
		return dir
	var angle := deg_to_rad(rng.randf_range(-spread_deg, spread_deg))
	return dir.rotated(Vector3.UP, angle).normalized()


## Casts one ray. Returns {} on miss, else {position, normal, collider, collider_id}.
static func cast(
	space: PhysicsDirectSpaceState3D, origin: Vector3, dir: Vector3, range_m: float, mask: int, exclude: Array[RID]
) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * range_m, mask, exclude)
	q.collide_with_areas = false
	return space.intersect_ray(q)


## Health component on a hit collider, walking up from the collider (null = not damageable).
static func health_of(collider: Object) -> HealthComponent:
	var n := collider as Node
	while n != null:
		var h := n.get_node_or_null(^"Health") as HealthComponent
		if h != null:
			return h
		if n is Actor:
			return null
		n = n.get_parent()
	return null
