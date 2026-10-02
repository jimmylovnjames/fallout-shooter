class_name MultiMeshPool
extends MultiMeshInstance3D
## Base for effects rendered as ONE draw call: fixed-capacity packed arrays + a MultiMesh whose
## visible_instance_count tracks the live count. Removal is swap-with-last (O(1), order-free).
## Subclasses implement _make_mesh(), _make_material() and _write_instance(i).

static var _beam_mesh: ArrayMesh

@export var capacity: int = 256

var live: int = 0


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _make_mesh()
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	# Effects roam the whole level: a fixed large AABB avoids per-frame AABB recomputation.
	mm.custom_aabb = AABB(Vector3(-512, -64, -512), Vector3(1024, 128, 1024))
	multimesh = mm
	material_override = _make_material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_allocate(capacity)


func _allocate(_n: int) -> void:
	pass


func _make_mesh() -> Mesh:
	return BoxMesh.new()


func _make_material() -> Material:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	return m


func _sync_visible() -> void:
	multimesh.visible_instance_count = live


## Two ribbons (flat and upright) so a bolt reads from the high camera. Unit size, local Z is the length.
static func beam_mesh() -> ArrayMesh:
	if _beam_mesh == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		var flat := Basis(Vector3.RIGHT, -PI * 0.5)
		var upright := Basis(Vector3.UP, PI * 0.5)
		var parts: Array[Dictionary] = [
			{"mesh": quad, "transform": Transform3D(flat, Vector3.ZERO), "color": Color.WHITE},
			{"mesh": quad, "transform": Transform3D(upright, Vector3.ZERO), "color": Color.WHITE},
		]
		_beam_mesh = MeshMerge.merge(parts)
	return _beam_mesh


static func beam_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/shaders/beam.gdshader")
	return m


## Transform that stretches a unit segment (1 m along local Z) from `a` to `b` with `width`.
static func segment_transform(a: Vector3, b: Vector3, width: float) -> Transform3D:
	var d := b - a
	var len := d.length()
	if len < 0.0001:
		return Transform3D(Basis.from_scale(Vector3(width, width, width)), a)
	var z := d / len
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	var basis := Basis(x * width, y * width, z * len)
	return Transform3D(basis, (a + b) * 0.5)
