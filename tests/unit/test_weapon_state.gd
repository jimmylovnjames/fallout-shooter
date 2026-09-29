extends GutTest

const DT := 1.0 / 60.0


func _def(rpm: float = 300.0, mag: int = 10, reload: float = 1.0) -> WeaponDef:
	var d := WeaponDef.new()
	d.id = &"wpn_test"
	d.name_key = "X"
	d.rpm = rpm
	d.mag_size = mag
	d.reload_s = reload
	return d


func test_fire_rate_is_frame_rate_independent() -> void:
	for dt: float in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0]:
		var w := WeaponState.new(_def(600.0, 1000))
		var shots := 0
		var t := 0.0
		while t < 3.0 - 0.0001:
			if w.try_fire(t):
				shots += 1
			t += dt
		assert_between(shots, 29, 31, "600 rpm for 3 s at dt=%.4f" % dt)


func test_pause_restarts_cadence() -> void:
	var w := WeaponState.new(_def(60.0))
	assert_true(w.try_fire(0.0))
	assert_false(w.try_fire(0.5), "within interval")
	assert_true(w.try_fire(5.0), "after a pause")
	assert_false(w.try_fire(5.5), "no burst after the pause")
	assert_true(w.try_fire(6.0))


func test_magazine_and_auto_reload() -> void:
	var w := WeaponState.new(_def(6000.0, 3, 1.0))
	watch_signals(w)
	var t := 0.0
	for i in 3:
		assert_true(w.try_fire(t))
		t += 0.02
	assert_eq(w.in_mag, 0)
	assert_false(w.try_fire(t), "empty")
	assert_true(w.reloading, "empty trigger pull starts a reload")
	assert_signal_emitted(w, "reload_started")
	assert_false(w.try_fire(t + 0.5), "still reloading")
	assert_almost_eq(w.reload_progress(t + 0.5), 0.5, 0.01)
	assert_true(w.try_fire(t + 1.01), "reloaded")
	assert_eq(w.in_mag, 2)


func test_manual_reload_rules() -> void:
	var w := WeaponState.new(_def())
	assert_false(w.start_reload(0.0), "full mag doesn't reload")
	w.try_fire(0.0)
	assert_true(w.start_reload(0.1))
	assert_false(w.start_reload(0.2), "already reloading")
	w.cancel_reload()
	assert_false(w.reloading)
	assert_eq(w.in_mag, 9, "cancelled reload doesn't refill")


func test_weapon_def_validation() -> void:
	var d := _def()
	assert_eq(d.validate().size(), 0)
	d.fire_mode = WeaponDef.FireMode.PROJECTILE
	d.projectile_speed = 0.0
	d.spread_deg = 90.0
	assert_eq(d.validate().size(), 2)
