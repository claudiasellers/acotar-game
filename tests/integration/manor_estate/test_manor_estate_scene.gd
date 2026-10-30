## Loads the whole Manor Estate region and walks Feyre onto it.
extends GutTest

const SCENE := preload("res://world/spring_court/manor_estate/manor_estate.tscn")
const FEYRE := preload("res://characters/feyre/feyre.tscn")

var estate: ManorEstate


func before_all() -> void:
	var t := Time.get_ticks_msec()
	estate = SCENE.instantiate()
	add_child(estate)
	gut.p("estate built in %d ms" % (Time.get_ticks_msec() - t))


func after_all() -> void:
	estate.queue_free()


func _drop_feyre_at(x: float, z: float, y: float = NAN) -> Node3D:
	var f := FEYRE.instantiate() as Node3D
	var ground := WorldHeight.height_at(x, z) if is_nan(y) else y
	f.position = Vector3(x, ground + 0.4, z)
	estate.add_child(f)
	return f


func test_feyre_lands_on_the_drive() -> void:
	var s := ManorSitePlan.SPAWN
	var f := _drop_feyre_at(s.x, s.z)
	await wait_physics_frames(40)
	assert_true((f as CharacterBody3D).is_on_floor())
	assert_gt(f.global_position.y, WorldHeight.height_at(s.x, s.z) - 0.3)
	f.queue_free()


func test_ground_never_lets_feyre_fall_through() -> void:
	var points := [Vector2(-500, -400), Vector2(450, -300), Vector2(-400, 200), Vector2(300, 250), Vector2(0, -150), Vector2(190, 160)]
	var bodies: Array[Node3D] = []
	for p in points:
		bodies.append(_drop_feyre_at(p.x, p.y))
	await wait_physics_frames(40)
	for i in bodies.size():
		var p: Vector2 = points[i]
		assert_gt(bodies[i].global_position.y, WorldHeight.height_at(p.x, p.y) - 0.5, "fell through at %s" % p)
		bodies[i].queue_free()


func test_grounds_and_scatter_are_in_the_region() -> void:
	assert_not_null(estate.grounds)
	assert_not_null(estate.scatter)
	assert_gt(estate.scatter.forage_chunks().size(), 50)
	assert_eq(get_tree().get_nodes_in_group(&"story_anchor").size(), 19, "4 grounds + 15 house anchors")


func test_feyre_stands_on_grounds_structures() -> void:
	# [x, z, expected floor y]: hayloft floor, jetty deck, island pavilion, belvedere floor
	var stable_y := WorldHeight.height_at(ManorStables.WEST.get_center().x, ManorStables.WEST.get_center().y)
	var bel := ManorSitePlan.BELVEDERE_HILL
	var spots := [
		[ManorStables.WEST.get_center().x + 2.0, -30.0, stable_y + ManorStables.LOFT_Y],
		[ManorPond.JETTY_X, 78.0, ManorPond.level() + 0.55],
		[ManorSitePlan.POND_ISLAND.x + 1.5, ManorSitePlan.POND_ISLAND.y + 3.5, ManorPond.level() + 0.5],
		[bel.x + 3.0, bel.y + 2.0, WorldHeight.height_at(bel.x, bel.y) + 1.2],
	]
	var bodies: Array[Node3D] = []
	for s in spots:
		bodies.append(_drop_feyre_at(s[0], s[1], s[2] + 0.3))
	await wait_physics_frames(40)
	for i in bodies.size():
		var want: float = spots[i][2]
		assert_almost_eq(bodies[i].global_position.y, want, 0.6, "stands on structure %d" % i)
		bodies[i].queue_free()
