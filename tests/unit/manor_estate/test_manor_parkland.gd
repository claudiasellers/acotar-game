## L56: the arrival lawns read composed, not sporadic, and the stables read as
## part of the manor. Groves instead of lone trees, roses in islands instead of
## lone bushes, walks kept clear, the stables' garden faces windowed and roofed
## in the manor's slate, and the parterre soil light enough to read as earth.
extends GutTest

var layers: Array[ScatterLayer]


func before_all() -> void:
	layers = ManorScatter.build_all()


func _points(pred: Callable) -> PackedVector2Array:
	var out := PackedVector2Array()
	var lawn := ManorParkland.zone()
	for l in layers:
		if not pred.call(l):
			continue
		for i in l.count():
			var p := l.position_of(i)
			if lawn.has_point(Vector2(p.x, p.z)):
				out.append(Vector2(p.x, p.z))
	return out


func _lonely(pts: PackedVector2Array, radius: float) -> int:
	var n := 0
	for i in pts.size():
		if ManorParkland.is_elsewhere(pts[i]):
			continue
		var near := false
		for j in pts.size():
			if i != j and pts[i].distance_to(pts[j]) < radius:
				near = true
				break
		if not near:
			n += 1
			gut.p("lonely at %s" % pts[i])
	return n


func test_no_lone_trees_on_the_lawns() -> void:
	var trees := _points(func(l: ScatterLayer) -> bool: return l.tags.has("tree"))
	assert_gte(trees.size(), 50, "groves planted")
	assert_eq(_lonely(trees, 9.0), 0, "every lawn tree stands in a grove")


func test_every_grove_is_planted() -> void:
	for g: Array in ManorParkland.GROVES:
		var want := 0
		for s: Array in g[2]:
			want += int(s[1])
		assert_gte(ManorParkland.grove_trees(g).size(), want - 1, "grove at %s" % g[0])


func test_roses_stand_in_islands_not_alone() -> void:
	var roses := _points(func(l: ScatterLayer) -> bool: return String(l.id).begins_with("ing_rose_"))
	assert_gte(roses.size(), 50)
	assert_eq(_lonely(roses, 4.0), 0, "no lone rose bush on the lawns")


func test_walks_are_clear() -> void:
	var blocked := 0
	for l in layers:
		if l.tags.has("collectible"):
			continue
		for i in l.count():
			var p := l.position_of(i)
			if ManorParkland.near_walk(Vector2(p.x, p.z), -0.3):
				blocked += 1
				gut.p("on a walk: %s at %s" % [l.id, p])
	assert_eq(blocked, 0, "nothing grows on the gravel walks")


func test_stables_garden_faces_are_dressed() -> void:
	var plan := ManorStablesDress.placements(0.0)
	for run: Dictionary in ManorStablesDress.runs():
		var length := (run.a as Vector2).distance_to(run.b)
		assert_gte(ManorStablesDress.windows_on(run).size(), floori(length / 5.0), "windows along %s" % run.out)
	assert_gte((plan[&"panes"] as Array).size(), 30)
	assert_gt((plan[&"facade_pilaster"] as Array).size(), 30)
	assert_true(ManorStables.roof() is ShaderMaterial, "stables roof is the manor's fish-scale slate")


func test_parterre_soil_reads_as_earth() -> void:
	assert_gte(GardenKit.MULCH.get_luminance(), 0.34, "lighter than the old near-black mauve")
	assert_true(GardenKit.MULCH.r > GardenKit.MULCH.g and GardenKit.MULCH.g > GardenKit.MULCH.b, "brown loam, not purple or salmon")
