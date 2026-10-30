extends GutTest

var director: GradeDirector


func before_each() -> void:
	director = GradeDirector.new()
	director.start_grade = &"human_winter"
	add_child_autofree(director)


func test_presets_load_with_expected_mood() -> void:
	var winter := GradeDirector.load_preset(&"human_winter")
	var spring := GradeDirector.load_preset(&"spring")
	assert_eq(winter.id, &"human_winter")
	assert_lt(winter.saturation, 0.7, "the human realm is desaturated")
	assert_gt(spring.saturation, 1.2, "the Spring Court is candy-bright")
	assert_eq(winter.snow_cover, 1.0)
	assert_eq(spring.magic, 1.0)
	assert_not_null(GradeDirector.load_preset(&"blight"))


func test_wall_swap_reaches_spring_in_two_seconds() -> void:
	EventBus.grade_swap_requested.emit(&"spring", 2.0)
	assert_true(director.is_blending())
	director._process(1.0)
	assert_between(director.current.saturation, 0.56, 1.34, "half-way at 1 s")
	director._process(1.01)
	assert_false(director.is_blending())
	assert_almost_eq(director.current.saturation, GradeDirector.load_preset(&"spring").saturation, 0.0001)
	assert_eq(director.current.id, &"spring")


func test_mix_switches_lut_at_half() -> void:
	var a := GradePreset.new()
	var b := GradePreset.new()
	b.lut = GradientTexture1D.new()
	assert_null(GradePreset.mix(a, b, 0.49).lut)
	assert_eq(GradePreset.mix(a, b, 0.5).lut, b.lut)


func test_sun_is_up_at_noon_and_down_at_midnight() -> void:
	var noon := Basis.from_euler(GradeDirector.sun_rotation(0.5))
	var midnight := Basis.from_euler(GradeDirector.sun_rotation(0.0))
	# A DirectionalLight3D shines along -Z of its basis; light pointing down = sun up.
	assert_lt((-noon.z).y, -0.5)
	assert_gt((-midnight.z).y, 0.0)
