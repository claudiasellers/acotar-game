## Ground floor + cellars part (gen_ground.gd -> ground.tres): the lane's
## definition of done, as numbers.
extends GutTest

const PATH := "res://data/regions/spring_court/manor_estate/house/ground.tres"
const FIXED_DOORS := [Vector2(0, -28), Vector2(42, -50), Vector2(-42, -50),
		Vector2(0, -72), Vector2(-24, -72), Vector2(24, -72)]
## Doors that legitimately lead outside or into another lane's wing.
const OUTER_DOORS := [Vector2(0, -28), Vector2(42, -50), Vector2(0, -72), Vector2(-24, -72), Vector2(24, -72)]
const REQUIRED := [&"entrance_hall", &"dining_hall", &"gallery", &"tamlin_study", &"library",
		&"drawing_room", &"music_room", &"morning_room", &"map_room", &"armory", &"ballroom",
		&"conservatory", &"shrine", &"west_corridor", &"east_corridor", &"wine_vault",
		&"old_storerooms", &"painting_store", &"old_tunnel", &"mask_vault"]

var layout: ManorHouseLayout
var index: ManorHouseIndex


func before_all() -> void:
	layout = load(PATH) as ManorHouseLayout
	index = ManorHouseIndex.new([layout])


func _start() -> StringName:
	for r in index.rooms_at(0, Vector2(0, -28.7)):
		return r.id
	return &""


func test_rooms_tile_and_are_reachable() -> void:
	var rooms := index.interior_rooms()
	var on_levels := rooms.filter(func(r: ManorRoomDef) -> bool: return r.level == 0 or r.level == -1)
	gut.p("rooms: %d (level 0: %d, level -1: %d)" % [rooms.size(),
			rooms.filter(func(r: ManorRoomDef) -> bool: return r.level == 0).size(),
			rooms.filter(func(r: ManorRoomDef) -> bool: return r.level == -1).size()])
	assert_eq(on_levels.size(), rooms.size(), "only levels 0 and -1")
	assert_gte(rooms.size(), 22)
	assert_eq(index.overlaps().size(), 0, "overlaps: %s" % [index.overlaps()])
	assert_eq(_start(), &"entrance_hall")
	var all := index.reachable(_start())
	var closed := index.reachable(_start(), false)
	var missing := rooms.filter(func(r: ManorRoomDef) -> bool: return not all.has(r.id)).map(func(r: ManorRoomDef) -> StringName: return r.id)
	assert_eq(missing.size(), 0, "unreachable with secrets open: %s" % [missing])
	var ratio := float(closed.size()) / rooms.size()
	gut.p("reachable: open %d / %d, closed %d (%.1f%%)" % [all.size(), rooms.size(), closed.size(), ratio * 100.0])
	assert_gte(ratio, 0.9)


func test_rooms_inside_footprints_and_cellar_zones() -> void:
	for r in index.interior_rooms():
		if r.level == 0:
			var ok := ManorSitePlan.HOUSE_MAIN.encloses(r.rect) or ManorSitePlan.HOUSE_WEST.encloses(r.rect)
			assert_true(ok, "%s inside main block or west wing" % r.id)
		else:
			var ok := ManorSitePlan.CELLAR_ZONES[0].encloses(r.rect) or ManorSitePlan.CELLAR_ZONES[2].encloses(r.rect)
			assert_true(ok, "%s inside a cellar zone" % r.id)
		assert_true(r.canon in ["C", "C?", "X"], "%s canon tag" % r.id)


func test_required_rooms_and_gallery_lock() -> void:
	for id in REQUIRED:
		assert_not_null(index.find_room(id), "has %s" % id)
	var locked := index.doors.filter(func(d: ManorDoorDef) -> bool: return d.kind == &"locked")
	assert_eq(locked.size(), 1)
	assert_eq(locked[0].requires_flag, "gallery_opened")
	var joined := index.door_rooms(locked[0]).map(func(r: ManorRoomDef) -> StringName: return r.id)
	assert_true(joined.has(&"gallery"))
	var gallery_art := index.find_room(&"gallery").props.filter(func(p: ManorPropPlacement) -> bool:
		return String(p.prop_id).begins_with("painting") or p.prop_id == &"portrait_masked")
	var statues := index.find_room(&"gallery").props.filter(func(p: ManorPropPlacement) -> bool:
		return p.prop_id in [&"statue_maiden", &"statue_stag", &"bust_pedestal"])
	gut.p("gallery: %d paintings, %d statues" % [gallery_art.size(), statues.size()])
	assert_gte(gallery_art.size(), 14)
	assert_gte(statues.size(), 3)
	var dining := index.find_room(&"dining_hall").props
	assert_gte(dining.filter(func(p: ManorPropPlacement) -> bool: return p.prop_id == &"chair_dining").size(), 14)
	assert_gte(dining.filter(func(p: ManorPropPlacement) -> bool: return p.prop_id == &"chandelier_crystal").size(), 2)


