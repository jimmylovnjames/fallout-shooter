extends GutTest

const DIR := "user://test_save_manager"

var _orig_dir: String


func before_all() -> void:
	_orig_dir = SaveManager.save_dir


func before_each() -> void:
	SaveManager.save_dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))
	GameState.reset()
	GameState.session_active = false
	SaveManager._last_lifecycle_save_ms = -1000000


func after_all() -> void:
	SaveManager.save_dir = _orig_dir
	GameState.reset()
	GameState.session_active = false


func test_slot_name_validation() -> void:
	for good: String in ["quick", "slot_01", "suspend"]:
		assert_true(SaveManager.is_valid_slot(StringName(good)), good)
	for bad: String in ["", "../evil", "Slot", "a b", "x/y", "a".repeat(33)]:
		assert_false(SaveManager.is_valid_slot(StringName(bad)), bad)


func test_invalid_slot_refused() -> void:
	assert_false(SaveManager.save_slot(&"../escape"))
	assert_push_error("invalid slot name")


func test_save_and_load_round_trip() -> void:
	GameState.set_flag(&"door_open", true)
	watch_signals(EventBus)
	assert_true(SaveManager.save_slot(&"slot_01", "Before the bridge"))
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [&"slot_01", true])
	GameState.reset()
	assert_true(SaveManager.load_slot(&"slot_01"))
	assert_eq(GameState.get_flag(&"door_open"), true)
	assert_signal_emitted(EventBus, "game_loaded")


func test_load_missing_slot_fails_cleanly() -> void:
	assert_false(SaveManager.load_slot(&"nothing_here"))
	assert_push_warning("load 'nothing_here' failed")


func test_list_slots_reads_metadata_newest_first() -> void:
	SaveManager.save_slot(&"slot_a", "A")
	SaveManager.save_slot(&"slot_b", "B")
	var slots := SaveManager.list_slots()
	assert_eq(slots.size(), 2)
	var labels := slots.map(func(m: Dictionary) -> String: return m["label"])
	assert_has(labels, "A")
	assert_has(labels, "B")
	assert_eq(int(slots[0]["schema"]), SaveMigrator.CURRENT_SCHEMA)


func test_delete_slot() -> void:
	SaveManager.save_slot(&"slot_a")
	SaveManager.save_slot(&"slot_a")  # creates .bak
	SaveManager.delete_slot(&"slot_a")
	assert_false(SaveManager.has_slot(&"slot_a"))
	assert_eq(DirAccess.get_files_at(DIR).size(), 0)


func test_lifecycle_save_only_during_session() -> void:
	assert_false(SaveManager.save_for_lifecycle(), "no session -> no save")
	GameState.session_active = true
	assert_true(SaveManager.save_for_lifecycle())
	assert_true(SaveManager.has_slot(SaveManager.SLOT_SUSPEND))
	assert_false(SaveManager.save_for_lifecycle(), "cooldown suppresses rapid repeats")


func test_pause_notification_triggers_suspend_save() -> void:
	SaveManager._last_lifecycle_save_ms = -1000000
	GameState.session_active = true
	GameState.set_flag(&"from_pause", 1)
	SaveManager.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	GameState.reset()
	assert_true(SaveManager.load_slot(SaveManager.SLOT_SUSPEND))
	assert_eq(GameState.get_flag(&"from_pause"), 1)
