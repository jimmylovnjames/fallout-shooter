class_name InvestigateState
extends AIState
## Go to where the target was last seen/heard, look around, then give up.

const LOOK_AROUND_S := 2.5


func state_name() -> StringName:
	return &"investigate"


func score(b: AIBrain) -> float:
	if not b.has_last_known:
		return 0.0
	return 0.6 if b.now() - b.last_alert_at < b.def.give_up_s else 0.0


func enter(b: AIBrain) -> void:
	b.enemy.move_speed_mult = 0.85
	b.aim_target_valid = false
	b.look_until = -1.0
	b.go_to(b.last_known)


func think(b: AIBrain, _dt: float) -> void:
	if b.moving and not b.arrived():
		return
	if b.look_until < 0.0:
		b.stop_moving()
		b.look_until = b.now() + LOOK_AROUND_S
		b.look_origin_yaw = b.enemy.visual.rotation.y
	if b.now() >= b.look_until:
		b.has_last_known = false
		return
	var yaw := b.look_origin_yaw + sin((b.now() - b.look_until) * 2.2) * 1.2
	b.aim_target = b.enemy.aim_point() + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 5.0
	b.aim_target_valid = true
