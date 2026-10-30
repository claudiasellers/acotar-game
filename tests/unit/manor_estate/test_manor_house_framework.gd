## The house builder and index on a tiny two-storey layout built in code.
extends GutTest


func _layout() -> ManorHouseLayout:
	var dsl := ManorLayoutDSL.new(&"test_part")
	var hall := dsl.room(&"hall", "Hall", 0, Rect2(-10, -20, 20, 20), "C", &"marble")
	dsl.prop(hall, &"chandelier_crystal", 10, 10, 0, 3.0)
	dsl.room(&"study", "Study", 0, Rect2(10, -20, 10, 10))
	dsl.room(&"closet", "Closet", 0, Rect2(10, -10, 10, 10))
	dsl.room(&"landing", "Landing", 1, Rect2(-10, -20, 20, 20))
	dsl.door(0, Vector2(0, 0), &"gate").region_id = &"manor_house"
	dsl.door(0, Vector2(10, -15))
	dsl.secret_door(0, Vector2(15, -10), &"closet", &"bookcase")
	dsl.stair(&"main", 0, Rect2(-3, -16, 6, 10), &"north")
	dsl.station(&"easel", "Easel", 0, Vector3(5, 0, -5), &"easel")
	dsl.secret(&"closet", &"lever", 0, Vector3(18, 1.2, -19))
	dsl.secret(&"brooch", &"keepsake", 0, Vector3(15, 0.1, -5), &"col_rose_brooch")
	return dsl.layout


func test_graph_reaches_every_room_and_hides_secret_rooms() -> void:
	var index := ManorHouseIndex.new([_layout()])
	assert_eq(index.overlaps().size(), 0)
	var all := index.reachable(&"hall")
	assert_true(all.has(&"study") and all.has(&"closet") and all.has(&"landing"))
	var open_only := index.reachable(&"hall", false)
	assert_false(open_only.has(&"closet"), "the closet is behind a secret door")


func test_builder_makes_rooms_stations_and_secrets() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var house := ManorHouseBuilder.build(root, [_layout()])
	assert_not_null(house.get_node_or_null("hall"))
	assert_eq(get_tree().get_nodes_in_group(ManorStation.GROUP).size(), 2, "easel and lever")
	var leaf := house.get_node("Door_closet") as ManorDoorLeaf
	assert_true(leaf.visible)
	var lever := house.get_node("Lever_closet") as ManorSecretLever
	lever.use()
	assert_true(WorldState.has_flag("fact.manor.secret_closet"))
	assert_false(leaf.visible, "secret door opens when its lever is pulled")
	WorldState.clear()


func test_subtract_cuts_a_hole() -> void:
	var parts := ManorHouseBuilder._subtract(Rect2(0, 0, 10, 10), [Rect2(4, 4, 2, 2)])
	var area := 0.0
	for p in parts:
		area += p.get_area()
	assert_almost_eq(area, 96.0, 0.01)
