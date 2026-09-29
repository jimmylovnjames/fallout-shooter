extends GutTest


func test_screen_to_world_without_yaw() -> void:
	assert_almost_eq(
		AimMath.screen_to_world(Vector2(0, -1), 0.0),
		Vector3(0, 0, -1),
		Vector3.ONE * 0.001,
		"stick up = away from camera"
	)
	assert_almost_eq(AimMath.screen_to_world(Vector2(1, 0), 0.0), Vector3(1, 0, 0), Vector3.ONE * 0.001)


func test_screen_to_world_follows_camera_yaw() -> void:
	# Camera yawed 90° left: "away from camera" becomes world -X.
	assert_almost_eq(AimMath.screen_to_world(Vector2(0, -1), PI / 2.0), Vector3(-1, 0, 0), Vector3.ONE * 0.001)


func test_ray_to_ground() -> void:
	var p: Variant = AimMath.ray_to_ground(Vector3(0, 10, 0), Vector3(0, -1, 1).normalized(), 0.0)
	assert_almost_eq(p as Vector3, Vector3(0, 0, 10), Vector3.ONE * 0.001)
	assert_null(AimMath.ray_to_ground(Vector3(0, 10, 0), Vector3(1, 0, 0), 0.0), "parallel")
	assert_null(AimMath.ray_to_ground(Vector3(0, 10, 0), Vector3(0, 1, 0), 0.0), "pointing away")


func test_flat_dir() -> void:
	assert_almost_eq(AimMath.flat_dir(Vector3(0, 5, 0), Vector3(3, -2, 4)), Vector3(0.6, 0, 0.8), Vector3.ONE * 0.001)
	assert_eq(AimMath.flat_dir(Vector3.ONE, Vector3.ONE), Vector3.ZERO)


func test_deadzone_rescales() -> void:
	assert_eq(AimMath.apply_deadzone(Vector2(0.1, 0), 0.2), Vector2.ZERO)
	assert_almost_eq(AimMath.apply_deadzone(Vector2(0.6, 0), 0.2).x, 0.5, 0.001)
	assert_almost_eq(AimMath.apply_deadzone(Vector2(2, 0), 0.2).x, 1.0, 0.001, "clamped")


func test_actor_math() -> void:
	var v := Actor.step_velocity(Vector3.ZERO, Vector3(5, 0, 0), 40.0, 60.0, 0.05)
	assert_almost_eq(v.x, 2.0, 0.001, "accelerates at accel rate")
	v = Actor.step_velocity(Vector3(5, 0, 0), Vector3.ZERO, 40.0, 60.0, 0.05)
	assert_almost_eq(v.x, 2.0, 0.001, "decelerates at decel rate")
	assert_almost_eq(Actor.yaw_for(Vector3(0, 0, -1)), 0.0, 0.001, "forward is -Z")
	assert_almost_eq(Actor.yaw_for(Vector3(-1, 0, 0)), PI / 2.0, 0.001)
