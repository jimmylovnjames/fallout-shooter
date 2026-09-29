class_name MeshMerge
extends RefCounted
## Merges primitive meshes into ONE surface with per-part vertex colours, so a multi-part greybox
## actor costs one draw (plus its outline pass) instead of one per part (PERF.md: 2-surface
## outlined actors cost 4 draws).


## parts: Array of {mesh: PrimitiveMesh, transform: Transform3D, color: Color}
static func merge(parts: Array[Dictionary]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for part in parts:
		var arrays: Array = (part["mesh"] as PrimitiveMesh).get_mesh_arrays()
		var xf: Transform3D = part["transform"]
		var c: Color = part["color"]
		var base := verts.size()
		var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in pv.size():
			verts.append(xf * pv[i])
			normals.append((xf.basis * pn[i]).normalized())
			colors.append(c)
		var pi: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for idx in pi:
			indices.append(base + idx)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh
