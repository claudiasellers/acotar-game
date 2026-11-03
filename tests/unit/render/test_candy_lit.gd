extends GutTest
## Contract for the candy_lit surface model (render program T2): the import
## remap turns a StandardMaterial3D into candy_lit carrying its values, and
## MaterialLibrary only hands out candy_lit materials.


func test_remap_carries_the_surface_values() -> void:
	var src := StandardMaterial3D.new()
	src.albedo_color = Color(0.9, 0.6, 0.7)
	src.roughness = 0.35
	src.metallic = 0.4
	src.vertex_color_use_as_albedo = true
	src.normal_enabled = true
	src.normal_texture = PlaceholderTexture2D.new()
	src.albedo_texture = PlaceholderTexture2D.new()
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.material = src
	mi.mesh = mesh
	root.add_child(mi)
	assert_eq(CandyMaterial.remap_scene(root), 1)
	var m := mi.mesh.surface_get_material(0) as CandyMaterial
	assert_not_null(m, "the surface is candy_lit")
	assert_eq(m.albedo_color, src.albedo_color)
	assert_almost_eq(m.roughness, 0.35, 0.001)
	assert_almost_eq(m.metallic, 0.4, 0.001)
	assert_true(m.vertex_color_use_as_albedo)
	assert_eq(m.normal_texture, src.normal_texture)
	assert_eq(m.albedo_texture, src.albedo_texture)
	assert_true(m.shader.resource_path.begins_with("res://world/shared/shaders/candy"), m.shader.resource_path)
	root.free()


func test_render_flags_pick_a_candy_variant() -> void:
	var src := StandardMaterial3D.new()
	src.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	src.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := CandyMaterial.from_base(src)
	assert_eq(m.variant_key(), "alpha-double")
	assert_eq(m.shader.resource_path, "res://world/shared/shaders/candy/candy_alpha-double.gdshader")
	m.albedo_color = Color(0.2, 0.4, 0.6, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	assert_eq(m.albedo_color, Color(0.2, 0.4, 0.6, 0.5), "values survive a variant change")


func test_material_library_returns_candy_kinds() -> void:
	assert_true(MaterialLibrary.surface() is CandyMaterial)
	assert_eq(MaterialLibrary.surface().shader.resource_path, CandyMaterial.DEFAULT_SHADER)
	for kind in MaterialLibrary.KINDS:
		var m := MaterialLibrary.get_material(kind, Color(0.8, 0.7, 0.9))
		assert_true(MaterialLibrary.is_candy(m), "%s is candy_lit" % kind)


func test_material_library_holds_the_albedo_cap() -> void:
	assert_almost_eq(CandyMaterial.MAX_ALBEDO, 0.85, 0.0001)
	for kind in MaterialLibrary.KINDS:
		var m := MaterialLibrary.get_material(kind, Color.WHITE)
		var cm := m as CandyMaterial
		if cm == null or cm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			continue
		var shown := cm.shown_albedo()
		assert_lte(maxf(shown.r, maxf(shown.g, shown.b)), 0.8501, "%s albedo capped" % kind)
	var surface := (load(CandyMaterial.SURFACE_INC) as ShaderInclude).code
	assert_true(surface.contains("uniform float albedo_cap : hint_range(0.0, 1.0) = 0.85;"), "cap defaults to D9")
	assert_true(surface.contains("ALBEDO = min(col.rgb, vec3(albedo_cap));"), "lit surfaces apply the cap")


func test_the_candy_rim_is_lit_not_emissive() -> void:
	var code := (load("res://world/shared/shaders/candy_lit.gdshaderinc") as ShaderInclude).code
	assert_false(code.contains("EMISSION"), "candy_lit never writes EMISSION")
	assert_true(code.contains("SPECULAR_LIGHT += rim_color.rgb"), "the rim is added per light")
	assert_true(code.contains("#define CANDY_RIM_STRENGTH_DEFAULT 0.0"), "default rim off")
