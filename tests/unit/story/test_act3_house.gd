## L28 contract (docs/contracts/house_beats.md): the p3 house beats, ch12-13.
## Her X marks and the rooms on her page; the tower views on the world map;
## the night of the Bogge from the foyer table to the bound hand; the study
## mural studied with a painter's eye. Each raises only facts; the moments
## turn them into the deeds (R2).
extends GutTest

const DT := 0.1

var root: Node3D
var house: Node3D
var feyre: Node3D


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	Clock.paused = true
	root = Node3D.new()
	add_child_autofree(root)
	house = Node3D.new()
	house.name = "House"
	root.add_child(house)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = false


func after_each() -> void:
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = true
	StoryControl.release()
	Clock.paused = false
	for page in get_tree().get_nodes_in_group(HallMapPage.GROUP):
		page.queue_free()


## A house anchor where the manor lane puts it (layout position, floor height, yaw).
func _anchor(anchor_id: StringName) -> Marker3D:
	var m := Marker3D.new()
	m.name = String(anchor_id)
	m.set_meta(&"anchor_id", anchor_id)
	for layout in ManorHouseBuilder.load_layouts():
		for a: ManorAnchorDef in layout.anchors:
			if a.anchor_id == anchor_id:
				m.position = Vector3(a.position.x, ManorHouseBuilder.floor_y(a.level), a.position.z)
				m.rotation.y = deg_to_rad(a.yaw_deg)
	house.add_child(m)
	return m


func _house_point(x: float, z: float, level: int = 0) -> Vector3:
	return house.to_global(Vector3(x, ManorHouseBuilder.floor_y(level) + 0.1, z))


func _hang(anchor_id: StringName) -> Marker3D:
	var a := _anchor(anchor_id)
	Act3Anchors.attach(a)
	for child in a.get_children():
		if child is SceneSpace:
			(child as SceneSpace).auto_tick = false
	return a


func _tick(space: SceneSpace, seconds: float) -> void:
	for _i in int(seconds / DT):
		space.tick(DT)


# --- Act3Anchors -------------------------------------------------------------------

func test_rows_hang_once_and_return_scene_spaces() -> void:
	var infirmary := _anchor(&"manor_infirmary")
	var spaces := Act3Anchors.attach(infirmary)
	assert_eq(spaces.size(), 1, "WoundDressing is the infirmary's scene")
	assert_true(spaces[0] is WoundDressing)
	assert_not_null(infirmary.get_node_or_null(^"InfirmaryWorktable"))
	Act3Anchors.attach(infirmary)
	assert_eq(infirmary.get_child_count(), 2, "attaching twice adds nothing")
	var first := _anchor(&"hall_mark_1")
	Act3Anchors.attach(first)
	assert_not_null(first.get_node_or_null(^"HallMap"))
	assert_not_null(first.get_node_or_null(^"HallMark"))
	assert_eq(Act3Anchors.attach(_anchor(&"manor_study_mural"))[0].name, &"StudyMural")


func test_stage_marks_follow_the_layout_anchors() -> void:
	# The generator wrote the marks from anchors.tres: the foyer table must be
	# in the entrance hall and the worktable in the infirmary, in house space.
	var a := _hang(&"manor_infirmary")
	var wound := a.get_node(^"WoundDressing") as WoundDressing
	var foyer := house.to_local(wound.mark(&"foyer_table"))
	assert_true(Rect2(-10, -60, 20, 32).has_point(Vector2(foyer.x, foyer.z)), "foyer table in the entrance hall: %s" % foyer)
	var table := house.to_local(wound.mark(&"table"))
	assert_true(Rect2(64, -41, 10, 7).has_point(Vector2(table.x, table.z)), "worktable in the infirmary: %s" % table)
	var bench := a.get_node(^"InfirmaryWorktable") as InfirmaryWorktable
	assert_almost_eq(house.to_local(bench.tray_point()).y, ManorHouseBuilder.floor_y(0) + 0.95, 0.05, "tray at worktable height")


# --- her map of the halls ------------------------------------------------------------

func test_rooms_go_on_her_page_only_from_the_night_after_the_puca() -> void:
	var a := _hang(&"hall_mark_1")
	var map := a.get_node(^"HallMap") as HallMap
	map.auto_tick = false
	var hall := Vector3(0, ManorHouseBuilder.floor_y(0) + 0.1, -36)
	assert_eq(map.check_at(hall), &"", "nothing before p3")
	WorldState.set_flag("puca_resisted")
	assert_eq(map.check_at(hall), &"entrance_hall")
	assert_eq(map.check_at(hall), &"", "a room goes on once")
	assert_eq(map.check_at(Vector3(23, ManorHouseBuilder.floor_y(1) + 0.1, -70)), &"feyre_bedroom", "upstairs by height")
	assert_eq(map.pictogram_for(&"svc_infirmary"), "bandage")
	assert_eq(HallMap.guess_pictogram("svc_kitchen"), "pot")


