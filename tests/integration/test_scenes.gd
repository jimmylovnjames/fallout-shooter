extends GutTest
## Smoke tests: scenes instantiate, run, and free without engine errors; the P1 arena plays.

const PROVING_GROUNDS := preload("res://src/world/proving_grounds/proving_grounds.tscn")


func after_each() -> void:
	Engine.time_scale = 1.0


func test_arena_builds_player_enemies_and_navmesh() -> void:
	var lvl := PROVING_GROUNDS.instantiate()
	add_child_autofree(lvl)
	await wait_physics_frames(5)
	var player: Player = lvl.get("player")
	assert_not_null(player)
	assert_true(player.alive)
	var spawner: EnemySpawner = lvl.call("enemy_spawner")
	assert_eq(spawner.enemies().size(), 10)
	assert_eq(spawner.alive_count(), 10)
	await wait_until(func() -> bool: return lvl.get("nav_ready"), 10.0, "navmesh bake")
	assert_true(lvl.get("nav_ready"), "navmesh baked")


func test_arena_sun_follows_presets() -> void:
	var lvl := PROVING_GROUNDS.instantiate()
	add_child_autofree(lvl)
	await wait_physics_frames(2)
	var sun := lvl.get_node("Sun") as DirectionalLight3D
	Settings.set_preset(&"gfx_low", false)
	assert_false(sun.shadow_enabled, "Low preset disables sun shadows")
	Settings.set_preset(&"gfx_high", false)
	assert_true(sun.shadow_enabled)


## End-to-end soak: the autopilot fights for up to ~45 s of game time (3× time scale, counted in
## physics frames because GUT timers scale with time_scale). Proves the whole loop — intent →
## weapons → projectiles/hitscan → health → death → pooled respawn — and that the AI hunts and
## fights back, with no script or engine errors.
func test_combat_soak_with_autopilot() -> void:
	var lvl := PROVING_GROUNDS.instantiate()
	add_child_autofree(lvl)
	await wait_physics_frames(2)
	await wait_until(func() -> bool: return lvl.get("nav_ready"), 10.0)
	lvl.call("enable_autopilot")
	var player: Player = lvl.get("player")
	var stats := {"kills": 0, "hurt": 0.0}
	var on_kill := func(_id: StringName) -> void: stats["kills"] += 1
	var on_hurt := func(amount: float, _d: Vector3) -> void: stats["hurt"] += amount
	EventBus.enemy_killed.connect(on_kill)
	EventBus.player_damaged.connect(on_hurt)
	Engine.time_scale = 3.0
	for i in 15:
		await wait_physics_frames(60)
		if stats["kills"] >= 2 and stats["hurt"] > 0.0:
			break
	Engine.time_scale = 1.0
	EventBus.enemy_killed.disconnect(on_kill)
	EventBus.player_damaged.disconnect(on_hurt)
	gut.p("soak: kills=%d damage_taken=%.0f player_alive=%s" % [stats["kills"], stats["hurt"], player.alive])
	assert_gte(stats["kills"], 2, "the player killed things")
	assert_gt(stats["hurt"], 0.0, "enemies hunted and fought back")


func test_bench_completes_all_stages() -> void:
	var bench := (load("res://src/debug/bench/bench.tscn") as PackedScene).instantiate() as Bench
	add_child_autofree(bench)
	bench.configure({"bench-warmup": "0.01", "bench-sample": "0.02", "bench-out": "user://test_bench.json"})
	watch_signals(bench)
	bench.run()
	assert_true(await wait_for_signal(bench.finished, 30), "bench finished")
	var results: Dictionary = get_signal_parameters(bench, "finished")[0]
	assert_eq(results["stages"].size(), Bench.STAGES.size())
	for st: Dictionary in results["stages"]:
		assert_gte(st["frames"], 5, st["name"])
		assert_true(st.has("draw_calls_max"))
	assert_true(FileAccess.file_exists("user://test_bench.json"))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://test_bench.json"))
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "bench JSON parses")


func test_main_scene_boots() -> void:
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_process_frames(3)
	var world := main.get_node("World")
	assert_eq(world.get_child_count(), 1, "default world loaded")
