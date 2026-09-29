class_name InputRouter
extends Node
## Turns keyboard/mouse, gamepad and touch into one device-agnostic InputFrame (DESIGN §6.13,
## DECISIONS D022). Tracks the last-used device so UI can show/hide touch controls.
## Emulated mouse events generated from touch are ignored here to avoid double input.

signal device_changed(device: InputFrame.Device)

## Right-stick deflection above which gamepad/touch aiming also fires (twin-stick convention).
const PAD_AUTOFIRE_THRESHOLD := 0.85
const TOUCH_FIRE_THRESHOLD := 0.5
const PAD_ACTIVATE_THRESHOLD := 0.3

var device: InputFrame.Device = (
	InputFrame.Device.TOUCH if OS.has_feature("mobile") else InputFrame.Device.KEYBOARD_MOUSE
)
## Disables all gameplay input (menus, death screen).
var enabled := true

var _frame := InputFrame.new()
var _touch_move := Vector2.ZERO
var _touch_aim := Vector2.ZERO
var _reload_latched := false
var _swap_latched := false
var _interact_latched := false


func _ready() -> void:
	InputBindings.ensure_registered()


func _input(event: InputEvent) -> void:
	_track_device(event)
	if event.is_action_pressed(&"reload"):
		_reload_latched = true
	elif event.is_action_pressed(&"swap_weapon"):
		_swap_latched = true
	elif event.is_action_pressed(&"interact"):
		_interact_latched = true


# --- Touch feed (called by TouchControls) --------------------------------------------------------


func set_touch_sticks(move: Vector2, aim: Vector2) -> void:
	_touch_move = move
	_touch_aim = aim
	if move != Vector2.ZERO or aim != Vector2.ZERO:
		_set_device(InputFrame.Device.TOUCH)


func press_touch_action(action: StringName) -> void:
	_set_device(InputFrame.Device.TOUCH)
	match action:
		&"reload":
			_reload_latched = true
		&"swap_weapon":
			_swap_latched = true
		&"interact":
			_interact_latched = true


# --- Frame ---------------------------------------------------------------------------------------


## Builds the frame for this tick and consumes one-shot presses. Reuses one object (no per-frame
## allocation); callers must not keep the reference across ticks.
func consume_frame() -> InputFrame:
	var f := _frame
	f.device = device
	f.reload_pressed = _reload_latched and enabled
	f.swap_pressed = _swap_latched and enabled
	f.interact_pressed = _interact_latched and enabled
	_reload_latched = false
	_swap_latched = false
	_interact_latched = false
	if not enabled:
		f.move = Vector2.ZERO
		f.aim = Vector2.ZERO
		f.aim_at_cursor = false
		f.fire = false
		return f
	match device:
		InputFrame.Device.TOUCH:
			f.move = _touch_move
			f.aim = _touch_aim
			f.aim_at_cursor = false
			f.fire = _touch_aim.length() >= TOUCH_FIRE_THRESHOLD
		InputFrame.Device.GAMEPAD:
			f.move = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
			f.aim = Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
			f.aim_at_cursor = false
			f.fire = Input.is_action_pressed(&"fire") or f.aim.length() >= PAD_AUTOFIRE_THRESHOLD
		_:
			f.move = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
			f.aim = Vector2.ZERO
			f.aim_at_cursor = true
			f.cursor_screen = get_viewport().get_mouse_position() if is_inside_tree() else Vector2.ZERO
			f.fire = Input.is_action_pressed(&"fire")
	return f


func _track_device(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_device(InputFrame.Device.TOUCH)
	elif event is InputEventJoypadButton:
		_set_device(InputFrame.Device.GAMEPAD)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > PAD_ACTIVATE_THRESHOLD:
			_set_device(InputFrame.Device.GAMEPAD)
	elif event is InputEventKey:
		_set_device(InputFrame.Device.KEYBOARD_MOUSE)
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		_set_device(InputFrame.Device.KEYBOARD_MOUSE)


func _set_device(d: InputFrame.Device) -> void:
	if d == device:
		return
	device = d
	if d != InputFrame.Device.TOUCH:
		_touch_move = Vector2.ZERO
		_touch_aim = Vector2.ZERO
	device_changed.emit(d)
