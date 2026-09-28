extends SceneTree
## Writes the fixture for the CURRENT save schema. Run ONCE when bumping the schema, then commit
## the .sav. Never regenerate an old fixture: they prove old saves still load.
##   godot --headless --path . -s tests/fixtures/saves/make_fixture.gd


func _initialize() -> void:
	var schema := SaveMigrator.CURRENT_SCHEMA
	var path := "res://tests/fixtures/saves/schema_%d.sav" % schema
	if FileAccess.file_exists(path):
		push_error("%s exists — fixtures are immutable" % path)
		quit(1)
		return
	var data := {
		"play_time_s": 3723.5,
		"flags":
		{"fixture_marker": "schema_%d" % schema, "met_trader": true, "karma": -3, "home_pos": Vector3(12, 0, -4)},
	}
	var status := SaveCodec.write(ProjectSettings.globalize_path(path), schema, data)
	print("fixture ", path, " -> ", SaveCodec.status_name(status))
	for leftover: String in [path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(leftover)
	quit(0 if status == SaveCodec.Status.OK else 1)
