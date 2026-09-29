class_name InputBindings
extends RefCounted
## Single source of truth for input actions and their default bindings (DECISIONS D028).
## Registered at boot into InputMap; user rebinding (P2) stores overrides in Settings.

const STICK_DEADZONE := 0.2


## action -> list of default events, built lazily (InputEvent objects can't be consts).
static func defaults() -> Dictionary[StringName, Array]:
	return {
		&"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		&"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		&"move_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		&"move_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		&"aim_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
		&"aim_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
		&"aim_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		&"aim_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		&"fire": [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		&"reload": [_key(KEY_R), _button(JOY_BUTTON_X)],
		&"swap_weapon": [_key(KEY_Q), _key(KEY_TAB), _button(JOY_BUTTON_Y)],
		&"interact": [_key(KEY_E), _button(JOY_BUTTON_A)],
	}


## Adds any missing action with its default events. Idempotent.
static func ensure_registered() -> void:
	var d := defaults()
	for action: StringName in d:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, STICK_DEADZONE)
		for ev: InputEvent in d[action]:
			InputMap.action_add_event(action, ev)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = -1
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = -1
	return e
