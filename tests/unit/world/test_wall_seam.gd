extends GutTest

const DIR := "res://world/human_realm/wall_seam/scatter"
const SCENE := "res://world/human_realm/wall_seam/wall_seam.tscn"


func _layers() -> Array[ScatterLayer]:
	var out: Array[ScatterLayer] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".tres"):
			out.append(load("%s/%s" % [DIR, f]))
	return out


func test_nothing_north_of_the_wall_and_all_in_the_strip() -> void:
	var rect: Rect2 = HumanRealmLayout.REGION_RECTS[&"wall_seam"]
	var bad := []
	for l in _layers():
		assert_true(l.tags.has("canon:C") or l.tags.has("canon:X"), "%s has a canon tag" % l.id)
		for i in l.count():
			var p := l.position_of(i)
			var q := Vector2(p.x, p.z)
			if p.z < WorldMap.WALL_Z or not rect.has_point(q):
				bad.append("%s:%d" % [l.id, i])
			if l.is_forage() and HumanRealmLayout.distance_to_road(q) <= HumanRealmLayout.ROAD_HALF_WIDTH:
				bad.append("%s:%d on road" % [l.id, i])
	assert_eq(bad.size(), 0, str(bad.slice(0, 10)))


func test_drifts_line_the_wall() -> void:
	var drift: ScatterLayer = load(DIR + "/wall_drift.tres")
	assert_gt(drift.count(), 300)
	for i in drift.count():
		assert_lt(drift.position_of(i).z, WorldMap.WALL_Z + 1.0)


func test_build_is_deterministic() -> void:
	var area := Rect2(-400.0, 1400.0, 300.0, 80.0)
	var a := WallSeamBuilder.new().build(5, area)
	var b := WallSeamBuilder.new().build(5, area)
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].instances, b[i].instances, "layer %s" % a[i].id)
	var full := {}
	for l in WallSeamBuilder.new().build():
		full[l.id] = l
	var saved: ScatterLayer = load(DIR + "/offering_bundle.tres")
	assert_eq(saved.instances, full[&"offering_bundle"].instances, "committed output matches the generator")


func test_proximity_math() -> void:
	assert_almost_eq(WallSenseVolume.proximity_for(0.0, 30.0), 1.0, 0.0001)
	assert_almost_eq(WallSenseVolume.proximity_for(30.0, 30.0), 0.0, 0.0001)
	assert_almost_eq(WallSenseVolume.proximity_for(45.0, 30.0), 0.0, 0.0001)
	assert_almost_eq(WallSenseVolume.proximity_for(15.0, 30.0), 0.5, 0.0001)
	assert_almost_eq(WallSenseVolume.proximity_for(-10.0, 30.0), WallSenseVolume.proximity_for(10.0, 30.0), 0.0001)
	assert_gt(WallSenseVolume.proximity_for(5.0, 30.0), WallSenseVolume.proximity_for(20.0, 30.0))
	assert_eq(WallSenseVolume.compass_jitter_for(0.0, 3.3), 0.0)
	for t in [0.0, 0.7, 2.1, 9.9]:
		assert_lte(absf(WallSenseVolume.compass_jitter_for(1.0, t)), PI + 0.0001)
	assert_almost_eq(WallShimmer.near_for(0.0, 15.0), 1.0, 0.0001)
	assert_almost_eq(WallShimmer.near_for(15.0, 15.0), 0.0, 0.0001)


func test_sense_volume_emits_proximity() -> void:
	var v := WallSenseVolume.new()
	add_child_autofree(v)
	watch_signals(v)
	v.update_from_position(Vector3(-100.0, 0.0, 1405.0))
	assert_signal_emitted(v, "proximity_changed")
	assert_almost_eq(v.wall_proximity, WallSenseVolume.proximity_for(5.0, v.sense_depth), 0.0001)
	v.update_from_position(Vector3(-100.0, 0.0, 1600.0))
	assert_eq(v.wall_proximity, 0.0)


func test_scene_nodes() -> void:
	var root: Node3D = (load(SCENE) as PackedScene).instantiate()
	add_child_autofree(root)
	assert_not_null(root.get_node_or_null("ScatterField"))
	assert_true(root.get_node("WallShimmer") is WallShimmer)
	assert_true(root.get_node("WallSenseVolume") is WallSenseVolume)
	for n in ["GapStoneWest", "GapStoneEast", "GreatWarningCairn", "OfferingPost"]:
		assert_not_null(root.find_child(n, true, false), n)
	var path: Path3D = root.get_node("WallSeamPath")
	var c := path.curve
	assert_almost_eq(Vector2(c.get_point_position(0).x, c.get_point_position(0).z).distance_to(Vector2(-80, 1500)), 0.0, 1.0)
	var last := c.get_point_position(c.point_count - 1)
	assert_almost_eq(Vector2(last.x, last.z).distance_to(Vector2(-100, 1300)), 0.0, 1.0)
	var through_gap := false
	for i in c.point_count:
		var p := c.get_point_position(i)
		through_gap = through_gap or Vector2(p.x, p.z).distance_to(Vector2(-100, 1400)) < 1.0
	assert_true(through_gap)
	var gate: Marker3D = root.get_node("wall_gate_north")
	assert_true(gate.is_in_group(&"story_anchor"))
	assert_almost_eq(Vector2(gate.position.x, gate.position.z).distance_to(Vector2(-100, 1402)), 0.0, 1.0)
	assert_almost_eq((-gate.global_basis.z).z, -1.0, 0.01, "faces north (-Z)")


func test_defile_compresses_toward_the_gap() -> void:
	var gen := load("res://world/human_realm/wall_seam/wall_seam_gen.gd")
	assert_gt(gen.defile_half_width(1446.0), 7.0)
	assert_lt(gen.defile_half_width(1401.0), 2.6)
	var root: Node = (load("res://world/human_realm/wall_seam/wall_seam.tscn") as PackedScene).instantiate()
	assert_not_null(root.find_child("wall_crossing_frame", true, false))
	assert_not_null(root.find_child("DefileWalls", true, false))
	root.free()
