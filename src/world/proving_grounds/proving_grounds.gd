extends Node3D
## P1 playable arena: greybox street block, player, 10 pooled hostiles, navmesh, respawn loop.
## Content is generated deterministically from SEED so perf numbers are comparable run to run.

const SEED := 1337
const PLAYER_DEF := &"act_player"
const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const PLAYER_SPAWN := Vector3(0, 0, 12)
const RESPAWN_DELAY_S := 3.0
const ARENA_HALF_M := 44.0

var context: WorldContext
var player: Player
var services: CombatServices
var nav_ready := false

var _router: InputRouter

@onready var _env: WorldEnvironment = $WorldEnvironment
@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var _geometry: Node3D = $NavigationRegion3D/Geometry
@onready var _rig: CameraRig = $CameraRig
@onready var _spawner: EnemySpawner = $EnemySpawner
@onready var _combat_root: Node3D = $Combat


## Called by Main before the scene enters the tree.
func setup_world(ctx: WorldContext) -> void:
	context = ctx


func _ready() -> void:
	# Environment is shared; duplicate so preset tweaks never leak into the resource on disk.
	_env.environment = _env.environment.duplicate(true) as Environment
	_apply_preset(Settings.get_preset())
	EventBus.graphics_preset_applied.connect(_apply_preset)

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	ArenaBuilder.build(_geometry, rng, ARENA_HALF_M)
	# Each level instance bakes its own navmesh (a shared resource can't bake twice concurrently).
	_nav_region.navigation_mesh = _nav_region.navigation_mesh.duplicate() as NavigationMesh
	_nav_region.bake_finished.connect(func() -> void: nav_ready = true)
	_nav_region.bake_navigation_mesh(true)

	services = CombatServices.create(_combat_root, SEED)
	if context != null and context.input_router != null:
		_router = context.input_router
	else:
		_router = InputRouter.new()
		_router.name = "InputRouter"
		add_child(_router)

	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.global_position = PLAYER_SPAWN
	player.setup_player(ContentDB.get_def(PLAYER_DEF) as ActorDef, services, _router, _rig, _hostiles)
	player.died.connect(_on_player_died)
	_rig.follow(player)

	_spawner.setup(services, player, ArenaBuilder.spawn_points(ARENA_HALF_M), SEED)
	if context != null and context.args.has("autoplay"):
		enable_autopilot()
	GameState.session_active = true


func enable_autopilot() -> AutoPilot:
	var pilot := AutoPilot.new()
	pilot.name = "AutoPilot"
	add_child(pilot)
	pilot.setup(player, _hostiles)
	return pilot


func enemy_spawner() -> EnemySpawner:
	return _spawner


func _exit_tree() -> void:
	GameState.session_active = false


func _hostiles() -> Array[Actor]:
	return _spawner.hostiles


func _apply_preset(p: GraphicsPreset) -> void:
	if p != null:
		_env.environment.glow_enabled = p.glow


func _on_player_died(_a: Actor) -> void:
	get_tree().create_timer(RESPAWN_DELAY_S, false).timeout.connect(
		func() -> void:
			if is_instance_valid(player):
				player.respawn(PLAYER_SPAWN)
	)
