extends GutTest
## Contract for grade unification (render program T3b, L63): every grade is
## AgX with one grade layer, a 32³ Texture3D LUT built from LutParams; the
## Spring grades carry R3's soft strong bloom; the horror grades keep theirs;
## the bright day grades roll their whites off below 0.98.
# gate: when:world/shared/grades/*,data/grades/*,tools/env/make_lut.gd

const SPRING := [&"spring", &"human_spring", &"manor", &"grade_blossom_vale", &"grade_rosewild",
	&"grade_solstice", &"grade_fae_village", &"grade_starlight_glen_day", &"grade_starlight_pool_sparkle"]
const HORROR := [&"dread", &"bogge", &"blight", &"grade_blight"]


func _ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for f in DirAccess.get_files_at(GradeDirector.PRESET_DIR):
		if f.ends_with(".tres"):
			out.append(StringName(f.get_basename()))
	return out


func test_every_grade_is_agx_with_a_lut_built_from_parameters() -> void:
	var ids := _ids()
	assert_gte(ids.size(), 20, "all the grades")
	for id in ids:
		var p := GradeDirector.load_preset(id)
		assert_eq(p.tonemap_mode, Environment.TONE_MAPPER_AGX, "%s is AgX" % id)
		assert_null(p.lut, "%s: no legacy 1D LUT left" % id)
		assert_not_null(p.lut_params, "%s has LUT parameters" % id)
		if p.lut_params == null:
			continue
		assert_eq(p.lut_params.resource_path, "res://data/grades/luts/%s.tres" % id, "%s: parameters live in data/" % id)
		var l := p.lut_params
		assert_true(l.lift == Color(0, 0, 0) and l.gamma == Color(1, 1, 1) and l.gain == Color(1, 1, 1) \
			and is_zero_approx(l.hue_shift), "%s: lift/gamma/gain and hue ship as identity" % id)
		# T3b's only look moves: the saturation curve that gives AgX back
		# today's chroma (rising with luma, where AgX drains it) and the white roll-off.
		assert_lte(l.shadow_saturation, l.highlight_saturation, "%s: the curve rises with luma" % id)
		assert_lte(l.shadow_saturation, 1.35, "%s: shadows and mid-tones stay pastel" % id)
		assert_between(l.highlight_saturation, 1.0, 1.8, "%s: chroma restore stays bounded" % id)
		assert_between(l.white_level, 0.95, 1.0, id)
		for k: StringName in [&"saturation", &"contrast", &"brightness"]:
			assert_eq(p.get(k), 1.0, "%s.%s is folded into the LUT (one grade layer)" % [id, k])
	var tex := GradeDirector.load_preset(&"spring").lut_texture()
	assert_true(tex is Texture3D, "a Texture3D")
	assert_eq([tex.get_width(), tex.get_height(), tex.get_depth()], [32, 32, 32])


func test_the_lut_is_the_old_grade() -> void:
	# Spring's old adjustment sliders (contrast 1.15, saturation 1.22), folded
	# with Godot 4.7's maths, on one colour; identity parameters change nothing.
	var c := Color(0.62, 0.48, 0.40)
	var spring := (GradeDirector.load_preset(&"spring")).lut_params
	var l := LutParams.new()
	l.contrast = spring.contrast
	l.saturation = spring.saturation
	var v := (Vector3(c.r, c.g, c.b) - Vector3.ONE * 0.5) * 1.15 + Vector3.ONE * 0.5
	var avg := (v.x + v.y + v.z) / 3.0
	v = Vector3(avg, avg, avg).lerp(v, 1.22)
	var got := l.apply(c)
	assert_almost_eq(Vector3(got.r, got.g, got.b), v, Vector3.ONE * 0.0005)
	assert_eq(LutParams.new().apply(c), c, "identity is identity")
	assert_eq([LutParams.texel_input(0), LutParams.texel_input(31)], [0.0, 1.0], "black and white exact")


func test_spring_grades_bloom_to_r3_and_horror_keeps_its_dark() -> void:
	for id: StringName in SPRING:
		var p := GradeDirector.load_preset(id)
		assert_almost_eq(p.glow_intensity, 0.7, 0.05, "%s glow" % id)
		assert_almost_eq(p.glow_bloom, 0.2, 0.02, "%s bloom" % id)
		assert_almost_eq(p.glow_hdr_threshold, 1.0, 0.05, "%s threshold" % id)
	for id: StringName in HORROR:
		var p := GradeDirector.load_preset(id)
		assert_eq(p.glow_bloom, 0.0, "%s: no bloom haze over the horror" % id)
		assert_lt(p.graded(&"saturation"), 0.5, "%s stays drained" % id)
		assert_gt(p.graded(&"contrast"), 1.05, "%s keeps its contrast" % id)


func test_blends_and_moods_stay_smooth_across_the_lut_switch() -> void:
	var a := GradeDirector.load_preset(&"human_winter")
	var b := GradeDirector.load_preset(&"spring")
	var before := GradePreset.mix(a, b, 0.499)
	var after := GradePreset.mix(a, b, 0.501)
	assert_ne(before.lut_params, after.lut_params, "the LUT switches at half")
	# The shown saturation is the slider times the LUT's folded value.
	var shown_before := before.saturation * before.lut_params.saturation
	var shown_after := after.saturation * after.lut_params.saturation
	assert_almost_eq(shown_before, shown_after, 0.01, "no saturation pop at the switch")
	var cold := GradeDirector.with_mood(b, 1.0, &"dread")
	assert_eq(cold.lut_params, b.lut_params, "a mood keeps the grade's LUT")
	assert_eq(cold.tonemap_mode, Environment.TONE_MAPPER_AGX)


func test_bright_day_grades_never_reach_paper_white() -> void:
	for id: StringName in [&"grade_blossom_vale", &"grade_starlight_pool_sparkle", &"human_spring", &"grade_solstice"]:
		var l := GradeDirector.load_preset(id).lut_params
		var white := l.apply(Color(1, 1, 1))
		assert_lt(maxf(white.r, maxf(white.g, white.b)), 0.98, "%s: white rolls off under 0.98" % id)
	var roll := LutParams.new()
	roll.white_level = 0.97
	assert_true(roll.apply(Color(0.5, 0.6, 0.79)).is_equal_approx(Color(0.5, 0.6, 0.79)), "nothing below the knee moves")
	assert_almost_eq(roll.apply(Color(1, 1, 1)).r, 0.97, 0.0001)
	assert_gt(roll.apply(Color(0.95, 0.95, 0.95)).r, roll.apply(Color(0.9, 0.9, 0.9)).r, "still rising: no flat band")
