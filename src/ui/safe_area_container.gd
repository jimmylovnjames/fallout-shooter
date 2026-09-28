class_name SafeAreaContainer
extends MarginContainer
## Keeps children clear of notches, punch-holes and rounded corners on mobile using the display
## safe area (DESIGN §6.13). On desktop it only applies the extra margin.

@export var extra_margin: int = 12


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.size_changed.connect(_update_margins)
	_update_margins()


func _update_margins() -> void:
	var m := Vector4i(extra_margin, extra_margin, extra_margin, extra_margin)  # l, t, r, b
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		if win.x > 0.0 and win.y > 0.0 and safe.size.x > 0.0:
			var k := get_viewport_rect().size / win
			m.x += int(maxf(safe.position.x, 0.0) * k.x)
			m.y += int(maxf(safe.position.y, 0.0) * k.y)
			m.z += int(maxf(win.x - safe.end.x, 0.0) * k.x)
			m.w += int(maxf(win.y - safe.end.y, 0.0) * k.y)
	add_theme_constant_override("margin_left", m.x)
	add_theme_constant_override("margin_top", m.y)
	add_theme_constant_override("margin_right", m.z)
	add_theme_constant_override("margin_bottom", m.w)
