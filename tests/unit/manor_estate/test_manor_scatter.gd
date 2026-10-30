## The estate's forage and decoration scatter: density bar, variety, zones,
## coverage, looks, canon tags and the draw-call budget.
extends GutTest

var layers: Array[ScatterLayer]


func before_all() -> void:
	var t := Time.get_ticks_msec()
	layers = ManorScatter.build_all()
	gut.p("scatter built in %d ms" % (Time.get_ticks_msec() - t))


func _forage() -> Array[ScatterLayer]:
	var out: Array[ScatterLayer] = []
	for l in layers:
		if l.is_forage():
			out.append(l)
	return out


func test_variety_of_gatherables_and_keepsakes() -> void:
	var ing := {}
	var col := {}
	for l in _forage():
		var id := String(l.ingredient_id)
		if id.begins_with("ing_"):
			ing[id] = true
		elif id.begins_with("col_"):
			col[id] = true
			assert_true(l.tags.has("collectible"), "%s tagged collectible" % id)
	assert_gte(ing.size() + col.size(), 30)
	assert_gte(ing.size(), 22)
	assert_gte(col.size(), 10)


func test_density_and_coverage() -> void:
	var placements := 0
	for l in _forage():
		placements += l.count()
	assert_gte(placements, 1500)
	var report := ScatterReport.compute(layers, ManorSitePlan.BOUNDS, ManorGrounds.LANDMARKS.size(), 0)
	assert_eq(report["empty_cells"], 0)
	assert_gte(report["placements_per_km2"], 300)
	assert_gte(report["types"], 30)


func test_each_type_in_three_zones_or_justified() -> void:
	for l in _forage():
		var zones := ManorScatter.zones_of(l)
		if zones.size() < 3:
			assert_true(ManorScatter.FEW_ZONES_OK.has(l.id), "%s only in %s" % [l.id, zones])


func test_every_layer_has_a_mesh_and_a_canon_tag() -> void:
	for l in layers:
		assert_not_null(l.mesh, String(l.id))
		var tagged := false
		for t in l.tags:
			if t.begins_with("canon:"):
				tagged = true
		assert_true(tagged, "%s carries canon:C/X" % l.id)


func test_instances_stay_inside_the_estate_and_out_of_buildings() -> void:
	var b := ManorSitePlan.BOUNDS
	for l in layers:
		for i in l.count():
			var p := l.position_of(i)
			assert_true(b.has_point(Vector2(p.x, p.z)), "%s:%d inside" % [l.id, i])
			if l.id == &"ing_trout" or l.id == &"deco_water_lily":
				continue
			for r in [ManorSitePlan.HOUSE_MAIN, ManorSitePlan.HOUSE_WEST, ManorSitePlan.HOUSE_SERVICE]:
				if r.has_point(Vector2(p.x, p.z)):
					fail_test("%s:%d inside the house" % [l.id, i])
					return


func test_deterministic() -> void:
	var again := ManorScatter.build_all()
	assert_eq(again.size(), layers.size())
	for i in layers.size():
		assert_eq(again[i].instances, layers[i].instances, String(layers[i].id))


func test_draw_calls_within_budget() -> void:
	var visible: Array = ManorScatter.visible_chunk_draws(layers)
	assert_lt(visible[0], 700, "scatter chunks drawn from the worst viewpoint")
	assert_lt(ManorScatter.chunk_draws(layers), 1300, "every scatter chunk loaded at once")
	var report := JSON.parse_string(FileAccess.get_file_as_string(ManorScatter.REPORT_PATH)) as Dictionary
	assert_lte(int(report["draw_calls"]), 1500)
	assert_gte(int(report["landmarks"]), 3)
	assert_eq(int(report["empty_cells"]), 0)


func test_field_chunks_carry_forage_metas() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var field := ManorScatter.add_field(parent, layers)
	var chunks := field.forage_chunks()
	assert_gt(chunks.size(), 50)
	var c := chunks[0]
	assert_eq(c.get_meta(&"region_id"), ManorScatter.REGION_ID)
	assert_true(String(c.get_meta(&"ingredient_id")) != "")
	assert_not_null(parent.get_node_or_null("ScatterFieldWide"))
	assert_gt(parent.get_node("TreeTrunks").get_child_count(), 300)
