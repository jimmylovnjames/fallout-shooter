class_name ArenaBuilder
extends RefCounted
## Builds the P1 greybox arena under a NavigationRegion3D child so the navmesh bakes from its
## static colliders. Repeated props are batched (one MultiMesh each) per the draw-call rules.

const _WALL_TONES: Array[Color] = [
	Color(0.93, 0.88, 0.72),
	Color(0.1, 0.11, 0.14),
	Color(0.9, 0.28, 0.06),
	Color(0.78, 0.42, 0.1),
]
const _AWNING_TONES: Array[Color] = [
	Color(0.98, 0.78, 0.08),
	Color(0.05, 0.55, 0.62),
	Color(0.86, 0.12, 0.1),
	Color(0.18, 0.32, 0.86),
]


static func build(root: Node3D, rng: RandomNumberGenerator, half: float) -> void:
	var visual_ground := GreyboxKit.ground(160.0)
	root.add_child(visual_ground)

	var statics := StaticBody3D.new()
	statics.name = "Statics"
	statics.collision_layer = PhysicsLayers.WORLD
	statics.collision_mask = 0
	root.add_child(statics)
	# Ground slab (top at y = 0) and invisible perimeter walls.
	statics.add_child(
		GreyboxKit.box_shape(Vector3(half * 2 + 4, 1, half * 2 + 4), Transform3D(Basis(), Vector3(0, -0.5, 0)))
	)
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var size := Vector3(1, 4, half * 2) if side.x != 0 else Vector3(half * 2, 4, 1)
		statics.add_child(GreyboxKit.box_shape(size, Transform3D(Basis(), side * (half + 0.5) + Vector3(0, 2, 0))))

	# Building shells along both sides of the road. The road itself is painted on the ground.
	var shells: Array[Transform3D] = []
	var shell_colors := PackedColorArray()
	var awnings: Array[Transform3D] = []
	var awning_colors := PackedColorArray()
	for side: int in [-1, 1]:
		for i in 4:
			var size := Vector3(rng.randf_range(5, 8), rng.randf_range(3, 7), rng.randf_range(5, 9))
			var pos := Vector3(side * (5.0 + size.x * 0.5), 0, -24 + i * 13 + rng.randf_range(-1.5, 1.5))
			var body := StaticBody3D.new()
			body.collision_layer = PhysicsLayers.WORLD
			body.collision_mask = 0
			body.position = pos + Vector3(0, size.y * 0.5, 0)
			body.add_child(GreyboxKit.box_shape(size, Transform3D()))
			root.add_child(body)
			shells.append(Transform3D(Basis().scaled(size), body.position))
			shell_colors.append(_WALL_TONES[(i + (0 if side < 0 else 1)) % _WALL_TONES.size()])
			var street := -1.0 if pos.x > 0.0 else 1.0
			var awn_pos := Vector3(pos.x + street * (size.x * 0.5 + 0.48), size.y * 0.62, pos.z)
			var depth := minf(size.z * 0.38, 2.3)
			awnings.append(Transform3D(Basis().scaled(Vector3(1.05, 0.04, depth)), awn_pos))
			awning_colors.append(_AWNING_TONES[(i + (0 if side < 0 else 2)) % _AWNING_TONES.size()])
	root.add_child(GreyboxKit.batch_occluders(shells, shell_colors))
	root.add_child(GreyboxKit.batch(BoxMesh.new(), awnings, awning_colors, GreyboxKit.Palette.ACCENT))

	_crates(root, statics, rng)
	_barrels(root, statics, rng)
	_barriers(root, statics, rng)
	_fence(root, half)
	root.add_child(
		GreyboxKit.scatter(
			GreyboxKit.rock_mesh(),
			GreyboxKit.Palette.SAND,
			220,
			40.0,
			rng,
			Vector2(0.5, 1.25),
			0.1,
			GreyboxKit.STYLE_ROCK
		)
	)
	_horizon(root)
	_street(root, statics)
	var haze := HazeField.new()
	haze.name = "HazeField"
	root.add_child(haze)


