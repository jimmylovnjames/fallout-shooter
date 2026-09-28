class_name PerfHud
extends PanelContainer
## On-screen performance overlay: fps, frame times, draw calls, memory, renderer and preset.
## Visible by default in debug builds; toggle with F3 or the dev panel.

const REFRESH_S := 0.25
const WINDOW_FRAMES := 120

var _label: Label
var _frame_ms := PackedFloat32Array()
var _cursor := 0
var _accum := 0.0
var _pipelines_at_start := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_ms.resize(WINDOW_FRAMES)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	visible = Settings.show_perf_hud
	EventBus.perf_hud_toggled.connect(func(v: bool) -> void: visible = v)
	_pipelines_at_start = PerfProbe.pipeline_compilations()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F3:
		Settings.set_perf_hud(not visible)


func _process(delta: float) -> void:
	_frame_ms[_cursor] = delta * 1000.0
	_cursor = (_cursor + 1) % WINDOW_FRAMES
	_accum += delta
	if _accum < REFRESH_S or not visible:
		return
	_accum = 0.0
	_label.text = _compose()


func _compose() -> String:
	var s := PerfProbe.snapshot()
	var sum := 0.0
	var worst := 0.0
	var n := 0
	for ms in _frame_ms:
		if ms > 0.0:
			sum += ms
			worst = maxf(worst, ms)
			n += 1
	var avg := sum / maxf(n, 1)
	var preset := Settings.get_preset()
	var size := get_tree().root.size
	var eff := Settings.effective_render_scale()
	return (
		"\n"
		. join(
			[
				"FPS %d   avg %.1f ms   max %.1f ms" % [s["fps"], avg, worst],
				"Draw %d   Prim %s   Obj %d" % [s["draw_calls"], _k(s["primitives"]), s["objects"]],
				(
					"VRAM %.0f MB   Tex %.0f MB   Static %.0f MB"
					% [s["video_mem_mb"], s["texture_mem_mb"], s["static_mem_mb"]]
				),
				"Nodes %d   PSO compiles +%d" % [s["nodes"], s["pipeline_compiles"] - _pipelines_at_start],
				(
					"%s  ×%.2f → %dp  %s/%s"
					% [
						preset.id if preset else "-",
						eff,
						int(mini(size.x, size.y) * eff),
						RenderingServer.get_current_rendering_method(),
						RenderingServer.get_current_rendering_driver_name()
					]
				),
				RenderingServer.get_video_adapter_name(),
			]
		)
	)


static func _k(v: int) -> String:
	return "%.1fk" % (v / 1000.0) if v >= 1000 else str(v)
