extends GutTest
## The village generator (world/human_realm/village/village_plan.gd).

var _plan: VillagePlan


func before_all() -> void:
	_plan = VillagePlan.new()
	_plan.generate()


func test_generation_is_deterministic() -> void:
	var again := VillagePlan.new()
	again.generate()
	assert_eq(again.layers.keys(), _plan.layers.keys())
	for id: StringName in _plan.layers:
		assert_eq((again.layers[id] as ScatterLayer).instances, (_plan.layers[id] as ScatterLayer).instances, "layer %s" % id)


func test_committed_scatter_matches_generator() -> void:
	for id: StringName in _plan.layers:
		var path := "res://world/human_realm/village/scatter/%s.tres" % id
		assert_true(ResourceLoader.exists(path), path)
		var saved := load(path) as ScatterLayer
		var mine: ScatterLayer = _plan.layers[id]
		assert_eq(saved.count(), mine.count(), "count of %s" % id)


func test_every_placement_is_inside_the_region() -> void:
	var rect := _plan.rect.grow(0.01)
	for layer in _plan.layer_list():
		for i in layer.count():
			var p := layer.position_of(i)
			if not rect.has_point(Vector2(p.x, p.z)):
				fail_test("%s:%d at %s is outside the village rect" % [layer.id, i, p])
				return
	pass_test("all inside")


func test_buildings_keep_off_roads_and_water() -> void:
	assert_between(_plan.buildings.filter(func(b: Dictionary) -> bool: return String(b.kind).begins_with("house")).size(), 12, 20)
	for b in _plan.buildings:
		for p in VillagePlan.footprint_points(b.pos, VillagePlan.FOOT[b.kind], b.yaw):
			assert_gt(HumanRealmLayout.distance_to_road(p), HumanRealmLayout.ROAD_HALF_WIDTH, "%s %s on a road" % [b.kind, b.pos])
			assert_false(VillagePlan.in_water(p, 0.0), "%s %s in the creek/pond" % [b.kind, b.pos])


func test_buildings_do_not_overlap_each_other() -> void:
	var bs := _plan.buildings
	for i in bs.size():
		for j in range(i + 1, bs.size()):
			var a := {c = bs[i].pos, h = VillagePlan.FOOT[bs[i].kind] * 0.5, yaw = bs[i].yaw}
			var b := {c = bs[j].pos, h = VillagePlan.FOOT[bs[j].kind] * 0.5, yaw = bs[j].yaw}
			assert_false(VillagePlan.obb_overlap(a, b), "%s and %s overlap" % [bs[i].kind, bs[j].kind])


func test_bridge_carries_the_ride_north_road() -> void:
	var bridge: ScatterLayer = _plan.layers[&"creek_bridge"]
	assert_eq(bridge.count(), 1)
	var p := bridge.position_of(0)
	var flat := Vector2(p.x, p.z)
	assert_lt(HumanRealmLayout.distance_to_polyline(flat, HumanRealmLayout.ROADS[1]), 0.5)
	assert_lt(HumanRealmLayout.distance_to_creek(flat), 0.5)
	assert_gt(p.y, WorldHeight.height_at(flat.x, flat.y), "deck above the creek bed")


func test_every_layer_has_a_canon_tag_and_no_ash() -> void:
	for layer in _plan.layer_list():
		assert_true(layer.tags.has("canon:C") or layer.tags.has("canon:X"), String(layer.id))
		assert_ne(layer.ingredient_id, &"ing_ash_wood")
		assert_false(layer.mesh_path.contains("tree_ash") or layer.mesh_path.contains("ash_deadfall"), layer.mesh_path)


func test_report_meets_the_smoke_bar() -> void:
	var r := ScatterReport.compute(_plan.layer_list(), _plan.rect, _plan.landmark_count(), 0)
	assert_gte(int(r.types), 25)
	assert_eq(int(r.empty_cells), 0)
	assert_gte(int(r.landmarks), 3)
	assert_true(_plan.layers.has(&"salt_sacks") and _plan.layers.has(&"iron_filings"))


func test_scene_has_story_markers() -> void:
	var scene := load("res://world/human_realm/village/village.tscn") as PackedScene
	assert_not_null(scene)
	var root := scene.instantiate()
	var stall := root.find_child("PeltTraderStall", true, false)
	assert_not_null(stall, "PeltTraderStall node")
	if stall != null:
		assert_true(stall.get_node_or_null("PeltTraderSpot") is Marker3D, "PeltTraderSpot marker")
	for n in ["Tavern", "MeetingHall", "DebtFamilyHouse", "AbandonedBarn", "Mill", "CreekBridge"]:
		assert_not_null(root.find_child(n, true, false), n)
	root.free()
