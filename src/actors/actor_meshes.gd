class_name ActorMeshes
extends RefCounted
## Stylized silhouettes for the top-down camera. Each result is ONE surface (D030).
## Vertex alpha 1 is cloth and takes the actor tint. Alpha 0 is gear and keeps its colour:
## warm gear lamps amber, cold gear lamps cyan (see actor.gdshader).


static func player() -> ArrayMesh:
	var parts: Array[Dictionary] = [
		_box(Vector3(0.46, 0.72, 0.32), Vector3(0, 1.08, 0.02), Color(1, 1, 1, 1)),
		_box(Vector3(0.66, 0.42, 0.4), Vector3(0, 0.5, 0.04), Color(0.92, 0.9, 0.88, 1)),
		_box(Vector3(0.22, 0.14, 0.3), Vector3(-0.4, 1.4, 0), Color(0.82, 0.78, 0.74, 1)),
		_box(Vector3(0.22, 0.14, 0.3), Vector3(0.4, 1.4, 0), Color(0.82, 0.78, 0.74, 1)),
		_box(Vector3(0.34, 0.26, 0.32), Vector3(0, 1.62, -0.02), Color(0.32, 0.08, 0.02, 0)),
		_box(Vector3(0.38, 0.1, 0.08), Vector3(0, 1.64, -0.2), Color(1, 0.42, 0.05, 0)),
		_box(Vector3(0.4, 0.08, 0.34), Vector3(0, 1.22, -0.02), Color(0.1, 0.09, 0.08, 0)),
		_box(Vector3(0.14, 0.16, 0.2), Vector3(-0.14, 0.1, 0.02), Color(0.08, 0.07, 0.06, 0)),
		_box(Vector3(0.14, 0.16, 0.2), Vector3(0.14, 0.1, 0.02), Color(0.08, 0.07, 0.06, 0)),
		_box(Vector3(0.09, 0.11, 0.42), Vector3(0.42, 1.08, -0.42), Color(0.18, 0.07, 0.03, 0)),
		_box(Vector3(0.05, 0.05, 0.28), Vector3(0.42, 1.12, -0.72), Color(0.28, 0.12, 0.04, 0)),
		_box(Vector3(0.08, 0.16, 0.09), Vector3(0.42, 0.94, -0.26), Color(0.14, 0.06, 0.03, 0)),
	]
	return MeshMerge.merge(parts)


static func scavenger() -> ArrayMesh:
	var parts: Array[Dictionary] = [
		_box(Vector3(0.36, 0.62, 0.28), Vector3(0, 0.92, 0.04), Color(1, 1, 1, 1)),
		_box(Vector3(0.48, 0.22, 0.34), Vector3(0.06, 0.48, 0.06), Color(0.7, 0.74, 0.76, 1)),
		_sphere(0.28, Vector3(0, 1.52, 0.02), Color(0.78, 0.82, 0.84, 1)),
		_box(Vector3(0.2, 0.06, 0.06), Vector3(0, 1.5, -0.24), Color(0.15, 0.82, 0.95, 0)),
		_box(Vector3(0.5, 0.46, 0.3), Vector3(0, 1.12, 0.32), Color(0.45, 0.5, 0.52, 1)),
		_box(Vector3(0.1, 0.34, 0.22), Vector3(-0.32, 1.28, 0.02), Color(0.55, 0.32, 0.12, 0)),
		_box(Vector3(0.08, 0.08, 1.15), Vector3(0.02, 1.02, -0.62), Color(0.14, 0.13, 0.12, 0)),
	]
	return MeshMerge.merge(parts)


static func _box(size: Vector3, pos: Vector3, color: Color) -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size = size
	return {"mesh": mesh, "transform": Transform3D(Basis(), pos), "color": color}


static func _sphere(radius: float, pos: Vector3, color: Color) -> Dictionary:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return {"mesh": mesh, "transform": Transform3D(Basis(), pos), "color": color}
