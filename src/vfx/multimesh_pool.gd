class_name MultiMeshPool
extends MultiMeshInstance3D
## Base for effects rendered as ONE draw call: fixed-capacity packed arrays + a MultiMesh whose
## visible_instance_count tracks the live count. Removal is swap-with-last (O(1), order-free).
## Subclasses implement _make_mesh(), _make_material() and _write_instance(i).

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


## Transform that stretches a unit box (1 m along local Z) from `a` to `b` with `width`.
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
