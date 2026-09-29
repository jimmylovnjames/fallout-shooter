extends GutTest

var _router: InputRouter
var _touch: TouchControls


func before_each() -> void:
	_router = InputRouter.new()
	add_child_autofree(_router)
	_touch = TouchControls.new()
	add_child_autofree(_touch)
	_touch.size = Vector2(1280, 720)
	_touch.bind(_router)
	_router._set_device(InputFrame.Device.TOUCH)


func _touch_event(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	_touch._input(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	_touch._input(e)


func test_stick_vector() -> void:
	assert_eq(TouchControls.stick_vector(Vector2.ZERO, Vector2(5, 0), 100.0, 0.12), Vector2.ZERO, "deadzone")
	assert_almost_eq(TouchControls.stick_vector(Vector2.ZERO, Vector2(300, 0), 100.0, 0.12).x, 1.0, 0.001, "clamped")


func test_twin_sticks_with_independent_fingers() -> void:
	_touch_event(0, Vector2(200, 500), true)
	_drag(0, Vector2(200, 400))
	_touch_event(1, Vector2(1000, 500), true)
	_drag(1, Vector2(1100, 500))
	var f := _router.consume_frame()
	assert_lt(f.move.y, -0.5, "left finger moves up")
	assert_gt(f.aim.x, 0.5, "right finger aims right")
	assert_true(f.fire, "full right deflection fires")
	_touch_event(1, Vector2(1100, 500), false)
	f = _router.consume_frame()
	assert_eq(f.aim, Vector2.ZERO)
	assert_lt(f.move.y, -0.5, "left stick unaffected by right release")


func test_button_tap_while_stick_held() -> void:
	_touch_event(0, Vector2(200, 500), true)
	_drag(0, Vector2(300, 500))
	_touch_event(1, _touch.button_center(0), true)  # reload
	assert_true(_router.consume_frame().reload_pressed, "second finger reaches the button")


func test_top_strip_ignored() -> void:
	_touch_event(0, Vector2(200, 50), true)
	_drag(0, Vector2(300, 50))
	assert_eq(_router.consume_frame().move, Vector2.ZERO)


func test_hidden_for_non_touch_devices() -> void:
	_router._set_device(InputFrame.Device.GAMEPAD)
	assert_false(_touch.visible)