func test_fixed_connection_points() -> void:
	for at in FIXED_DOORS:
		var found := index.doors.filter(func(d: ManorDoorDef) -> bool: return d.level == 0 and d.at.is_equal_approx(at))
		assert_eq(found.size(), 1, "door at %s" % at)
	var gate := index.doors.filter(func(d: ManorDoorDef) -> bool: return d.kind == &"gate")
	assert_eq(gate.size(), 1)
	assert_eq(gate[0].region_id, &"manor_house")
	assert_almost_eq(gate[0].width, 2.4, 0.01)
	for at in [Vector2(0, -72), Vector2(-24, -72), Vector2(24, -72)]:
		var d: ManorDoorDef = index.doors.filter(func(x: ManorDoorDef) -> bool: return x.at.is_equal_approx(at))[0]
		assert_almost_eq(d.width, 2.0, 0.01)
	var grand := index.stairs.filter(func(s: ManorStairDef) -> bool: return s.level_from == 0)
	assert_eq(grand.size(), 1)
	assert_eq(grand[0].rect, Rect2(-5, -52, 10, 12))
	assert_eq(grand[0].rise_toward, &"north")
	var cellar := index.stairs.filter(func(s: ManorStairDef) -> bool:
		return s.level_from == -1 and ManorSitePlan.CELLAR_ZONES[0].encloses(s.rect) and s.style == &"cellar")
	assert_gte(cellar.size(), 1, "main cellar stair")
	for s in index.stairs:
		if s.level_from == -1:
			assert_gt(index.rooms_at(-1, ManorHouseBuilder.stair_bottom(s)).size(), 0, "%s bottom in a room" % s.id)
			assert_gt(index.rooms_at(0, ManorHouseBuilder.stair_top(s)).size(), 0, "%s top in a room" % s.id)
	# Every inner door joins two rooms; outer doors lead outside / to the service wing.
	for d in index.doors:
		var n := index.door_rooms(d).size()
		var outer := OUTER_DOORS.any(func(o: Vector2) -> bool: return o.is_equal_approx(d.at))
		assert_eq(n, 1 if outer else 2, "door at %s (level %d) joins %d rooms" % [d.at, d.level, n])


func test_furnishing() -> void:
	var rooms := index.interior_rooms()
	var total := 0
	var min_props := 999
	var colors := {}
	var used := {}
	for r in rooms:
		total += r.props.size()
		min_props = mini(min_props, r.props.size())
		colors[r.wall_color.to_html(false)] = true
		for p in r.props:
			used[p.prop_id] = used.get(p.prop_id, 0) + 1
			var inside := p.position.x >= 0.0 and p.position.z >= 0.0 \
					and p.position.x <= r.rect.size.x and p.position.z <= r.rect.size.y
			assert_true(inside, "%s: %s inside the room" % [r.id, p.prop_id])
		assert_gte(r.props.size(), 6, "%s has >= 6 props" % r.id)
	var avg := float(total) / rooms.size()
	gut.p("props: %d total, average %.1f, min %d, wall colours %d" % [total, avg, min_props, colors.size()])
	assert_gte(avg, 10.0)
	assert_gte(colors.size(), 6)
	var lights := 0
	for id in [&"chandelier_crystal", &"chandelier_small", &"candle_sconce", &"lantern_hanging"]:
		lights += used.get(id, 0)
	assert_gte(lights, 150)
	var all_ids: Array = []
	for r in index.rooms:
		for p in r.props:
			all_ids.append(p.prop_id)
	for s in index.stations:
		all_ids.append(s.prop_id)
	assert_eq(PropLib.missing_ids(all_ids).size(), 0, "unknown prop ids: %s" % [PropLib.missing_ids(all_ids)])
	var keys := used.keys().map(func(k: StringName) -> String: return String(k))
	keys.sort()
	gut.p("catalogue coverage: %d / %d ids used: %s" % [keys.size(), PropCatalog.ENTRIES.size(), ", ".join(keys)])


func test_stations() -> void:
	var ids := index.stations.map(func(s: ManorStationDef) -> StringName: return s.station_id)
	assert_gte(ids.count(&"hearth"), 4)
	for id in [&"library_desk", &"harp", &"pianoforte", &"armory_rack"]:
		assert_true(ids.has(id), "station %s" % id)
	for s in index.stations:
		var p := Vector2(s.position.x, s.position.z)
		assert_gt(index.rooms_at(s.level, p).size(), 0, "station %s in a room" % s.display_name)


func test_secrets() -> void:
	var levers := index.secrets.filter(func(s: ManorSecretDef) -> bool: return s.kind == &"lever")
	var keepsakes := index.secrets.filter(func(s: ManorSecretDef) -> bool: return s.kind == &"keepsake")
	gut.p("secrets: %d (%d levers, %d keepsakes)" % [index.secrets.size(), levers.size(), keepsakes.size()])
	assert_gte(index.secrets.size(), 5)
	assert_gte(keepsakes.size(), 3)
	for k in keepsakes:
		assert_true(String(k.item_id).begins_with("col_"), "%s is a col_ item" % k.secret_id)
	for s in index.secrets:
		assert_gt(index.rooms_at(s.level, Vector2(s.position.x, s.position.z)).size(), 0, "%s inside a room" % s.secret_id)
	var lever_ids := {}
	for l in levers:
		lever_ids[l.secret_id] = true
	assert_gte(lever_ids.size(), 4)
	for id in lever_ids:
		var doors := index.doors.filter(func(d: ManorDoorDef) -> bool: return d.kind == &"secret" and d.secret_id == id)
		assert_gt(doors.size(), 0, "lever %s opens a door" % id)
		for d in doors:
			assert_eq(index.door_rooms(d).size(), 2, "secret door %s leads somewhere real" % id)
	for d in index.doors.filter(func(x: ManorDoorDef) -> bool: return x.kind == &"secret"):
		assert_true(lever_ids.has(d.secret_id), "secret door %s has a lever" % d.secret_id)


func test_builds_headless() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var house := ManorHouseBuilder.build(root, [layout])
	assert_not_null(house)
	assert_not_null(house.get_node_or_null("entrance_hall"))
	assert_not_null(house.get_node_or_null("Gate_manor_house"))
	assert_not_null(house.get_node_or_null("Door_mask_vault"))
	assert_eq(get_tree().get_nodes_in_group(ManorStation.GROUP).size(), index.stations.size() + 5, "stations + levers")
	WorldState.clear()
