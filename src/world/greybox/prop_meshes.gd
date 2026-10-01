class_name PropMeshes
extends RefCounted
## Shared low-poly silhouettes that still batch as one MultiMesh. Not final art.


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
