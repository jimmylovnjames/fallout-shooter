extends RefCounted
## Builds a tiny flat arena for combat/AI integration tests: ground collider + baked navmesh +
## combat services. Not a test file (no test_ prefix).

const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const ENEMY_SCENE := preload("res://src/actors/enemy/enemy.tscn")

var root: Node3D
var services: CombatServices
var nav: NavigationRegion3D
var router: InputRouter


func build(test: GutTest) -> void:
	root = Node3D.new()
	test.add_child_autofree(root)
	nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = PhysicsLayers.WORLD
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.25
	nav.navigation_mesh = nm
	root.add_child(nav)
	var ground := StaticBody3D.new()
	ground.collision_layer = PhysicsLayers.WORLD
	ground.add_child(GreyboxKit.box_shape(Vector3(60, 1, 60), Transform3D(Basis(), Vector3(0, -0.5, 0))))
	nav.add_child(ground)
	nav.bake_navigation_mesh(false)
	services = CombatServices.create(root, 99)
	router = InputRouter.new()
	root.add_child(router)


func add_wall(size: Vector3, pos: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	wall.add_child(GreyboxKit.box_shape(size, Transform3D(Basis(), pos + Vector3(0, size.y * 0.5, 0))))
	root.add_child(wall)
	return wall


func spawn_player(pos: Vector3) -> Player:
	var p := PLAYER_SCENE.instantiate() as Player
	root.add_child(p)
	p.global_position = pos
	p.setup_player(ContentDB.get_def(&"act_player") as ActorDef, services, router, null, Callable())
	p.controller.enabled = false
	return p


func spawn_enemy(pos: Vector3, target: Actor) -> Enemy:
	var e := ENEMY_SCENE.instantiate() as Enemy
	root.add_child(e)
	e.setup_enemy(ContentDB.get_def(&"enm_scavenger") as EnemyArchetypeDef, services, target, 7)
	e.spawn_at(pos)
	return e
