extends GutTest
## Shots must show the game's manor look, not the estate's preview sky and fog
## (the L35 garden shots read overcast while the game is sunny; T043).


func _dressed() -> Node3D:
	var estate := Node3D.new()
	add_child_autofree(estate)
	ShotLook.dress(estate)
	return estate


func test_a_dressed_estate_has_the_world_environment() -> void:
	var we := _dressed().get_node("WorldEnvironment") as WorldEnvironment
	assert_eq(we.environment.tonemap_mode, GradeDirector.load_preset(&"manor").tonemap_mode, "the game's tonemap")
	assert_false(we.environment.sdfgi_enabled, "no preview SDFGI")


func test_its_director_shows_the_manor_grade() -> void:
	var estate := _dressed()
	var we := estate.get_node("WorldEnvironment") as WorldEnvironment
	var d := estate.get_node("GradeDirector") as GradeDirector
	var manor := GradeDirector.load_preset(&"manor")
	assert_eq(d.current.id, &"manor")
	assert_almost_eq(we.environment.tonemap_exposure, manor.exposure, 0.0001)
	assert_almost_eq(we.environment.volumetric_fog_density, manor.volumetric_density, 0.0001)
