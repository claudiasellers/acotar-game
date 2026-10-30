## The service wing layout (data/regions/spring_court/manor_estate/house/service.tres).
extends GutTest

const PATH := "res://data/regions/spring_court/manor_estate/house/service.tres"
const NEW_PROP_IDS := [&"toy_wooden_horse", &"dumbwaiter", &"loose_jar"]

var layout: ManorHouseLayout
var index: ManorHouseIndex


func before_each() -> void:
	layout = load(PATH) as ManorHouseLayout
	index = ManorHouseIndex.new([layout])


func _main_door_room(level: int) -> ManorRoomDef:
	var found := index.rooms_at(level, Vector2(42.4, -50))
	return found[0] if found.size() == 1 else null


func test_rooms_fit_the_wing_and_do_not_overlap() -> void:
	var rooms := index.interior_rooms()
	assert_gte(rooms.size(), 14)
	assert_eq(index.overlaps().size(), 0, str(index.overlaps()))
	var levels := {}
	for r in rooms:
		levels[r.level] = true
		assert_true(ManorSitePlan.HOUSE_SERVICE.encloses(r.rect), "%s inside the wing" % r.id)
		if r.level < 0:
			assert_true(ManorSitePlan.CELLAR_ZONES[1].encloses(r.rect), "%s inside the cellar zone" % r.id)
		assert_true(r.canon in ["C", "C?", "X"], "%s canon tag" % r.id)
	assert_eq(levels.keys().size(), 4, "levels -1, 0, 1, 2")


func test_every_room_reachable_from_main_door_and_yard_door() -> void:
	var start := _main_door_room(0)
	assert_not_null(start, "a level-0 room touches (42,-50)")
	assert_not_null(_main_door_room(1), "a level-1 room touches (42,-50)")
	assert_almost_eq(start.rect.position.x, 42.0, 0.01)
	var yard: ManorDoorDef = null
	for d in layout.doors:
		if d.level == 0 and is_equal_approx(d.at.x, 74.0):
			yard = d
	assert_not_null(yard, "kitchen-yard door on x=74")
	var yard_rooms := index.door_rooms(yard)
	assert_eq(yard_rooms.size(), 1, "yard door leads outside")
	var rooms := index.interior_rooms()
	for from in [start.id, yard_rooms[0].id]:
		var all := index.reachable(from)
		for r in rooms:
			assert_true(all.has(r.id), "%s reachable from %s" % [r.id, from])
	var open_only := index.reachable(start.id, false)
	assert_gte(float(open_only.size()) / rooms.size(), 0.9, "90% reachable with secrets closed")


func test_required_rooms() -> void:
	for id in [&"svc_kitchen", &"svc_scullery", &"svc_pantry", &"svc_bakery", &"svc_servants_hall",
			&"svc_housekeeper", &"svc_alis_room", &"svc_stillroom", &"svc_infirmary", &"svc_laundry",
			&"svc_linen_room", &"svc_maids_dorm", &"svc_footmen_room", &"svc_maid_bedroom_a",
			&"svc_back_stair_0", &"svc_back_stair_1", &"svc_back_stair_2",
			&"svc_wine_cellar", &"svc_cold_store", &"svc_root_cellar"]:
		assert_not_null(index.find_room(id), "room %s" % id)
	assert_eq(index.find_room(&"svc_infirmary").canon, "C")
	assert_eq(index.find_room(&"svc_stillroom").canon, "X")
	assert_eq(index.find_room(&"svc_kitchen").canon, "C?")
	assert_eq(index.find_room(&"svc_laundry").canon, "X")
	assert_eq(index.find_room(&"svc_alis_room").level, 1)
	assert_eq(index.find_room(&"svc_maid_bedroom_a").level, 2)


