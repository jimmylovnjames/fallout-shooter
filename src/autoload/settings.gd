extends Node
## User preferences persisted to user://settings.cfg, plus application of graphics/audio
## settings (DESIGN §4.2, §7). Graphics presets are data: res://data/settings/graphics/*.tres.

const PATH := "user://settings.cfg"
const PRESET_TYPE := &"GraphicsPreset"
const FALLBACK_PRESET := &"gfx_medium"
const AUDIO_BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"Ambience", &"UI", &"Voice"]
## Render scale is expressed relative to this many lines on the screen's short side, so a preset
## costs roughly the same GPU time on a 1080p and a 1440p phone (DECISIONS D026).
const REFERENCE_LINES := 1080.0
const MIN_EFFECTIVE_SCALE := 0.25

var preset_id: StringName = &""
## < 0 means "use the preset's render scale".
var render_scale_override: float = -1.0
var show_perf_hud: bool = true
var bus_volumes: Dictionary[StringName, float] = {}

## Overridable for tests.
var config_path: String = PATH


func _ready() -> void:
	ContentDB.ensure_loaded()
	load_settings()
	apply_all()
	get_tree().root.size_changed.connect(func() -> void: _apply_render_scale(get_tree().root))


func apply_all() -> void:
	apply_graphics()
	apply_audio()


# --- Graphics ------------------------------------------------------------------------------------


func get_preset() -> GraphicsPreset:
	var p := ContentDB.get_def(preset_id) as GraphicsPreset
	if p == null:
		p = ContentDB.get_def(FALLBACK_PRESET) as GraphicsPreset
	return p


func get_presets() -> Array[GraphicsPreset]:
	var out: Array[GraphicsPreset] = []
	for d in ContentDB.get_all(PRESET_TYPE):
		out.append(d as GraphicsPreset)
	out.sort_custom(func(a: GraphicsPreset, b: GraphicsPreset) -> bool: return a.sort_order < b.sort_order)
	return out


## Applies a preset; `persist = false` is for automation runs that must not touch user settings.
func set_preset(id: StringName, persist: bool = true) -> void:
	if not ContentDB.get_def(id) is GraphicsPreset:
		Log.warn("Settings", "unknown graphics preset '%s'" % id)
		return
	preset_id = id
	render_scale_override = -1.0
	apply_graphics()
	if persist:
		save_settings()


func set_render_scale(scale: float) -> void:
	render_scale_override = clampf(scale, 0.5, 1.0)
	_apply_render_scale(get_tree().root)
	save_settings()


## The user-facing scale (preset value or slider override), before resolution normalisation.
func base_render_scale() -> float:
	if render_scale_override > 0.0:
		return render_scale_override
	var p := get_preset()
	return p.render_scale if p else 1.0


## The scale actually handed to the viewport for the current window size.
func effective_render_scale() -> float:
	var size := get_tree().root.size
	return compute_render_scale(base_render_scale(), mini(size.x, size.y))


## Pure: base scale is relative to REFERENCE_LINES on the short side, capped at native.
static func compute_render_scale(base: float, short_side_px: int) -> float:
	if short_side_px <= 0:
		return clampf(base, MIN_EFFECTIVE_SCALE, 1.0)
	return clampf(base * REFERENCE_LINES / float(short_side_px), MIN_EFFECTIVE_SCALE, 1.0)


func set_perf_hud(visible: bool) -> void:
	show_perf_hud = visible
	EventBus.perf_hud_toggled.emit(visible)
	save_settings()


