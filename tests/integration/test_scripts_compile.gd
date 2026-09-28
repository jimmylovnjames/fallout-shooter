extends GutTest
## Loads every GDScript under res://src so parse/type errors fail CI even for scripts no other
## test touches. (Headless import does not compile scripts.)


func _collect(dir: String, out: PackedStringArray) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), out)
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "gd":
			out.append(dir.path_join(f))


func test_all_src_scripts_compile() -> void:
	var paths := PackedStringArray()
	_collect("res://src", paths)
	assert_gt(paths.size(), 10)
	for path in paths:
		var s := load(path) as GDScript
		assert_not_null(s, path)
		if s != null:
			assert_true(s.can_instantiate() or s.get_global_name() != &"", "%s compiles" % path)


func test_all_scenes_load() -> void:
	var paths := PackedStringArray()
	for dir: String in ["res://src"]:
		_collect_ext(dir, "tscn", paths)
	for path in paths:
		assert_not_null(load(path) as PackedScene, path)


func _collect_ext(dir: String, ext: String, out: PackedStringArray) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_collect_ext(dir.path_join(sub), ext, out)
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == ext:
			out.append(dir.path_join(f))
