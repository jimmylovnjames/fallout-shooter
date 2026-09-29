class_name BurstPool
extends MultiMeshPool
## Impact sparks / muzzle flashes: a low-poly ball that pops out and shrinks. One draw call.

var _pos := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _color := PackedColorArray()


func _allocate(n: int) -> void:
	_pos.resize(n)
	_age.resize(n)
	_life.resize(n)
	_size.resize(n)
	_color.resize(n)


func _make_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	return m


func spawn(at: Vector3, size: float, color: Color, life_s: float = 0.12) -> void:
	if live >= capacity:
		return
	_pos[live] = at
	_age[live] = 0.0
	_life[live] = life_s
	_size[live] = size
	_color[live] = color
	live += 1


func _process(delta: float) -> void:
	var i := 0
	while i < live:
		_age[i] += delta
		if _age[i] >= _life[i]:
			live -= 1
			_pos[i] = _pos[live]
			_age[i] = _age[live]
			_life[i] = _life[live]
			_size[i] = _size[live]
			_color[i] = _color[live]
			continue
		var t := _age[i] / _life[i]
		var s := _size[i] * (0.4 + 0.6 * sin(t * PI))
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), _pos[i]))
		multimesh.set_instance_color(i, _color[i])
		i += 1
	_sync_visible()
