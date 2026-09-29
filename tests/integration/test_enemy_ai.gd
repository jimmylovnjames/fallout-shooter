extends GutTest
## AI state transitions in a flat arena.

const Fixture := preload("res://tests/integration/combat_fixture.gd")

var fx: Fixture


func before_each() -> void:
	fx = Fixture.new()
	fx.build(self)
	await wait_physics_frames(2)


func test_patrols_when_alone() -> void:
	var dummy := fx.spawn_player(Vector3(25, 0, 25))
	var e := fx.spawn_enemy(Vector3.ZERO, dummy)
	await wait_physics_frames(20)
	assert_eq(e.brain.state_name(), &"patrol")


func test_engages_and_shoots_visible_player() -> void:
	var p := fx.spawn_player(Vector3(0, 0, -8))
	var e := fx.spawn_enemy(Vector3.ZERO, p)
	e.face_instantly(Vector3(0, 0, -1))
	await wait_seconds(2.5)
	assert_eq(e.brain.state_name(), &"engage")
	assert_lt(p.health.pool.current, p.health.pool.maximum, "enemy hit the player")


func test_does_not_see_through_walls() -> void:
	var p := fx.spawn_player(Vector3(0, 0, -8))
	fx.add_wall(Vector3(6, 3, 0.5), Vector3(0, 0, -4))
	var e := fx.spawn_enemy(Vector3.ZERO, p)
	e.face_instantly(Vector3(0, 0, -1))
	await wait_physics_frames(30)
	assert_ne(e.brain.state_name(), &"engage")
	assert_eq(p.health.pool.current, p.health.pool.maximum)


func test_hears_gunshots_and_investigates() -> void:
	var p := fx.spawn_player(Vector3(0, 0, 12))
	fx.add_wall(Vector3(10, 3, 0.5), Vector3(0, 0, 6))
	var e := fx.spawn_enemy(Vector3.ZERO, p)
	e.face_instantly(Vector3(0, 0, -1))
	await wait_physics_frames(5)
	EventBus.noise_made.emit(p.global_position, 26.0, p.get_instance_id())
	await wait_physics_frames(15)
	assert_eq(e.brain.state_name(), &"investigate")


func test_damage_from_behind_turns_enemy() -> void:
	var p := fx.spawn_player(Vector3(0, 0, 8))
	var e := fx.spawn_enemy(Vector3.ZERO, p)
	e.face_instantly(Vector3(0, 0, -1))
	await wait_physics_frames(3)
	e.health.apply_damage(DamageInfo.make(5.0, p.get_instance_id(), e.global_position, Vector3(0, 0, -1)))
	await wait_physics_frames(15)
	assert_eq(e.brain.state_name(), &"engage", "turned toward the shooter and saw them")
