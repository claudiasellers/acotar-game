extends GutTest


func test_veil_faces_regions_open_before_the_grounds() -> void:
	assert_eq(ManorWardVeil.open_neighbours(), PackedStringArray(["border_woods"]))


func test_veil_runs_the_gate_line_and_leaves_the_gate() -> void:
	var segs := ManorWardVeil.segments()
	assert_eq(segs.size(), 2)
	var gate := ManorSitePlan.SENTRY_GATE
	var b := ManorSitePlan.BOUNDS
	var xs: Array[float] = []
	for seg: Array in segs:
		for p: Vector2 in seg:
			assert_almost_eq(p.y, gate.y, 0.01)
			xs.append(p.x)
	xs.sort()
	assert_almost_eq(xs[0], b.position.x, 0.01)
	assert_almost_eq(xs[3], b.end.x, 0.01)
	assert_almost_eq(xs[1], gate.x - ManorForecourt.PIER_X, 0.01)
	assert_almost_eq(xs[2], gate.x + ManorForecourt.PIER_X, 0.01)


func test_veil_blocks_as_high_as_a_gate_and_is_seen() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var veil := ManorWardVeil.build(root)
	var shapes := veil.find_children("*", "CollisionShape3D", true, false)
	assert_gt(shapes.size(), 10)
	for cs: CollisionShape3D in shapes:
		assert_gte((cs.shape as BoxShape3D).size.y, RegionGate.min_height())
	assert_eq(veil.find_children("Veil*", "MeshInstance3D", true, false).size(), 2)
	assert_true(RegionGate.owns(shapes[0]))
