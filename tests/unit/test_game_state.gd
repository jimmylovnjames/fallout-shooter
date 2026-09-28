extends GutTest


func before_each() -> void:
	GameState.reset()


func after_all() -> void:
	GameState.reset()


func test_set_and_get_flag() -> void:
	GameState.set_flag(&"met_trader", true)
	assert_true(GameState.has_flag(&"met_trader"))
	assert_eq(GameState.get_flag(&"met_trader"), true)
	assert_eq(GameState.get_flag(&"unknown", 5), 5)


func test_flag_changed_emitted_only_on_change() -> void:
	watch_signals(EventBus)
	GameState.set_flag(&"karma", 1)
	GameState.set_flag(&"karma", 1)
	GameState.set_flag(&"karma", 2)
	assert_signal_emit_count(EventBus, "flag_changed", 2)


func test_type_change_counts_as_change() -> void:
	watch_signals(EventBus)
	GameState.set_flag(&"x", 1)
	GameState.set_flag(&"x", "1")
	assert_signal_emit_count(EventBus, "flag_changed", 2)
	assert_eq(GameState.get_flag(&"x"), "1")


func test_rejects_objects() -> void:
	var n := Node.new()
	GameState.set_flag(&"bad", n)
	n.free()
	assert_false(GameState.has_flag(&"bad"))
	assert_push_error("rejected non-plain value")


func test_rejects_objects_nested_in_containers() -> void:
	var n := RefCounted.new()
	GameState.set_flag(&"bad", {"k": [1, n]})
	assert_false(GameState.has_flag(&"bad"))
	assert_push_error("rejected non-plain value")


func test_clear_flag() -> void:
	GameState.set_flag(&"a", true)
	GameState.clear_flag(&"a")
	assert_false(GameState.has_flag(&"a"))


func test_round_trip() -> void:
	GameState.set_flag(&"a", true)
	GameState.set_flag(&"b", {"nested": [1, 2, Vector3(1, 2, 3)]})
	GameState.play_time_s = 12.5
	var d := GameState.to_dict()
	GameState.reset()
	GameState.from_dict(d)
	assert_eq(GameState.get_flag(&"a"), true)
	assert_eq(GameState.get_flag(&"b"), {"nested": [1, 2, Vector3(1, 2, 3)]})
	assert_eq(GameState.play_time_s, 12.5)


func test_from_dict_sanitises_hostile_input() -> void:
	GameState.from_dict({"play_time_s": -50.0, "flags": {"ok": 1, 42: "int key dropped"}})
	assert_eq(GameState.play_time_s, 0.0)
	assert_eq(GameState.flag_count(), 1)
	GameState.from_dict({"flags": "not a dict"})
	assert_eq(GameState.flag_count(), 0)
