## The beast at the door speaks (review O1-O3, lane L86): every beat the scene
## asks for has the Keeper's lines, the Treaty's terms are said verbatim, the
## scene waits on each beat before the next, her choice is thrown and glances
## off him, her thought comes 3 s into a window with no press, and the ride
## has its metal thought.
extends GutTest

const BEATS := [&"accuse", &"anything", &"chin", &"who", &"confess", &"provoked", &"deserved", &"life", &"plead", &"silence", &"gold", &"worth",
	&"when", &"now", &"goodbye"]


class FakeDoor:
	extends Node
	var running: bool = true
	var label: String = ""
	var choice: StringName = &""

	func current_beat_label() -> String:
		return label

	func last_choice() -> StringName:
		return choice


var director: DialogueDirector
var shown: Array = []


func before_each() -> void:
	WorldState.clear()
	PhaseManager.current_phase = &"p1_wolf_and_crossing"
	shown.clear()
	director = DialogueDirector.new()
	director.auto_tick = false
	director.books_dir = ""
	director.add_book(load("res://data/dialogue/lines/beast_door.tres") as DialogueBook)
	director.add_book(load("res://data/dialogue/lines/ride_north.tres") as DialogueBook)
	director.show_fn = func(_who: String, text: String, _inner: bool) -> float:
		shown.append(text)
		return 2.0
	add_child_autofree(director)


