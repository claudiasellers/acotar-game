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


func test_keepsakes_sit_by_the_hearth_and_the_bed() -> void:
	var interior_room := Node3D.new()
	add_child_autofree(interior_room)
	var hearth := Node3D.new()
	hearth.name = "Hearth"
	hearth.position = Vector3(3.6, 0, 0)
	interior_room.add_child(hearth)
	var spot := Marker3D.new()
	spot.name = "HearthSpot"
	hearth.add_child(spot)
	var bed := Node3D.new()
	bed.name = "SistersBed"
	bed.position = Vector3(-3, 0, 1.8)
	interior_room.add_child(bed)
	var anchor := Marker3D.new()
	anchor.name = "act1_cottage_interior"
	interior_room.add_child(anchor)
	StoryDirector.attach_anchor(anchor)
	var at_hearth := anchor.get_node_or_null(^"HearthKeepsake") as KeepsakeStation
	var at_bed := anchor.get_node_or_null(^"BedKeepsake") as KeepsakeStation
	assert_not_null(at_hearth)
	assert_not_null(at_bed)
	assert_almost_eq(at_hearth.global_position.x, 3.6, 0.01)
	assert_true(at_bed.is_in_group(&"station"), "Feyre's E finds it")
	WorldState.clear()
	at_bed.use(null)
	assert_true(WorldState.has_flag("fact.mother_bed_seen"))
	at_hearth.use(null)
	assert_true(WorldState.has_flag("fact.father_hearth_sat"))


func test_the_fur_stall_sells_andras_pelt() -> void:
	var stall_anchor := _anchor("act1_fur_stall", Vector3(150, 0, 0))
	StoryDirector.attach_anchor(stall_anchor)
	var stall := stall_anchor.get_node_or_null(^"FurStall") as FurStall
	assert_not_null(stall)
	assert_true(stall.is_in_group(&"station"))
	Gameplay.inventory.remove(&"obj_wolf_pelt", Gameplay.inventory.count(&"obj_wolf_pelt"))
	watch_signals(EventBus)
	stall.use(null)
	assert_signal_not_emitted(EventBus, "item_sold", "nothing to sell")
	Gameplay.inventory.add(&"obj_wolf_pelt", 1)
	stall.use(null)
	assert_signal_emitted_with_parameters(EventBus, "item_sold", [&"obj_wolf_pelt", 40])
	assert_eq(Gameplay.inventory.count(&"obj_wolf_pelt"), 0)


func test_the_bed_sleeps_to_night_only_after_the_sale() -> void:
	WorldState.clear()
	var saved := Clock.to_dict()
	var bed := CottageBed.new()
	bed.fact = "fact.mother_bed_seen"
	add_child_autofree(bed)
	Clock.from_dict({"time_of_day": 0.5, "day": 3})
	assert_false(bed.can_sleep(), "not before the pelt is sold")
	WorldState.set_flag("pelt_sold")
	assert_true(bed.can_sleep())
	CottageBed.skip_to_night()
	assert_true(Clock.is_night())
	assert_eq(Clock.day, 3, "the same night, not the next day")
	assert_false(bed.can_sleep(), "already night")
	Clock.from_dict(saved)
