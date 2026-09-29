class_name EngageState
extends AIState
## Fight: hold preferred range (advance / back off / strafe), aim with an error cone that
## tightens over time, fire in bursts only with line of sight.

const MEMORY_S := 1.0


func state_name() -> StringName:
	return &"engage"


func score(b: AIBrain) -> float:
	if not b.target_valid():
		return 0.0
	return 1.0 if b.target_visible or b.now() - b.last_seen_at < MEMORY_S else 0.0


func enter(b: AIBrain) -> void:
	b.engaged_at = b.now()
	b.burst_left = 0
	b.next_burst_at = b.now() + b.def.reaction_s
	b.strafe_until = -1.0
	b.enemy.move_speed_mult = 1.0


func exit(b: AIBrain) -> void:
	b.burst_left = 0
	b.enemy.intent.fire = false
	b.enemy.weapon.extra_spread_deg = 0.0


func think(b: AIBrain, _dt: float) -> void:
	var def := b.def
	var me := b.enemy.global_position
	var target := b.target.global_position
	var dist := me.distance_to(target)
	b.aim_target = b.target.aim_point() if b.target_visible else b.last_known + Vector3(0, 1.2, 0)
	b.aim_target_valid = true

	if not b.target_visible:
		b.go_to(b.last_known)
	elif dist > def.preferred_range_m + 2.5:
		b.go_to(target)
	elif dist < def.preferred_range_m - 3.0:
		b.move_direct(AimMath.flat_dir(target, me) * 0.8)
	else:
		if b.now() >= b.strafe_until:
			b.strafe_sign = -1.0 if b.rng.randf() < 0.5 else 1.0
			b.strafe_until = b.now() + b.rng.randf_range(1.2, 2.6)
		var lateral := AimMath.flat_dir(me, target).cross(Vector3.UP) * b.strafe_sign
		b.move_direct(lateral * 0.6)

	var settle := clampf((b.now() - b.engaged_at) / maxf(def.aim_settle_s, 0.01), 0.0, 1.0)
	b.enemy.weapon.extra_spread_deg = lerpf(def.aim_error_deg, def.aim_error_min_deg, settle)
	if b.target_visible and b.burst_left == 0 and b.now() >= b.next_burst_at:
		b.burst_left = def.burst_shots
	b.enemy.intent.fire = b.target_visible and b.burst_left > 0
