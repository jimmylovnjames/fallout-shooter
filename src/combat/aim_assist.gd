class_name AimAssist
extends RefCounted
## Touch/gamepad aim assist (DESIGN §6.3): pick the best target inside a cone and bend the aim
## toward it. Pure functions; the caller supplies candidate positions and does the LOS check.


## Index of the best candidate or -1. Score favours small angle first, then distance.
static func pick(
	origin: Vector3, aim_dir: Vector3, candidates: PackedVector3Array, cone_deg: float, max_range: float
) -> int:
	var best := -1
	var best_score := INF
	var cos_limit := cos(deg_to_rad(cone_deg))
	for i in candidates.size():
		var to := candidates[i] - origin
		to.y = 0.0
		var dist := to.length()
		if dist < 0.001 or dist > max_range:
			continue
		var c := aim_dir.dot(to / dist)
		if c < cos_limit:
			continue
		var angle := acos(clampf(c, -1.0, 1.0))
		var score := angle / deg_to_rad(cone_deg) + 0.35 * dist / max_range
		if score < best_score:
			best_score = score
			best = i
	return best


## Rotates `aim_dir` toward `target_dir` by `strength` (0 = none, 1 = snap). Both unit, flat.
static func bend(aim_dir: Vector3, target_dir: Vector3, strength: float) -> Vector3:
	if strength <= 0.0 or target_dir == Vector3.ZERO:
		return aim_dir
	return aim_dir.slerp(target_dir, clampf(strength, 0.0, 1.0)).normalized()
