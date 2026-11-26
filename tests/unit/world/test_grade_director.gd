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
	# Book light (Keeper): nothing glows by day before the glamour lifts (ch 23),
	# so daytime Spring keeps only a faint rim shimmer.
	assert_between(spring.magic, 0.2, 0.5, "faint daytime shimmer, not a glow")
	assert_not_null(GradeDirector.load_preset(&"blight"))


func test_wall_swap_reaches_spring_in_two_seconds() -> void:
	EventBus.grade_swap_requested.emit(self, &"spring", 2.0)
	assert_true(director.is_blending())
	director._process(1.0)
	assert_between(director.current.saturation, 0.56, 1.34, "half-way at 1 s")
	director._process(1.01)
	assert_false(director.is_blending())
	assert_almost_eq(director.current.saturation, GradeDirector.load_preset(&"spring").saturation, 0.0001)
	assert_eq(director.current.id, &"spring")


func test_a_story_swap_holds_off_the_region_grade_until_released() -> void:
	var focus := Node3D.new()
	add_child_autofree(focus)
	director.focus = focus
	var region := RegionGrade.new()
	region.grade = &"manor"
	region.bounds = Rect2(-10.0, -10.0, 20.0, 20.0)
	add_child_autofree(region)
	EventBus.grade_swap_requested.emit(self, &"spring", 0.0)
	director._process(0.1)
	assert_eq(director.target_id(), &"spring", "the story's grade wins while it holds")
	EventBus.grade_swap_requested.emit(self, &"", 2.0)
	director._process(0.1)
	assert_eq(director.target_id(), &"manor", "released, the region's grade takes over")


## A house's rooms inside its estate: the higher priority wins wherever both
## contain her, whatever order they joined the tree in (the estate's grade now
## arrives first, before the house is built).
func test_the_higher_priority_grade_wins_where_two_overlap() -> void:
	var focus := Node3D.new()
	add_child_autofree(focus)
	director.focus = focus
	var estate := RegionGrade.new()
	estate.grade = &"manor"
	estate.bounds = Rect2(-50.0, -50.0, 100.0, 100.0)
	add_child_autofree(estate)
	var rooms := RegionGrade.new()
	rooms.grade = &"manor_interior"
	rooms.priority = 10
	rooms.bounds = Rect2(-5.0, -5.0, 10.0, 10.0)
	add_child_autofree(rooms)
	director._process(0.1)
	assert_eq(director.target_id(), &"manor_interior", "in the rooms")
	director.swap_to(director.target_id(), 0.0)
	focus.position = Vector3(30.0, 0.0, 0.0)
	director._process(0.1)
	assert_eq(director.target_id(), &"manor", "out on the grounds")


func test_the_house_grade_has_no_gi_and_the_manor_tone_mapper() -> void:
	var inside := GradeDirector.load_preset(&"manor_interior")
	var manor := GradeDirector.load_preset(&"manor")
	assert_false("sdfgi" in inside, "GradePreset has no GI switch, so no grade can turn it on")
	assert_eq(inside.tonemap_mode, manor.tonemap_mode, "the tone mapper doesn't blend, so it must not pop at a doorway")
	assert_eq(inside.ambient_sky_contribution, 0.0, "flat ambient, not sky-fed")
	# Value contrast (L18-12): the flat ambient at 1.1 washed every room out
	# (dining hall 37% of pixels clipped). It fills; windows and lamps model.
	assert_between(inside.ambient_energy, 0.15, 0.6, "rooms readable, not washed out")
	var night := GradeDirector.with_night(inside, 1.0)
	assert_lt(night.ambient_energy * night.ambient_color.get_luminance(),
		inside.ambient_energy * inside.ambient_color.get_luminance() * 0.6,
		"at night the lamps carry the rooms, not the day's ambient")
	assert_gt(night.ambient_energy * night.ambient_color.get_luminance() * night.exposure, 0.08,
		"but a night room is never black between the lamps")
	assert_eq(night.tonemap_mode, inside.tonemap_mode, "no pop at nightfall")
	assert_almost_eq(GradeDirector.with_night(inside, 0.0).ambient_energy, inside.ambient_energy, 0.0001)
	var spring := GradeDirector.load_preset(&"spring")
	assert_eq(GradeDirector.with_night(spring, 1.0), spring, "outdoor grades darken with the sun alone")


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


