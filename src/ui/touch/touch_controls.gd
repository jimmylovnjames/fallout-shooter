class_name TouchControls
extends Control
## Twin-stick touch layer (DESIGN §6.13): floating left stick = move, floating right stick = aim
## (fires past a threshold), plus action buttons. ONE multi-touch dispatcher owns every finger, so
## a thumb on a stick never blocks a tap on a button (Godot only emulates mouse for finger 0).
## Drawn with _draw() on a single canvas item: a handful of draw calls total.

const STICK_RADIUS := 105.0
const DEADZONE := 0.12
## Zones start below this fraction of the height (top strip is for HUD/menus).
const TOP_EXCLUSION := 0.18
const BUTTON_RADIUS := 46.0

## Buttons: action, label key, position relative to the bottom-right corner.
const BUTTONS: Array[Dictionary] = [
	{"action": &"reload", "label": "TOUCH_RELOAD", "offset": Vector2(-250, -300)},
	{"action": &"swap_weapon", "label": "TOUCH_SWAP", "offset": Vector2(-130, -370)},
	{"action": &"interact", "label": "TOUCH_USE", "offset": Vector2(-370, -200)},
]

var router: InputRouter

var _left := _Stick.new()
var _right := _Stick.new()
## finger index -> button index
var _button_fingers: Dictionary[int, int] = {}


class _Stick:
	var finger := -1
	var origin := Vector2.ZERO
	var pos := Vector2.ZERO

	func active() -> bool:
		return finger != -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


## Connects to the router; visibility follows the active input device.
func bind(r: InputRouter) -> void:
	router = r
	router.device_changed.connect(_on_device_changed)
	_on_device_changed(router.device)


func _on_device_changed(d: InputFrame.Device) -> void:
	visible = d == InputFrame.Device.TOUCH
	if not visible:
		_release_all()


## Pure: stick output for a finger at `pos` on a stick centred at `origin`.
static func stick_vector(origin: Vector2, pos: Vector2, radius: float, deadzone: float) -> Vector2:
	return AimMath.apply_deadzone((pos - origin) / radius, deadzone).limit_length(1.0)


func button_center(i: int) -> Vector2:
	return size + (BUTTONS[i]["offset"] as Vector2)


func _input(event: InputEvent) -> void:
	if not visible or router == null:
		return
	if event is InputEventScreenTouch:
		var t := make_input_local(event) as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := make_input_local(event) as InputEventScreenDrag
		_touch_move(d.index, d.position)


func _touch_down(finger: int, p: Vector2) -> void:
	for i in BUTTONS.size():
		if p.distance_to(button_center(i)) <= BUTTON_RADIUS * 1.15:
			_button_fingers[finger] = i
			router.press_touch_action(BUTTONS[i]["action"])
			queue_redraw()
			return
	if p.y < size.y * TOP_EXCLUSION or _blocked(p):
		return
	var stick := _left if p.x < size.x * 0.5 else _right
	if stick.active():
		return
	stick.finger = finger
	stick.origin = p
	stick.pos = p
	_publish()


func _touch_move(finger: int, p: Vector2) -> void:
	for stick: _Stick in [_left, _right]:
		if stick.finger == finger:
			stick.pos = p
			# Base follows a finger that drifts far outside the ring.
			var off := p - stick.origin
			if off.length() > STICK_RADIUS * 1.3:
				stick.origin = p - off.normalized() * STICK_RADIUS * 1.3
			_publish()
			return


func _touch_up(finger: int) -> void:
	if _button_fingers.erase(finger):
		queue_redraw()
		return
	for stick: _Stick in [_left, _right]:
		if stick.finger == finger:
			stick.finger = -1
			_publish()
			return


func _release_all() -> void:
	_left.finger = -1
	_right.finger = -1
	_button_fingers.clear()
	if router != null:
		router.set_touch_sticks(Vector2.ZERO, Vector2.ZERO)
	queue_redraw()


func _publish() -> void:
	var m := stick_vector(_left.origin, _left.pos, STICK_RADIUS, DEADZONE) if _left.active() else Vector2.ZERO
	var a := stick_vector(_right.origin, _right.pos, STICK_RADIUS, DEADZONE) if _right.active() else Vector2.ZERO
	router.set_touch_sticks(m, a)
	queue_redraw()


## Touches that start on a registered blocker (e.g. the expanded dev panel) are ignored.
func _blocked(p: Vector2) -> bool:
	var global_p := get_global_transform() * p
	for n in get_tree().get_nodes_in_group(&"touch_blocker"):
		var c := n as Control
		if c != null and c.is_visible_in_tree() and c.get_global_rect().has_point(global_p):
			return true
	return false


func _draw() -> void:
	var font := get_theme_default_font()
	for stick: _Stick in [_left, _right]:
		var idle := not stick.active()
		var o := stick.origin
		if idle:
			o = Vector2(size.x * (0.16 if stick == _left else 0.84), size.y * 0.74)
		draw_circle(o, STICK_RADIUS, Color(1, 1, 1, 0.05 if idle else 0.1))
		draw_arc(o, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.18 if idle else 0.35), 3.0)
		var knob := o
		if not idle:
			knob = o + (stick.pos - o).limit_length(STICK_RADIUS)
		var knob_col := Color(1.0, 0.6, 0.25, 0.8) if stick == _right and not idle else Color(1, 1, 1, 0.5)
		draw_circle(knob, 38.0, knob_col if not idle else Color(1, 1, 1, 0.15))
	for i in BUTTONS.size():
		var c := button_center(i)
		var pressed := _button_fingers.values().has(i)
		draw_circle(c, BUTTON_RADIUS, Color(0.1, 0.09, 0.08, 0.7 if pressed else 0.45))
		draw_arc(c, BUTTON_RADIUS, 0.0, TAU, 40, Color(1.0, 0.6, 0.25, 0.9 if pressed else 0.5), 3.0)
		var text := tr(BUTTONS[i]["label"])
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
		draw_string(font, c + Vector2(-w * 0.5, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.9))
