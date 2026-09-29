class_name GreyboxKit
extends RefCounted
## Shared greybox meshes/materials for test scenes and the benchmark. Materials are cached and
## shared so identical props never duplicate GPU state. Placeholder art only — replaced in P6.

enum Palette { CONCRETE, RUST, SAND, WOOD, ACCENT, DARK }

const _COLORS: Dictionary[Palette, Color] = {
	Palette.CONCRETE: Color(0.56, 0.54, 0.5),
	Palette.RUST: Color(0.52, 0.3, 0.18),
	Palette.SAND: Color(0.72, 0.62, 0.47),
	Palette.WOOD: Color(0.42, 0.33, 0.24),
	Palette.ACCENT: Color(0.9, 0.47, 0.17),
	Palette.DARK: Color(0.22, 0.21, 0.2),
}
const OUTLINE_SHADER := preload("res://src/shaders/outline_hull.gdshader")
const OCCLUDER_SHADER := preload("res://src/shaders/world_occluder.gdshader")

static var _materials: Dictionary[Palette, StandardMaterial3D] = {}
static var _outlined: Dictionary[Palette, StandardMaterial3D] = {}
static var _batch_material: StandardMaterial3D
static var _occluder_material: ShaderMaterial


static func material(p: Palette) -> StandardMaterial3D:
	if not _materials.has(p):
		var m := StandardMaterial3D.new()
		m.albedo_color = _COLORS[p]
		m.roughness = 0.85 if p != Palette.RUST else 0.7
		m.metallic = 0.3 if p == Palette.RUST else 0.0
		_materials[p] = m
	return _materials[p]


## Same colour, with the inverted-hull outline as next_pass (actors/interactables only).
static func outlined_material(p: Palette) -> StandardMaterial3D:
	if not _outlined.has(p):
		var m := material(p).duplicate() as StandardMaterial3D
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		m.next_pass = outline
		_outlined[p] = m
	return _outlined[p]


static func box(size: Vector3, p: Palette, pos: Vector3, yaw_deg: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(p)
	mi.position = pos + Vector3(0, size.y * 0.5, 0)
	mi.rotation_degrees.y = yaw_deg
	return mi


static func cylinder(radius: float, height: float, p: Palette, pos: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(p)
	mi.position = pos + Vector3(0, height * 0.5, 0)
	return mi


static func ground(size_m: float) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size_m, size_m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(Palette.SAND)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Capsule "actor" with an outlined body and a box "weapon": 2 surfaces + 2 outline passes.
static func actor_dummy(p: Palette = Palette.ACCENT) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.8
	cap.radial_segments = 12
	cap.rings = 4
	body.mesh = cap
	body.material_override = outlined_material(p)
	body.position.y = 0.9
	root.add_child(body)
	var gun := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.12, 0.14, 0.7)
	gun.mesh = gm
	gun.material_override = outlined_material(Palette.DARK)
	gun.position = Vector3(0.3, 1.1, -0.35)
	root.add_child(gun)
	return root


## Scatters `count` instances of `mesh` in a square of half-extent `extent` with one draw call
## per surface (DESIGN §3.1: props go through MultiMesh).
static func scatter(
	mesh: Mesh,
	p: Palette,
	count: int,
	extent: float,
	rng: RandomNumberGenerator,
	scale_range: Vector2 = Vector2(0.6, 1.4)
) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.5, 1.2), s))
		var pos := Vector3(rng.randf_range(-extent, extent), 0.0, rng.randf_range(-extent, extent))
		mm.set_instance_transform(i, Transform3D(basis, pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material(p)
	return mmi


static func rock_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 0.35
	m.height = 0.45
	m.radial_segments = 6
	m.rings = 3
	return m


# --- P1: collidable, batched level pieces ----------------------------------------------------------


## Shared material for MultiMesh props: per-instance colour through vertex colour.
static func batch_material() -> StandardMaterial3D:
	if _batch_material == null:
		_batch_material = StandardMaterial3D.new()
		_batch_material.vertex_color_use_as_albedo = true
		_batch_material.vertex_color_is_srgb = true
		_batch_material.roughness = 0.85
	return _batch_material


static func occluder_material() -> ShaderMaterial:
	if _occluder_material == null:
		_occluder_material = ShaderMaterial.new()
		_occluder_material.shader = OCCLUDER_SHADER
	return _occluder_material


## One MultiMesh (one draw + one shadow draw) for many identical props.
static func batch(mesh: Mesh, transforms: Array[Transform3D], colors: PackedColorArray) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i] if i < colors.size() else Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = batch_material()
	return mmi


## Collision-only box (no draw call). `xform` must be unscaled.
static func box_shape(size: Vector3, xform: Transform3D) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xform
	return cs


## Tall building shell: static collider + a mesh using the camera cut-away occluder shader.
static func building(size: Vector3, pos: Vector3, tint: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	body.add_child(box_shape(size, Transform3D()))
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = occluder_material()
	mi.set_instance_shader_parameter(&"tint", tint)
	body.add_child(mi)
	return body
