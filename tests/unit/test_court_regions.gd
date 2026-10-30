extends GutTest
## Wider-court regions: the map, the height provider, the content tables, the
## scatter generator and the coverage bar (R1), plus one region built for real.

const CONTENT_DIR := "res://data/regions/spring_court/content/"
## Other lanes' rectangles from docs/contracts/world.md, [min_x, min_z, max_x, max_z].
const OTHERS := [
	[-600.0, -500.0, 600.0, 500.0], [-700.0, 300.0, 500.0, 1400.0], [650.0, -650.0, 1850.0, 550.0],
	[-950.0, 450.0, -700.0, 800.0], [-900.0, 1400.0, 700.0, 2500.0],
	[600.0, -500.0, 650.0, 500.0], # seam between the manor and the eastern woods (theirs to settle)
]


func _contents() -> Array[CourtRegionContent]:
	var out: Array[CourtRegionContent] = []
	for id in CourtMap.region_ids():
		out.append(load("%s%s.tres" % [CONTENT_DIR, id]) as CourtRegionContent)
	return out


func test_map_has_no_overlaps_and_covers_the_court() -> void:
	var overlaps := 0
	var unowned := 0
	var x := -1790.0
	while x < 1300.0:
		var z := -1690.0
		while z < 1400.0:
			var owners := 1 if CourtMap.region_at(x, z) != &"" else 0
			for r: Array in OTHERS:
				if x >= r[0] and x < r[2] and z >= r[1] and z < r[3]:
					owners += 1
			if owners > 1 and CourtMap.region_at(x, z) != &"":
				overlaps += 1
			if owners == 0:
				unowned += 1
			z += 50.0
		x += 50.0
	assert_eq(overlaps, 0, "a wider-court cell overlaps another lane")
	assert_eq(unowned, 0, "gap in the court map")


func test_height_meets_macro_at_region_edges_and_keeps_the_river() -> void:
	# Away from our sculpting the provider is the macro height, so seams cannot step.
	assert_almost_eq(CourtHeight.height_at(-700.0, -1000.0), MacroHeight.height_at(-700.0, -1000.0), 0.05)
	# The river bed is carved exactly like MacroHeight's.
	var p := MacroHeight.THORNWATER[1]
	assert_almost_eq(CourtHeight.height_at(p.x, p.y), MacroHeight.height_at(p.x, p.y), 1.0)
	# The Hill of the Rite stands well above the meadow, the escarpment drops away.
	assert_gt(CourtHeight.height_at(800.0, -1100.0) - CourtHeight.height_at(200.0, -900.0), 60.0)
	assert_gt(CourtHeight.height_at(-1760.0, 300.0) - CourtHeight.height_at(-1840.0, 300.0), 60.0)


func test_lakes_hold_water_below_their_shores() -> void:
	for lake in CourtHeight.lakes():
		var c: Vector2 = lake["center"]
		assert_lt(CourtHeight.height_at(c.x, c.y), float(lake["level"]) - 0.5, "lake bed under water at %s" % c)
		var shore := c + Vector2(float(lake["radius"]) * 1.55, 0.0)
		assert_gt(CourtHeight.height_at(shore.x, shore.y), float(lake["level"]), "shore above water at %s" % c)


func test_every_region_meets_the_density_bar() -> void:
	for c in _contents():
		var forage := CourtScatterGenerator.forage_layers(c)
		var r := CourtScatterGenerator.report(c, forage, [] as Array[ScatterLayer])
		assert_gte(int(r["types"]), 25, "%s types" % c.region_id)
		assert_gte(int(r["placements_per_km2"]), 300, "%s density" % c.region_id)
		assert_eq(int(r["empty_cells"]), 0, "%s empty 100 m cells" % c.region_id)
		assert_gte(int(r["landmarks"]), 3, "%s landmarks" % c.region_id)
		for lm in c.landmarks:
			assert_gte(lm.visible_from_m, 200.0, "%s visible" % lm.id)


func test_every_type_is_spread_out_not_clumped() -> void:
	var c := load(CONTENT_DIR + "starlight_glen.tres") as CourtRegionContent
	for layer in CourtScatterGenerator.forage_layers(c):
		# The pool's own treasures live only in and around the 18 m pool.
		if layer.id in [&"forage_ing_starlight_water", &"forage_col_stone_starglass", &"forage_ing_moonflower"]:
			continue
		var cells := {}
		for i in layer.count():
			var p := layer.position_of(i)
			cells[Vector2i(floori(p.x / 100.0), floori(p.z / 100.0))] = true
		assert_gte(cells.size(), 3, "%s grows in at least 3 separate 100 m cells" % layer.id)


func test_generator_is_deterministic() -> void:
	var c := load(CONTENT_DIR + "rosewild.tres") as CourtRegionContent
	var a := CourtScatterGenerator.forage_layers(c)
	var b := CourtScatterGenerator.forage_layers(c)
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].id, b[i].id)
		assert_eq(a[i].instances, b[i].instances)


func test_region_scene_builds_forage_fields_and_landmarks() -> void:
	var scene := load("res://world/spring_court/rosewild/rosewild.tscn") as PackedScene
	var region := scene.instantiate() as CourtRegion
	region.threaded = false
	add_child_autofree(region)
	assert_true(region.is_built)
	var chunks := region.forage_field.forage_chunks()
	assert_gt(chunks.size(), 20)
	assert_true(chunks[0].has_meta(&"ingredient_id"))
	assert_eq(region.get_node("Landmarks").get_child_count(), region.content.landmarks.size())
	var grade := region.get_node("RegionGrade") as RegionGrade
	assert_true(ResourceLoader.exists("res://world/shared/grades/%s.tres" % grade.grade), "grade preset exists")


func test_story_anchors_from_the_contract_exist() -> void:
	var want := {
		&"starlight_glen": [&"starlight_pool"],
		&"hill_of_the_rite": [&"calanmai_bonfires", &"calanmai_cave_mouth"],
		&"solstice_meadow": [&"solstice_dance_floor"],
		&"blossom_vale": [&"glamour_lift_glade"],
		&"blighted_reaches": [&"the_pass_road"],
	}
	for region: StringName in want:
		var c := load("%s%s.tres" % [CONTENT_DIR, region]) as CourtRegionContent
		var ids: Array = c.anchors.map(func(a: Dictionary) -> StringName: return a["id"])
		for id: StringName in want[region]:
			assert_has(ids, id, "%s has anchor %s" % [region, id])
		for a in c.anchors:
			assert_true(c.owns(a["position"]), "anchor %s inside %s" % [a["id"], region])
