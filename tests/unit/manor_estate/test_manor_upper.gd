## Sub-lane B: the upper storeys (levels 1-3), towers and roofs of the manor.
## Checks upper.tres on its own against the definition of done.
extends GutTest

const PATH := "res://data/regions/spring_court/manor_estate/house/upper.tres"
const START := &"upper_hall"

var layout: ManorHouseLayout
var index: ManorHouseIndex


func before_all() -> void:
	layout = load(PATH) as ManorHouseLayout
	index = ManorHouseIndex.new([layout])


func _interior() -> Array[ManorRoomDef]:
	return index.interior_rooms()


func test_room_count_levels_and_no_overlaps() -> void:
	var rooms := _interior()
	assert_gte(rooms.size(), 22, "at least 22 upper rooms")
	for r in rooms:
		assert_true(r.level >= 1 and r.level <= 3, "%s on levels 1-3" % r.id)
		assert_true(r.ceiling_height <= 4.5, "%s is not double height" % r.id)
		var in_main := ManorSitePlan.HOUSE_MAIN.encloses(r.rect)
		var in_west := ManorSitePlan.HOUSE_WEST.encloses(r.rect)
		assert_true(in_main or (in_west and r.level == 1), "%s inside main block (or west wing on level 1)" % r.id)
	assert_eq(index.overlaps().size(), 0, "overlaps: %s" % [index.overlaps()])


func test_landing_covers_grand_stair_and_reachability() -> void:
	var hall := index.find_room(START)
	assert_eq(hall.level, 1)
	assert_true(hall.rect.encloses(Rect2(-8, -62, 16, 24)), "upper hall covers the grand stair landing")
	assert_eq(index.rooms_at(1, Vector2(0, -53)).size(), 1, "grand stair arrives in a level-1 room")
	var rooms := _interior()
	var all := index.reachable(START, true)
	for r in rooms:
		assert_true(all.has(r.id), "%s reachable with secrets open" % r.id)
	var open := index.reachable(START, false)
	var ratio := float(open.size()) / rooms.size()
	assert_gte(ratio, 0.9, "%.2f reachable with secrets closed" % ratio)


func test_required_rooms_present() -> void:
	var want := [&"upper_hall", &"feyre_bedroom", &"feyre_bath", &"dressing_room", &"painting_room",
			&"tamlin_bedchamber", &"lucien_chambers", &"guest_suite_periwinkle", &"guest_suite_lilac",
			&"portrait_gallery", &"sewing_room", &"front_reading_nook", &"garden_loggia",
			&"attic_trunk_room", &"attic_costume_store", &"moon_tower_hidden", &"observatory", &"rose_bower"]
	for id in want:
		assert_not_null(index.find_room(id), "room %s" % id)
	# Dressing room sits next to Feyre's bedroom and is fully kitted.
	var dr := index.find_room(&"dressing_room")
	var bed := index.find_room(&"feyre_bedroom")
	assert_true(dr.rect.grow(0.1).intersects(bed.rect), "dressing room adjoins the bedroom")
	assert_true(index.graph(false)[&"feyre_bedroom"].has(&"dressing_room"), "door bedroom -> dressing room")
	var ids := dr.props.map(func(p: ManorPropPlacement) -> StringName: return p.prop_id)
	for need in [&"gown_rack", &"mannequin_gown", &"shoe_shelf", &"hat_stand", &"cheval_mirror", &"vanity_table",
			&"jewelry_box", &"makeup_palette", &"perfume_tray", &"dressing_screen", &"pouf_stool"]:
		assert_has(ids, need, "dressing room has %s" % need)
	# Bedroom: window seat on the garden (north) wall; tagging.
	var seat := bed.props.filter(func(p: ManorPropPlacement) -> bool: return p.prop_id == &"window_seat" and p.position.z < 1.0)
	assert_gt(seat.size(), 0, "window seat on the garden wall")
	for id in [&"upper_hall", &"feyre_bedroom", &"feyre_bath", &"tamlin_bedchamber", &"lucien_chambers"]:
		assert_eq(index.find_room(id).canon, "C", "%s is canon" % id)
	assert_eq(dr.canon, "X")
	var levels := {1: 0, 2: 0, 3: 0}
	for r in _interior():
		levels[r.level] += 1
	assert_gte(levels[2], 8, "attic rooms")
	assert_eq(levels[3], 4, "four tower tops")


func test_every_room_furnished_and_colours_vary() -> void:
	var total := 0
	var colours := {}
	for r in _interior():
		assert_gte(r.props.size(), 6, "%s has >= 6 props" % r.id)
		total += r.props.size()
		colours[r.wall_color.to_html(false)] = true
		var lum := r.wall_color.get_luminance()
		assert_true(r.wall_color.s > 0.03 and lum > 0.7, "%s wall colour is pastel, not grey" % r.id)
	var avg := float(total) / _interior().size()
	assert_gte(avg, 10.0, "average props per room %.1f" % avg)
	assert_gte(colours.size(), 7, "wall colours vary")


