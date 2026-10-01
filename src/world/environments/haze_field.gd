class_name HazeField
extends Node3D
## Ground-haze sheets and dry scrub for a level. One draw each. Density follows the graphics
## preset (`fog_detail`, `foliage_density`) so Low can turn the cards off.

const DUST_SHADER := preload("res://src/shaders/dust.gdshader")
const SCRUB_SHADER := preload("res://src/shaders/scrub.gdshader")
const DUST_CAPACITY := 6
const SCRUB_CAPACITY := 80

var _dust: MultiMeshInstance3D
var _scrub: MultiMeshInstance3D


func _ready() -> void:
	_dust = _make_dust()
	_scrub = _make_scrub()
	add_child(_dust)
	add_child(_scrub)
	_apply(Settings.get_preset())
	EventBus.graphics_preset_applied.connect(_apply)


func _apply(p: GraphicsPreset) -> void:
	if p == null or _dust == null:
		return
	_dust.multimesh.visible_instance_count = mini(DUST_CAPACITY, p.fog_detail * 2)
	var scrub_count := int(round(float(SCRUB_CAPACITY) * p.foliage_density))
	_scrub.multimesh.visible_instance_count = mini(_scrub.multimesh.instance_count, scrub_count)


func _make_dust() -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(96.0, 96.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = DUST_CAPACITY
	var heights: Array[float] = [0.35, 0.85, 1.45, 0.55, 1.15, 2.1]
	var offsets: Array[Vector3] = [
		Vector3(0, 0, 0),
		Vector3(22, 0, -8),
		Vector3(-16, 0, 14),
		Vector3(8, 0, 20),
		Vector3(-24, 0, -18),
		Vector3(4, 0, -28),
	]
	var lie := Basis(Vector3.RIGHT, -PI * 0.5)
	for i in DUST_CAPACITY:
		var at := offsets[i] + Vector3(0, heights[i], 0)
		mm.set_instance_transform(i, Transform3D(lie, at))
		mm.set_instance_color(i, Color(1, 1, 1, 0.55 + float(i % 3) * 0.15))
	var mat := ShaderMaterial.new()
	mat.shader = DUST_SHADER
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func _make_scrub() -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var xforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	var guard := 0
	while xforms.size() < SCRUB_CAPACITY and guard < SCRUB_CAPACITY * 6:
		guard += 1
		var x := rng.randf_range(-40.0, 40.0)
		var z := rng.randf_range(-40.0, 40.0)
		if absf(x) < 4.0:
			continue
		if Vector2(x, z - 12.0).length() < 3.2:
			continue
		var s := rng.randf_range(0.65, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, rng.randf_range(0.7, 1.25), s))
		xforms.append(Transform3D(basis, Vector3(x, 0.0, z)))
		colors.append(Color(0.98, 0.86, 0.12).lerp(Color(0.55, 0.72, 0.18), rng.randf()))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = PropMeshes.scrub_card()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mat := ShaderMaterial.new()
	mat.shader = SCRUB_SHADER
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
