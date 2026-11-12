extends GutTest
# gate: when:world/spring_court/wider/*,world/spring_court/shared/landscape_layout.gd,tools/court/court_content_table.gd,tools/court/gen_court_content.gd,data/regions/spring_court/content/*
## Finish plan P2: the court's regions are planted by the shape of the land
## (CourtPlanting). Every region's trees per hectare sit inside its recipe's
## ranges, overall and on the landforms the recipe names; no hectare is
## planted past the frame-time ceiling (T7); the land's own rules show: a
## closed Western Woods, one big tree on each knoll of the glen with the mound
## bare, hedges on the village's road verges, thickets in Rosewild's hollows
## and open hummocks, the meadow open below a wooded descent, pines on the
## Rite's steep banks under a bald crown.

const CONTENT_DIR := "res://data/regions/spring_court/content/"

var reports := {}
var layers := {}


func before_all() -> void:
	CourtHeight.prewarm()
	for id in CourtMap.region_ids():
		var content := load(CONTENT_DIR + "%s.tres" % id) as CourtRegionContent
		layers[id] = CourtPlanting.tree_layers(content)
		reports[id] = CourtPlanting.report(content, layers[id], 16.0)
		gut.p("%s: %d trees, %.1f/ha, densest hectare %d" % [id, reports[id]["trees"], reports[id]["per_ha"], reports[id]["densest_ha"]])


func _content(id: StringName) -> CourtRegionContent:
	return load(CONTENT_DIR + "%s.tres" % id) as CourtRegionContent


func _per_ha(id: StringName, form: StringName) -> float:
	return reports[id]["form_per_ha"][CourtLandHabitats.NAMES.find(form)]


func _count(id: StringName, kind: String) -> int:
	return int(reports[id]["kinds"].get(kind, 0))


func test_every_region_sits_inside_its_recipe() -> void:
	for id: StringName in reports:
		var content := _content(id)
		assert_gt(content.trees_per_ha.y, 0.0, "%s has a recipe range" % id)
		assert_between(float(reports[id]["per_ha"]), content.trees_per_ha.x, content.trees_per_ha.y, "%s trees per hectare" % id)
		for form: String in content.form_per_ha:
			var range: Vector2 = content.form_per_ha[form]
			assert_between(_per_ha(id, StringName(form)), range.x, range.y, "%s trees per hectare on %s" % [id, form])


func test_no_hectare_is_planted_past_the_ceiling() -> void:
	# T7: about 80 trees a hectare held the frame time; a 100 m square may
	# catch a grove's edge a little over.
	for id: StringName in reports:
		assert_lte(int(reports[id]["densest_ha"]), 100, "%s's densest hectare" % id)
	assert_almost_eq(CourtPlanting.open_share(0.0072), 0.1, 0.01, "a wood asked for 72/ha is closed: a tenth open")
	assert_almost_eq(CourtPlanting.open_share(0.001), 0.755, 0.01, "a sparse habitat keeps LandscapeLayout's open share")
	assert_eq(CourtPlanting.capped(0.02), CourtPlanting.CEILING * 0.96, "densities are held to the ceiling")
	assert_gt(CourtPlanting.capped(0.06, &"@verge"), 0.04, "a hedge on a verge may stand closer")


func test_land_tags() -> void:
	var glen := _content(&"starlight_glen")
	assert_eq(CourtPlanting.tree_tag(glen, &"glen_meadow", Vector2(-1208.0, 270.0)), &"", "the mound is bare")
	assert_eq(CourtPlanting.tree_tag(glen, &"birch_copse", Vector2(-1420.0, -380.0)), &"birch_copse", "an authored habitat keeps its planting")
	var rite := _content(&"hill_of_the_rite")
	var seen := {}
	for x in range(450, 1150, 12):
		for z in range(-1400, -700, 12):
			var p := Vector2(x, z)
			if rite.owns(p):
				seen[CourtPlanting.tree_tag(rite, rite.habitat_at(p), p)] = true
	assert_true(seen.has(&"@slope"), "the Rite's foothill slopes are their own habitat")
	assert_true(seen.has(&"fire_lily_slope@steep"), "and the steep banks inside the fire-lily ring")
	assert_false(seen.has(&"fire_lily_slope@slope"), "the ring's gentler slopes stay the fire lilies'")


func test_the_western_woods_are_a_closed_wood() -> void:
	assert_gt(int(reports[&"western_fells"]["trees"]), 4000)
	assert_gt(_count(&"western_fells", "woods_ancient_oak"), 250, "twisted oaks among the broadleaf")
	assert_lt(_count(&"western_fells", "woods_yew"), _count(&"western_fells", "woods_oak") / 8, "pines sparingly")
	# the tower hill's crown is bare
	for layer: ScatterLayer in layers[&"western_fells"]:
		for i in layer.count():
			var p := layer.position_of(i)
			assert_gt(Vector2(p.x, p.z).distance_to(Vector2(-1630.0, -650.0)), 8.0, "no tree on the tower hill's crown")


