## Contract: spring weather visuals (T5) and GradeDirector's weather fog.
extends GutTest


func test_ground_wetness_rises_in_rain_and_dries_slowly() -> void:
	var wet := 0.0
	for i in 600:
		wet = SpringWeather.step_wetness(wet, 0.65, 0.1)
	assert_gt(wet, 0.8, "a minute of showers soaks the ground")
	var soaked := wet
	for i in 300:
		wet = SpringWeather.step_wetness(wet, 0.0, 0.1)
	assert_lt(wet, soaked, "dries")
	assert_gt(wet, 0.5, "slowly: half a minute later it is still wet")


func test_wetness_global_exists() -> void:
	SpringWeather.ensure_wetness_global()
	assert_true(RenderingServer.global_shader_parameter_get_list().has(SpringWeather.WETNESS_GLOBAL))


func test_only_spring_states_are_taken() -> void:
	var w := SpringWeather.new()
	add_child_autofree(w)
	w.request(&"snow_heavy", 1.0)
	assert_eq(w.state, &"spring_clear", "winter states belong to WinterWeather")
	w.request(&"spring_showers", 1.0)
	assert_eq(w.state, &"spring_showers")
	assert_false(w.active, "inactive outside the Spring Court (no player here)")
	assert_eq(w.wind_ms(), Vector3.ZERO)


func test_weather_fog_defaults_to_zero_and_is_clamped() -> void:
	var g := GradeDirector.new()
	add_child_autofree(g)
	assert_eq(g.weather_fog, 0.0, "no mist unless the weather asks")
	g.set_weather_fog(1.0)
	assert_almost_eq(g.weather_fog, GradeDirector.MAX_WEATHER_FOG, 0.00001, "clamped")
	assert_lte(GradeDirector.MAX_WEATHER_FOG, 0.04)
	g.set_weather_fog(-1.0)
	assert_eq(g.weather_fog, 0.0)


func test_weather_steps_aside_while_a_story_scene_runs() -> void:
	var w := SpringWeather.new()
	add_child_autofree(w)
	var space := SceneSpace.new()
	add_child_autofree(space)
	w.active = true
	w.mist = 1.0
	w.precipitation = 0.7
	assert_almost_eq(w.fog_offset(), GradeDirector.MAX_WEATHER_FOG, 0.00001, "mist outside scenes")
	space.running = true
	w.held = w.story_running()
	assert_true(w.held, "sees the running scene")
	assert_eq(w.fog_offset(), 0.0, "no weather fog during a scene")
	space.running = false
	w.held = w.story_running()
	assert_false(w.held, "back after the scene")