func test_enough_rooms_and_tower_views_reveal_map_places() -> void:
	WorldState.set_flag("puca_resisted")
	var a := _hang(&"hall_mark_1")
	var map := a.get_node(^"HallMap") as HallMap
	map.auto_tick = false
	var drawn: Array[StringName] = []
	map.reveal_fn = func(id: StringName) -> bool:
		drawn.append(id)
		return true
	var count := 0
	for r in map.rooms:
		if int(r["level"]) == 0 and count < map.plan.min_rooms - 1:
			var c := (r["rect"] as Rect2).get_center()
			if map.check_at(Vector3(c.x, ManorHouseBuilder.floor_y(0) + 0.1, c.y)) != &"":
				count += 1
	assert_false(WorldState.has_flag(HallMap.ENOUGH_FACT), "one short of enough")
	var towers := 0
	for room_id in map.plan.lookouts.keys():
		for r in map.rooms:
			if StringName(r["id"]) == StringName(room_id):
				var c := (r["rect"] as Rect2).get_center()
				assert_eq(map.check_at(Vector3(c.x, ManorHouseBuilder.floor_y(int(r["level"])) + 0.1, c.y)), StringName(room_id))
				towers += 1
	assert_eq(towers, 4, "four tower tops")
	assert_true(WorldState.has_flag(HallMap.ENOUGH_FACT))
	assert_gte(drawn.size(), 4, "the towers sketch at least four places")
	assert_true(drawn.has(&"rosewild") and drawn.has(&"blossom_vale"))


func test_a_hall_mark_needs_her_there_and_raises_its_fact() -> void:
	var a := _hang(&"hall_mark_3")
	var mark := a.get_node(^"HallMark") as HallMark
	feyre.global_position = a.global_position + Vector3(1, 0, 0)
	mark.press_interact()
	assert_false(mark.running, "not before the night after the puca")
	WorldState.set_flag("puca_resisted")
	feyre.global_position = a.global_position + Vector3(6, 0, 0)
	mark.press_interact()
	assert_false(mark.running, "not from across the hall")
	feyre.global_position = a.global_position + Vector3(1, 0, 0)
	mark.press_interact()
	assert_true(mark.running)
	_tick(mark, 3.0)
	assert_true(WorldState.has_flag("fact.hall_x_3"))
	assert_false(WorldState.has_flag("manor_map_drawn"), "a mark is a fact, never the deed")
	assert_eq(String(mark.info().get("shape")), "x")


# --- the night of the Bogge ----------------------------------------------------------

func _ready_for_the_night() -> void:
	for i in range(1, 6):
		WorldState.set_flag("fact.hall_x_%d" % i)
	WorldState.set_flag(HallMap.ENOUGH_FACT)
	WorldState.set_flag("puca_resisted")
	Clock.from_dict({"time_of_day": 0.95, "day": 1})


## Plays the scene the way a player would: walks where the glints are and presses E.
func _play_night(wound: WoundDressing) -> int:
	var steps := 0
	for _i in 4000:
		if not wound.running:
			break
		var label := wound.current_beat_label()
		var target := Vector3.INF
		if label == "until she sets the map down":
			target = wound.mark(&"foyer_map")
		elif label.begins_with("lead tamlin") or label == "until feyre reaches feyre_work":
			var t := wound.actor(&"tamlin")
			target = t.global_position if t else Vector3.INF
		elif label.begins_with("until ") and wound.glint.visible:
			target = wound.glint.global_position
		if target != Vector3.INF:
			feyre.global_position = Vector3(target.x, target.y - 0.3 if label.begins_with("until the") else target.y, target.z)
			if label.begins_with("until the") or label.begins_with("until his") or label.begins_with("until she sets"):
				wound.press_interact()
				steps += 1
		wound.tick(DT)
	return steps


func test_the_night_of_the_bogge_plays_to_the_bound_hand() -> void:
	_ready_for_the_night()
	var a := _hang(&"manor_infirmary")
	var wound := a.get_node(^"WoundDressing") as WoundDressing
	wound.instant_fades = true
	feyre.global_position = wound.mark(&"foyer_table")
	assert_true(wound.start(), "starts at the foyer table at night")
	_play_night(wound)
	assert_false(wound.running, "finished (stuck at '%s')" % wound.current_beat_label())
	assert_true(WorldState.has_flag("fact.hall_map_set_down"))
	assert_true(WorldState.has_flag("fact.tamlin_knows_she_cannot_read"))
	assert_true(WorldState.has_flag("fact.tamlin_hand_bound"))
	assert_eq(wound.collected.size(), 3, "bowl, linen, bandage")
	assert_true(wound.bowl_full and wound.bowl_emptied)
	assert_eq(wound.cleaned, WoundDressing.STEPS_CLEAN)
	assert_eq(wound.bound, WoundDressing.STEPS_BIND)
	assert_gt(wound.stains.size(), 5, "dark, shining stains across the marble")
	assert_false(WorldState.has_flag("tamlin_wound_dressed"), "the moment raises the deed, not the scene")
	assert_false(wound.can_start(), "never twice")


