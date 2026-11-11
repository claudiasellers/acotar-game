extends GutTest
# gate: when:world/spring_court/wider/*,data/regions/spring_court/content/*,data/places/*,story/act4/wider_court_anchors.gd,story/act4/sentry_range.gd,tools/court/*
## Finish plan P1 (docs/lanes/wider-court-finish-plan.md): the court's ground
## read as habitats (CourtLandHabitats), and the keep-open zones no trunk may
## stand in: clearings, gates, paths, water, standpoints, the story's spots.

const CONTENT_DIR := "res://data/regions/spring_court/content/"
const F := CourtLandHabitats.Form


func before_all() -> void:
	CourtHeight.prewarm()


func _shares(region_id: StringName, step: float) -> PackedFloat32Array:
	var counts := PackedFloat32Array()
	counts.resize(CourtLandHabitats.NAMES.size())
	var total := 0.0
	for r in CourtMap.rects(region_id):
		var x := r.position.x + step * 0.5
		while x < r.end.x:
			var z := r.position.y + step * 0.5
			while z < r.end.y:
				if CourtMap.region_at(x, z) == region_id:
					counts[CourtLandHabitats.form_at(x, z)] += 1.0
					total += 1.0
				z += step
			x += step
	for i in counts.size():
		counts[i] /= maxf(total, 1.0)
	return counts


func test_each_region_has_the_landforms_its_recipe_plants() -> void:
	# What P2's recipes plant in (the owner's terrain table), at a 32 m grid.
	var needs := {
		&"western_fells": [F.CREST, F.HOLLOW, F.STEEP, F.WATER],
		&"starlight_glen": [F.KNOLL, F.SHORE, F.RIVER_BANK, F.BROOK_BANK, F.WATER],
		&"fae_village": [F.RIVER_BANK, F.VALLEY, F.VERGE],
		&"autumn_foothills": [F.STEEP, F.CREST],
		&"rosewild": [F.HOLLOW, F.KNOLL],
		&"solstice_meadow": [F.VALLEY, F.FLOOR, F.SLOPE],
		&"hill_of_the_rite": [F.SLOPE, F.STEEP, F.CREST],
		&"blighted_reaches": [F.HOLLOW, F.CREST],
		&"blossom_vale": [F.FLOOR, F.RIVER_BANK],
	}
	var missing: Array[String] = []
	for id: StringName in needs:
		var s := _shares(id, 32.0)
		var sum := 0.0
		for v in s:
			sum += v
		assert_almost_eq(sum, 1.0, 0.001, "%s: shares add up" % id)
		for f: int in needs[id]:
			if s[f] <= 0.0:
				missing.append("%s: no %s" % [id, CourtLandHabitats.NAMES[f]])
	assert_eq(missing, [] as Array[String])


func test_named_ground_reads_as_the_book_shapes_it() -> void:
	var looking := CourtHeight.site(&"looking_lake")
	assert_eq(CourtLandHabitats.form_at(looking.x + 40.0, looking.y + 30.0), F.WATER, "Looking Lake holds water")
	assert_eq(CourtLandHabitats.form_at(-1300.0, 262.0 - 18.0 - 6.0), F.SHORE, "the starlight pool's rim is shore")
	assert_eq(CourtLandHabitats.form_name(-1630.0, -645.0), &"floor", "the tower hill's crown is flattened")
	# The trench between two hills is steep-sided (TRENCH, 8 m off its line).
	var steep := 0
	for x in range(480, 690, 30):
		var f := CourtLandHabitats.form_at(float(x), -976.0)
		steep += 1 if f == F.STEEP or f == F.SLOPE else 0
	assert_gt(steep, 2, "the rite trench's banks are slopes")


func test_keep_open_zones_cover_every_standpoint_gate_and_story_spot() -> void:
	var kinds := {}
	for zn in CourtLandHabitats.zones():
		kinds[zn["kind"]] = int(kinds.get(zn["kind"], 0)) + 1
		assert_gt(float(zn["r"]), 0.0, "%s has a radius" % zn["id"])
	assert_gt(int(kinds.get(&"clearing", 0)), CourtHeight.PADS.size(), "every pad plus the site clearings")
	assert_eq(int(kinds.get(&"gate", 0)), CourtHeight.GATES.size())
	assert_eq(int(kinds.get(&"story", 0)), 3, "sentry range, potion room, starlight rim")
	# The sentries shoot east from beside the tower: the whole lane is open.
	var line_at := CourtHeight.site(&"north_watchtower") + Vector2(14.0, 0.0)
	for d in [0.0, 20.0, 35.0, 55.0]:
		assert_true(CourtLandHabitats.keep_open(line_at.x + d, line_at.y), "sentry lane open at %d m" % d)
		assert_true(CourtLandHabitats.keep_open(line_at.x + d, line_at.y + 3.0), "sentry lane open beside the butts")
	assert_true(CourtLandHabitats.keep_open(-1300.0, 262.0 + 20.0), "the starlight pool's rim")
	assert_false(CourtLandHabitats.keep_open(-1500.0, 820.0), "the open wood is plantable")
	assert_eq(CourtLandHabitats.keep_open_reason(-150.0, -1060.0).begins_with("clearing"), true, "the plateau is a clearing")


func test_every_ground_view_in_the_shot_tool_is_a_standpoint() -> void:
	var shots := load("res://tools/court/court_terrain_shots.gd") as GDScript
	var views: Dictionary = shots.get_script_constant_map()["VIEWS"]
	var missing: Array[String] = []
	for id: String in views:
		var v: Array = views[id]
		if float(v[2]) > 10.0:
			continue  # air views
		var p: Array = CourtLandHabitats.VIEWPOINTS.get(StringName(id), [])
		if p.is_empty() or Vector2(p[0], p[1]).distance_to(Vector2(v[0], v[1])) > 0.5:
			missing.append(id)
	assert_eq(missing, [] as Array[String], "court_terrain_shots VIEWS and CourtLandHabitats.VIEWPOINTS agree")


func test_no_tree_stands_in_a_keep_open_zone() -> void:
	var intruders: Array[String] = []
	var trees := 0
	for f in DirAccess.get_files_at(CONTENT_DIR):
		if not f.ends_with(".tres"):
			continue
		var content := load(CONTENT_DIR + f) as CourtRegionContent
		for layer in CourtScatterGenerator.decor_layers(content):
			if not layer.tags.has("tree"):
				continue
			for i in layer.count():
				var p := layer.position_of(i)
				trees += 1
				var why := CourtLandHabitats.keep_open_reason(p.x, p.z)
				if why != &"" and intruders.size() < 20:
					intruders.append("%s %s at (%.0f, %.0f)" % [content.region_id, why, p.x, p.z])
	assert_gt(trees, 1000, "the court still has its trees")
	assert_eq(intruders, [] as Array[String], "trees inside keep-open zones")
