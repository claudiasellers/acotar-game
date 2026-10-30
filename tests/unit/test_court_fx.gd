extends GutTest

const FX := "res://world/spring_court/wider/fx/"
const SHADERS: Array[String] = [
	"court_foliage", "court_prop", "court_water", "court_glint", "court_terrain_tint",
	"court_particle", "court_particle_glow", "court_butterfly",
]
const PARTICLES: Array[String] = [
	"fx_rose_petals", "fx_cherry_petals", "fx_pollen_motes", "fx_faelights", "fx_will_o_wisps",
	"fx_fireflies", "fx_butterflies", "fx_dandelion_seeds", "fx_sparkle_burst", "fx_starlight_sparkles",
	"fx_water_mist", "fx_bonfire_embers", "fx_bonfire_flame", "fx_bonfire_smoke", "fx_autumn_leaves",
	"fx_blight_ash", "fx_lantern_glow_motes",
]
const MATERIALS: Array[String] = [
	"mat_foliage_default", "mat_foliage_glow", "mat_foliage_blight", "mat_prop_default", "mat_prop_pearl",
	"mat_prop_glitter", "mat_water_lake", "mat_water_river", "mat_water_starlight", "mat_glint",
	"mat_terrain_tint", "mat_particle_lit", "mat_particle_glow", "mat_butterfly",
]
const GRADES: Array[String] = [
	"grade_starlight_glen_day", "grade_starlight_pool_sparkle", "grade_fells", "grade_fae_village",
	"grade_solstice", "grade_solstice_twilight", "grade_hill_of_the_rite_dusk", "grade_rite_calanmai_night",
	"grade_rosewild", "grade_blossom_vale", "grade_autumn_foothills", "grade_blight",
]


func after_all() -> void:
	CourtBlightDriver.set_blight(0.0)


func test_shaders_load_with_code() -> void:
	for id: String in SHADERS:
		var sh := load(FX + "shaders/" + id + ".gdshader") as Shader
		assert_not_null(sh, id)
		if sh != null:
			assert_true(sh.code.begins_with("//") or sh.code.contains("shader_type spatial"), id)
			assert_true(sh.code.contains("shader_type spatial"), id + " is spatial")
	assert_not_null(load(FX + "shaders/court_fx_common.gdshaderinc"), "common include")


func test_materials_are_shader_materials() -> void:
	for id: String in MATERIALS:
		var m := load(FX + "materials/" + id + ".tres") as ShaderMaterial
		assert_not_null(m, id)
		if m != null:
			assert_not_null(m.shader, id + " shader")


func test_particle_scenes_instance_within_budget() -> void:
	for id: String in PARTICLES:
		var ps := load(FX + "particles/" + id + ".tscn") as PackedScene
		assert_not_null(ps, id)
		if ps == null:
			continue
		var p := ps.instantiate() as GPUParticles3D
		assert_not_null(p, id + " root is GPUParticles3D")
		if p == null:
			continue
		assert_lte(p.amount, 2000, id + " amount")
		assert_gt(p.amount, 0, id + " amount")
		assert_gt(p.visibility_aabb.size.length(), 0.0, id + " visibility_aabb")
		assert_not_null(p.process_material, id + " process material")
		assert_not_null(p.draw_pass_1, id + " draw pass")
		p.free()
	var burst := (load(FX + "particles/fx_sparkle_burst.tscn") as PackedScene).instantiate() as GPUParticles3D
	assert_true(burst.one_shot, "sparkle burst is one-shot")
	burst.free()
	var glint := (load(FX + "particles/fx_collectible_glint.tscn") as PackedScene).instantiate() as MeshInstance3D
	assert_not_null(glint, "collectible glint")
	glint.free()


func test_blight_driver_idempotent_and_clamped() -> void:
	var a := CourtBlightDriver.new()
	var b := CourtBlightDriver.new()
	add_child_autofree(a)
	add_child_autofree(b)
	var count := CourtBlightDriver.registered_count()
	assert_gt(count, 0, "shipped materials registered")
	CourtBlightDriver.ensure_shipped_registered()
	assert_eq(CourtBlightDriver.registered_count(), count, "no duplicate registrations")
	CourtBlightDriver.set_blight(2.0)
	assert_eq(CourtBlightDriver.get_blight(), 1.0)
	var foliage := load(FX + "materials/mat_foliage_default.tres") as ShaderMaterial
	assert_almost_eq(float(foliage.get_shader_parameter(&"blight")), 1.0, 0.0001)
	CourtBlightDriver.set_blight(-3.0)
	assert_eq(CourtBlightDriver.get_blight(), 0.0)
	assert_almost_eq(float(foliage.get_shader_parameter(&"blight")), 0.0, 0.0001)
	# The always-blighted material has blight_affect 0: it is not driven and stays grey.
	var dead := load(FX + "materials/mat_foliage_blight.tres") as ShaderMaterial
	assert_false(CourtBlightDriver.register_material(dead))
	assert_almost_eq(float(dead.get_shader_parameter(&"blight")), 1.0, 0.0001)
	CourtBlightDriver.set_blight(0.4)
	assert_almost_eq(CourtBlightDriver.get_blight(), 0.4, 0.0001)


func test_grades_are_presets_with_fog_and_blight_is_greyest() -> void:
	var blight_sat := 0.0
	var min_other := 99.0
	for id: String in GRADES:
		var g := load(FX + "grades/" + id + ".tres") as GradePreset
		assert_not_null(g, id)
		if g == null:
			continue
		assert_eq(String(g.id), id, "id matches file name")
		assert_gt(g.fog_density, 0.0, id + " fog")
		assert_gt(g.volumetric_density, 0.0, id + " volumetric fog")
		assert_not_null(g.lut, id + " lut")
		if id == "grade_blight":
			blight_sat = g.saturation
		else:
			min_other = minf(min_other, g.saturation)
			assert_gt(g.glow_intensity, 0.5, id + " strong glow")
	assert_lt(blight_sat, min_other, "blight is the least saturated")
	assert_true(FileAccess.file_exists(FX + "grades/grades_readme.md"))
