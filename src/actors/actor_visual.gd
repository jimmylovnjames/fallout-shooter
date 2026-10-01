class_name ActorVisual
extends Node3D
## Actor body: one merged surface + outline pass. Player and scavenger use different meshes and
## share one material. Tint, hit flash and dissolve are instance uniforms.

signal dissolved

enum Silhouette { PLAYER, SCAVENGER }

const ACTOR_SHADER := preload("res://src/shaders/actor.gdshader")
const OUTLINE_SHADER := preload("res://src/shaders/outline_hull.gdshader")
const FLASH_DECAY_PER_S := 9.0

static var _player_mesh: ArrayMesh
static var _scavenger_mesh: ArrayMesh
static var _shared_material: ShaderMaterial

@export var silhouette: Silhouette = Silhouette.SCAVENGER

var _mi: MeshInstance3D
var _tint := Color.WHITE
var _flash := 0.0
var _dissolve := 0.0
var _dissolve_rate := 0.0


func _ready() -> void:
	_mi = MeshInstance3D.new()
	_mi.name = "Body"
	_mi.mesh = mesh_for(silhouette)
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


static func mesh_for(kind: Silhouette) -> ArrayMesh:
	match kind:
		Silhouette.PLAYER:
			return player_mesh()
		_:
			return scavenger_mesh()


## Player silhouette. Kept so existing callers still get one outlined surface.
static func shared_mesh() -> ArrayMesh:
	return player_mesh()


static func player_mesh() -> ArrayMesh:
	if _player_mesh == null:
		_player_mesh = ActorMeshes.player()
	return _player_mesh


static func scavenger_mesh() -> ArrayMesh:
	if _scavenger_mesh == null:
		_scavenger_mesh = ActorMeshes.scavenger()
	return _scavenger_mesh