func test_rooms_are_furnished_and_colourful() -> void:
	var rooms := index.interior_rooms()
	var total := 0
	var colours := {}
	for r in rooms:
		assert_gte(r.props.size(), 6, "%s has >= 6 props" % r.id)
		total += r.props.size()
		colours[r.wall_color.to_html(false)] = true
		for p in r.props:
			assert_true(PropCatalog.ENTRIES.has(p.prop_id) or p.prop_id in NEW_PROP_IDS,
					"%s: known prop %s" % [r.id, p.prop_id])
	assert_gte(float(total) / rooms.size(), 10.0, "average props per room")
	assert_gte(colours.size(), 6, "varied wall colours")
	var kitchen := index.find_room(&"svc_kitchen")
	var ids := kitchen.props.map(func(p: ManorPropPlacement) -> StringName: return p.prop_id)
	for need in [&"copper_pots", &"table_kitchen", &"dresser_crockery"]:
		assert_true(ids.has(need), "kitchen has %s" % need)


func test_stations() -> void:
	var by_id := {}
	for s in layout.stations:
		by_id[s.station_id] = by_id.get(s.station_id, 0) + 1
		var inside := index.rooms_at(s.level, Vector2(s.position.x, s.position.z))
		assert_eq(inside.size(), 1, "%s stands in a room" % s.station_id)
	for id in [&"kitchen", &"bread_oven", &"stillroom", &"infirmary", &"hearth"]:
		assert_gte(by_id.get(id, 0), 1, "station %s" % id)
	assert_eq(index.rooms_at(0, Vector2(49, -67.2))[0].id, &"svc_kitchen", "range in the kitchen")


func test_secrets() -> void:
	assert_gte(layout.secrets.size(), 3)
	var kinds := {}
	for s in layout.secrets:
		kinds[s.kind] = kinds.get(s.kind, 0) + 1
		if s.kind == &"keepsake":
			assert_true(String(s.item_id).begins_with("col_"), "keepsake id %s" % s.item_id)
		if s.kind == &"lever":
			var doors := layout.doors.filter(func(d: ManorDoorDef) -> bool:
				return d.kind == &"secret" and d.secret_id == s.secret_id)
			assert_eq(doors.size(), 1, "lever %s opens a secret door" % s.secret_id)
	assert_gte(kinds.get(&"lever", 0), 1)
	assert_gte(kinds.get(&"keepsake", 0), 1)
	assert_gte(kinds.get(&"discovery", 0), 1)
	assert_false(index.reachable(&"svc_passage_0", false).has(&"svc_smugglers_passage"),
			"smugglers' passage is hidden until the jar is tilted")


func test_back_stairs_and_roof() -> void:
	var from_levels := {}
	for s in layout.stairs:
		from_levels[s.level_from] = true
		assert_true(ManorSitePlan.HOUSE_SERVICE.encloses(s.rect), "%s inside the wing" % s.id)
		assert_eq(index.rooms_at(s.level_from, ManorHouseBuilder.stair_bottom(s)).size(), 1, "%s bottom" % s.id)
		assert_eq(index.rooms_at(s.level_from + 1, ManorHouseBuilder.stair_top(s)).size(), 1, "%s top" % s.id)
	assert_true(from_levels.has(-1) and from_levels.has(0) and from_levels.has(1))
	var hip: ManorRoofDef = null
	for r in layout.roofs:
		if r.rect == ManorSitePlan.HOUSE_SERVICE:
			hip = r
	assert_not_null(hip, "service wing roof")
	assert_eq(hip.style, &"hip")
	assert_eq(hip.base_level, 2)
	assert_true(hip.color.b > hip.color.g, "lilac slate")


func test_builds_alone() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var house := ManorHouseBuilder.build(root, [layout])
	for r in layout.rooms:
		assert_not_null(house.get_node_or_null(String(r.id)), "built %s" % r.id)
	assert_not_null(house.get_node_or_null("Stair_svc_cellar"))
	assert_not_null(house.get_node_or_null("Door_smugglers_run"))
	var levers := layout.secrets.filter(func(s: ManorSecretDef) -> bool: return s.kind == &"lever").size()
	assert_eq(get_tree().get_nodes_in_group(ManorStation.GROUP).size(), layout.stations.size() + levers,
			"stations and levers are usable")
	assert_gt(house.find_children("*", "MeshInstance3D", true, false).size(), 500, "a densely built wing")
