extends Node
## Authoritative persistent data model (DESIGN §4.2). Plain data only — never Node references —
## so to_dict()/from_dict() stay trivial and saves stay safe. Systems read/write through this API
## and are notified via EventBus.
##
## P0 scope: world flags + play time. Player profile, quests, factions and world deltas arrive in
## P2/P5 as typed sub-models with their own to_dict/from_dict.

## Variant types allowed in persistent state (containers are checked recursively).
const _PLAIN_TYPES: Array[int] = [
	TYPE_NIL,
	TYPE_BOOL,
	TYPE_INT,
	TYPE_FLOAT,
	TYPE_STRING,
	TYPE_STRING_NAME,
	TYPE_VECTOR2,
	TYPE_VECTOR2I,
	TYPE_VECTOR3,
	TYPE_VECTOR3I,
	TYPE_COLOR,
	TYPE_PACKED_INT32_ARRAY,
	TYPE_PACKED_FLOAT32_ARRAY,
	TYPE_PACKED_STRING_ARRAY,
]

## True while a game session is running (not in menus/bench). Gates play-time and lifecycle saves.
var session_active: bool = false
var play_time_s: float = 0.0

var _flags: Dictionary[StringName, Variant] = {}


func _process(delta: float) -> void:
	if session_active:
		play_time_s += delta


func reset() -> void:
	_flags.clear()
	play_time_s = 0.0
	EventBus.game_state_reset.emit()


# --- Flags ---------------------------------------------------------------------------------------


func has_flag(flag: StringName) -> bool:
	return _flags.has(flag)


func get_flag(flag: StringName, default: Variant = null) -> Variant:
	return _flags.get(flag, default)


## Sets a world-state flag. Only plain-data values are allowed (they end up in save files).
## Emits EventBus.flag_changed only when the value actually changes.
func set_flag(flag: StringName, value: Variant) -> void:
	if not _is_plain(value):
		Log.error("GameState", "flag '%s' rejected non-plain value of type %s" % [flag, type_string(typeof(value))])
		return
	if _flags.has(flag) and typeof(_flags[flag]) == typeof(value) and _flags[flag] == value:
		return
	_flags[flag] = value
	EventBus.flag_changed.emit(flag, value)


func clear_flag(flag: StringName) -> void:
	if _flags.erase(flag):
		EventBus.flag_changed.emit(flag, null)


func flag_count() -> int:
	return _flags.size()


# --- Serialization -------------------------------------------------------------------------------


func to_dict() -> Dictionary:
	var flags := {}
	for k: StringName in _flags:
		flags[String(k)] = _flags[k]
	return {
		"play_time_s": play_time_s,
		"flags": flags,
	}


## Loads from an already-migrated dictionary. Defensive: saves are untrusted input.
func from_dict(d: Dictionary) -> void:
	_flags.clear()
	play_time_s = maxf(0.0, float(d.get("play_time_s", 0.0)))
	var flags: Variant = d.get("flags", {})
	if typeof(flags) == TYPE_DICTIONARY:
		for k: Variant in flags:
			var v: Variant = (flags as Dictionary)[k]
			if (typeof(k) == TYPE_STRING or typeof(k) == TYPE_STRING_NAME) and _is_plain(v):
				_flags[StringName(k)] = v


static func _is_plain(v: Variant) -> bool:
	var t := typeof(v)
	if t in _PLAIN_TYPES:
		return true
	if t == TYPE_ARRAY:
		for e: Variant in v:
			if not _is_plain(e):
				return false
		return true
	if t == TYPE_DICTIONARY:
		for k: Variant in v:
			if not _is_plain(k) or not _is_plain((v as Dictionary)[k]):
				return false
		return true
	return false