func test_the_glen_has_a_tree_on_each_knoll_and_an_open_floor() -> void:
	var glen := _content(&"starlight_glen")
	var tops := CourtPlanting.knoll_tops(glen)
	assert_gt(tops.size(), 15, "the glen is a valley of knolls")
	var oaks: ScatterLayer = null
	for layer: ScatterLayer in layers[&"starlight_glen"]:
		if String(layer.id).ends_with("woods_oak"):
			oaks = layer
	assert_not_null(oaks)
	assert_between(oaks.count(), tops.size() / 2, tops.size(), "one oak a knoll (standpoints and paths stay clear)")
	for i in oaks.count():
		var p := oaks.position_of(i)
		var best := 1e9
		for t in tops:
			best = minf(best, t.distance_to(Vector2(p.x, p.z)))
		assert_lt(best, 0.5, "the oak stands on a knoll's top")
		assert_gt(oaks.transform_of(i).basis.get_scale().y, 1.3, "and is a big one")
		assert_gt(Vector2(p.x, p.z).distance_to(Vector2(-1208.0, 270.0)), 40.0, "not on the mound")
	assert_gt(_per_ha(&"starlight_glen", &"brook_bank"), _per_ha(&"starlight_glen", &"floor") * 2.5, "birch and willow gather by the brooks")


func test_rosewild_meadow_village_and_rite() -> void:
	assert_gt(_per_ha(&"rosewild", &"hollow"), _per_ha(&"rosewild", &"floor") * 3.0, "Rosewild: thickets in the hollows")
	assert_gt(_per_ha(&"solstice_meadow", &"slope"), _per_ha(&"solstice_meadow", &"floor") * 6.0, "the meadow: a wooded descent, an open floor")
	assert_gt(_count(&"fae_village", "woods_hawthorn"), 120, "the village: hedges on the verges")
	assert_gt(_per_ha(&"fae_village", &"verge"), _per_ha(&"fae_village", &"floor") * 1.8)
	assert_gt(_count(&"hill_of_the_rite", "woods_yew"), 100, "the Rite: pines on the steep banks")
	assert_gt(_per_ha(&"hill_of_the_rite", &"steep"), _per_ha(&"hill_of_the_rite", &"floor") * 5.0)
	# the Rite's crown is bald
	for layer: ScatterLayer in layers[&"hill_of_the_rite"]:
		for i in layer.count():
			var p := layer.position_of(i)
			assert_gt(Vector2(p.x, p.z).distance_to(Vector2(800.0, -1100.0)), 60.0, "no tree on the Rite's crown")


## Finish plan P3: every tree as a crown (a drum from a quarter of its height
## to its top, three tenths of its height in radius), bucketed for the rays.
func _crowns() -> Dictionary:
	var cells := {}
	for id: StringName in layers:
		for layer: ScatterLayer in layers[id]:
			var decor_id := StringName(String(layer.id).substr(9))
			var tall := CourtTreeSet.target_height(decor_id) if CourtTreeSet.has(decor_id) else 9.0
			for i in layer.count():
				var p := layer.position_of(i)
				var k := Vector2i(floori(p.x / 16.0), floori(p.z / 16.0))
				if not cells.has(k):
					cells[k] = []
				cells[k].append([p, tall * layer.instances[i * ScatterLayer.STRIDE + 4]])
	return cells


func test_the_landmarks_stay_seen_past_the_trees() -> void:
	# CourtHeight.SIGHTLINES holds the land to what you see from where
	# (test_court_terrain); the trees must not close what the land leaves
	# open. A hidden line stays hidden: trees only add cover.
	var crowns := _crowns()
	for line: Array in CourtHeight.SIGHTLINES:
		if not line[3]:
			continue
		var from: Vector2 = CourtHeight.site(line[0]) if line[0] is StringName else Vector2(line[0][0], line[0][1])
		var to := CourtHeight.site(line[1])
		var a := Vector3(from.x, WorldHeight.height_at(from.x, from.y) + 1.7, from.y)
		var b := Vector3(to.x, WorldHeight.height_at(to.x, to.y) + float(line[2]) + 0.5, to.y)
		var d := Vector2(b.x - a.x, b.z - a.z).length()
		var blocker := ""
		for s in range(2, int(d) - 8, 3):
			var q := a.lerp(b, s / d)
			var k := Vector2i(floori(q.x / 16.0), floori(q.z / 16.0))
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					for t: Array in crowns.get(k + Vector2i(dx, dz), []):
						var at: Vector3 = t[0]
						var tall: float = t[1]
						if Vector2(at.x - q.x, at.z - q.z).length() < tall * 0.3 and q.y > at.y + tall * 0.25 and q.y < at.y + tall:
							blocker = "a %.0f m tree %d m along" % [tall, s]
		assert_eq(blocker, "", "%s -> %s is not closed by a tree" % [str(line[0]), line[1]])


func test_paths_gates_and_viewpoints_stay_clear_of_trunks() -> void:
	var inside := 0
	var first := ""
	for id: StringName in layers:
		for layer: ScatterLayer in layers[id]:
			for i in layer.count():
				var p := layer.position_of(i)
				var why := CourtLandHabitats.keep_open_reason(p.x, p.z)
				if why != &"":
					inside += 1
					if first == "":
						first = "%s in %s at %s" % [layer.id, why, p]
	assert_eq(inside, 0, "no trunk in a keep-open place (first: %s)" % first)
