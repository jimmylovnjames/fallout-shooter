class_name SaveMigrator
extends RefCounted
## Upgrades raw save dictionaries from any past schema to CURRENT_SCHEMA, one step at a time.
## Rules: never delete a step; every bump adds a permanent fixture in tests/fixtures/saves/.

const CURRENT_SCHEMA := 1


## Steps keyed by the schema they upgrade FROM. Each takes and returns the raw Dictionary.
static func default_steps() -> Dictionary[int, Callable]:
	return {
	# 1: _v1_to_v2,   <- add here when schema 2 exists
	}


## Returns the migrated data, or an empty Dictionary if the save is from the future or a step
## is missing (caller treats that as a failed load).
static func migrate(
	data: Dictionary,
	from_schema: int,
	to_schema: int = CURRENT_SCHEMA,
	steps: Dictionary[int, Callable] = default_steps()
) -> Dictionary:
	if from_schema > to_schema:
		Log.warn("SaveMigrator", "save schema %d is newer than supported %d" % [from_schema, to_schema])
		return {}
	var out := data.duplicate(true)
	var v := from_schema
	while v < to_schema:
		if not steps.has(v):
			Log.warn("SaveMigrator", "no migration step from schema %d" % v)
			return {}
		out = steps[v].call(out)
		v += 1
	return out
