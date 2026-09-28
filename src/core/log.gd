class_name Log
extends RefCounted
## Tiny levelled logger. Output goes to stdout (logcat on Android).
## WARN/ERROR also go through push_warning/push_error so they surface in the debugger and fail GUT
## tests unless a test explicitly asserts them.

enum Level { DEBUG, INFO, WARN, ERROR }

const _LEVEL_NAMES: PackedStringArray = ["DEBUG", "INFO", "WARN", "ERROR"]

static var min_level: Level = Level.DEBUG if OS.is_debug_build() else Level.INFO


static func debug(tag: String, msg: String) -> void:
	_emit(Level.DEBUG, tag, msg)


static func info(tag: String, msg: String) -> void:
	_emit(Level.INFO, tag, msg)


static func warn(tag: String, msg: String) -> void:
	_emit(Level.WARN, tag, msg)


static func error(tag: String, msg: String) -> void:
	_emit(Level.ERROR, tag, msg)


static func _emit(level: Level, tag: String, msg: String) -> void:
	if level < min_level:
		return
	var line := "[%s][%s] %s" % [_LEVEL_NAMES[level], tag, msg]
	match level:
		Level.ERROR:
			push_error(line)
		Level.WARN:
			push_warning(line)
		_:
			print(line)
