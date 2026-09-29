class_name EnemySpawner
extends Node3D
## Keeps `max_alive` enemies of one archetype in play using a fixed pool: dead enemies dissolve,
## deactivate, and respawn after a delay at the spawn point farthest from the player.

const ENEMY_SCENE := preload("res://src/actors/enemy/enemy.tscn")

@export var archetype_id: StringName = &"enm_scavenger"
@export var max_alive: int = 10
@export var respawn_delay_s: float = 4.0
@export var min_spawn_distance_m: float = 18.0
## Spawned enemies roam toward the player (arena pressure) instead of idling at their spawn.
@export var hunt: bool = true

## All pooled enemies (alive or not) as Actors, for aim assist; filter by `alive`.
var hostiles: Array[Actor] = []
var points: Array[Vector3] = []

var _enemies: Array[Enemy] = []
var _respawn_at: Dictionary[Enemy, float] = {}
var _time := 0.0
var _target: Actor
var _rng := RandomNumberGenerator.new()


func setup(combat: CombatServices, target: Actor, spawn_points: Array[Vector3], seed_value: int) -> void:
	_target = target
	points = spawn_points
	_rng.seed = seed_value
	var arch := ContentDB.get_def(archetype_id) as EnemyArchetypeDef
	if arch == null:
		Log.error("EnemySpawner", "unknown archetype '%s'" % archetype_id)
		return
	for i in max_alive:
		var e := ENEMY_SCENE.instantiate() as Enemy
		e.name = "Enemy%02d" % i
		add_child(e)
		e.setup_enemy(arch, combat, target, seed_value + i * 7919)
		e.brain.hunting = hunt
		e.died.connect(_on_died)
		e.visual.dissolved.connect(func() -> void: e.set_active(false))
		_enemies.append(e)
		hostiles.append(e)
		e.spawn_at(points[i % points.size()] if not points.is_empty() else global_position)


func alive_count() -> int:
	var n := 0
	for e in _enemies:
		if e.alive:
			n += 1
	return n


func enemies() -> Array[Enemy]:
	return _enemies


func _process(delta: float) -> void:
	_time += delta
	if _respawn_at.is_empty():
		return
	for e: Enemy in _respawn_at.keys():
		if _time >= _respawn_at[e]:
			_respawn_at.erase(e)
			e.spawn_at(pick_spawn_point())


## A random spawn point at least min_spawn_distance_m from the player; the farthest point if
## none qualifies. Never spawns enemies on top of the player.
func pick_spawn_point() -> Vector3:
	if points.is_empty():
		return global_position
	var ref := _target.global_position if _target != null else global_position
	var ok: Array[Vector3] = []
	var farthest := points[0]
	for p in points:
		if p.distance_to(ref) >= min_spawn_distance_m:
			ok.append(p)
		if p.distance_to(ref) > farthest.distance_to(ref):
			farthest = p
	return ok[_rng.randi() % ok.size()] if not ok.is_empty() else farthest


func _on_died(actor: Actor) -> void:
	_respawn_at[actor as Enemy] = _time + Actor.DISSOLVE_S + respawn_delay_s
