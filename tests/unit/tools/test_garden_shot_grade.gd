extends GutTest
## Garden shots must show the game's manor look, not the estate's grey preview
## sky and fog (the L35 garden shots read overcast while the game is sunny).


func test_garden_shot_takes_the_world_environment() -> void:
	var gs: Node3D = load("res://tools/manor_estate/garden_shot.gd").new()
	var we: WorldEnvironment = gs._world_environment()
	assert_not_null(we, "the World scene's WorldEnvironment")
	assert_eq(we.environment.tonemap_mode, Environment.TONE_MAPPER_ACES, "the game's tonemap, not the preview's AgX")
	assert_false(we.environment.sdfgi_enabled, "no preview SDFGI")
	we.free()
	gs.free()


func test_a_director_on_that_environment_shows_the_manor_grade() -> void:
	var gs: Node3D = load("res://tools/manor_estate/garden_shot.gd").new()
	var we: WorldEnvironment = gs._world_environment()
	add_child_autofree(we)
	var d := GradeDirector.new()
	d.environment = we
	d.start_grade = &"manor"
	add_child_autofree(d)
	var manor := GradeDirector.load_preset(&"manor")
	assert_eq(d.current.id, &"manor")
	assert_almost_eq(we.environment.tonemap_exposure, manor.exposure, 0.0001)
	assert_almost_eq(we.environment.volumetric_fog_density, manor.volumetric_density, 0.0001)
	gs.free()
