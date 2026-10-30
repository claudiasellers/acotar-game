extends GutTest

const WORLD := preload("res://world/shared/world/world.tscn")


func test_world_scene_loads_with_its_parts() -> void:
	var world: World = WORLD.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(2)
	assert_not_null(world.regions)
	assert_not_null(world.grade.environment)
	assert_eq(world.grade.current.id, &"human_winter")
	assert_true(world.is_in_group(World.GROUP))


func test_prints_fade_and_stop_at_the_wall() -> void:
	var prints := SnowPrints.new()
	prints.pool_size = 8
	prints.lifetime = 10.0
	prints.snowfall = 0.0
	add_child_autofree(prints)
	prints.stamp(Vector3(0, 0, 2000), 0.0)
	prints.stamp(Vector3(0, 0, 1000), 0.0)
	assert_eq(prints.active_count(), 1, "no prints north of the Wall")
	prints._process(11.0)
	assert_eq(prints.active_count(), 0, "faded out")
	prints.snowfall = 1.0
	prints.stamp(Vector3(0, 0, 2000), 0.0)
	prints._process(2.0)
	assert_eq(prints.active_count(), 0, "heavy snow covers prints faster")


func test_weather_requests_blend_to_state() -> void:
	var w := WinterWeather.new()
	add_child_autofree(w)
	w.request(&"snow_slow", 2.0)
	w._process(2.0)
	assert_almost_eq(w.values[0], 0.45, 0.001)
	assert_almost_eq(w.values[1], 2.4, 0.001)
