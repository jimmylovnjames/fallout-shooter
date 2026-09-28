extends GutTest

const CFG := "user://test_settings.cfg"

var _orig_path: String
var _orig_preset: StringName
var _orig_override: float


func before_all() -> void:
	_orig_path = Settings.config_path
	_orig_preset = Settings.preset_id
	_orig_override = Settings.render_scale_override


func before_each() -> void:
	Settings.config_path = CFG
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(CFG)


func after_all() -> void:
	Settings.config_path = _orig_path
	Settings.preset_id = _orig_preset
	Settings.render_scale_override = _orig_override
	Settings.apply_graphics()


func test_default_preset_heuristic() -> void:
	var cases := [
		["Adreno (TM) 750", 12000, "mobile", &"gfx_high"],  # OnePlus 12 reference device
		["Adreno (TM) 740", 8000, "mobile", &"gfx_high"],
		["Adreno (TM) 660", 8000, "mobile", &"gfx_medium"],
		["Adreno (TM) 618", 6000, "mobile", &"gfx_low"],
		["Mali-G57 MC2", 4000, "mobile", &"gfx_low"],
		["Mali-G710", 8192, "mobile", &"gfx_medium"],
		["Samsung Xclipse 940", 8192, "mobile", &"gfx_high"],
		["Adreno (TM) 750", 12000, "gl_compatibility", &"gfx_low"],
		["NVIDIA GeForce RTX 4070", 32000, "mobile", &"gfx_high"],
		["llvmpipe (LLVM 20.1.2, 256 bits)", 16000, "mobile", &"gfx_medium"],
	]
	for c: Array in cases:
		assert_eq(Settings.pick_default_preset(c[0], c[1], c[2]), c[3], "%s / %s" % [c[0], c[2]])


func test_adreno_model_parse() -> void:
	assert_eq(Settings._adreno_model("adreno (tm) 750"), 750)
	assert_eq(Settings._adreno_model("mali-g78"), 0)


func test_render_scale_normalised_to_1080_lines() -> void:
	assert_almost_eq(Settings.compute_render_scale(0.9, 1440), 0.675, 0.001, "1440p phone on High")
	assert_almost_eq(Settings.compute_render_scale(0.9, 1080), 0.9, 0.001)
	assert_almost_eq(Settings.compute_render_scale(0.9, 720), 1.0, 0.001, "never above native")
	assert_almost_eq(Settings.compute_render_scale(0.5, 4320), 0.25, 0.001, "floored")
	assert_almost_eq(Settings.compute_render_scale(0.8, 0), 0.8, 0.001, "unknown size -> raw")


func test_presets_are_ordered_low_to_ultra() -> void:
	var ids := Settings.get_presets().map(func(p: GraphicsPreset) -> StringName: return p.id)
	assert_eq(ids, [&"gfx_low", &"gfx_medium", &"gfx_high", &"gfx_ultra"])


func test_presets_scale_monotonically() -> void:
	var prev: GraphicsPreset = null
	for p in Settings.get_presets():
		if prev != null:
			assert_true(p.render_scale >= prev.render_scale, "%s render_scale" % p.id)
			assert_true(p.max_fps >= prev.max_fps, "%s max_fps" % p.id)
			assert_true(p.mesh_lod_threshold <= prev.mesh_lod_threshold, "%s lod" % p.id)
		prev = p


func test_low_preset_meets_30fps_floor_and_high_targets_60() -> void:
	assert_eq((ContentDB.get_def(&"gfx_low") as GraphicsPreset).max_fps, 30)
	assert_eq((ContentDB.get_def(&"gfx_high") as GraphicsPreset).max_fps, 60)


func test_set_preset_applies_and_persists() -> void:
	watch_signals(EventBus)
	Settings.set_preset(&"gfx_ultra")
	assert_eq(Settings.get_preset().id, &"gfx_ultra")
	assert_eq(Engine.max_fps, 60)
	assert_eq(get_tree().root.msaa_3d, Viewport.MSAA_4X)
	assert_signal_emitted(EventBus, "graphics_preset_applied")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(CFG), OK)
	assert_eq(cfg.get_value("graphics", "preset"), "gfx_ultra")


func test_set_preset_without_persist_writes_nothing() -> void:
	Settings.set_preset(&"gfx_low", false)
	assert_eq(Settings.get_preset().id, &"gfx_low")
	assert_false(FileAccess.file_exists(CFG))


func test_unknown_preset_ignored() -> void:
	Settings.set_preset(&"gfx_high", false)
	Settings.set_preset(&"gfx_nope", false)
	assert_eq(Settings.get_preset().id, &"gfx_high")
	assert_push_warning("unknown graphics preset")


func test_render_scale_override_round_trip() -> void:
	Settings.set_preset(&"gfx_medium", false)
	Settings.set_render_scale(0.55)
	assert_almost_eq(Settings.base_render_scale(), 0.55, 0.001)
	Settings.render_scale_override = -1.0
	Settings.load_settings()
	assert_almost_eq(Settings.base_render_scale(), 0.55, 0.001)
	Settings.set_preset(&"gfx_medium", false)
	assert_almost_eq(Settings.base_render_scale(), 0.75, 0.001, "preset change clears override")


func test_bus_volume_applied() -> void:
	Settings.set_bus_volume(&"Music", 0.0)
	var idx := AudioServer.get_bus_index(&"Music")
	assert_true(AudioServer.is_bus_mute(idx))
	Settings.set_bus_volume(&"Music", 1.0)
	assert_false(AudioServer.is_bus_mute(idx))
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), 0.0, 0.01)
