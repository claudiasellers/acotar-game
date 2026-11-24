extends GutTest


func test_marks_fade_with_age() -> void:
	assert_eq(TrackLayer.visibility(0.0, 300.0), 1.0)
	assert_almost_eq(TrackLayer.visibility(150.0, 300.0), 0.5, 0.001)
	assert_eq(TrackLayer.visibility(400.0, 300.0), 0.0)


func test_snowfall_buries_six_times_faster() -> void:
	assert_almost_eq(TrackLayer.burial_step(1.0, 1.0), TrackLayer.burial_step(1.0, 0.0) * 6.0, 0.001)


func test_layer_removes_buried_marks() -> void:
	var layer := TrackLayer.new()
	add_child_autofree(layer)
	layer.snowfall = 1.0
	layer.add_mark(&"print", Vector3.ZERO, 0.0, 0.1)
	layer.add_mark(&"twig", Vector3(1, 0, 0), 0.0, 0.1)
	layer.step(55.0)  # 330 s of burial in full snow: the print (360 s) survives just barely
	assert_eq(layer.marks.size(), 2)
	layer.step(10.0)
	assert_eq(layer.marks.size(), 1, "the print is buried, the twig (900 s) remains")
	assert_eq(layer.marks[0].kind, &"twig")


func test_layer_is_capped() -> void:
	var layer := TrackLayer.new()
	add_child_autofree(layer)
	for i in TrackLayer.MAX_MARKS + 5:
		layer.add_mark(&"print", Vector3(i, 0, 0), 0.0, 0.1, i)
	assert_eq(layer.marks.size(), TrackLayer.MAX_MARKS)


## Fresh trail only (health-interactions.md §3.6): one short crisp line per
## walker, and what falls off the end of it fades within 8 s.
func test_only_the_head_of_each_trail_stays_crisp() -> void:
	var layer := TrackLayer.new()
	add_child_autofree(layer)
	for i in 60:
		layer.add_mark(&"print", Vector3(i, 0, 0), 0.0, 0.1, 7)
	for i in 30:
		layer.add_mark(&"hoof", Vector3(i, 0, 5), 0.0, 0.07, 8)
	assert_eq(layer.head_of(7).size(), 24, "the wolf's newest 24 prints")
	assert_eq(layer.head_of(8).size(), 24, "and the doe's, a trail of her own")
	var crisp := 0
	for mark in layer.marks:
		if float(mark.fade) < 0.0:
			crisp += 1
	assert_eq(crisp, 48, "everything older has begun to fade")
	layer.step(TrackLayer.FADE_S * 0.5)
	var old := layer.marks[0]
	assert_almost_eq((old.node as GeometryInstance3D).transparency, 0.5, 0.02, "half gone after 4 s")
	layer.step(TrackLayer.FADE_S * 0.5 + 0.01)
	assert_eq(layer.marks.size(), 48, "old prints are gone within 8 s")
	layer.step(60.0)
	assert_eq(layer.marks.size(), 48, "the head stays while she reads it")


func test_blood_keeps_a_longer_trail_of_its_own() -> void:
	var layer := TrackLayer.new()
	add_child_autofree(layer)
	for i in 50:
		layer.add_mark(&"blood", Vector3(i, 0, 0), 0.0, 0.1, 7)
		layer.add_mark(&"print", Vector3(i, 0, 0), 0.0, 0.1, 7)
	assert_eq(layer.head_of(7, true).size(), 40, "40 marks of blood lead to a wounded animal")
	assert_eq(layer.head_of(7).size(), 24)


func test_her_boots_join_the_same_layer_and_stop_at_the_wall() -> void:
	var layer := TrackLayer.new()
	add_child_autofree(layer)
	var south := Vector3(0, 0, WorldMap.WALL_Z + 100.0)
	for i in 61:
		layer.boot_step(1, south + Vector3(i, 0, 0), 0.0, Vector3.RIGHT)
	assert_eq(layer.marks.size(), 60, "a print a stride in the snow")
	assert_true(layer.marks[0].node is Decal)
	assert_eq(layer.head_of(1).size(), 40, "her own newest 40 stay crisp")
	layer.step(TrackLayer.FADE_S + 0.01)
	assert_eq(layer.marks.size(), 40, "the rest fade behind her")
	var north := Vector3(0, 0, WorldMap.WALL_Z - 100.0)
	for i in 20:
		layer.boot_step(2, north + Vector3(i, 0, 0), 4.0, Vector3.RIGHT)
	assert_eq(layer.head_of(2).size(), 0, "no prints north of the Wall")
	for i in 20:
		layer.boot_step(3, south + Vector3(i, 0, 9), 4.0, Vector3.RIGHT, false)
	assert_eq(layer.head_of(3).size(), 0, "none in the air")
	assert_false(ResourceLoader.exists("res://world/shared/weather/snow_prints.gd"), "one print system")


## Eight deer in a clearing for ten minutes: one short fresh line each, never
## a carpet, and nothing lingers more than 8 s once it leaves the line.
func test_eight_deer_for_ten_minutes_leave_eight_short_trails() -> void:
	var layer := TrackLayer.new()
	add_child_autofree(layer)
	var most_crisp := 0
	var longest_fade := 0.0
	var most_marks := 0
	for tick in 1200:
		for deer in 8:
			layer.add_mark(&"hoof", Vector3(tick * 0.4, 0, deer * 3.0), 0.0, 0.07, 100 + deer)
		layer.step(0.5)
		most_marks = maxi(most_marks, layer.marks.size())
		if tick % 40 != 0:
			continue
		for deer in 8:
			most_crisp = maxi(most_crisp, layer.head_of(100 + deer).size())
		for mark in layer.marks:
			longest_fade = maxf(longest_fade, float(mark.fade))
	assert_eq(most_crisp, 24, "no deer shows more than 24 crisp prints")
	assert_lte(longest_fade, TrackLayer.FADE_S, "old prints are gone within 8 s")
	assert_lt(most_marks, 8 * (24 + 20), "the clearing never fills up")
