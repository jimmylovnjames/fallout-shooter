class_name HealthPool
extends RefCounted
## Hit points with death-once semantics and optional invulnerability window. Pure domain logic;
## HealthComponent is the Node adapter. P3 adds per-limb pools and resistances.

signal changed(current: float, maximum: float)
signal damaged(applied: float, info: DamageInfo)
signal died(info: DamageInfo)

var maximum: float
var current: float
var invulnerable_until: float = -1.0


func _init(max_hp: float = 100.0) -> void:
	maximum = maxf(max_hp, 1.0)
	current = maximum


func is_dead() -> bool:
	return current <= 0.0


func fraction() -> float:
	return current / maximum


## Applies damage at time `now` (seconds). Returns the amount actually removed.
func apply(info: DamageInfo, now: float) -> float:
	if is_dead() or info.amount <= 0.0 or now < invulnerable_until:
		return 0.0
	var applied := minf(info.amount, current)
	current -= applied
	damaged.emit(applied, info)
	changed.emit(current, maximum)
	if is_dead():
		died.emit(info)
	return applied


func heal(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var healed := minf(amount, maximum - current)
	current += healed
	if healed > 0.0:
		changed.emit(current, maximum)
	return healed


## Full restore (respawn). Optional invulnerability for `grace_s` seconds from `now`.
func revive(now: float, grace_s: float = 0.0) -> void:
	current = maximum
	invulnerable_until = now + grace_s
	changed.emit(current, maximum)
