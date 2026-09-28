extends GutTest
## Content gate: every definition under res://data must load and validate. CI fails otherwise.


func after_all() -> void:
	ContentDB.load_all()


func test_all_shipped_content_validates() -> void:
	ContentDB.load_all()
	assert_gt(ContentDB.count(), 0, "content loaded")
	var errors := ContentDB.validate_all()
	assert_eq(errors.size(), 0, "\n".join(errors))


func test_duplicate_ids_are_reported() -> void:
	ContentDB.clear()
	var a := GraphicsPreset.new()
	a.id = &"gfx_dup"
	a.name_key = "X"
	var b := GraphicsPreset.new()
	b.id = &"gfx_dup"
	b.name_key = "Y"
	ContentDB.register(a, "a.tres")
	ContentDB.register(b, "b.tres")
	assert_eq(ContentDB.get_def(&"gfx_dup"), a, "first definition wins")
	var errors := ContentDB.validate_all()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "duplicate id 'gfx_dup'")


func test_missing_id_reported() -> void:
	ContentDB.clear()
	ContentDB.register(GraphicsPreset.new(), "anon.tres")
	assert_string_contains(ContentDB.validate_all()[0], "without id")


func test_def_id_rules() -> void:
	var d := Def.new()
	d.id = &"Bad-Id"
	assert_eq(d.validate().size(), 1)
	d.id = &"good_id_1"
	assert_eq(d.validate().size(), 0)


func test_get_all_sorted_and_typed() -> void:
	ContentDB.load_all()
	var all := ContentDB.get_all(&"GraphicsPreset")
	assert_eq(all.size(), 4)
	var ids := all.map(func(d: Def) -> String: return String(d.id))
	var sorted := ids.duplicate()
	sorted.sort()
	assert_eq(ids, sorted)
	assert_eq(ContentDB.get_all(&"NoSuchType").size(), 0)


func test_preset_validation_catches_bad_values() -> void:
	var p := GraphicsPreset.new()
	p.id = &"gfx_bad"
	p.name_key = "K"
	p.max_fps = 20
	p.shadow_size = 3000
	var errors := p.validate()
	assert_eq(errors.size(), 2, "\n".join(errors))
