class_name PropMeshes
extends RefCounted
## Shared low-poly silhouettes that still batch as one MultiMesh. Not final art.

static var _shell: ArrayMesh
static var _wreck: ArrayMesh
static var _lamp_post: ArrayMesh
static var _lamp_bulb: ArrayMesh


static func dead_tree() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.07
	trunk.bottom_radius = 0.16
	trunk.height = 3.3
	trunk.radial_segments = 5
	var branch := CylinderMesh.new()
	branch.top_radius = 0.035
	branch.bottom_radius = 0.06
	branch.height = 1.25
	branch.radial_segments = 5
	var lean := Basis(Vector3.RIGHT, deg_to_rad(62.0))
	var parts: Array[Dictionary] = [
		{"mesh": trunk, "transform": Transform3D(Basis(), Vector3(0, 1.65, 0)), "color": Color(1, 1, 1, 1)},
		{
			"mesh": branch,
			"transform": Transform3D(lean, Vector3(0.42, 2.25, 0.05)),
			"color": Color(0.78, 0.74, 0.68, 1),
		},
	]
	return MeshMerge.merge(parts)


## Unit building (1×1×1, centered). UV tag: 0 glass, 1 wall, 2 interior floor.
static func building_shell() -> ArrayMesh:
	if _shell == null:
		_shell = _build_shell()
	return _shell


static func wreck() -> ArrayMesh:
	if _wreck == null:
		_wreck = _build_wreck()
	return _wreck


static func lamp_post() -> ArrayMesh:
	if _lamp_post == null:
		_lamp_post = _build_lamp_post()
	return _lamp_post


static func lamp_bulb() -> ArrayMesh:
	if _lamp_bulb == null:
		_lamp_bulb = _build_lamp_bulb()
	return _lamp_bulb


static func scrub_card() -> ArrayMesh:
	var card := QuadMesh.new()
	card.size = Vector2(1.9, 2.15)
	var lift := card.size.y * 0.5
	var flat := Transform3D(Basis(), Vector3(0, lift, 0))
	var turned := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, lift, 0))
	var parts: Array[Dictionary] = [
		{"mesh": card, "transform": flat, "color": Color.WHITE},
		{"mesh": card, "transform": turned, "color": Color.WHITE},
	]
	return MeshMerge.merge(parts)


static func _build_shell() -> ArrayMesh:
	var parts: Array[Dictionary] = []
	var wall := Color(0.96, 0.94, 0.9, 1)
	parts.append(_tagged(Vector3(1.16, 0.08, 1.16), Vector3(0, 0.46, 0), Basis.IDENTITY, wall, 1.0))
	# Solid core so door and window holes read as shadow, not the desert behind the shell.
	parts.append(_tagged(Vector3(0.66, 0.8, 0.66), Vector3(0, -0.02, 0), Basis.IDENTITY, Color(0.04, 0.03, 0.03), 2.0))
	_facade(parts, 0.0, false, wall)
	_facade(parts, PI, false, wall)
	_facade(parts, PI * 0.5, true, wall)
	_facade(parts, -PI * 0.5, true, wall)
	return MeshMerge.merge(parts)


static func _facade(parts: Array[Dictionary], yaw: float, door: bool, wall: Color) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var z := 0.46
	var thick := 0.12
	var pier_w := 0.3 if door else 0.18
	var pier_x := 0.35 if door else 0.41
	parts.append(_tagged(Vector3(pier_w, 0.92, thick), Vector3(-pier_x, 0.0, z), basis, wall, 1.0))
	parts.append(_tagged(Vector3(pier_w, 0.92, thick), Vector3(pier_x, 0.0, z), basis, wall, 1.0))
	parts.append(_tagged(Vector3(0.7, 0.16, thick), Vector3(0, 0.38, z), basis, wall, 1.0))
	if door:
		return
	parts.append(_tagged(Vector3(0.64, 0.26, thick), Vector3(0, -0.33, z), basis, wall, 1.0))
	parts.append(_tagged(Vector3(0.07, 0.38, thick), Vector3(0, 0.05, z), basis, wall, 1.0))
	var glass := Color(0.2, 0.28, 0.36, 1)
	parts.append(_tagged(Vector3(0.52, 0.38, 0.02), Vector3(0, 0.05, z - 0.04), basis, glass, 0.0))


static func _build_wreck() -> ArrayMesh:
	var body := BoxMesh.new()
	body.size = Vector3(1.7, 0.42, 3.5)
	var cabin := BoxMesh.new()
	cabin.size = Vector3(1.45, 0.5, 1.45)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.32
	wheel.bottom_radius = 0.32
	wheel.height = 0.24
	wheel.radial_segments = 7
	var axle := Basis(Vector3.FORWARD, -PI * 0.5)
	var parts: Array[Dictionary] = [
		{"mesh": body, "transform": Transform3D(Basis(), Vector3(0, 0.52, 0)), "color": Color(0.72, 0.4, 0.16)},
		{"mesh": cabin, "transform": Transform3D(Basis(), Vector3(0, 0.95, -0.4)), "color": Color(0.16, 0.18, 0.22)},
		{"mesh": wheel, "transform": Transform3D(axle, Vector3(-0.86, 0.32, 1.1)), "color": Color(0.08, 0.08, 0.08)},
		{"mesh": wheel, "transform": Transform3D(axle, Vector3(0.86, 0.32, 1.1)), "color": Color(0.08, 0.08, 0.08)},
		{"mesh": wheel, "transform": Transform3D(axle, Vector3(-0.86, 0.32, -1.1)), "color": Color(0.08, 0.08, 0.08)},
		{"mesh": wheel, "transform": Transform3D(axle, Vector3(0.86, 0.32, -1.1)), "color": Color(0.08, 0.08, 0.08)},
	]
	return MeshMerge.merge(parts)


static func _build_lamp_post() -> ArrayMesh:
	var pole := BoxMesh.new()
	pole.size = Vector3(0.12, 3.15, 0.12)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.95, 0.07, 0.07)
	var parts: Array[Dictionary] = [
		{"mesh": pole, "transform": Transform3D(Basis(), Vector3(0, 1.58, 0)), "color": Color(0.15, 0.16, 0.18)},
		{"mesh": arm, "transform": Transform3D(Basis(), Vector3(0.42, 3.08, 0)), "color": Color(0.15, 0.16, 0.18)},
	]
	return MeshMerge.merge(parts)


static func _build_lamp_bulb() -> ArrayMesh:
	var bulb := SphereMesh.new()
	bulb.radius = 0.14
	bulb.height = 0.28
	bulb.radial_segments = 6
	bulb.rings = 2
	var parts: Array[Dictionary] = [
		{"mesh": bulb, "transform": Transform3D(Basis(), Vector3(0.86, 3.02, 0)), "color": Color.WHITE},
	]
	return MeshMerge.merge(parts)


static func _tagged(size: Vector3, pos: Vector3, basis: Basis, color: Color, tag: float) -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size = size
	return {"mesh": mesh, "transform": Transform3D(basis, pos), "color": color, "tag": tag}
