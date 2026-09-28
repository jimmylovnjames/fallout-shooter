extends GutTest
## Guards the project settings that DECISIONS.md depends on. If one of these fails, somebody
## changed an architectural setting — update DECISIONS.md in the same commit.


func _setting(name: String) -> Variant:
	return ProjectSettings.get_setting(name)


func test_mobile_renderer_with_gl_fallback() -> void:
	assert_eq(_setting("rendering/renderer/rendering_method"), "mobile")
	assert_eq(_setting("rendering/renderer/rendering_method.mobile"), "mobile")
	assert_true(_setting("rendering/rendering_device/fallback_to_opengl3"))


func test_mobile_texture_compression_enabled() -> void:
	assert_true(_setting("rendering/textures/vram_compression/import_etc2_astc"))


func test_jolt_physics() -> void:
	assert_eq(_setting("physics/3d/physics_engine"), "Jolt Physics")


func test_typed_gdscript_enforced() -> void:
	assert_eq(_setting("debug/gdscript/warnings/untyped_declaration"), 2, "untyped declarations are errors")


func test_scaling_for_phones() -> void:
	assert_eq(_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(_setting("display/window/stretch/aspect"), "expand")
	assert_eq(_setting("display/window/handheld/orientation"), 4, "sensor landscape")


func test_exactly_four_autoloads() -> void:
	var autoloads: PackedStringArray = []
	for p in ProjectSettings.get_property_list():
		var n: String = p["name"]
		if n.begins_with("autoload/"):
			autoloads.append(n.trim_prefix("autoload/"))
	autoloads.sort()
	assert_eq(Array(autoloads), ["EventBus", "GameState", "SaveManager", "Settings"], "DECISIONS D005")


func test_audio_bus_layout() -> void:
	for bus: StringName in Settings.AUDIO_BUSES:
		assert_ne(AudioServer.get_bus_index(bus), -1, "bus %s" % bus)


func test_translations_loaded() -> void:
	assert_eq(tr("UI_PRESET_HIGH"), "High")


func test_main_scene_exists() -> void:
	assert_true(ResourceLoader.exists(_setting("application/run/main_scene")))
