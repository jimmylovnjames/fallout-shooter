extends GutTest
## Smoke tests: scenes instantiate, run a few frames and free without engine errors.

const PROVING_GROUNDS := preload("res://src/world/proving_grounds/proving_grounds.tscn")


func test_proving_grounds_runs() -> void:
	var root := PROVING_GROUNDS.instantiate() as Node3D
	add_child_autofree(root)
	await wait_physics_frames(5)
	assert_gt(root.get_node("Props").get_child_count(), 30, "greybox generated")
	var sun := root.get_node("Sun") as DirectionalLight3D
	Settings.set_preset(&"gfx_low", false)
	assert_false(sun.shadow_enabled, "Low preset disables sun shadows")
	Settings.set_preset(&"gfx_high", false)
	assert_true(sun.shadow_enabled)


func test_proving_grounds_is_deterministic() -> void:
	var a := PROVING_GROUNDS.instantiate() as Node3D
	var b := PROVING_GROUNDS.instantiate() as Node3D
	add_child_autofree(a)
	add_child_autofree(b)
	await wait_process_frames(1)
	var pa := a.get_node("Props")
	var pb := b.get_node("Props")
	assert_eq(pa.get_child_count(), pb.get_child_count())
	for i in pa.get_child_count():
		assert_eq((pa.get_child(i) as Node3D).position, (pb.get_child(i) as Node3D).position)


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
