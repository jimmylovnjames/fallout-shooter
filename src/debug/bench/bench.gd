class_name Bench
extends Node3D
## In-app benchmark (DESIGN §8). Runs fixed stages from a fixed camera, samples frame times and
## render stats, writes JSON to user://bench/ and prints one `BENCH_RESULT {...}` line (logcat).
## Draw calls/primitives are comparable across machines; fps only on real devices.

signal finished(results: Dictionary)

const DRAW_CALL_BUDGET := 250
const SEED := 4242

## Each stage: name, content counts, and whether the draw-call budget applies.
## props_nodes_400 is informational: it shows why unbatched props are banned (each shadow-casting
## MeshInstance3D costs ~2 draw calls on the Mobile renderer). target_scene approximates a busy
## gameplay view: ~30 unique meshes, batched debris, 20 outlined actors.
const STAGES: Array[Dictionary] = [
	{"name": "baseline", "budget": true},
	{"name": "props_nodes_400", "nodes": 400, "budget": false},
	{"name": "props_multimesh_4000", "multimesh": 4000, "budget": true},
	{"name": "actors_20_outlined", "actors": 20, "budget": true},
	{"name": "target_scene", "nodes": 30, "multimesh": 3000, "actors": 20, "budget": true},
]

var warmup_s: float = 1.0
var sample_s: float = 3.0
var out_path: String = ""
var stage_filter: String = ""

var _actors: Array[Node3D] = []
var _t := 0.0

@onready var _stage_root: Node3D = $StageRoot


## Accepts CLI-style options: bench-warmup, bench-sample, bench-out, bench-stage.
func configure(args: Dictionary) -> void:
	warmup_s = float(args.get("bench-warmup", warmup_s))
	sample_s = float(args.get("bench-sample", sample_s))
	out_path = str(args.get("bench-out", out_path))
	stage_filter = str(args.get("bench-stage", stage_filter))


func run() -> void:
	EventBus.bench_started.emit()
	var stages: Array[Dictionary] = []
	for stage in STAGES:
		if stage_filter.is_empty() or stage["name"] == stage_filter:
			stages.append(await _run_stage(stage))
	var results := {
		"schema": 1,
		"timestamp": Time.get_datetime_string_from_system(true),
		"device": PerfProbe.device_info(),
		"preset": String(Settings.get_preset().id),
		"render_scale": Settings.effective_render_scale(),
		"viewport": [get_viewport().size.x, get_viewport().size.y],
		"draw_call_budget": DRAW_CALL_BUDGET,
		"stages": stages,
		"within_budget": stages.all(func(s: Dictionary) -> bool: return s["within_budget"]),
	}
	results["saved_to"] = _save(results)
	print("BENCH_RESULT ", JSON.stringify(summarize(results)))
	EventBus.bench_finished.emit(results)
	finished.emit(results)


func _process(delta: float) -> void:
	_t += delta
	for i in _actors.size():
		var a := _actors[i]
		var phase := _t * 0.7 + i * 0.9
		a.position = Vector3(cos(phase), 0.0, sin(phase)) * (4.0 + (i % 5) * 2.0)
		a.rotation.y = -phase


func _run_stage(stage: Dictionary) -> Dictionary:
	_build_stage(stage)
	var t := 0.0
	while t < warmup_s:
		t += await _frame()
	var pso_start := PerfProbe.pipeline_compilations()
	var frame_ms := PackedFloat32Array()
	var draws := PackedInt32Array()
	var prims := PackedInt32Array()
	var objs := PackedInt32Array()
	t = 0.0
	while t < sample_s or frame_ms.size() < 5:
		var dt := await _frame()
		t += dt
		frame_ms.append(dt * 1000.0)
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		prims.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		objs.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	var sorted := frame_ms.duplicate()
	sorted.sort()
	var avg_ms := _mean(frame_ms)
	var draw_max := _max_i(draws)
	var snap := PerfProbe.snapshot()
	return {
		"name": stage["name"],
		"frames": frame_ms.size(),
		"avg_ms": avg_ms,
		"p95_ms": sorted[int(floor((sorted.size() - 1) * 0.95))],
		"max_ms": sorted[sorted.size() - 1],
		"fps_avg": 1000.0 / maxf(avg_ms, 0.001),
		"draw_calls_avg": _mean_i(draws),
		"draw_calls_max": draw_max,
		"primitives_avg": _mean_i(prims),
		"objects_avg": _mean_i(objs),
		"pipeline_compiles": PerfProbe.pipeline_compilations() - pso_start,
		"video_mem_mb": snap["video_mem_mb"],
		"static_mem_mb": snap["static_mem_mb"],
		"within_budget": (not stage.get("budget", true)) or draw_max <= DRAW_CALL_BUDGET,
	}