## Owner, 2026-11-26: fear never darkens the screen. A dread request is still
## the mood (sound, HUD and her vitals follow it), but the look is untouched.
func test_dread_is_the_mood_but_never_darkens_the_look() -> void:
	var env := Environment.new()
	var we := WorldEnvironment.new()
	we.environment = env
	add_child_autofree(we)
	director.environment = we
	director.apply(director.current)
	var exposure := env.tonemap_exposure
	var saturation := env.adjustment_saturation
	director._on_mood_requested(self, &"dread", 1.0, 0.5)
	director._process(1.0)
	assert_eq(director.mood, &"dread")
	assert_almost_eq(director.mood_strength, 1.0, 0.001)
	assert_almost_eq(env.tonemap_exposure, exposure, 0.0001, "no darkening")
	assert_almost_eq(env.adjustment_saturation, saturation, 0.0001, "no draining")
	director._on_mood_requested(self, &"calm", 0.0, 0.5)
	assert_eq(director.mood, &"calm")


func test_enchanted_sleep_fades_down() -> void:
	director._on_mood_requested(self, &"enchanted_sleep", 1.0, 2.5)
	director._process(2.5)
	assert_almost_eq(director.sleep_amount, 1.0, 0.001)
	var base := GradeDirector.load_preset(&"human_winter")
	var sleepy := GradeDirector.with_sleep(base, director.sleep_amount)
	assert_lt(sleepy.exposure, base.exposure * 0.5, "she drifts off: over a stop down")
	assert_gt(sleepy.exposure, base.exposure * 0.3, "a dreamy fade, not a dropout to black")


func test_spring_sky_is_not_eaten_by_fog() -> void:
	var spring := GradeDirector.load_preset(&"spring")
	assert_lte(spring.fog_sky_affect, 0.15, "distance fog must leave the sky gradient alone")
	assert_gt(spring.fog_height_density, 0.0, "mist pools low instead")
	# Depth haze (owner, 2026-11-09): far layers keep the haze's own colour, a
	# cool lilac-blue darker than the pink horizon, so the hills stand out from
	# the sky as foreground, midground and background instead of melting into it.
	assert_lte(spring.fog_aerial_perspective, 0.2, "far layers keep the haze colour, not the sky's")
	assert_lt(spring.fog_color.get_luminance(), spring.sky_horizon.get_luminance() - 0.05,
		"the haze is darker than the horizon, so the far hills read against it")
	assert_gt(spring.fog_color.b, spring.fog_color.r, "the haze is cool")
	# The weenie (Great Oak, ~285 m from the wall-crossing frame) stays readable.
	assert_lt(1.0 - exp(-spring.fog_density * 285.0), 0.2, "≤20% depth fog at the weenie's distance")


func test_golden_hour_peaks_at_the_horizon() -> void:
	assert_almost_eq(GradeDirector.golden_amount(0.0), 1.0, 0.001)
	assert_almost_eq(GradeDirector.golden_amount(0.9), 0.0, 0.001)
	assert_almost_eq(GradeDirector.golden_amount(-0.5), 0.0, 0.001, "no golden sky at night")


