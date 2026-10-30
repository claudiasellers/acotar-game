extends GutTest


func _layer(id: StringName, ingredient: StringName, points: Array) -> ScatterLayer:
	var l := ScatterLayer.new()
	l.id = id
	l.ingredient_id = ingredient
	l.mesh = BoxMesh.new()
	for p: Vector3 in points:
		l.add(p, 0.5, 1.2)
	return l


func test_layer_round_trips_transforms() -> void:
	var l := _layer(&"a", &"", [Vector3(10, 2, -5)])
	assert_eq(l.count(), 1)
	assert_eq(l.position_of(0), Vector3(10, 2, -5))
	assert_almost_eq(l.transform_of(0).basis.get_scale().x, 1.2, 0.0001)


func test_forage_chunks_carry_ids_and_meta() -> void:
	var field := ScatterField.new()
	field.region_id = &"hunting_forest"
	field.layers = [
		_layer(&"snowdrop", &"ing_snowdrop", [Vector3(1, 0, 1), Vector3(70, 0, 1), Vector3(2, 0, 3)]),
		_layer(&"rock", &"", [Vector3(5, 0, 5)]),
	]
	add_child_autofree(field)
	var chunks := field.forage_chunks()
	assert_eq(chunks.size(), 2, "two 64 m chunks of snowdrops")
	var total := 0
	for c in chunks:
		assert_eq(c.get_meta(&"ingredient_id"), &"ing_snowdrop")
		assert_eq(c.get_meta(&"scatter_id"), &"snowdrop")
		assert_eq(c.get_meta(&"region_id"), &"hunting_forest")
		var ids: PackedInt32Array = c.get_meta(&"instance_ids")
		assert_eq(ids.size(), c.multimesh.instance_count)
		total += ids.size()
		for j in ids.size():
			var world := ScatterField.instance_position(c, j)
			assert_eq(field.chunk_key(world), field.chunk_key(c.position), "instance lies in its chunk")
	assert_eq(total, 3)
	assert_eq(field.get_child_count(), 3, "decoration rock chunk is built too but not in the forage group")


func test_report_counts_types_density_and_empty_cells() -> void:
	var layers: Array[ScatterLayer] = [
		_layer(&"snowdrop", &"ing_snowdrop", [Vector3(10, 0, 10), Vector3(150, 0, 10)]),
		_layer(&"holly", &"ing_holly_berry", [Vector3(10, 0, 150)]),
		_layer(&"rock", &"", [Vector3(150, 0, 150)]),
	]
	var r := ScatterReport.compute(layers, Rect2(0, 0, 200, 200), 3, 400)
	assert_eq(r.types, 2)
	assert_eq(r.placements_per_km2, 75)
	assert_eq(r.empty_cells, 1, "the rock-only cell counts as empty")
	assert_eq(r.landmarks, 3)
