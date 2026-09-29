class_name ProjectileSystem
extends MultiMeshPool
## Every projectile in the level, simulated as packed arrays and drawn with one MultiMesh
## (DECISIONS D017). Each physics tick sweeps a ray along each projectile's motion.

signal impacted(position: Vector3, normal: Vector3, hit_damageable: bool)

const LENGTH_M := 0.7
const WIDTH_M := 0.09

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _ttl := PackedFloat32Array()
var _damage := PackedFloat32Array()
var _source := PackedInt64Array()
var _mask := PackedInt32Array()
var _color := PackedColorArray()
var _exclude: Array[RID] = []
var _query := PhysicsRayQueryParameters3D.new()
var _no_exclude: Array[RID] = []
var _one_exclude: Array[RID] = [RID()]


func _allocate(n: int) -> void:
	_pos.resize(n)
	_vel.resize(n)
	_ttl.resize(n)
	_damage.resize(n)
	_source.resize(n)
	_mask.resize(n)
	_color.resize(n)
	_exclude.resize(n)
	_query.collide_with_areas = false


## Returns false when the pool is full (the shot is dropped — logged once per session in debug).
func spawn(
	origin: Vector3,
	velocity: Vector3,
	damage: float,
	source_id: int,
	source_rid: RID,
	mask: int,
	range_m: float,
	color: Color
) -> bool:
	if live >= capacity:
		return false
	_pos[live] = origin
	_vel[live] = velocity
	_ttl[live] = range_m / maxf(velocity.length(), 0.001)
	_damage[live] = damage
	_source[live] = source_id
	_mask[live] = mask
	_color[live] = color
	_exclude[live] = source_rid
	live += 1
	return true


func _physics_process(delta: float) -> void:
	if live == 0:
		_sync_visible()
		return
	var space := get_world_3d().direct_space_state
	var i := 0
	while i < live:
		var from := _pos[i]
		var to := from + _vel[i] * delta
		_query.from = from
		_query.to = to
		_query.collision_mask = _mask[i]
		if _exclude[i].is_valid():
			_one_exclude[0] = _exclude[i]
			_query.exclude = _one_exclude
		else:
			_query.exclude = _no_exclude
		var hit := space.intersect_ray(_query)
		if not hit.is_empty():
			_resolve_hit(i, hit)
			_remove(i)
			continue
		_pos[i] = to
		_ttl[i] -= delta
		if _ttl[i] <= 0.0:
			_remove(i)
			continue
		i += 1
	_write_transforms()


func _resolve_hit(i: int, hit: Dictionary) -> void:
	var health := Hitscan.health_of(hit["collider"])
	if health != null:
		health.apply_damage(DamageInfo.make(_damage[i], _source[i], hit["position"], _vel[i].normalized()))
	impacted.emit(hit["position"], hit["normal"], health != null)


func _remove(i: int) -> void:
	live -= 1
	_pos[i] = _pos[live]
	_vel[i] = _vel[live]
	_ttl[i] = _ttl[live]
	_damage[i] = _damage[live]
	_source[i] = _source[live]
	_mask[i] = _mask[live]
	_color[i] = _color[live]
	_exclude[i] = _exclude[live]


func _write_transforms() -> void:
	for i in live:
		var dir := _vel[i].normalized()
		multimesh.set_instance_transform(i, segment_transform(_pos[i] - dir * LENGTH_M, _pos[i], WIDTH_M))
		multimesh.set_instance_color(i, _color[i])
	_sync_visible()
