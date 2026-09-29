class_name Enemy
extends Actor
## Hostile actor driven by AIBrain. Pool-friendly: spawn_at() reuses the instance.

var archetype: EnemyArchetypeDef

@onready var brain: AIBrain = $AIBrain
@onready var nav: NavigationAgent3D = $NavigationAgent3D


func setup_enemy(arch: EnemyArchetypeDef, combat: CombatServices, hostile: Actor, seed_value: int) -> void:
	archetype = arch
	collision_layer = PhysicsLayers.ACTORS
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLAYER | PhysicsLayers.ACTORS
	setup(arch, combat, PhysicsLayers.HOSTILE_SHOTS)
	brain.setup(self, arch, hostile, seed_value)


func spawn_at(pos: Vector3) -> void:
	set_active(true)
	revive_at(pos)
	brain.reset(pos)


func _damaged(_applied: float, info: DamageInfo) -> void:
	brain.on_damaged(info)


func _died(_info: DamageInfo) -> void:
	EventBus.enemy_killed.emit(archetype.id)