func test_the_bogge_fog_is_lit_by_its_cold_ambient() -> void:
	# Fog lit by a 0.45 sun alone became a black wall that ate the sky, so the
	# trunks had nothing paler behind them (audit D8). Its ambient lights it.
	var bogge := GradeDirector.load_preset(&"bogge")
	assert_gt(bogge.volumetric_ambient_inject, 0.5, "the Bogge fog takes the ambient")
	assert_gt(bogge.fog_color.get_luminance(), 0.45, "the murk is paler than the trunks")
	assert_lt(bogge.fog_color.get_luminance(), 0.65, "but still grey murk, not milk")
	assert_gt(bogge.sun_color.b, bogge.sun_color.r, "a cold rim, not a warm one")
	assert_almost_eq(GradeDirector.load_preset(&"spring").volumetric_ambient_inject, 0.0, 0.0001,
		"other grades keep their sun-lit fog")
	var env := Environment.new()
	var we := WorldEnvironment.new()
	we.environment = env
	add_child_autofree(we)
	director.environment = we
	director.apply(bogge)
	assert_almost_eq(env.volumetric_fog_ambient_inject, bogge.volumetric_ambient_inject, 0.0001)


func test_painted_clouds_per_grade() -> void:
	# A cloudless sky read unfinished (audit): a few soft clouds in Spring,
	# an overcast lid over the human winter, none to compete with the Bogge fog.
	var spring := GradeDirector.load_preset(&"spring")
	var manor := GradeDirector.load_preset(&"manor")
	var winter := GradeDirector.load_preset(&"human_winter")
	assert_between(spring.cloud_cover, 0.2, 0.45, "a few fair-weather clouds")
	assert_between(manor.cloud_cover, 0.2, 0.45, "a few fair-weather clouds")
	assert_gt(winter.cloud_cover, 0.65, "winter is overcast")
	assert_gt(spring.cloud_color.get_luminance(), winter.cloud_color.get_luminance(), "Spring clouds are brighter")
	assert_lt(spring.cloud_color.get_luminance(), 0.99, "but not pure white glare")
	assert_eq(GradeDirector.load_preset(&"bogge").cloud_cover, 0.0)


func test_director_drives_the_painted_sky() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/shared/grades/painted_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = mat
	var env := Environment.new()
	env.sky = sky
	var we := WorldEnvironment.new()
	we.environment = env
	add_child_autofree(we)
	director.environment = we
	var manor := GradeDirector.load_preset(&"manor")
	director.apply(manor)
	assert_almost_eq(float(mat.get_shader_parameter(&"cloud_cover")), manor.cloud_cover, 0.0001)
	assert_eq(mat.get_shader_parameter(&"ground_bottom_color"), manor.ground_bottom)
	assert_eq(mat.get_shader_parameter(&"cloud_shade"), manor.cloud_shade)



func test_night_fog_takes_the_ambient_instead_of_going_black() -> void:
	# The mill void (L51): volumetric fog and every mist FogVolume are lit only by
	# lights unless they take the ambient, so with the sun down they rendered as
	# an opaque black wall. At night the fog takes at least NIGHT_FOG_INJECT.
	assert_almost_eq(GradeDirector.night_amount(0.8), 0.0, 0.0001, "noon is day")
	assert_almost_eq(GradeDirector.night_amount(-0.5), 1.0, 0.0001, "midnight is night")
	assert_almost_eq(GradeDirector.fog_ambient_inject(0.0, 0.0), 0.0, 0.0001, "daytime fog keeps its sun-lit look")
	assert_almost_eq(GradeDirector.fog_ambient_inject(0.0, 1.0), GradeDirector.NIGHT_FOG_INJECT, 0.0001)
	assert_almost_eq(GradeDirector.fog_ambient_inject(1.5, 1.0), 1.5, 0.0001, "never lowers a grade's own take")
	var env := Environment.new()
	var we := WorldEnvironment.new()
	we.environment = env
	add_child_autofree(we)
	director.environment = we
	director.night = 1.0
	director.apply(GradeDirector.load_preset(&"human_winter"))
	assert_gt(env.volumetric_fog_ambient_inject, 0.3, "the winter night fog is lit by the ambient")
