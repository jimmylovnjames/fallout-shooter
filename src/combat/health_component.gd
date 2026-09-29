class_name HealthComponent
extends Node
## Node adapter around HealthPool. Lives as a child named "Health" so hits can find it
## (Hitscan.health_of). Time comes from the owning actor's clock (respects time scale).

signal changed(current: float, maximum: float)
signal damaged(applied: float, info: DamageInfo)
signal died(info: DamageInfo)

var pool := HealthPool.new()
## Returns the owner's game-time seconds; set by the actor. Defaults to engine ticks.
var clock := func() -> float: return Time.get_ticks_msec() / 1000.0


func setup(max_hp: float) -> void:
	pool = HealthPool.new(max_hp)
	pool.changed.connect(func(c: float, m: float) -> void: changed.emit(c, m))
	pool.damaged.connect(func(a: float, i: DamageInfo) -> void: damaged.emit(a, i))
	pool.died.connect(func(i: DamageInfo) -> void: died.emit(i))


func apply_damage(info: DamageInfo) -> float:
	return pool.apply(info, clock.call())


func is_dead() -> bool:
	return pool.is_dead()


func revive(grace_s: float = 0.0) -> void:
	pool.revive(clock.call(), grace_s)