func _build_stage(stage: Dictionary) -> void:
	for c in _stage_root.get_children():
		_stage_root.remove_child(c)
		c.queue_free()
	_actors.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_stage_root.add_child(GreyboxKit.ground(160.0))
	var nodes: int = stage.get("nodes", 0)
	for i in nodes:
		var pos := Vector3(rng.randf_range(-18, 18), 0, rng.randf_range(-12, 12))
		var s := rng.randf_range(0.5, 1.2)
		var pal := GreyboxKit.Palette.WOOD if i % 2 == 0 else GreyboxKit.Palette.CONCRETE
		_stage_root.add_child(GreyboxKit.box(Vector3(s, s, s), pal, pos, rng.randf() * 90.0))
	var mm_count: int = stage.get("multimesh", 0)
	if mm_count > 0:
		var rocks := GreyboxKit.scatter(GreyboxKit.rock_mesh(), GreyboxKit.Palette.CONCRETE, mm_count / 2, 30.0, rng)
		var crates := GreyboxKit.scatter(
			BoxMesh.new(), GreyboxKit.Palette.WOOD, mm_count / 2, 30.0, rng, Vector2(0.3, 0.8)
		)
		_stage_root.add_child(rocks)
		_stage_root.add_child(crates)
	var actors: int = stage.get("actors", 0)
	for i in actors:
		var a := GreyboxKit.actor_dummy(GreyboxKit.Palette.ACCENT if i == 0 else GreyboxKit.Palette.DARK)
		_stage_root.add_child(a)
		_actors.append(a)


func _frame() -> float:
	var before := Time.get_ticks_usec()
	await get_tree().process_frame
	return (Time.get_ticks_usec() - before) / 1000000.0


func _save(results: Dictionary) -> String:
	var json := JSON.stringify(results, "  ", false)
	var dir := "user://bench"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("bench_%d.json" % int(Time.get_unix_time_from_system()))
	for p: String in [path, out_path]:
		if p.is_empty():
			continue
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f == null:
			Log.error("Bench", "cannot write %s" % p)
			continue
		f.store_string(json)
	return ProjectSettings.globalize_path(path)


## Compact one-line form for logcat / clipboard.
static func summarize(results: Dictionary) -> Dictionary:
	var stages := {}
	for s: Dictionary in results["stages"]:
		stages[s["name"]] = {
			"fps": snappedf(s["fps_avg"], 0.1),
			"p95_ms": snappedf(s["p95_ms"], 0.01),
			"draws": s["draw_calls_max"],
			"prims": int(s["primitives_avg"]),
		}
	var device: Dictionary = results["device"]
	return {
		"model": device["model"],
		"gpu": device["gpu"],
		"renderer": "%s/%s" % [device["renderer"], device["driver"]],
		"ram_mb": device["ram_mb"],
		"preset": results["preset"],
		"scale": snappedf(results["render_scale"], 0.01),
		"viewport": results["viewport"],
		"within_budget": results["within_budget"],
		"stages": stages,
	}


static func _mean(a: PackedFloat32Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)


static func _mean_i(a: PackedInt32Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)


static func _max_i(a: PackedInt32Array) -> int:
	var m := 0
	for v in a:
		m = maxi(m, v)
	return m
