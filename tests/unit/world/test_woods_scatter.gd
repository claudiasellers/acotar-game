## Woods lane: the scatter generator and the committed coverage reports.
extends GutTest

const REGIONS := [&"border_woods", &"eastern_woods", &"suriel_glade"]


func _def(id: StringName) -> WoodsRegionDef:
	return load("res://data/regions/spring_court/%s_biomes.tres" % id)


func test_scatter_is_deterministic() -> void:
	var def := _def(&"border_woods")
	var rect := Rect2(-200, 900, 80, 80)
	var a := WoodsScatter.place(def, rect, "shrub")
	var b := WoodsScatter.place(def, rect, "shrub")
	assert_eq(a.keys(), b.keys())
	for k in a:
		assert_eq(a[k], b[k], "same placements for %s" % k)


func test_big_regions_have_1500_plus_forage_spread_over_100m_cells() -> void:
	for id in [&"border_woods", &"eastern_woods"]:
		var def := _def(id)
		var bounds: Rect2 = def.provider.BOUNDS
		var forage := WoodsScatter.place(def, bounds, "forage")
		var total := 0
		var cells := {}
		for k in forage:
			var inst: PackedFloat32Array = forage[k]
			total += inst.size() / ScatterLayer.STRIDE
			for i in range(0, inst.size(), ScatterLayer.STRIDE):
				cells[Vector2i(floori(inst[i] / 100.0), floori(inst[i + 2] / 100.0))] = true
		assert_gte(total, 1500, "%s forage placements" % id)
		assert_gte(forage.size(), 25, "%s forage types placed" % id)
		assert_gte(cells.size(), int(bounds.get_area() / 10000.0 * 0.95), "%s forage reaches nearly every 100 m cell" % id)


func test_forage_sits_on_world_height() -> void:
	var def := _def(&"suriel_glade")
	var forage := WoodsScatter.place(def, Rect2(-900, 550, 100, 100), "forage")
	for k in forage:
		var inst: PackedFloat32Array = forage[k]
		assert_almost_eq(inst[1], WorldHeight.height_at(inst[0], inst[2]), 0.01)
		break


func test_committed_reports_meet_the_world_smoke_bar() -> void:
	for id in REGIONS:
		var text := FileAccess.get_file_as_string("res://world/spring_court/%s/%s_report.json" % [id, id])
		var r: Dictionary = JSON.parse_string(text)
		assert_gte(int(r["types"]), 25, "%s types" % id)
		assert_gte(int(r["placements_per_km2"]), 300, "%s density" % id)
		assert_eq(int(r["empty_cells"]), 0, "%s empty cells" % id)
		assert_gte(int(r["landmarks"]), 3, "%s landmarks" % id)
		assert_lte(int(r["draw_calls"]), 1500, "%s draw calls" % id)


func test_composition_spaces_clearings_and_keeps_vistas_open() -> void:
	for id in REGIONS:
		var def := _def(id)
		var glades := 0
		var beacons := 0
		for c: Dictionary in WoodsComposition.clearings(def):
			var center: Vector2 = c["center"]
			if c["beacon"]:
				beacons += 1
			else:
				glades += 1
				assert_false(c["dread"], "%s: no clearing in a horror biome" % id)
			assert_false(WoodsComposition.in_vista(def, center.x, center.y), "%s: hero at %s blocks a vista" % [id, center])
		assert_gte(glades, 1, "%s has clearings" % id)
		assert_gte(beacons, 2, "%s has beacons between them" % id)
	# The border's paths run ~4 km: a clearing every 150-250 m is 15+.
	var border_glades := 0
	for c: Dictionary in WoodsComposition.clearings(_def(&"border_woods")):
		if not c["beacon"]:
			border_glades += 1
	assert_gte(border_glades, 15, "border woods clearings")


func test_forage_comes_in_drifts() -> void:
	var def := _def(&"border_woods")
	var forage := WoodsScatter.place(def, Rect2(-300, 900, 200, 200), "forage")
	var drifted := 0
	var total := 0
	var s := ScatterLayer.STRIDE
	for k in forage:
		var inst: PackedFloat32Array = forage[k]
		var n := inst.size() / s
		total += n
		for i in n:
			# A drift member has a same-kind neighbour within 6 m.
			for j in n:
				if i != j and Vector2(inst[i * s], inst[i * s + 2]).distance_to(Vector2(inst[j * s], inst[j * s + 2])) < 6.0:
					drifted += 1
					break
	assert_gt(total, 0)
	assert_gte(float(drifted) / total, 0.8, "most forage grows in drifts, not alone")
