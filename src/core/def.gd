class_name Def
extends Resource
## Base class for every data-driven content definition (items, perks, presets, quests...).
## Subclasses add typed @export fields and extend validate(). See docs/DESIGN.md §5.

## Globally unique, type-prefixed id, e.g. &"wpn_pipe_pistol". Never change a shipped id: saves
## reference it.
@export var id: StringName


## Class name of the concrete definition type, e.g. &"GraphicsPreset".
func get_def_type() -> StringName:
	var s: Script = get_script()
	if s == null:
		return &"Def"
	var n := s.get_global_name()
	return n if not n.is_empty() else &"Def"


## Returns human-readable problems; empty means valid. Subclasses call super() and append.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("missing id")
	elif not String(id).is_valid_identifier() or String(id) != String(id).to_lower():
		errors.append("id '%s' must be a lower_snake_case identifier" % id)
	return errors
