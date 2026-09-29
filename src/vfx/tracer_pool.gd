class_name TracerPool
extends MultiMeshPool
## Short-lived hitscan tracers (bright segments that thin out over their lifetime).

const LIFE_S := 0.07
const WIDTH := 0.06

var _a := PackedVector3Array()
var _b := PackedVector3Array()
var _age := PackedFloat32Array()
var _color := PackedColorArray()


func _allocate(n: int) -> void:
	_a.resize(n)
	_b.resize(n)
	_age.resize(n)
	_color.resize(n)


func spawn(from: Vector3, to: Vector3, color: Color) -> void:
	if live >= capacity:
		return
	_a[live] = from
	_b[live] = to
	_age[live] = 0.0
	_color[live] = color
	live += 1


func _process(delta: float) -> void:
	var i := 0
	while i < live:
		_age[i] += delta
		if _age[i] >= LIFE_S:
			live -= 1
			_a[i] = _a[live]
			_b[i] = _b[live]
			_age[i] = _age[live]
			_color[i] = _color[live]
			continue
		var k := 1.0 - _age[i] / LIFE_S
		multimesh.set_instance_transform(i, segment_transform(_a[i], _b[i], WIDTH * k))
		multimesh.set_instance_color(i, _color[i])
		i += 1
	_sync_visible()
