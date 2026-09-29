class_name ActorVisual
extends Node3D
## Greybox actor body: one merged surface + outline pass, shared by every actor. Per-actor look
## (tint, hit flash, dissolve) goes through instance uniforms, so no material is ever duplicated.

signal dissolved

const ACTOR_SHADER := preload("res://src/shaders/actor.gdshader")
const OUTLINE_SHADER := preload("res://src/shaders/outline_hull.gdshader")
const FLASH_DECAY_PER_S := 9.0

static var _shared_mesh: ArrayMesh
static var _shared_material: ShaderMaterial

var _mi: MeshInstance3D
var _tint := Color.WHITE
var _flash := 0.0
var _dissolve := 0.0
var _dissolve_rate := 0.0


func _ready() -> void:
	_mi = MeshInstance3D.new()
	_mi.name = "Body"
	_mi.mesh = shared_mesh()
	_mi.material_override = shared_material()
	add_child(_mi)
	_mi.set_instance_shader_parameter(&"tint", _tint)
	set_process(false)


func set_tint(c: Color) -> void:
	_tint = c
	if _mi != null:
		_mi.set_instance_shader_parameter(&"tint", c)


func flash(strength: float = 1.0) -> void:
	_flash = maxf(_flash, strength)
	set_process(true)


func dissolve_out(duration: float) -> void:
	_dissolve = 0.001
	_dissolve_rate = 1.0 / maxf(duration, 0.01)
	set_process(true)


func reset() -> void:
	_flash = 0.0
	_dissolve = 0.0
	_dissolve_rate = 0.0
	_mi.set_instance_shader_parameter(&"hit_flash", 0.0)
	_mi.set_instance_shader_parameter(&"dissolve", 0.0)
	set_process(false)


func is_dissolving() -> bool:
	return _dissolve > 0.0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - FLASH_DECAY_PER_S * delta, 0.0)
		_mi.set_instance_shader_parameter(&"hit_flash", _flash)
	if _dissolve_rate > 0.0:
		_dissolve = minf(_dissolve + _dissolve_rate * delta, 1.0)
		_mi.set_instance_shader_parameter(&"dissolve", _dissolve)
		if _dissolve >= 1.0:
			_dissolve_rate = 0.0
			dissolved.emit()
	if _flash <= 0.0 and _dissolve_rate <= 0.0:
		set_process(false)


static func shared_material() -> ShaderMaterial:
	if _shared_material == null:
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = ACTOR_SHADER
		_shared_material.next_pass = outline
	return _shared_material


## Capsule body (tintable), head band, and a dark box weapon pointing along -Z (forward).
static func shared_mesh() -> ArrayMesh:
	if _shared_mesh == null:
		var body := CapsuleMesh.new()
		body.radius = 0.35
		body.height = 1.8
		body.radial_segments = 12
		body.rings = 4
		var visor := BoxMesh.new()
		visor.size = Vector3(0.42, 0.12, 0.2)
		var gun := BoxMesh.new()
		gun.size = Vector3(0.12, 0.14, 0.75)
		var parts: Array[Dictionary] = [
			{"mesh": body, "transform": Transform3D(Basis(), Vector3(0, 0.9, 0)), "color": Color(1, 1, 1, 1)},
			{
				"mesh": visor,
				"transform": Transform3D(Basis(), Vector3(0, 1.5, -0.26)),
				"color": Color(0.1, 0.1, 0.1, 0)
			},
			{
				"mesh": gun,
				"transform": Transform3D(Basis(), Vector3(0.3, 1.15, -0.4)),
				"color": Color(0.15, 0.14, 0.13, 0)
			},
		]
		_shared_mesh = MeshMerge.merge(parts)
	return _shared_mesh