func apply_graphics() -> void:
	var p := get_preset()
	if p == null:
		Log.error("Settings", "no graphics presets found in ContentDB")
		return
	var vp := get_tree().root
	_apply_render_scale(vp)
	vp.msaa_3d = p.msaa
	vp.mesh_lod_threshold = p.mesh_lod_threshold
	Engine.max_fps = p.max_fps
	if p.sun_shadows:
		RenderingServer.directional_shadow_atlas_set_size(p.shadow_size, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(p.shadow_quality)
	EventBus.graphics_preset_applied.emit(p)
	Log.info("Settings", "graphics preset %s applied (scale %.2f)" % [p.id, effective_render_scale()])


func _apply_render_scale(vp: Viewport) -> void:
	var p := get_preset()
	var scale := effective_render_scale()
	vp.scaling_3d_scale = scale
	if scale >= 0.999 or (p != null and p.upscaler == GraphicsPreset.Upscaler.BILINEAR):
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	EventBus.render_scale_changed.emit(scale)


## First-launch preset choice from device facts. Pure function so it can be unit-tested.
## Ultra is never auto-selected. Thresholds are guesses until device numbers exist (PERF.md).
static func pick_default_preset(adapter_name: String, ram_mb: int, rendering_method: String) -> StringName:
	if rendering_method == "gl_compatibility":
		return &"gfx_low"
	var n := adapter_name.to_lower()
	var adreno := _adreno_model(n)
	if adreno > 0:
		if adreno >= 730:
			return &"gfx_high"
		if adreno >= 640:
			return &"gfx_medium"
		return &"gfx_low"
	if n.contains("immortalis") or n.contains("xclipse"):
		return &"gfx_high" if ram_mb >= 8000 else &"gfx_medium"
	if n.contains("mali"):
		return &"gfx_medium" if ram_mb >= 8000 else &"gfx_low"
	if n.contains("nvidia") or n.contains("radeon") or n.contains("geforce") or n.contains("apple"):
		return &"gfx_high"
	return &"gfx_medium" if ram_mb >= 6000 else &"gfx_low"


## "adreno (tm) 750" -> 750; 0 when not an Adreno GPU.
static func _adreno_model(lower_name: String) -> int:
	var i := lower_name.find("adreno")
	if i == -1:
		return 0
	var digits := ""
	for c in lower_name.substr(i + 6):
		if c >= "0" and c <= "9":
			digits += c
		elif not digits.is_empty():
			break
	return digits.to_int()


# --- Audio ---------------------------------------------------------------------------------------


func set_bus_volume(bus: StringName, linear: float) -> void:
	bus_volumes[bus] = clampf(linear, 0.0, 1.0)
	apply_audio()
	save_settings()


func apply_audio() -> void:
	for bus in AUDIO_BUSES:
		var idx := AudioServer.get_bus_index(bus)
		if idx == -1:
			continue
		var v: float = bus_volumes.get(bus, 1.0)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.0001)


# --- Persistence ---------------------------------------------------------------------------------


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var exists := cfg.load(config_path) == OK
	var mem := OS.get_memory_info()
	var detected := pick_default_preset(
		RenderingServer.get_video_adapter_name(),
		int(mem.get("physical", 0) / 1048576),
		RenderingServer.get_current_rendering_method()
	)
	preset_id = StringName(cfg.get_value("graphics", "preset", String(detected)))
	if not ContentDB.get_def(preset_id) is GraphicsPreset:
		preset_id = detected
	render_scale_override = float(cfg.get_value("graphics", "render_scale_override", -1.0))
	show_perf_hud = bool(cfg.get_value("debug", "show_perf_hud", OS.is_debug_build()))
	bus_volumes.clear()
	for bus in AUDIO_BUSES:
		bus_volumes[bus] = clampf(float(cfg.get_value("audio", String(bus), 1.0)), 0.0, 1.0)
	if not exists:
		Log.info(
			"Settings",
			"first launch: detected preset %s for '%s'" % [detected, RenderingServer.get_video_adapter_name()]
		)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "preset", String(preset_id))
	cfg.set_value("graphics", "render_scale_override", render_scale_override)
	cfg.set_value("debug", "show_perf_hud", show_perf_hud)
	for bus in bus_volumes:
		cfg.set_value("audio", String(bus), bus_volumes[bus])
	var err := cfg.save(config_path)
	if err != OK:
		Log.error("Settings", "failed to save %s (%s)" % [config_path, error_string(err)])
