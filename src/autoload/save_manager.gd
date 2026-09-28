extends Node
## Save slots, metadata and Android-lifecycle saves (DESIGN §6.12). Encoding lives in SaveCodec,
## upgrades in SaveMigrator, the data model in GameState.

const SLOT_SUSPEND := &"suspend"
const SLOT_QUICK := &"quick"
## Minimum seconds between two lifecycle saves (desktop focus-out can fire rapidly).
const LIFECYCLE_SAVE_COOLDOWN_S := 5.0

## Overridable for tests.
var save_dir: String = "user://saves"

var _last_lifecycle_save_ms: int = -1000000


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			save_for_lifecycle()


## Saves the suspend slot if a session is active. Synchronous on purpose: Android may kill the
## process right after onPause.
func save_for_lifecycle() -> bool:
	if not GameState.session_active:
		return false
	var now := Time.get_ticks_msec()
	if now - _last_lifecycle_save_ms < int(LIFECYCLE_SAVE_COOLDOWN_S * 1000.0):
		return false
	_last_lifecycle_save_ms = now
	return save_slot(SLOT_SUSPEND, "Suspend")


static func is_valid_slot(slot: StringName) -> bool:
	var s := String(slot)
	if s.is_empty() or s.length() > 32:
		return false
	for c in s:
		if not (c == "_" or (c >= "a" and c <= "z") or (c >= "0" and c <= "9")):
			return false
	return true


func slot_path(slot: StringName) -> String:
	return save_dir.path_join("%s.sav" % slot)


func meta_path(slot: StringName) -> String:
	return save_dir.path_join("%s.meta" % slot)


func has_slot(slot: StringName) -> bool:
	return (
		is_valid_slot(slot)
		and (FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak"))
	)


func save_slot(slot: StringName, label: String = "") -> bool:
	if not is_valid_slot(slot):
		Log.error("SaveManager", "invalid slot name '%s'" % slot)
		return false
	DirAccess.make_dir_recursive_absolute(save_dir)
	var status := SaveCodec.write(slot_path(slot), SaveMigrator.CURRENT_SCHEMA, GameState.to_dict())
	var ok := status == SaveCodec.Status.OK
	if ok:
		_write_meta(slot, label)
	Log.info("SaveManager", "save '%s': %s" % [slot, SaveCodec.status_name(status)])
	EventBus.game_saved.emit(slot, ok)
	return ok


func load_slot(slot: StringName) -> bool:
	if not is_valid_slot(slot):
		Log.error("SaveManager", "invalid slot name '%s'" % slot)
		return false
	var r := SaveCodec.read_with_fallback(slot_path(slot))
	if not r.ok():
		Log.warn("SaveManager", "load '%s' failed: %s" % [slot, SaveCodec.status_name(r.status)])
		return false
	var data := SaveMigrator.migrate(r.data, r.schema)
	if data.is_empty() and not r.data.is_empty():
		return false
	GameState.from_dict(data)
	EventBus.game_loaded.emit(slot)
	return true


func delete_slot(slot: StringName) -> void:
	if not is_valid_slot(slot):
		return
	for p: String in [slot_path(slot), slot_path(slot) + ".bak", slot_path(slot) + ".tmp", meta_path(slot)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Metadata for every slot, newest first. Never decompresses save payloads.
func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in DirAccess.get_files_at(save_dir):
		if f.get_extension() != "meta":
			continue
		var cfg := ConfigFile.new()
		if cfg.load(save_dir.path_join(f)) != OK:
			continue
		var m := {"slot": f.get_basename()}
		for key in cfg.get_section_keys("meta"):
			m[key] = cfg.get_value("meta", key)
		out.append(m)
	out.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("saved_unix", 0)) > int(b.get("saved_unix", 0))
	)
	return out


func _write_meta(slot: StringName, label: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "label", label if not label.is_empty() else String(slot))
	cfg.set_value("meta", "schema", SaveMigrator.CURRENT_SCHEMA)
	cfg.set_value("meta", "saved_unix", int(Time.get_unix_time_from_system()))
	cfg.set_value("meta", "play_time_s", GameState.play_time_s)
	cfg.set_value("meta", "game_version", ProjectSettings.get_setting("application/config/version", ""))
	cfg.save(meta_path(slot))
