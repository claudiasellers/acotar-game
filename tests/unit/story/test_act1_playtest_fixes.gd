## The Act I playtest's soft-locks (plans/act1-fixlist.md F1, F2, F4, F7).
extends GutTest

var granted: Array = []


func _on_granted(item_id: StringName, n: int) -> void:
	granted.append([item_id, n])


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	granted.clear()
	EventBus.story_item_granted.connect(_on_granted)


func after_each() -> void:
	EventBus.story_item_granted.disconnect(_on_granted)
	StoryControl.release()
	# A scene stopped mid-run never sends its closing calm (the beast door
	# leaves dread up for HudLayout.DREAD_LAPSE_MS), which hushes later cards.
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	var ride := Act1Anchors.find_ride(get_tree())
	if ride:
		ride.free()


func test_a_landmark_named_ride_north_does_not_stop_the_ride() -> void:
	var landmarks := Node3D.new()
	landmarks.name = "RideNorth"
	add_child_autofree(landmarks)
	var anchor := Marker3D.new()
	anchor.name = "act1_fur_stall"
	add_child_autofree(anchor)
	StoryDirector.attach_anchor(anchor)
	StoryDirector.attach_anchor(anchor)
	assert_not_null(Act1Anchors.find_ride(get_tree()), "the ride exists")
	assert_eq(get_tree().get_nodes_in_group(RideNorth.GROUP).size(), 1, "only one")


func test_the_doe_and_the_wolf_stand_on_the_slope() -> void:
	var c := HumanRealmLayout.DOE_CLEARING
	var wolf := WolfKill.new()
	wolf.auto_tick = false
	add_child_autofree(wolf)
	wolf.global_position = Vector3(c.x, WorldHeight.height_at(c.x, c.y), c.y)
	for offset in [wolf.doe_offset, wolf.wolf_offset]:
		var at: Vector3 = wolf._at(offset).origin
		assert_almost_eq(at.y, WorldHeight.height_at(at.x, at.z), 0.1, "on the ground at %s" % offset)
	wolf.global_position.y += 400.0
	assert_almost_eq(wolf._at(wolf.wolf_offset).origin.y, wolf.global_position.y, 0.01,
			"off the shared terrain (greybox) the anchor's height stands")


func test_a_lost_ash_arrow_comes_back_once() -> void:
	var have := Gameplay.inventory.count(&"arrow_ash")
	if have > 0:
		Gameplay.inventory.remove(&"arrow_ash", have)
	var wolf := WolfKill.new()
	wolf.auto_tick = false
	add_child_autofree(wolf)
	wolf.running = true
	for i in 18:
		wolf._physics_process(0.5)
	assert_eq(granted, [[&"arrow_ash", 1], [&"arrow_ash", 1]], "one every 4 s while none is anywhere")
	granted.clear()
	var stuck := Node3D.new()
	stuck.set_meta(&"arrow_id", &"ash")
	stuck.add_to_group(Arrow.STUCK_GROUP)
	add_child_autofree(stuck)
	for i in 10:
		wolf._physics_process(0.5)
	assert_eq(granted, [], "not while one is stuck in the world to pick up")
	wolf.ash_struck = true
	stuck.remove_from_group(Arrow.STUCK_GROUP)
	var plain := Gameplay.inventory.count(&"arrow_wood")
	Gameplay.inventory.add(&"arrow_wood", 1)
	for i in 10:
		wolf._physics_process(0.5)
	assert_eq(granted, [], "not once the ash arrow has done its work and she has one for his eye")
	# Three arrows is all she carries: with none left anywhere, one plain one.
	Gameplay.inventory.remove(&"arrow_wood", Gameplay.inventory.count(&"arrow_wood"))
	for i in 9:
		wolf._physics_process(0.5)
	assert_eq(granted, [[&"arrow_wood", 1]], "the hunt can always end")
	Gameplay.inventory.add(&"arrow_wood", plain)


func test_the_knife_press_does_not_use_the_bed() -> void:
	WorldState.set_flag("wolf_killed")
	WorldState.set_flag("pelt_sold")
	WorldState.set_flag(CottageEvening.SLEPT)
	Clock.paused = true
	Clock.from_dict({"time_of_day": 0.9, "day": 1})
	var door := BeastDoor.new()
	door.auto_tick = false
	add_child_autofree(door)
	door.set_player_inside(true)
	assert_true(door.start())
	var guard := 0
	while not door.current_beat_label().begins_with("decision") and guard < 2000:
		door.tick(1.0 / 30.0)
		guard += 1
	assert_true(door.current_beat_label().begins_with("decision"), "at the window")
	assert_false(StoryControl.can_interact(), "E doesn't reach the stations")
	assert_true(StoryControl.allowed_actions.has("fire"), "the bracelets (fire) still can")
	assert_false(StoryControl.can_shoot(), "and the button is never the bow")
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	door._unhandled_input(press)
	door.tick(1.0 / 30.0)
	assert_eq(door.chosen_fact, "fact.beast_door.threw_knife")
	Clock.paused = false


func test_the_ride_ends_up_the_manor_drive() -> void:
	var drive := RideNorth.drive_points()
	var first := drive[0]
	var last := drive[drive.size() - 1]
	var gate := ManorSitePlan.SENTRY_GATE
	assert_almost_eq(first.distance_to(gate), RideNorth.GATE_INSIDE, 0.01, "just inside the sentry gate")
	assert_true(first.y < gate.y, "on the manor side")
	var door := Vector2(ManorSitePlan.FRONT_DOOR.x, ManorSitePlan.FRONT_DOOR.z)
	assert_almost_eq(last.distance_to(door), RideNorth.STOP_OUT, 0.2, "to the front steps")
	var road := RideNorth.route_points()
	assert_true(road.has(gate), "his road comes in through the sentry gate")