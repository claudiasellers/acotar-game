extends GutTest


func _anchor(anchor_name: String, at: Vector3) -> Marker3D:
	var anchor := Marker3D.new()
	anchor.name = anchor_name
	anchor.position = at
	anchor.add_to_group(&"story_anchor")
	add_child_autofree(anchor)
	return anchor


func after_each() -> void:
	var ride := StoryDirector.get_node_or_null(^"RideNorth")
	if ride:
		ride.free()


func test_act_one_spaces_hang_on_their_anchors() -> void:
	var interior := _anchor("act1_cottage_interior", Vector3.ZERO)
	var door := _anchor("act1_cottage_door", Vector3(0, 0, 3))
	var clearing := _anchor("act1_wolf_clearing", Vector3(0, 0, -200))
	var stall := _anchor("act1_fur_stall", Vector3(150, 0, 0))
	var beam := _anchor("act1_food_tally_beam", Vector3(-3, 2, 0))
	for anchor in [interior, door, clearing, stall, beam]:
		StoryDirector.attach_anchor(anchor)
	StoryDirector.attach_anchor(clearing)
	assert_not_null(interior.get_node_or_null(^"BeastDoor/Entry"), "the room is the Entry")
	assert_eq(door.get_child_count(), 0)
	assert_not_null(clearing.get_node_or_null(^"WolfKill/Entry"))
	assert_not_null(clearing.get_node_or_null(^"WolfSkinning"))
	assert_eq(clearing.get_child_count(), 2, "attaching twice adds nothing")
	assert_not_null(stall.get_node_or_null(^"PeltSale"))
	assert_not_null(beam.get_node_or_null(^"FoodTally"))
	assert_not_null(StoryDirector.get_node_or_null(^"RideNorth"), "one ride north")
