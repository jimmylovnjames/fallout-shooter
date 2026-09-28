extends GutTest


func test_current_schema_is_identity() -> void:
	var d := {"a": 1}
	assert_eq(SaveMigrator.migrate(d, SaveMigrator.CURRENT_SCHEMA), d)


func test_future_schema_rejected() -> void:
	assert_eq(SaveMigrator.migrate({"a": 1}, SaveMigrator.CURRENT_SCHEMA + 1), {})
	assert_push_warning("newer than supported")


func test_steps_chain_in_order() -> void:
	var steps: Dictionary[int, Callable] = {
		1:
		func(d: Dictionary) -> Dictionary:
			d["hp"] = d["health"]
			d.erase("health")
			return d,
		2:
		func(d: Dictionary) -> Dictionary:
			d["hp_max"] = 100
			return d,
	}
	var out := SaveMigrator.migrate({"health": 42}, 1, 3, steps)
	assert_eq(out, {"hp": 42, "hp_max": 100})


func test_missing_step_fails_closed() -> void:
	var steps: Dictionary[int, Callable] = {1: func(d: Dictionary) -> Dictionary: return d}
	assert_eq(SaveMigrator.migrate({"x": 1}, 1, 3, steps), {})
	assert_push_warning("no migration step from schema 2")


func test_input_not_mutated() -> void:
	var steps: Dictionary[int, Callable] = {
		1:
		func(d: Dictionary) -> Dictionary:
			d["added"] = true
			return d,
	}
	var src := {"nested": {"k": 1}}
	SaveMigrator.migrate(src, 1, 2, steps)
	assert_eq(src, {"nested": {"k": 1}})
