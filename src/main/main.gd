extends Node
## Application root: boot, world routing, CLI automation flags, app-lifecycle broadcast.
##
## User args (after `--`):
##   --scene=res://...        world scene to load (default: proving grounds)
##   --preset=gfx_high        graphics preset for this run only (not persisted)
##   --bench                  run the benchmark, then quit (exit code 1 if over budget)
##   --bench-warmup=S --bench-sample=S --bench-out=PATH --bench-stage=NAME
##   --screenshot=PATH        save a PNG after --frames=N frames (default 45), then quit
##   --no-debug-ui            hide perf HUD + dev panel (clean screenshots)
##   --touch-ui               start in touch mode (shows the virtual sticks on desktop)
##   --autoplay               a scripted pilot plays the player (soak tests, demos, device perf runs)

const DEFAULT_WORLD := "res://src/world/proving_grounds/proving_grounds.tscn"
const BENCH_WORLD := "res://src/debug/bench/bench.tscn"

var _args: Dictionary = {}
var _context := WorldContext.new()

@onready var _world: Node3D = %World
@onready var _input_router: InputRouter = %InputRouter
@onready var _touch: TouchControls = %TouchControls
@onready var _hud: Hud = %Hud
@onready var _debug_ui: Control = %DebugUI
@onready var _dev_panel: DevPanel = %DevPanel


func _ready() -> void:
	_args = CliArgs.parse(OS.get_cmdline_user_args())
	_context.input_router = _input_router
	_context.args = _args
	_touch.bind(_input_router)
	Log.info(
		"Main", "boot %s | %s" % [ProjectSettings.get_setting("application/config/version"), PerfProbe.device_info()]
	)
	if _args.has("preset"):
		Settings.set_preset(StringName(str(_args["preset"])), false)
	if not OS.is_debug_build() or _args.has("no-debug-ui"):
		_debug_ui.queue_free()
	if _args.has("touch-ui"):  # screenshots/tests of the touch layout on desktop
		_input_router.press_touch_action(&"")
	else:
		_dev_panel.bench_requested.connect(func() -> void: run_bench(false))

	if _args.has("bench"):
		run_bench(true)
	else:
		load_world(str(_args.get("scene", DEFAULT_WORLD)))
	if _args.has("screenshot"):
		_screenshot_and_quit(str(_args["screenshot"]), int(str(_args.get("frames", "45"))))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			EventBus.app_paused.emit()
		NOTIFICATION_APPLICATION_RESUMED:
			EventBus.app_resumed.emit()


## Replaces the current world with the scene at `path`. Returns the new root (or null).
func load_world(path: String) -> Node:
	for c in _world.get_children():
		_world.remove_child(c)
		c.queue_free()
	var scene := load(path) as PackedScene
	if scene == null:
		Log.error("Main", "cannot load world scene %s" % path)
		return null
	var inst := scene.instantiate()
	if inst.has_method(&"setup_world"):
		inst.call(&"setup_world", _context)
	_world.add_child(inst)
	return inst


## Debug UI is hidden while measuring so its ~25 canvas draw calls don't pollute the numbers.
func run_bench(quit_when_done: bool) -> void:
	var bench := load_world(BENCH_WORLD) as Bench
	bench.configure(_args)
	var ui_was_visible := is_instance_valid(_debug_ui) and _debug_ui.visible
	if is_instance_valid(_debug_ui):
		_debug_ui.visible = false
	_hud.visible = false
	bench.run()
	var results: Dictionary = await bench.finished
	if is_instance_valid(_debug_ui):
		_debug_ui.visible = ui_was_visible
	_hud.visible = true
	if is_instance_valid(_dev_panel):
		_dev_panel.show_bench_results(results)
	if quit_when_done:
		get_tree().quit(0 if results.get("within_budget", false) else 1)
	else:
		load_world(DEFAULT_WORLD)


func _screenshot_and_quit(path: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	Log.info("Main", "screenshot %s -> %s" % [path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
