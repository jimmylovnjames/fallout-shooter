extends GutTest


func _hit(amount: float) -> DamageInfo:
	return DamageInfo.make(amount, 0, Vector3.ZERO, Vector3.FORWARD)


func test_damage_clamps_and_dies_once() -> void:
	var h := HealthPool.new(50.0)
	watch_signals(h)
	assert_eq(h.apply(_hit(20.0), 0.0), 20.0)
	assert_eq(h.apply(_hit(100.0), 0.0), 30.0, "only what's left")
	assert_true(h.is_dead())
	assert_eq(h.apply(_hit(10.0), 0.0), 0.0, "dead ignores damage")
	assert_signal_emit_count(h, "died", 1)


func test_invulnerability_window() -> void:
	var h := HealthPool.new(100.0)
	h.revive(10.0, 2.0)
	assert_eq(h.apply(_hit(10.0), 11.0), 0.0)
	assert_eq(h.apply(_hit(10.0), 12.5), 10.0)


func test_heal_and_revive() -> void:
	var h := HealthPool.new(100.0)
	h.apply(_hit(30.0), 0.0)
	assert_eq(h.heal(50.0), 30.0, "capped at maximum")
	h.apply(_hit(100.0), 0.0)
	assert_eq(h.heal(10.0), 0.0, "can't heal the dead")
	h.revive(0.0)
	assert_eq(h.current, 100.0)
	assert_false(h.is_dead())


func test_zero_or_negative_damage_ignored() -> void:
	var h := HealthPool.new(10.0)
	watch_signals(h)
	h.apply(_hit(0.0), 0.0)
	h.apply(_hit(-5.0), 0.0)
	assert_eq(h.current, 10.0)
	assert_signal_not_emitted(h, "damaged")
