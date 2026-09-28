extends GutTest
## Every historical save fixture must keep loading through codec → migrator → GameState, forever.

const DIR := "res://tests/fixtures/saves"


func after_all() -> void:
	GameState.reset()


func test_every_fixture_loads_into_current_schema() -> void:
	var fixtures := Array(DirAccess.get_files_at(DIR)).filter(func(f: String) -> bool: return f.ends_with(".sav"))
	assert_gt(fixtures.size(), 0, "at least one fixture")
	assert_true(
		fixtures.has("schema_%d.sav" % SaveMigrator.CURRENT_SCHEMA),
		"current schema has a fixture (run tests/fixtures/saves/make_fixture.gd after a bump)"
	)
	for f: String in fixtures:
		var r := SaveCodec.read(ProjectSettings.globalize_path(DIR.path_join(f)))
		assert_true(r.ok(), "%s: %s" % [f, SaveCodec.status_name(r.status)])
		var data := SaveMigrator.migrate(r.data, r.schema)
		assert_false(data.is_empty(), "%s migrates" % f)
		GameState.reset()
		GameState.from_dict(data)
		assert_eq(GameState.get_flag(&"fixture_marker"), "schema_%d" % r.schema, f)
		assert_eq(GameState.get_flag(&"met_trader"), true, f)
		assert_almost_eq(GameState.play_time_s, 3723.5, 0.001, f)
