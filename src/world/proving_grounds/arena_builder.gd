class_name ArenaBuilder
extends RefCounted
## Builds the P1 greybox arena under a NavigationRegion3D child so the navmesh bakes from its
## static colliders. Repeated props are batched (one MultiMesh each) per the draw-call rules.


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

	root.add_child(GreyboxKit.box(Vector3(6, 0.05, 90), GreyboxKit.Palette.DARK, Vector3.ZERO))  # road (no collider)

	# Building shells along both sides of the road.
	for side: int in [-1, 1]:
		for i in 4:
			var size := Vector3(rng.randf_range(5, 8), rng.randf_range(3, 7), rng.randf_range(5, 9))
			var pos := Vector3(side * (5.0 + size.x * 0.5), 0, -24 + i * 13 + rng.randf_range(-1.5, 1.5))
			var tint := Color(0.56, 0.54, 0.5) if (i + side) % 2 == 0 else Color(0.52, 0.3, 0.18)
			root.add_child(GreyboxKit.building(size, pos, tint))

	_crates(root, statics, rng)
	_barrels(root, statics, rng)
	_barriers(root, statics, rng)
	_fence(root, half)
	root.add_child(GreyboxKit.scatter(GreyboxKit.rock_mesh(), GreyboxKit.Palette.CONCRETE, 600, 40.0, rng))


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
	root.add_child(GreyboxKit.batch(BoxMesh.new(), xforms, colors))


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
	root.add_child(GreyboxKit.batch(mesh, xforms, colors))


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
	root.add_child(GreyboxKit.batch(mesh, xforms, colors))


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
	root.add_child(GreyboxKit.batch(mesh, xforms, colors))
