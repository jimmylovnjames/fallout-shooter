extends GutTest


func test_batch_carries_style_in_custom_data() -> void:
	var xforms: Array[Transform3D] = [Transform3D()]
	var colors := PackedColorArray([Color.WHITE])
	var mm := GreyboxKit.batch(BoxMesh.new(), xforms, colors, GreyboxKit.Palette.WOOD)
	var mat := mm.material_override as ShaderMaterial
	assert_eq(int(mat.get_shader_parameter(&"style")), int(GreyboxKit.Palette.WOOD))
	mm.free()


func test_rock_mesh_is_faceted_single_surface() -> void:
	var mesh := GreyboxKit.rock_mesh()
	assert_eq(mesh.get_surface_count(), 1)
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_gt(normals.size(), 8)
	assert_eq(normals[0], normals[1], "a face shares one normal")


func test_ground_does_not_cast() -> void:
	var ground := GreyboxKit.ground(16.0)
	assert_eq(ground.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_true(ground.material_override is ShaderMaterial)
	ground.free()
