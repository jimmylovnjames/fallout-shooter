extends GutTest
## Weapons, projectiles and health against real physics.

const Fixture := preload("res://tests/integration/combat_fixture.gd")

var fx: Fixture


func before_each() -> void:
	fx = Fixture.new()
	fx.build(self)
	await wait_physics_frames(2)


func test_hitscan_damages_target() -> void:
	var shooter := fx.spawn_player(Vector3(0, 0, 0))
	var victim := fx.spawn_enemy(Vector3(0, 0, -8), shooter)
	victim.brain.set_physics_process(false)
	await wait_physics_frames(3)
	shooter.intent.aim = Vector3(0, 0, -1)
	shooter.intent.fire = true
	await wait_physics_frames(2)
	shooter.intent.fire = false
	assert_lt(victim.health.pool.current, victim.health.pool.maximum, "pistol hitscan landed")


func test_projectile_travels_and_hits() -> void:
	var target := fx.spawn_player(Vector3(0, 0, -10))
	var p := fx.services.projectiles
	var ok := p.spawn(
		Vector3(0, 1.2, 0), Vector3(0, 0, -30), 15.0, 0, RID(), PhysicsLayers.HOSTILE_SHOTS, 40.0, Color.RED
	)
	assert_true(ok)
	assert_eq(p.live, 1)
	await wait_physics_frames(3)
	assert_eq(p.live, 1, "still in flight after 0.05 s")
	await wait_physics_frames(30)
	assert_eq(p.live, 0, "consumed on impact")
	assert_eq(target.health.pool.current, target.health.pool.maximum - 15.0)


func test_projectile_blocked_by_wall() -> void:
	var target := fx.spawn_player(Vector3(0, 0, -10))
	fx.add_wall(Vector3(4, 3, 0.5), Vector3(0, 0, -5))
	await wait_physics_frames(2)
	fx.services.projectiles.spawn(
		Vector3(0, 1.2, 0), Vector3(0, 0, -30), 15.0, 0, RID(), PhysicsLayers.HOSTILE_SHOTS, 40.0, Color.RED
	)
	await wait_physics_frames(40)
	assert_eq(target.health.pool.current, target.health.pool.maximum, "wall absorbed the shot")


func test_projectile_expires_at_range_and_pool_caps() -> void:
	var p := fx.services.projectiles
	p.spawn(Vector3(0, 30, 0), Vector3(0, 0, -60), 1.0, 0, RID(), 0, 3.0, Color.RED)
	await wait_physics_frames(6)
	assert_eq(p.live, 0, "3 m at 60 m/s expires in 0.05 s")
	for i in p.capacity:
		p.spawn(Vector3(0, 30, 0), Vector3(0, 0, -1), 1.0, 0, RID(), 0, 100.0, Color.RED)
	assert_false(p.spawn(Vector3.ZERO, Vector3.FORWARD, 1.0, 0, RID(), 0, 1.0, Color.RED), "full pool drops the shot")


func test_player_dies_and_respawns() -> void:
	var p := fx.spawn_player(Vector3.ZERO)
	watch_signals(EventBus)
	p.health.apply_damage(DamageInfo.make(500.0, 0, Vector3.ZERO, Vector3.FORWARD))
	assert_false(p.alive)
	assert_signal_emitted(EventBus, "player_died")
	var ammo := p.weapon.active().in_mag
	p.intent.aim = Vector3(0, 0, -1)
	p.intent.fire = true
	await wait_physics_frames(3)
	assert_eq(p.weapon.active().in_mag, ammo, "dead actors don't shoot")
	p.respawn(Vector3(3, 0, 3))
	assert_true(p.alive)
	assert_eq(p.health.pool.current, p.health.pool.maximum)
	assert_eq(p.health.apply_damage(DamageInfo.make(10.0, 0, Vector3.ZERO, Vector3.FORWARD)), 0.0, "spawn protection")
	assert_signal_emitted(EventBus, "player_respawned")


func test_weapon_swap_and_reload_via_intent() -> void:
	var p := fx.spawn_player(Vector3.ZERO)
	watch_signals(EventBus)
	assert_eq(p.weapon.active().def.id, &"wpn_service_pistol")
	p.intent.swap = true
	await wait_physics_frames(3)
	assert_eq(p.weapon.active().def.id, &"wpn_rivet_carbine", "one swap per request")
	assert_false(p.intent.swap, "consumed")
	assert_signal_emitted(EventBus, "weapon_equipped")
