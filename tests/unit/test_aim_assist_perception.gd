extends GutTest


func test_pick_prefers_smallest_angle() -> void:
	var c := PackedVector3Array([Vector3(3, 0, -10), Vector3(0.5, 0, -12), Vector3(-2, 0, -5)])
	assert_eq(AimAssist.pick(Vector3.ZERO, Vector3(0, 0, -1), c, 20.0, 30.0), 1)


func test_pick_respects_cone_and_range() -> void:
	var c := PackedVector3Array([Vector3(10, 0, -1), Vector3(0, 0, -50)])
	assert_eq(AimAssist.pick(Vector3.ZERO, Vector3(0, 0, -1), c, 15.0, 30.0), -1)


func test_bend() -> void:
	var a := Vector3(0, 0, -1)
	var t := Vector3(1, 0, -1).normalized()
	assert_eq(AimAssist.bend(a, t, 0.0), a)
	assert_almost_eq(AimAssist.bend(a, t, 1.0), t, Vector3.ONE * 0.001)
	var half := AimAssist.bend(a, t, 0.5)
	assert_almost_eq(rad_to_deg(a.angle_to(half)), 22.5, 0.1)


func test_view_cone() -> void:
	var fwd := Vector3(0, 0, -1)
	assert_true(Perception.in_view_cone(Vector3.ZERO, fwd, Vector3(0, 0, -10), 90.0, 20.0))
	assert_false(Perception.in_view_cone(Vector3.ZERO, fwd, Vector3(0, 0, 10), 90.0, 20.0), "behind")
	assert_false(Perception.in_view_cone(Vector3.ZERO, fwd, Vector3(0, 0, -30), 90.0, 20.0), "too far")
	assert_true(Perception.in_view_cone(Vector3.ZERO, fwd, Vector3(0, 0, 10), 360.0, 20.0), "omnidirectional")
	assert_true(Perception.in_view_cone(Vector3.ZERO, fwd, Vector3(9, 5, -9.5), 90.0, 20.0), "height ignored")


func test_lead_point() -> void:
	var from := Vector3.ZERO
	var to := Vector3(0, 0, -20)
	var vel := Vector3(5, 0, 0)
	assert_eq(AIBrain.lead_point(from, to, vel, 0.0, 1.0), to, "hitscan: no lead")
	assert_eq(AIBrain.lead_point(from, to, vel, 20.0, 0.0), to, "no skill: no lead")
	# 20 m at 20 m/s = 1 s of flight: a perfect shooter aims 5 m ahead.
	assert_almost_eq(AIBrain.lead_point(from, to, vel, 20.0, 1.0), Vector3(5, 0, -20), Vector3.ONE * 0.001)
	assert_almost_eq(AIBrain.lead_point(from, to, vel, 20.0, 0.5), Vector3(2.5, 0, -20), Vector3.ONE * 0.001)
