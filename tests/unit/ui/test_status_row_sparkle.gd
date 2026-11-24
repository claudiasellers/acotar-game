## Contract: the status row never hands the engine a zero-area polygon, which
## logs an error as the new-status sparkle pop ends.
extends GutTest


func test_tiny_sparkle_draws_nothing() -> void:
	assert_eq(VitalsStatusRow.sparkle_points(Vector2.ZERO, 0.0).size(), 0)
	assert_eq(VitalsStatusRow.sparkle_points(Vector2.ZERO, 0.4).size(), 0)


func test_normal_sparkle_is_a_diamond() -> void:
	assert_eq(VitalsStatusRow.sparkle_points(Vector2.ZERO, 5.0).size(), 4)


func test_row_draws_through_end_of_pop() -> void:
	var row := VitalsStatusRow.new()
	add_child_autofree(row)
	row.size = Vector2(400, 200)
	row.set_statuses([{"tag": &"swift", "total": 10, "seconds_left": 8, "magnitude": 1.0}] as Array[Dictionary])
	row._born[&"swift"] = 0.595
	# Fixed deltas: headless frames are uncapped, so frame counts don't age it.
	row._process(0.01)
	row._process(0.01)
	await get_tree().process_frame
	assert_gt(float(row._born[&"swift"]), 0.6)
