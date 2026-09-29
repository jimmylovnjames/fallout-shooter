class_name WeaponState
extends RefCounted
## Runtime state of one carried weapon: magazine, fire cooldown, reload timer. Time is passed in
## explicitly so the logic is deterministic and unit-testable. Reserve ammo arrives with P2's
## inventory; until then reloads are free.

signal fired
signal reload_started(duration: float)
signal reloaded
signal ammo_changed(in_mag: int, mag_size: int)

## Max lateness (s) of a shot that still counts as "trigger held" for cadence carry-over.
const CADENCE_CARRY_S := 0.05

var def: WeaponDef
var in_mag: int
var reloading := false

var _next_shot_at := 0.0
var _reload_done_at := 0.0


func _init(weapon: WeaponDef) -> void:
	def = weapon
	in_mag = weapon.mag_size


func can_fire(now: float) -> bool:
	return not reloading and in_mag > 0 and now >= _next_shot_at


## Consumes one round if possible. Auto-starts a reload on an empty trigger pull.
func try_fire(now: float) -> bool:
	update(now)
	if reloading:
		return false
	if in_mag <= 0:
		start_reload(now)
		return false
	if now < _next_shot_at:
		return false
	in_mag -= 1
	# While the trigger is held, keep exact cadence (carry the sub-frame remainder) so the fire
	# rate doesn't depend on frame rate; after a pause, restart the cadence from now.
	if now - _next_shot_at <= CADENCE_CARRY_S:
		_next_shot_at += def.fire_interval()
	else:
		_next_shot_at = now + def.fire_interval()
	fired.emit()
	ammo_changed.emit(in_mag, def.mag_size)
	return true


func start_reload(now: float) -> bool:
	if reloading or in_mag >= def.mag_size:
		return false
	reloading = true
	_reload_done_at = now + def.reload_s
	reload_started.emit(def.reload_s)
	return true


## Progress 0..1 of the current reload (0 when not reloading).
func reload_progress(now: float) -> float:
	if not reloading or def.reload_s <= 0.0:
		return 0.0
	return clampf(1.0 - (_reload_done_at - now) / def.reload_s, 0.0, 1.0)


func update(now: float) -> void:
	if reloading and now >= _reload_done_at:
		reloading = false
		in_mag = def.mag_size
		reloaded.emit()
		ammo_changed.emit(in_mag, def.mag_size)


## Cancels a reload in progress (weapon swap).
func cancel_reload() -> void:
	reloading = false
