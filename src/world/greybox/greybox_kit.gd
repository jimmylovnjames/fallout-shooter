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
const SURFACE_SHADER := preload("res://src/shaders/world_surface.gdshader")
const GROUND_SHADER := preload("res://src/shaders/ground.gdshader")
## world_surface.gdshader style ids that are not a Palette entry.
const STYLE_ROCK := 7
const STYLE_BARK := 8

const _ROUGHNESS: Dictionary[Palette, float] = {
	Palette.CONCRETE: 0.9,
	Palette.RUST: 0.58,
	Palette.SAND: 0.96,
	Palette.WOOD: 0.78,
	Palette.ACCENT: 0.48,
	Palette.DARK: 0.4,
}
const _METALLIC: Dictionary[Palette, float] = {
	Palette.CONCRETE: 0.0,
	Palette.RUST: 0.42,
	Palette.SAND: 0.0,
	Palette.WOOD: 0.0,
	Palette.ACCENT: 0.12,
	Palette.DARK: 0.7,
}

static var _materials: Dictionary[Palette, ShaderMaterial] = {}
static var _outlined: Dictionary[Palette, ShaderMaterial] = {}
static var _batch_material: ShaderMaterial
static var _styled: Dictionary[String, ShaderMaterial] = {}
static var _ground_mat: ShaderMaterial
static var _occluder_material: ShaderMaterial
static var _unit_box: BoxMesh
static var _rock_mesh: ArrayMesh


static func material(p: Palette) -> ShaderMaterial:
	if not _materials.has(p):
		var m := ShaderMaterial.new()
		m.shader = SURFACE_SHADER
		m.set_shader_parameter(&"albedo", _COLORS[p])
		m.set_shader_parameter(&"roughness_amt", _ROUGHNESS[p])
		m.set_shader_parameter(&"metallic_amt", _METALLIC[p])
		m.set_shader_parameter(&"style", int(p))
		_materials[p] = m
	return _materials[p]


## Same colour, with the inverted-hull outline as next_pass (actors/interactables only).
static func outlined_material(p: Palette) -> ShaderMaterial:
	if not _outlined.has(p):
		var m := material(p).duplicate() as ShaderMaterial
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
	var splits := clampi(int(size_m / 4.0), 8, 48)
	mesh.subdivide_width = splits
	mesh.subdivide_depth = splits
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _ground_material()
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
	scale_range: Vector2 = Vector2(0.6, 1.4),
	deform: float = 0.0,
	style: int = -1
) -> MultiMeshInstance3D:
	var xforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	for i in count:
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.5, 1.2), s))
		var pos := Vector3(rng.randf_range(-extent, extent), 0.0, rng.randf_range(-extent, extent))
		xforms.append(Transform3D(basis, pos))
		colors.append(_COLORS[p])
	var resolved := style if style >= 0 else (STYLE_ROCK if deform > 0.0 else int(p))
	return batch(mesh, xforms, colors, resolved, deform)


static func rock_mesh() -> Mesh:
	if _rock_mesh == null:
		_rock_mesh = _build_rock_mesh()
	return _rock_mesh


# --- P1: collidable, batched level pieces ----------------------------------------------------------


## Shared base for MultiMesh props. Colour is the instance colour. Style and deform are uniforms,
## so each (style, deform) pair is its own material; instances of one batch still share it.
static func batch_material() -> ShaderMaterial:
	if _batch_material == null:
		_batch_material = ShaderMaterial.new()
		_batch_material.shader = SURFACE_SHADER
		_batch_material.set_shader_parameter(&"albedo", Color.WHITE)
		_batch_material.set_shader_parameter(&"roughness_amt", 0.86)
		_batch_material.set_shader_parameter(&"metallic_amt", 0.0)
		_batch_material.set_shader_parameter(&"style", 0)
		_batch_material.set_shader_parameter(&"deform_amt", 0.0)
	return _batch_material


static func occluder_material() -> ShaderMaterial:
	if _occluder_material == null:
		_occluder_material = ShaderMaterial.new()
		_occluder_material.shader = OCCLUDER_SHADER
	return _occluder_material


## One MultiMesh (one draw + one shadow draw) for many identical props.
## `style` is a world_surface style id. `deform` pushes vertices along the normal per instance.
static func batch(
	mesh: Mesh, transforms: Array[Transform3D], colors: PackedColorArray, style: int = 0, deform: float = 0.0
) -> MultiMeshInstance3D:
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
	mmi.material_override = _styled_material(style, deform)
	return mmi


## Buildings as one scaled unit-box MultiMesh (cut-away shader reads instance colour).
static func batch_occluders(transforms: Array[Transform3D], colors: PackedColorArray) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _unit_box_mesh()
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i] if i < colors.size() else Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = occluder_material()
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
	var mi := MeshInstance3D.new()
	mi.mesh = _unit_box_mesh()
	mi.scale = size
	mi.material_override = occluder_material()
	mi.set_instance_shader_parameter(&"tint", tint)
	body.add_child(mi)
	return body


static func _styled_material(style: int, deform: float) -> ShaderMaterial:
	var key := "%d@%.3f" % [style, deform]
	if not _styled.has(key):
		var m := batch_material().duplicate() as ShaderMaterial
		m.set_shader_parameter(&"style", style)
		m.set_shader_parameter(&"deform_amt", deform)
		_styled[key] = m
	return _styled[key]


static func _ground_material() -> ShaderMaterial:
	if _ground_mat == null:
		_ground_mat = ShaderMaterial.new()
		_ground_mat.shader = GROUND_SHADER
	return _ground_mat


static func _unit_box_mesh() -> BoxMesh:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	return _unit_box


## Faceted pebble. Flat normals so per-instance deform reads as a rock, not a blob.
static func _build_rock_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.36
	sphere.radial_segments = 6
	sphere.rings = 3
	var src: PackedVector3Array = sphere.get_mesh_arrays()[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = sphere.get_mesh_arrays()[Mesh.ARRAY_INDEX]
	var displaced := PackedVector3Array()
	for v: Vector3 in src:
		var len := v.length()
		if len < 0.001:
			displaced.append(v)
		else:
			displaced.append(v.normalized() * len * (0.72 + 0.5 * _unit_hash(v)))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var out_idx := PackedInt32Array()
	var f := 0
	while f < indices.size():
		var a := displaced[indices[f]]
		var b := displaced[indices[f + 1]]
		var c := displaced[indices[f + 2]]
		a.y *= 0.72
		b.y *= 0.72
		c.y *= 0.72
		var face_n := (b - a).cross(c - a)
		if face_n.length_squared() < 0.000001:
			f += 3
			continue
		face_n = face_n.normalized()
		var base := verts.size()
		verts.append(a)
		verts.append(b)
		verts.append(c)
		normals.append(face_n)
		normals.append(face_n)
		normals.append(face_n)
		out_idx.append(base)
		out_idx.append(base + 1)
		out_idx.append(base + 2)
		f += 3
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_INDEX] = out_idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


static func _unit_hash(v: Vector3) -> float:
	var s := sin(v.dot(Vector3(12.9898, 78.233, 45.164))) * 43758.5453
	return s - floor(s)
