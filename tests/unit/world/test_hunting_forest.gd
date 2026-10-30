extends GutTest

const DIR := "res://world/human_realm/hunting_forest/scatter"
const SCENE := "res://world/human_realm/hunting_forest/hunting_forest.tscn"


func _layers() -> Array[ScatterLayer]:
	var out: Array[ScatterLayer] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".tres"):
			out.append(load("%s/%s" % [DIR, f]))
	return out


func test_every_placement_is_in_the_region_and_forage_is_off_roads_and_creek() -> void:
	var rect: Rect2 = HumanRealmLayout.REGION_RECTS[&"hunting_forest"]
	var bad := []
	for l in _layers():
		assert_true(l.tags.has("canon:C") or l.tags.has("canon:X"), "%s has a canon tag" % l.id)
		for i in l.count():
			var p := l.position_of(i)
			var q := Vector2(p.x, p.z)
			if not rect.has_point(q) or p.z < WorldMap.WALL_Z:
				bad.append("%s:%d outside" % [l.id, i])
			if l.is_forage() or l.tags.has("collectible") or l.tags.has("look"):
				if HumanRealmLayout.distance_to_road(q) <= HumanRealmLayout.ROAD_HALF_WIDTH:
					bad.append("%s:%d on road" % [l.id, i])
				if HumanRealmLayout.distance_to_creek(q) <= HumanRealmLayout.CREEK_HALF_WIDTH:
					bad.append("%s:%d in creek" % [l.id, i])
	assert_eq(bad.size(), 0, str(bad.slice(0, 10)))


func test_ash_only_inside_the_walled_grove() -> void:
	for l in _layers():
		if l.id == &"tree_ash" or l.ingredient_id == &"ing_ash_wood":
			assert_gt(l.count(), 0)
			for i in l.count():
				var p := l.position_of(i)
				assert_lt(Vector2(p.x, p.z).distance_to(HumanRealmLayout.ASH_GROVE), HuntingForestBuilder.GROVE_RADIUS, "%s inside the wall" % l.id)


func test_build_is_deterministic_on_a_sub_rect() -> void:
	var area := Rect2(-520.0, 1620.0, 220.0, 200.0)
	var a := HuntingForestBuilder.new().build(77, area)
	var b := HuntingForestBuilder.new().build(77, area)
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].id, b[i].id)
		assert_eq(a[i].instances, b[i].instances, "layer %s" % a[i].id)
	var c := HuntingForestBuilder.new().build(78, area)
	assert_ne(a[0].instances, c[0].instances, "another seed differs")


func test_committed_layers_match_the_generator() -> void:
	var fresh := {}
	for l in HuntingForestBuilder.new().build():
		fresh[l.id] = l
	for id: StringName in [&"tree_oak", &"holly", &"deer_tracks"]:
		var saved: ScatterLayer = load("%s/%s.tres" % [DIR, id])
		assert_eq(saved.count(), fresh[id].count(), "%s count" % id)
		for k in 10:
			assert_almost_eq(saved.instances[k], fresh[id].instances[k], 0.001)


func test_report_meets_world_smoke() -> void:
	var r: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://world/human_realm/hunting_forest/hunting_forest_report.json"))
	assert_gte(int(r.types), 25)
	assert_gte(float(r.placements_per_km2), 300.0)
	assert_eq(int(r.empty_cells), 0)
	assert_gte(int(r.landmarks), 5)
	assert_lte(int(r.draw_calls), 1500)


func test_scene_has_landmarks_and_trunk_collision() -> void:
	var root: Node3D = (load(SCENE) as PackedScene).instantiate()
	add_child_autofree(root)
	assert_not_null(root.get_node_or_null("ScatterField"))
	assert_not_null(root.find_child("AshGroveWalled", true, false))
	for n in ["HuntingLodgeRuin", "HuntersHide", "FrozenFall", "LightningSplitOak", "WoodcuttersLeanTo", "FrozenBridge", "AbandonedFarmstead", "GamekeeperHut", "AshGroveGate", "WaitingOakSeat"]:
		assert_not_null(root.find_child(n, true, false), n)
	var trunks: ForestTrunkCollision = root.get_node("TrunkCollision")
	assert_gt(trunks.shape_count(), 1000, "a trunk cylinder per scatter tree")
	for body in trunks.get_children():
		assert_eq((body as StaticBody3D).collision_layer, 1)
		assert_lt(body.position.x - floorf(body.position.x / 64.0) * 64.0, 64.0)
