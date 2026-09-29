extends GutTest


func test_merge_single_surface_with_part_colours() -> void:
	var a := BoxMesh.new()
	var b := SphereMesh.new()
	b.radial_segments = 8
	b.rings = 4
	var parts: Array[Dictionary] = [
		{"mesh": a, "transform": Transform3D(), "color": Color(1, 0, 0, 1)},
		{"mesh": b, "transform": Transform3D(Basis(), Vector3(0, 2, 0)), "color": Color(0, 0, 1, 0)},
	]
	var m := MeshMerge.merge(parts)
	assert_eq(m.get_surface_count(), 1)
	var arrays := m.surface_get_arrays(0)
	var na: int = (a.get_mesh_arrays()[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var nb: int = (b.get_mesh_arrays()[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_eq(colors.size(), na + nb)
	assert_eq(colors[0], Color(1, 0, 0, 1))
	assert_eq(colors[na], Color(0, 0, 1, 0))
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(verts[na].y, 1.0, "second part transformed")


func test_actor_mesh_is_one_surface() -> void:
	assert_eq(ActorVisual.shared_mesh().get_surface_count(), 1, "one draw (+outline) per actor")
	assert_not_null(ActorVisual.shared_material().next_pass, "outline pass")
