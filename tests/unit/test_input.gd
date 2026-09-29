extends GutTest

var _router: InputRouter


func before_each() -> void:
	_router = InputRouter.new()
	add_child_autofree(_router)


func after_each() -> void:
	for a: StringName in [&"move_right", &"move_up", &"fire"]:
		Input.action_release(a)


func test_bindings_registered_and_idempotent() -> void:
	InputBindings.ensure_registered()
	InputBindings.ensure_registered()
	for action: StringName in InputBindings.defaults():
		assert_true(InputMap.has_action(action), String(action))
	assert_eq(InputMap.action_get_events(&"reload").size(), InputBindings.defaults()[&"reload"].size(), "no duplicates")


func test_keyboard_mouse_frame() -> void:
	_router._set_device(InputFrame.Device.KEYBOARD_MOUSE)
	Input.action_press(&"move_right")
	Input.action_press(&"fire")
	var f := _router.consume_frame()
	assert_almost_eq(f.move.x, 1.0, 0.001)
	assert_true(f.aim_at_cursor, "KBM aims at the cursor")
	assert_true(f.fire)


func test_touch_fire_threshold() -> void:
	_router.set_touch_sticks(Vector2(0, -1), Vector2(0.3, 0))
	var f := _router.consume_frame()
	assert_eq(f.device, InputFrame.Device.TOUCH)
	assert_eq(f.move, Vector2(0, -1))
	assert_false(f.fire, "small aim deflection only aims")
	_router.set_touch_sticks(Vector2.ZERO, Vector2(0.8, 0))
	assert_true(_router.consume_frame().fire, "past the threshold fires")


func test_one_shot_actions_are_consumed_once() -> void:
	_router.press_touch_action(&"reload")
	assert_true(_router.consume_frame().reload_pressed)
	assert_false(_router.consume_frame().reload_pressed)


func test_disabled_router_outputs_nothing() -> void:
	_router.set_touch_sticks(Vector2(1, 0), Vector2(1, 0))
	_router.press_touch_action(&"swap_weapon")
	_router.enabled = false
	var f := _router.consume_frame()
	assert_eq(f.move, Vector2.ZERO)
	assert_false(f.fire)
	assert_false(f.swap_pressed)


func test_device_switch_emits_and_clears_touch() -> void:
	_router.set_touch_sticks(Vector2(1, 0), Vector2.ZERO)
	watch_signals(_router)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	_router._input(key)
	assert_signal_emitted_with_parameters(_router, "device_changed", [InputFrame.Device.KEYBOARD_MOUSE])
	_router._set_device(InputFrame.Device.TOUCH)
	assert_eq(_router.consume_frame().move, Vector2.ZERO, "stale touch state cleared on device switch")


func test_emulated_mouse_does_not_steal_touch() -> void:
	_router._set_device(InputFrame.Device.TOUCH)
	var m := InputEventMouseMotion.new()
	m.device = InputEvent.DEVICE_ID_EMULATION
	_router._input(m)
	assert_eq(_router.device, InputFrame.Device.TOUCH)