func test_the_night_waits_for_the_marks_and_the_dark() -> void:
	var a := _hang(&"manor_infirmary")
	var wound := a.get_node(^"WoundDressing") as WoundDressing
	_ready_for_the_night()
	WorldState.set_flag("fact.hall_x_4", false)
	assert_false(wound.can_start(), "one mark missing")
	WorldState.set_flag("fact.hall_x_4")
	Clock.from_dict({"time_of_day": 0.5, "day": 1})
	assert_false(wound.can_start(), "not by day")
	assert_true(wound.waits_only_for_time(), "by day the night comes to her at the table")


func test_washing_comes_before_binding_and_needs_the_full_bowl() -> void:
	_ready_for_the_night()
	WorldState.set_flag("fact.hall_map_set_down")
	var a := _hang(&"manor_infirmary")
	var wound := a.get_node(^"WoundDressing") as WoundDressing
	wound.instant_fades = true
	feyre.global_position = wound.mark(&"foyer_table")
	wound.start()
	# Run to the infirmary deed without pressing anything.
	for _i in 2000:
		if wound.current_beat_label() == "until the supplies are on the table":
			break
		var t := wound.actor(&"tamlin")
		if t:
			feyre.global_position = t.global_position
		wound.tick(DT)
	assert_eq(wound.current_beat_label(), "until the supplies are on the table")
	feyre.global_position = wound._hand_point()
	for _i in 5:
		wound.press_interact()
		wound.tick(DT)
	assert_eq(wound.cleaned, 0, "no cleaning before the supplies and the water")
	assert_eq(wound.collected.size(), 0)


# --- the study mural ----------------------------------------------------------------

func test_the_mural_is_studied_by_looking_at_three_details() -> void:
	var a := _hang(&"manor_study_mural")
	var mural := a.get_node(^"StudyMural") as StudyMural
	assert_eq(mural.spots.size(), 5, "crocuses, lambs, roses, the Wall, the mountain")
	assert_not_null(mural.painting.material_override, "the painting is on the wall before the beat")
	feyre.global_position = mural.mark(&"view")
	assert_false(mural.start(), "not before his hand is dressed")
	WorldState.set_flag("tamlin_wound_dressed")
	assert_true(mural.start())
	var from := mural.mark(&"view") + Vector3.UP * 1.6
	var looking_at := [&"crocuses"]
	mural.gaze_fn = func() -> Array: return [from, mural.spot_world(looking_at[0]) - from]
	_tick(mural, 0.5)
	assert_eq(mural.noticed.size(), 0, "a glance is not enough")
	for id: StringName in [&"crocuses", &"lambs", &"wall"]:
		looking_at[0] = id
		_tick(mural, 1.2)
	assert_eq(mural.noticed.size(), 3)
	_tick(mural, 8.0)
	assert_true(WorldState.has_flag("fact.mural_studied"))
	assert_false(WorldState.has_flag("study_mural_seen"), "the moment raises the deed")
	assert_false(mural.running)


func test_looking_away_notices_nothing() -> void:
	WorldState.set_flag("tamlin_wound_dressed")
	var a := _hang(&"manor_study_mural")
	var mural := a.get_node(^"StudyMural") as StudyMural
	mural.start()
	var from := mural.mark(&"view") + Vector3.UP * 1.6
	mural.gaze_fn = func() -> Array: return [from, from - mural.spot_world(&"roses")]
	_tick(mural, 5.0)
	assert_eq(mural.noticed.size(), 0)
	assert_true(mural.running)


# --- the moments turn facts into deeds -------------------------------------------------

func test_moments_chain_the_house_deeds_in_book_order() -> void:
	var wound := StoryDirector.get_moment(&"wound_dressing")
	assert_eq(Array(wound.require_flags), ["manor_map_drawn"], "the map comes first (Keeper, ch12)")
	var map := StoryDirector.get_moment(&"manor_map")
	var waits := []
	for step in map.steps:
		if step.get("do") == "until_flag":
			waits.append(String(step["flag"]))
	assert_true(waits.has("fact.hall_map_set_down"))
	assert_eq(Array(StoryDirector.get_moment(&"study_mural").require_flags), ["tamlin_wound_dressed"])
