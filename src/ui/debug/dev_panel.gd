class_name DevPanel
extends PanelContainer
## Touch-friendly developer panel: graphics preset, render scale, perf HUD, benchmark.
## Debug builds only (Main frees it in release builds).

signal bench_requested

const BUTTON_HEIGHT := 64
const FONT_SIZE := 22

var _body: VBoxContainer
var _preset_buttons: Dictionary[StringName, Button] = {}
var _scale_slider: HSlider
var _scale_label: Label
var _hud_toggle: CheckButton
var _bench_button: Button
var _copy_button: Button
var _result_label: Label
var _last_summary: String = ""


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.82)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size.x = 440
	_build()
	_sync()
	EventBus.graphics_preset_applied.connect(func(_p: GraphicsPreset) -> void: _sync())
	EventBus.perf_hud_toggled.connect(func(_v: bool) -> void: _sync())


func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := Button.new()
	header.text = tr("UI_DEV_PANEL") + "  ▾"
	header.toggle_mode = true
	header.button_pressed = true
	_style_button(header)
	root.add_child(header)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	root.add_child(_body)
	header.toggled.connect(
		func(on: bool) -> void:
			_body.visible = on
			header.text = tr("UI_DEV_PANEL") + ("  ▾" if on else "  ▸")
	)

	_body.add_child(_label(tr("UI_GRAPHICS")))
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 6)
	_body.add_child(presets)
	var group := ButtonGroup.new()
	for p in Settings.get_presets():
		var b := Button.new()
		b.text = tr(p.name_key)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(b)
		var pid := p.id
		b.pressed.connect(func() -> void: Settings.set_preset(pid))
		presets.add_child(b)
		_preset_buttons[p.id] = b

	var scale_row := HBoxContainer.new()
	_body.add_child(scale_row)
	scale_row.add_child(_label(tr("UI_RENDER_SCALE")))
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.5
	_scale_slider.max_value = 1.0
	_scale_slider.step = 0.05
	_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_slider.custom_minimum_size.y = BUTTON_HEIGHT
	_scale_slider.drag_ended.connect(
		func(changed: bool) -> void:
			if changed:
				Settings.set_render_scale(_scale_slider.value)
				_sync()
	)
	scale_row.add_child(_scale_slider)
	_scale_label = _label("")
	_scale_label.custom_minimum_size.x = 64
	scale_row.add_child(_scale_label)

	_hud_toggle = CheckButton.new()
	_hud_toggle.text = tr("UI_TOGGLE_HUD")
	_style_button(_hud_toggle)
	_hud_toggle.toggled.connect(func(on: bool) -> void: Settings.set_perf_hud(on))
	_body.add_child(_hud_toggle)

	_bench_button = Button.new()
	_bench_button.text = tr("UI_RUN_BENCH")
	_style_button(_bench_button)
	_bench_button.pressed.connect(
		func() -> void:
			_bench_button.disabled = true
			_result_label.text = tr("UI_BENCH_RUNNING")
			bench_requested.emit()
	)
	_body.add_child(_bench_button)

	_copy_button = Button.new()
	_copy_button.text = tr("UI_COPY_RESULT")
	_copy_button.visible = false
	_style_button(_copy_button)
	_copy_button.pressed.connect(func() -> void: DisplayServer.clipboard_set(_last_summary))
	_body.add_child(_copy_button)

	_result_label = _label("")
	_result_label.add_theme_font_size_override("font_size", 16)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_result_label)


func _sync() -> void:
	var current := Settings.get_preset()
	for id in _preset_buttons:
		_preset_buttons[id].set_pressed_no_signal(current != null and id == current.id)
	_scale_slider.set_value_no_signal(Settings.base_render_scale())
	_scale_label.text = "%.2f" % Settings.base_render_scale()
	_hud_toggle.set_pressed_no_signal(Settings.show_perf_hud)


func show_bench_results(results: Dictionary) -> void:
	_bench_button.disabled = false
	_last_summary = "BENCH_RESULT " + JSON.stringify(Bench.summarize(results))
	_copy_button.visible = true
	var lines := PackedStringArray([tr("UI_BENCH_DONE")])
	for st: Dictionary in results.get("stages", []):
		lines.append(
			(
				"%s: %.1f fps (p95 %.1f ms) · %d draws%s"
				% [
					st["name"],
					st["fps_avg"],
					st["p95_ms"],
					st["draw_calls_max"],
					"" if st.get("within_budget", true) else "  ✗ OVER BUDGET"
				]
			)
		)
	lines.append(str(results.get("saved_to", "")))
	_result_label.text = "\n".join(lines)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	return l


func _style_button(b: BaseButton) -> void:
	b.custom_minimum_size.y = BUTTON_HEIGHT
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.focus_mode = Control.FOCUS_NONE
