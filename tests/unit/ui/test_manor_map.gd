extends GutTest
## Feyre's plan of the manor's inside: what she knows, where she is, how it
## is drawn, and the minimap and full map switching to it indoors.

const ManorPlan := preload("res://ui/map/manor_plan.gd")
const ManorSketch := preload("res://ui/map/manor_sketch.gd")

var _flags: Dictionary = {}


func _plan() -> ManorPlan:
	var plan := ManorPlan.new()
	plan.has_flag = func(f: String) -> bool: return _flags.has(f)
	return plan


func before_each() -> void:
	_flags.clear()


func _at(plan: ManorPlan, id: StringName) -> Vector3:
	var r := plan.index.find_room(id)
	var c := r.rect.get_center()
	return Vector3(c.x, ManorHouseBuilder.floor_y(r.level) + 0.05, c.y)


func test_level_from_height() -> void:
	for l in ManorPlan.LEVELS:
		assert_eq(ManorPlan.level_at(ManorHouseBuilder.floor_y(l) + 0.1), l)
	assert_eq(ManorPlan.level_at(ManorHouseBuilder.floor_y(1) - 1.5), 0, "on the stair, still below")


func test_locate_finds_her_room_and_remembers_it() -> void:
	var plan := _plan()
	assert_true(plan.locate(_at(plan, &"library")))
	assert_eq(plan.level, 0)
	assert_eq(plan.room, &"library")
	assert_true(plan.seen.has(&"library"))
	assert_false(plan.locate(Vector3(0, ManorHouseBuilder.floor_y(0), 60)), "out on the drive")
	assert_true(plan.seen.has(&"library"), "kept after leaving")


func test_her_suite_is_known_from_arrival_and_nothing_else() -> void:
	var plan := _plan()
	assert_true(plan.levels_shown().is_empty(), "nothing before she arrives")
	_flags[ManorPlan.KNOWN_FLAG] = true
	var ids := plan.rooms_on(1).map(func(r: ManorRoomDef) -> StringName: return r.id)
	for id in ManorPlan.SUITE:
		assert_has(ids, id)
	assert_has(ids, &"east_corridor")
	assert_does_not_have(ids, &"lucien_chambers", "Lucien's rooms only once she has been in")
	assert_true(plan.rooms_on(-1).is_empty(), "no cellars until she finds them")
	assert_false(plan.stairs_on(0).is_empty() and plan.stairs_on(1).is_empty(), "the grand stair shows")
	plan.locate(_at(plan, &"lucien_chambers"))
	assert_has(plan.rooms_on(1).map(func(r: ManorRoomDef) -> StringName: return r.id), &"lucien_chambers")


func test_doors_windows_and_secret_doors() -> void:
	var plan := _plan()
	_flags[ManorPlan.KNOWN_FLAG] = true
	assert_false(plan.doors_on(1).is_empty(), "doors of her suite")
	var bedroom := plan.index.find_room(&"feyre_bedroom")
	assert_false(plan.windows_of(bedroom).is_empty(), "her bedroom looks over the garden")
	for p in plan.windows_of(bedroom):
		assert_false(plan.index.is_inside_any(1, p + Vector2(0, -0.8)) and plan.index.is_inside_any(1, p + Vector2(0, 0.8))
			and plan.index.is_inside_any(1, p + Vector2(-0.8, 0)) and plan.index.is_inside_any(1, p + Vector2(0.8, 0)), "on an outside wall")
	for r in plan.index.rooms:
		plan.seen[r.id] = true
	for d in plan.doors_on(0) + plan.doors_on(1) + plan.doors_on(2):
		assert_ne(d.kind, &"secret", "a secret door stays hidden until found")


func test_inked_and_save_round_trip() -> void:
	var plan := _plan()
	assert_false(plan.inked())
	_flags[ManorPlan.INKED_FLAG] = true
	assert_true(plan.inked())
	plan.locate(_at(plan, &"svc_kitchen"))
	var other := _plan()
	other.load_state(JSON.parse_string(JSON.stringify(plan.save_state())))
	assert_true(other.seen.has(&"svc_kitchen"))


func test_pictures_without_words() -> void:
	assert_eq(ManorSketch.picture_for(&"feyre_bedroom"), &"her_bed")
	assert_eq(ManorSketch.picture_for(&"tamlin_bedchamber"), &"bed")
	assert_eq(ManorSketch.picture_for(&"feyre_bath"), &"tub")
	assert_eq(ManorSketch.picture_for(&"library"), &"book")
	assert_eq(ManorSketch.picture_for(&"svc_kitchen"), &"pot")
	assert_eq(ManorSketch.picture_for(&"gallery"), &"")


func test_hud_switches_to_the_house_plan_indoors_and_saves_it() -> void:
	var house := Node3D.new()
	house.add_to_group(&"manor_house")  # as ManorHouseBuilder does
	add_child_autofree(house)
	house.position = Vector3(5, 0, 7)
	var feyre := Node3D.new()
	feyre.add_to_group(&"player")
	add_child_autofree(feyre)
	var hud := WorldMapHud.new()
	add_child_autofree(hud)
	hud.manor.has_flag = func(f: String) -> bool: return _flags.has(f)
	_flags[ManorPlan.KNOWN_FLAG] = true
	var bed := _at(hud.manor, &"feyre_bedroom")
	feyre.global_position = bed + house.position
	await wait_process_frames(3)
	assert_eq(hud.manor_house, house, "found the house by its group")
	assert_true(hud.manor.inside)
	assert_eq(hud.manor.room, &"feyre_bedroom")
	assert_true(hud.minimap.in_manor())
	hud.full_map.open()
	assert_true(hud.full_map.showing_manor, "the map opens on the house indoors")
	assert_eq(hud.full_map.manor_level, 1)
	assert_true(hud.full_map.floors().has(1))
	hud.full_map.step_floor(-1)
	assert_eq(hud.full_map.manor_level, 0, "down to the ground floor")
	await wait_process_frames(2)
	hud.full_map.close()
	feyre.global_position = Vector3(400, 0, 400)
	await wait_process_frames(3)
	assert_false(hud.minimap.in_manor(), "back to the land outside")
	var data := hud.save_state()
	var other := WorldMapHud.new()
	add_child_autofree(other)
	other.load_state(JSON.parse_string(JSON.stringify(data)))
	assert_true(other.manor.seen.has(&"feyre_bedroom"))
