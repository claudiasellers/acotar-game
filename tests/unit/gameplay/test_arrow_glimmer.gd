extends GutTest
## Contract (T121): an arrow that lands in the ground glimmers until picked up.


func _landed(id: String, body: Node) -> Arrow:
	var arrow := Arrow.create(load("res://data/arrows/%s.tres" % id))
	add_child_autofree(arrow)
	arrow._stick(body)
	return arrow


func _ground() -> StaticBody3D:
	var g := StaticBody3D.new()
	add_child_autofree(g)
	return g


func test_ash_arrow_on_ground_glimmers_with_one_unshadowed_light() -> void:
	var arrow := _landed("ash", _ground())
	var g := ArrowGlimmer.of(arrow)
	assert_not_null(g, "glimmer present")
	assert_not_null(g.light, "ash glimmer has a light")
	assert_false(g.light.shadow_enabled)
	assert_eq(g.find_children("*", "OmniLight3D", true, false).size(), 1)


func test_glimmer_gone_after_pickup() -> void:
	var arrow := _landed("ash", _ground())
	var g := ArrowGlimmer.of(arrow)
	arrow.remove_from_group(Arrow.STUCK_GROUP)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(g) and not g.is_queued_for_deletion(), "glimmer removed")


func test_arrow_in_creature_does_not_glimmer() -> void:
	var wolf := Node3D.new()
	wolf.set_script(load("res://tests/unit/gameplay/arrow_glimmer_dummy_target.gd"))
	add_child_autofree(wolf)
	assert_null(ArrowGlimmer.of(_landed("ash", wolf)))


func test_wood_arrows_are_capped_ash_is_not() -> void:
	var ground := _ground()
	for i in ArrowGlimmer.WOOD_CAP + 3:
		_landed("wood", ground)
	assert_eq(get_tree().get_nodes_in_group(ArrowGlimmer.GROUP).size(), ArrowGlimmer.WOOD_CAP)
	assert_not_null(ArrowGlimmer.of(_landed("ash", ground)), "ash always glimmers")
