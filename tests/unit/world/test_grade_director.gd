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


func test_dread_darkens_and_desaturates_then_calm_restores() -> void:
	director._on_mood_requested(&"dread", 1.0, 1.0)
	director._process(1.0)
	assert_almost_eq(director.mood_amount, 1.0, 0.001)
	var base := GradeDirector.load_preset(&"human_winter")
	var dark := GradeDirector.with_mood(base, director.mood_amount)
	assert_lt(dark.saturation, base.saturation)
	assert_lt(dark.exposure, base.exposure)
	assert_gt(dark.fog_density, base.fog_density)
	director._on_mood_requested(&"calm", 0.0, 0.5)
	director._process(0.5)
	assert_almost_eq(director.mood_amount, 0.0, 0.001)


func test_enchanted_sleep_fades_down() -> void:
	director._on_mood_requested(&"enchanted_sleep", 1.0, 2.5)
	director._process(2.5)
	var base := GradeDirector.load_preset(&"human_winter")
	assert_lt(GradeDirector.with_mood(base, director.mood_amount, director.mood).exposure, base.exposure * 0.2)


func test_spring_sky_is_not_eaten_by_fog() -> void:
	var spring := GradeDirector.load_preset(&"spring")
	assert_lte(spring.fog_sky_affect, 0.15, "distance fog must leave the sky gradient alone")
	assert_gt(spring.fog_height_density, 0.0, "mist pools low instead")
	assert_between(spring.fog_aerial_perspective, 0.3, 0.6, "far layers fade toward the sky, not into it")
	# The weenie (Great Oak, ~285 m from the wall-crossing frame) stays readable.
	assert_lt(1.0 - exp(-spring.fog_density * 285.0), 0.2, "≤20% depth fog at the weenie's distance")


func test_golden_hour_peaks_at_the_horizon() -> void:
	assert_almost_eq(GradeDirector.golden_amount(0.0), 1.0, 0.001)
	assert_almost_eq(GradeDirector.golden_amount(0.9), 0.0, 0.001)
	assert_almost_eq(GradeDirector.golden_amount(-0.5), 0.0, 0.001, "no golden sky at night")


func test_dread_drains_the_world() -> void:
	var base := GradeDirector.load_preset(&"spring")
	var dark := GradeDirector.with_mood(base, 1.0, &"dread")
	assert_almost_eq(dark.saturation, 0.4, 0.01, "§1.5 saturation")
	assert_lt(dark.exposure, base.exposure * 0.25, "two stops down or more")
	assert_eq(dark.magic, 0.0, "sparkles off")
	assert_gt(dark.fog_height_density, 0.06, "dense low fog")
