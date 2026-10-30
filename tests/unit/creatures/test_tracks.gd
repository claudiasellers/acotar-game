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
	layer.snowfall_override = 1.0
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
		layer.add_mark(&"print", Vector3(i, 0, 0), 0.0, 0.1)
	assert_eq(layer.marks.size(), TrackLayer.MAX_MARKS)