## Enemy spawn ring near the arena edge.
static func spawn_points(half: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var r := half - 6.0
	for i in 12:
		var a := TAU * i / 12.0 + 0.2
		pts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	return pts


static func _crates(root: Node3D, statics: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var xforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	for i in 22:
		var s := rng.randf_range(0.8, 1.3)
		var pos := Vector3(rng.randf_range(-14, 14), s * 0.5, rng.randf_range(-24, 24))
		if absf(pos.x) < 3.2 and absf(pos.z - 12.0) < 3.0:
			continue  # keep the player spawn clear
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		xforms.append(Transform3D(basis.scaled(Vector3(s, s, s)), pos))
		colors.append(Color(0.42, 0.33, 0.24).lerp(Color(0.55, 0.42, 0.28), rng.randf()))
		statics.add_child(GreyboxKit.box_shape(Vector3(s, s, s), Transform3D(basis, pos)))
	root.add_child(GreyboxKit.batch(BoxMesh.new(), xforms, colors, GreyboxKit.Palette.WOOD))


static func _barrels(root: Node3D, statics: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.3
	mesh.height = 0.9
	mesh.radial_segments = 10
	var xforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	for i in 10:
		var pos := Vector3(rng.randf_range(-7, 7), 0.45, rng.randf_range(-20, 20))
		xforms.append(Transform3D(Basis(), pos))
		colors.append(Color(0.52, 0.3, 0.18) if i % 3 else Color(0.35, 0.4, 0.3))
		var shape := CylinderShape3D.new()
		shape.radius = 0.3
		shape.height = 0.9
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = pos
		statics.add_child(cs)
	root.add_child(GreyboxKit.batch(mesh, xforms, colors, GreyboxKit.Palette.RUST))


static func _barriers(root: Node3D, statics: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.9, 0.5)
	var xforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	for i in 8:
		var pos := Vector3(-2.2 + (i % 2) * 4.4, 0.45, -16 + i * 4.2)
		var basis := Basis(Vector3.UP, deg_to_rad(rng.randf_range(-12, 12)))
		xforms.append(Transform3D(basis, pos))
		colors.append(Color(0.6, 0.58, 0.54))
		statics.add_child(GreyboxKit.box_shape(mesh.size, Transform3D(basis, pos)))
	root.add_child(GreyboxKit.batch(mesh, xforms, colors, GreyboxKit.Palette.CONCRETE))


## Visual perimeter posts (the walls themselves are invisible colliders).
static func _fence(root: Node3D, half: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.25, 1.4, 0.25)
	var xforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	var step := 3.0
	var n := int(half * 2.0 / step)
	for i in n + 1:
		var t := -half + i * step
		for p: Vector3 in [
			Vector3(t, 0.7, -half), Vector3(t, 0.7, half), Vector3(-half, 0.7, t), Vector3(half, 0.7, t)
		]:
			xforms.append(Transform3D(Basis(), p))
			colors.append(Color(0.3, 0.28, 0.26))
	root.add_child(GreyboxKit.batch(mesh, xforms, colors, GreyboxKit.Palette.DARK))
	_rails(root, half, step, n)


static func _rails(root: Node3D, half: float, step: float, n: int) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(step * 0.92, 0.07, 0.08)
	var xforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	var yaw := Basis(Vector3.UP, PI * 0.5)
	for i in n:
		var t := -half + i * step + step * 0.5
		for height: float in PackedFloat32Array([0.42, 1.05]):
			xforms.append(Transform3D(Basis(), Vector3(t, height, -half)))
			xforms.append(Transform3D(Basis(), Vector3(t, height, half)))
			xforms.append(Transform3D(yaw, Vector3(-half, height, t)))
			xforms.append(Transform3D(yaw, Vector3(half, height, t)))
			var rail_color := Color(0.28, 0.26, 0.24)
			colors.append(rail_color)
			colors.append(rail_color)
			colors.append(rail_color)
			colors.append(rail_color)
	root.add_child(GreyboxKit.batch(mesh, xforms, colors, GreyboxKit.Palette.DARK))


## Buttes and dead trees outside the fence. Own RNG so the prop layout above stays fixed.
static func _horizon(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4400
	var rocks: Array[Transform3D] = []
	var rock_colors := PackedColorArray()
	for i in 9:
		var ang := TAU * float(i) / 9.0 + 0.4
		var radius := rng.randf_range(56.0, 72.0)
		var s := rng.randf_range(8.0, 15.0)
		var sy := s * rng.randf_range(0.4, 0.75)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, sy, s))
		rocks.append(Transform3D(basis, Vector3(cos(ang) * radius, 0.36 * sy * 0.2, sin(ang) * radius)))
		rock_colors.append(Color(0.48, 0.44, 0.4).lerp(Color(0.38, 0.32, 0.28), rng.randf()))
	root.add_child(GreyboxKit.batch(GreyboxKit.rock_mesh(), rocks, rock_colors, GreyboxKit.STYLE_ROCK, 0.12))

	var trees: Array[Transform3D] = []
	var tree_colors := PackedColorArray()
	for i in 14:
		var ang := TAU * float(i) / 14.0
		var radius := rng.randf_range(46.5, 52.0)
		var s := rng.randf_range(0.85, 1.45)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, rng.randf_range(0.8, 1.3), s))
		trees.append(Transform3D(basis, Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)))
		tree_colors.append(Color(0.4, 0.32, 0.22).lerp(Color(0.28, 0.22, 0.16), rng.randf()))
	root.add_child(GreyboxKit.batch(PropMeshes.dead_tree(), trees, tree_colors, GreyboxKit.STYLE_BARK))