func test_stations() -> void:
	var count := {}
	for s in layout.stations:
		count[s.station_id] = count.get(s.station_id, 0) + 1
		assert_eq(index.rooms_at(s.level, Vector2(s.position.x, s.position.z)).size(), 1, "%s inside a room" % s.station_id)
	for id in [&"bed", &"bath", &"wardrobe", &"dressing_mirror", &"easel"]:
		assert_eq(count.get(id, 0), 1, "station %s" % id)
	assert_gte(count.get(&"hearth", 0), 2, "hearths")
	var by_id := {}
	for s in layout.stations:
		by_id[s.station_id] = index.rooms_at(s.level, Vector2(s.position.x, s.position.z))[0].id
	assert_eq(by_id[&"bed"], &"feyre_bedroom")
	assert_eq(by_id[&"bath"], &"feyre_bath")
	assert_eq(by_id[&"wardrobe"], &"dressing_room")
	assert_eq(by_id[&"dressing_mirror"], &"dressing_room")
	assert_eq(by_id[&"easel"], &"painting_room")
	var mirror: ManorStationDef = layout.stations.filter(func(s: ManorStationDef) -> bool: return s.station_id == &"dressing_mirror")[0]
	assert_eq(mirror.prop_id, &"vanity_mirror")


func test_secrets() -> void:
	var levers := {}
	var keepsakes := 0
	for s in layout.secrets:
		assert_eq(index.rooms_at(s.level, Vector2(s.position.x, s.position.z)).size(), 1, "%s inside a room" % s.secret_id)
		if s.kind == &"lever":
			levers[s.secret_id] = true
		elif s.kind == &"keepsake":
			keepsakes += 1
			assert_true(String(s.item_id).begins_with("col_"), "%s uses a col_ id" % s.secret_id)
	assert_gte(layout.secrets.size(), 4)
	assert_gte(keepsakes, 2)
	var secret_doors := layout.doors.filter(func(d: ManorDoorDef) -> bool: return d.kind == &"secret")
	assert_gte(secret_doors.size(), 3)
	for d in secret_doors:
		assert_true(levers.has(d.secret_id), "secret door %s has a lever" % d.secret_id)
		assert_eq(index.door_rooms(d).size(), 2, "secret door %s joins two rooms" % d.secret_id)
	var mirror := secret_doors.filter(func(d: ManorDoorDef) -> bool: return d.disguise == &"mirror")
	assert_eq(mirror.size(), 1, "mirror door in the dressing room")
	var hidden := index.reachable(START, false)
	for id in [&"jewel_closet", &"lucien_cabinet", &"moon_tower_hidden"]:
		assert_false(hidden.has(id), "%s hidden while secrets are closed" % id)


func test_fixed_connection_points_stairs_and_roofs() -> void:
	for at in [Vector2(42, -50), Vector2(-42, -50)]:
		var found := layout.doors.filter(func(d: ManorDoorDef) -> bool: return d.level == 1 and d.at == at)
		assert_eq(found.size(), 1, "level-1 door at %s" % at)
	var attic := layout.stairs.filter(func(s: ManorStairDef) -> bool: return s.level_from == 1)
	var towers := layout.stairs.filter(func(s: ManorStairDef) -> bool: return s.level_from == 2)
	assert_eq(attic.size(), 1, "attic stair 1->2")
	assert_eq(towers.size(), 4, "tower stairs 2->3")
	for s in layout.stairs:
		assert_eq(index.rooms_at(s.level_from, ManorHouseBuilder.stair_bottom(s)).size(), 1, "%s bottom in a room" % s.id)
		assert_eq(index.rooms_at(s.level_from + 1, ManorHouseBuilder.stair_top(s)).size(), 1, "%s top in a room" % s.id)
	var over_main := false
	var over_west := false
	var cones := 0
	var gold := 0
	for r in layout.roofs:
		assert_false(r.rect.intersects(ManorSitePlan.HOUSE_SERVICE), "no roof on the service wing")
		over_main = over_main or ManorSitePlan.HOUSE_MAIN.encloses(r.rect) and r.rect.get_area() > 1000.0
		over_west = over_west or r.rect == ManorSitePlan.HOUSE_WEST
		if r.style == &"cone" or r.style == &"dome":
			if r.rect.size.x >= 8.0:
				cones += 1
			else:
				gold += 1
	assert_true(over_main and over_west, "roofs over main block and west wing")
	assert_eq(cones, 4, "four tower roofs")
	assert_eq(gold, 4, "four gold finials")
	# Tower tops reach landmark height (> 25 m above the ground floor).
	var tip := ManorHouseBuilder.floor_y(4) + 11.0 - ManorHouseBuilder.floor_y(0)
	assert_gt(tip, 25.0)


func test_builder_builds_layout_alone() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var house := ManorHouseBuilder.build(root, [layout])
	for r in layout.rooms:
		assert_not_null(house.get_node_or_null(String(r.id)), "built %s" % r.id)
	assert_eq(get_tree().get_nodes_in_group(ManorStation.GROUP).size(), layout.stations.size() + 3, "stations + 3 levers")
	assert_not_null(house.get_node_or_null("Door_jewel_closet"))
	assert_not_null(house.get_node_or_null("Stair_attic"))
	assert_gt(house.get_child_count(), 60)
