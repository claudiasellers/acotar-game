# gate: needs:terrain
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


func test_weather_requests_blend_to_state() -> void:
	var w := WinterWeather.new()
	add_child_autofree(w)
	w.request(&"snow_slow", 2.0)
	w._process(2.0)
	assert_almost_eq(w.values[0], 0.45, 0.001)
	assert_almost_eq(w.values[1], 2.4, 0.001)