## Wrecks and street lamps. Fixed layout so the scattered props above keep their seed.
static func _street(root: Node3D, statics: StaticBody3D) -> void:
	var wrecks: Array[Transform3D] = []
	var wreck_colors := PackedColorArray()
	var spots: Array[Vector3] = [Vector3(1.5, 0.0, -8.0), Vector3(-1.7, 0.0, 1.5), Vector3(1.2, 0.0, -20.0)]
	var yaws: Array[float] = [0.35, 2.4, -0.5]
	for i in spots.size():
		var basis := Basis(Vector3.UP, yaws[i])
		wrecks.append(Transform3D(basis, spots[i]))
		wreck_colors.append(Color(0.85, 0.42, 0.12))
		statics.add_child(
			GreyboxKit.box_shape(Vector3(1.8, 1.1, 3.6), Transform3D(basis, spots[i] + Vector3(0, 0.55, 0)))
		)
	root.add_child(GreyboxKit.batch(PropMeshes.wreck(), wrecks, wreck_colors, GreyboxKit.Palette.RUST))

	var posts: Array[Transform3D] = []
	var post_colors := PackedColorArray()
	for z: float in PackedFloat32Array([-18.0, -6.0, 6.0, 18.0]):
		for x: float in PackedFloat32Array([-4.6, 4.6]):
			var yaw := 0.0 if x < 0.0 else PI
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, z))
			posts.append(xf)
			post_colors.append(Color(0.12, 0.13, 0.15))
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.62, 0.22)
			lamp.light_energy = 1.6
			lamp.omni_range = 7.5
			lamp.shadow_enabled = false
			lamp.position = xf * Vector3(0.86, 3.02, 0)
			root.add_child(lamp)
	root.add_child(GreyboxKit.batch(PropMeshes.lamp_post(), posts, post_colors, GreyboxKit.Palette.DARK))
	root.add_child(GreyboxKit.batch_emissive(PropMeshes.lamp_bulb(), posts, Color(1.0, 0.48, 0.08)))