func _elapse(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		director._now += 0.25
		director._pump_scene()
		t += 0.25


func test_every_beat_has_keeper_lines_and_the_treaty_is_verbatim() -> void:
	for beat: StringName in BEATS:
		var key := StringName("beast_door.%s" % beat)
		assert_false(director._of(DialogueLine.Trigger.SCENE, key).is_empty(), "lines for %s" % beat)
	var life := director._of(DialogueLine.Trigger.SCENE, &"beast_door.life")
	assert_eq(life.size(), 2, "the rule, then the deal")
	assert_string_starts_with((life[0] as DialogueLine).text, "A life for a life. Any unprovoked attacks on faerie-kind")
	assert_string_contains((life[1] as DialogueLine).text, "Prythian")
	assert_eq((director.by_id[&"A1_11_beast_who"] as DialogueLine).text, "Who killed the wolf?")
	assert_false((director.by_id[&"A1_10_beast_murderers"] as DialogueLine).inner, "he says it aloud")
	assert_true((director.by_id[&"H1_anything"] as DialogueLine).inner, "her thought")
	assert_false(director._of(DialogueLine.Trigger.SCENE, &"ride_north.smell_metal").is_empty(), "H1_metal")


func test_guide_says_each_beat_once_and_waits_until_said() -> void:
	var door := FakeDoor.new()
	add_child_autofree(door)
	var guide := BeastDoorGuide.new()
	guide.set_process(false)
	door.add_child(guide)
	EventBus.scene_space_started.emit(&"beast_door")
	assert_true(director.held(), "the guide holds the ambient voice")
	assert_true(guide.say(&"life"))
	assert_false(guide.quiet(), "still saying the terms")
	_elapse(2.0)
	assert_false(guide.quiet(), "two lines: the rule, then the deal")
	_elapse(4.0)
	assert_true(guide.quiet())
	assert_eq(shown.size(), 2)
	assert_false(guide.say(&"life"), "once a scene")
	EventBus.scene_space_finished.emit(&"beast_door")
	assert_false(director.held())


func test_her_thought_comes_three_seconds_into_a_window_with_no_press() -> void:
	var door := FakeDoor.new()
	add_child_autofree(door)
	var guide := BeastDoorGuide.new()
	guide.set_process(false)
	door.add_child(guide)
	EventBus.scene_space_started.emit(&"beast_door")
	door.label = "decision 6.0 s"
	guide.window_time = 2.0
	guide.tick()
	assert_eq(shown, [], "not yet")
	guide.window_time = BeastDoorGuide.ANYTHING_AFTER
	guide.tick()
	assert_eq(shown, ["Bracelets. Knife. Anything."])
	guide.note_backed_away()
	_elapse(2.5)
	assert_string_contains(String(shown.back()), "chin held high")
	door.label = "say who"
	guide.said.erase(&"chin")
	guide.note_backed_away()
	assert_eq(shown.size(), 2, "only inside the window")


func test_her_choice_is_thrown_and_glances_off_him() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var feyre := Node3D.new()
	var beast := Node3D.new()
	root.add_child(feyre)
	root.add_child(beast)
	beast.global_position = Vector3(0, 0, -3)
	var throw := BeastDoorThrow.new()
	root.add_child(throw)
	throw.throw_for("fact.beast_door.froze", feyre, beast)
	assert_null(throw.prop, "standing still throws nothing")
	assert_true(throw.advance(0.1))
	throw.throw_for("fact.beast_door.threw_bracelets", feyre, beast)
	assert_not_null(throw.prop, "the iron bracelets leave her hand")
	assert_false(throw.advance(BeastDoorThrow.FLIGHT_SECONDS * 0.5))
	assert_gt(throw.prop.global_position.y, 1.2, "in the air between them")
	assert_false(throw.struck)
	assert_false(throw.advance(BeastDoorThrow.FLIGHT_SECONDS * 0.6))
	assert_true(throw.struck, "it strikes his hide (the clink)")
	assert_true(throw.advance(BeastDoorThrow.FALL_SECONDS))
	assert_almost_eq(throw.prop.global_position.y, 0.04, 0.01, "and lies on the floor")
	assert_lt(throw.prop.global_position.distance_to(beast.global_position), 3.0, "at his feet")


func test_the_scene_speaks_in_the_keepers_order() -> void:
	var door := BeastDoor.new()
	door.auto_tick = false
	add_child_autofree(door)
	var labels: Array = door._build_beats().map(func(b: SceneBeat) -> String: return b.label)
	var at := func(label: String) -> int: return labels.find(label)
	assert_lt(at.call("decision 6.0 s"), at.call("it glances off him"))
	assert_lt(at.call("it glances off him"), at.call("say who"))
	for pair in [["say who", "say confess"], ["say confess", "say provoked"], ["say provoked", "say deserved"],
			["say deserved", "say life"], ["say life", "say plead"],
			["say plead", "say silence"], ["say silence", "say gold"], ["say gold", "say worth"], ["say worth", "raise beast_claim_accepted"],
			["raise beast_claim_accepted", "say when"], ["say when", "raise fact.ash_arrow_burned"],
			["raise fact.ash_arrow_burned", "say now"], ["say now", "say goodbye"]]:
		assert_lt(at.call(pair[0]), at.call(pair[1]), "%s before %s" % pair)
		if String(pair[0]).begins_with("say "):
			assert_eq(labels[at.call(pair[0]) + 1], "until %s is said" % String(pair[0]).trim_prefix("say "),
					"%s is waited on" % pair[0])
	assert_false(labels.has("wait 4.0"), "no fixed wait cuts the terms short")


func test_the_ride_is_played_from_the_cottage_road_to_the_steps() -> void:
	var ride := RideNorth.new()
	ride.auto_tick = false
	add_child_autofree(ride)
	var labels: Array = ride._build_beats().map(func(b: SceneBeat) -> String: return b.label)
	assert_eq(labels, ["the mare waits at the trees", "cue tamlin_beast lead", "follow the beast", "she is down at the stairs"],
			"no fade, no sleep, no drive cut: she rides it")
	var road := RideNorth.route_points()
	assert_lt(road[0].distance_to(HumanRealmLayout.COTTAGE), 1.0, "from the cottage")
	var gap := Vector2(WorldMap.WALL_GAP_X, WorldMap.WALL_Z)
	var through := false
	for i in road.size() - 1:
		var on := Geometry2D.get_closest_point_to_segment(gap, road[i], road[i + 1])
		through = through or on.distance_to(gap) < 3.0
	assert_true(through, "through the gap in the Wall")
	# Her thoughts come in road order, the metal just before the Wall, birds just after.
	var at: Array = ride._marks.map(func(m: Array) -> float: return m[1])
	for i in at.size() - 1:
		assert_lt(at[i], at[i + 1], "%s before %s" % [ride._marks[i][0], ride._marks[i + 1][0]])
	assert_lt(ride._mark(&"smell_metal"), ride.seam_at())
	assert_gt(ride._mark(&"birds"), ride.seam_at())
	for beat: StringName in [&"mounted", &"still", &"village", &"live", &"ash", &"faerie", &"lamb", &"smell_metal",
			&"birds", &"warm", &"name", &"gate", &"magic", &"paint", &"stairs",
			&"stray_mare", &"stray_growl", &"stray_roar", &"stray_block"]:
		assert_false(director._of(DialogueLine.Trigger.SCENE, StringName("ride_north.%s" % beat)).is_empty(), "lines for %s" % beat)
	assert_eq((director.by_id[&"rn_stray_block"] as DialogueLine).speaker, &"tamlin_beast", "the block is his one line")
	var drive := RideNorth.drive_points()
	var last := drive[drive.size() - 1]
	var door := Vector2(ManorSitePlan.FRONT_DOOR.x, ManorSitePlan.FRONT_DOOR.z)
	assert_almost_eq(road[road.size() - 1].distance_to(last), 0.0, 0.01, "the road ends where the drive does")
	assert_almost_eq(last.distance_to(door), RideNorth.STOP_OUT, 0.2, "in the saddle just outside the doors' radius")
	for p in drive:
		assert_gt(p.distance_to(ManorSitePlan.FORECOURT_CENTER), 15.0, "on gravel, round the fountain")
		assert_gt(p.distance_to(door), ManorArrival.DOOR_RADIUS, "never inside the radius mounted")
	var steps := RideNorth.beast_steps()
	assert_lt(Vector2(steps.x, steps.z).distance_to(door), ManorArrival.DOOR_RADIUS, "he waits at the doors")
