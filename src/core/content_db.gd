class_name ContentDB
extends RefCounted
## Static registry of every Def under res://data, indexed by id and by type (DESIGN §5.2).
## Not an autoload on purpose (DECISIONS D005). Walks with ResourceLoader.list_directory so it
## works in exported builds where files are remapped.

const DEFAULT_ROOT := "res://data"

static var _defs: Dictionary[StringName, Def] = {}
static var _by_type: Dictionary[StringName, Array] = {}
static var _sources: Dictionary[StringName, String] = {}
static var _load_errors: PackedStringArray = []
static var _loaded_root: String = ""


## Loads the registry once; cheap to call from anywhere.
static func ensure_loaded(root: String = DEFAULT_ROOT) -> void:
	if _loaded_root != root:
		load_all(root)


static func load_all(root: String = DEFAULT_ROOT) -> void:
	clear()
	_loaded_root = root
	_scan(root)
	Log.info("ContentDB", "loaded %d defs from %s" % [_defs.size(), root])


static func clear() -> void:
	_defs.clear()
	_by_type.clear()
	_sources.clear()
	_load_errors.clear()
	_loaded_root = ""


## Registers a definition. Duplicate or empty ids are recorded as load errors (reported by
## validate_all) rather than silently overwriting.
static func register(def: Def, source: String = "") -> void:
	if def.id.is_empty():
		_load_errors.append("%s: definition without id" % source)
		return
	if _defs.has(def.id):
		_load_errors.append("%s: duplicate id '%s' (already defined in %s)" % [source, def.id, _sources[def.id]])
		return
	_defs[def.id] = def
	_sources[def.id] = source
	var t := def.get_def_type()
	if not _by_type.has(t):
		_by_type[t] = []
	_by_type[t].append(def)


static func has_def(id: StringName) -> bool:
	return _defs.has(id)


static func get_def(id: StringName) -> Def:
	return _defs.get(id)


## All definitions of a type, sorted by id for determinism.
static func get_all(type: StringName) -> Array[Def]:
	var out: Array[Def] = []
	if _by_type.has(type):
		out.assign(_by_type[type])
	out.sort_custom(func(a: Def, b: Def) -> bool: return String(a.id) < String(b.id))
	return out


static func count() -> int:
	return _defs.size()


## Every problem found while loading plus every Def.validate() error. CI fails on any entry.
static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray(_load_errors)
	var ids := _defs.keys()
	ids.sort()
	for id: StringName in ids:
		for e in _defs[id].validate():
			errors.append("%s (%s): %s" % [id, _sources[id], e])
	return errors


static func _scan(dir: String) -> void:
	var entries := ResourceLoader.list_directory(dir)
	var sorted := Array(entries)
	sorted.sort()
	for entry: String in sorted:
		var path := dir.path_join(entry)
		if entry.ends_with("/"):
			_scan(path.trim_suffix("/"))
		elif entry.get_extension() in ["tres", "res"]:
			var res := ResourceLoader.load(path)
			if res is Def:
				register(res as Def, path)
