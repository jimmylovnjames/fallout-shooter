class_name PatrolState
extends AIState
## Idle wandering around home at walking pace, pausing between points.


func state_name() -> StringName:
	return &"patrol"


func score(_b: AIBrain) -> float:
	return 0.1


func enter(b: AIBrain) -> void:
	b.stop_moving()
	b.aim_target_valid = false
	b.enemy.move_speed_mult = 0.75 if b.hunting else b.def.patrol_speed_mult
	b.next_wander_at = b.now() + b.rng.randf_range(0.2, 1.5)


func think(b: AIBrain, _dt: float) -> void:
	if b.moving and not b.arrived():
		return
	if b.moving:
		b.stop_moving()
		b.next_wander_at = b.now() + b.rng.randf_range(1.0, 3.0)
	if b.now() >= b.next_wander_at:
		var angle := b.rng.randf() * TAU
		var radius := b.def.patrol_radius_m * (1.5 if b.hunting else 1.0)
		var r := b.rng.randf_range(2.0, radius)
		b.go_to(b.patrol_center() + Vector3(cos(angle), 0.0, sin(angle)) * r)
