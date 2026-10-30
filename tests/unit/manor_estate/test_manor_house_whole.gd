## All house parts together: the seams between lanes, totals for the done list,
## and the story anchors.
extends GutTest

const ANCHORS := [&"feyre_bedroom_window", &"hall_mark_1", &"hall_mark_2", &"hall_mark_3",
	&"hall_mark_4", &"hall_mark_5", &"manor_alis_hiding", &"manor_dining_table", &"manor_gallery",
	&"manor_infirmary", &"manor_kitchen_hall", &"manor_study_mural", &"manor_tamlin_room",
	&"manor_window_hide", &"painting_room_easel"]

var index: ManorHouseIndex


func before_all() -> void:
	index = ManorHouseIndex.new(ManorHouseBuilder.load_layouts())


func test_parts_do_not_overlap() -> void:
	assert_eq(index.overlaps(), PackedStringArray())


func test_every_room_is_reachable_from_the_entrance_hall() -> void:
	var seen := index.reachable(&"entrance_hall")
	var missing: Array = []
	for r in index.interior_rooms():
		if not seen.has(r.id):
			missing.append(r.id)
	assert_eq(missing, [], "unreachable rooms")
	var open := index.reachable(&"entrance_hall", false)
	gut.p("rooms %d, reachable without secrets %d" % [index.interior_rooms().size(), open.size()])
	assert_gt(float(open.size()) / index.interior_rooms().size(), 0.9)


func test_done_list_totals() -> void:
	var rooms := index.interior_rooms()
	var props := 0
	for r in rooms:
		props += r.props.size()
	var ids := {}
	for s in index.stations:
		ids[s.station_id] = true
	gut.p("rooms %d, props %d, stations %d, secrets %d" % [rooms.size(), props, index.stations.size(), index.secrets.size()])
	assert_gte(rooms.size(), 50)
	assert_gte(float(props) / rooms.size(), 8.0)
	assert_gte(index.stations.size(), 14)
	assert_gte(index.secrets.size(), 12)
	for id in [&"wardrobe", &"dressing_mirror", &"kitchen", &"stillroom", &"easel", &"bed", &"bath",
			&"library_desk", &"harp", &"pianoforte", &"armory_rack", &"bread_oven", &"infirmary", &"hearth"]:
		assert_true(ids.has(id), "station %s" % id)


func test_story_anchors_sit_inside_rooms() -> void:
	var found := {}
	for a in index.anchors:
		found[a.anchor_id] = true
		var p := Vector2(a.position.x, a.position.z)
		assert_false(index.rooms_at(a.level, p).is_empty(), "%s is inside a room" % a.anchor_id)
	for id in ANCHORS:
		assert_true(found.has(id), "anchor %s" % id)


func test_whole_house_builds() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var t := Time.get_ticks_msec()
	var house := ManorHouseBuilder.build(root)
	gut.p("house built in %d ms, %d nodes" % [Time.get_ticks_msec() - t, house.get_child_count()])
	assert_eq(get_tree().get_nodes_in_group(&"story_anchor").size(), ANCHORS.size())
