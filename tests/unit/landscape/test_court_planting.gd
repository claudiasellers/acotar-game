extends GutTest
# gate: when:world/spring_court/wider/*,world/spring_court/shared/landscape_layout.gd,tools/court/court_content_table.gd,tools/court/gen_court_content.gd,data/regions/spring_court/content/*
## Finish plan P2: the court's regions are planted by the shape of the land
## (CourtPlanting). Every region's trees per hectare sit inside its recipe's
## ranges, overall and on the landforms the recipe names; no hectare is
## planted past the frame-time ceiling (T7); the land's own rules show: a
## closed Western Woods, the glen planted by place (a tree on each knoll, the
## mound bare, its flowers under its trees), hedges on the village's road verges, thickets in Rosewild's hollows
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


## The glen is planted by place (CourtGlenPlanting; docs/lanes/
## court-planting-by-place.md): every tree answers to something on the land.
func test_the_glen_is_planted_by_place() -> void:
	var glen := _content(&"starlight_glen")
	assert_eq(glen.place_planting, CourtGlenPlanting.ID)
	var trunks := PackedVector2Array()
	for layer: ScatterLayer in layers[&"starlight_glen"]:
		assert_true(layer.tags.has("place"), "%s is the place's own" % layer.id)
		assert_not_null(layer.mesh, "%s has its mesh" % layer.id)
		assert_not_null(layer.impostor_mesh, "%s has a far form" % layer.id)
		for i in layer.count():
			var p := layer.position_of(i)
			trunks.append(Vector2(p.x, p.z))
	# one tree (or one clump) on a knoll's top
	var tops := CourtGlenPlanting.knoll_tops(glen)
	assert_gt(tops.size(), 40, "the glen is a valley of knolls")
	var crowned := 0
	for top in tops:
		for q in trunks:
			if q.distance_to(top) < 0.5:
				crowned += 1
				break
	assert_gt(crowned, tops.size() * 3 / 4, "a tree on the top of most knolls (the mound, the fall's knoll and the kept-open ones stay bare)")
	# the pool: a ring of birches, open where you come down from the mound; the mound bare
	var ring := 0
	for q in trunks:
		assert_gt(q.distance_to(CourtGlenPlanting.MOUND), 40.0, "no tree on the mound")
		var from_pool := q.distance_to(CourtGlenPlanting.POOL)
		assert_gt(from_pool, CourtGlenPlanting.POOL_RADIUS + 5.0, "no trunk at the water's edge")
		if from_pool < 40.0:
			ring += 1
			assert_gt(absf(angle_difference((q - CourtGlenPlanting.POOL).angle(), CourtGlenPlanting.ARRIVAL)), 0.3, "the way in to the pool is open")
	assert_between(ring, 18, 45, "the pool's ring of birches")
	assert_gt(_per_ha(&"starlight_glen", &"brook_bank"), _per_ha(&"starlight_glen", &"floor") * 2.5, "trees gather by the brooks")
	assert_gt(_per_ha(&"starlight_glen", &"knoll"), _per_ha(&"starlight_glen", &"floor") * 2.5, "and on the knolls: the floor is open glade")


## The glen's flowers belong to its trees (owner, 2026-11-16: "a bluebell
## grove", not "someone dumped a bunch of flowers here"): most bluebells lie in
## a tree's shade (the rest are the crescents at the knolls' feet), none on a
## path or in a brook's bed.
func test_the_glens_flowers_pool_under_its_trees() -> void:
	var glen := _content(&"starlight_glen")
	var all := CourtGlenPlanting.layers(glen)
	var grid := {}
	for layer in all:
		if layer.tags.has("tree") and not String(layer.id).contains("thorn_bush"):
			for i in layer.count():
				var p := layer.position_of(i)
				var k := Vector2i(floori(p.x / 16.0), floori(p.z / 16.0))
				if not grid.has(k):
					grid[k] = PackedVector2Array()
				(grid[k] as PackedVector2Array).append(Vector2(p.x, p.z))
	var bluebells := 0
	var under := 0
	var misplaced := 0
	for layer in all:
		var id := String(layer.id)
		if not id.begins_with("place_flower_") or id.ends_with("_mid"):
			continue
		assert_not_null(layer.mesh, "%s has its mesh" % id)
		for i in layer.count():
			var p3 := layer.position_of(i)
			var p := Vector2(p3.x, p3.z)
			if not CourtGlenPlanting.dry(p, 0.3):
				misplaced += 1
			if not id.contains("bluebell"):
				continue
			bluebells += 1
			var k := Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))
			var shaded := false
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					for q: Vector2 in grid.get(k + Vector2i(dx, dz), PackedVector2Array()):
						if q.distance_to(p) < 15.5:
							shaded = true
			if shaded:
				under += 1
	assert_gt(bluebells, 5000, "the glen has its bluebells")
	assert_gt(under, bluebells / 2, "most bluebell patches lie in a tree's shade")
	assert_eq(misplaced, 0, "no flower on a path or in a brook's bed")
	# every patch has its middle-distance form over the same patches
	for layer in all:
		var id := String(layer.id)
		if id.begins_with("place_flower_") and id.ends_with("_mid"):
			var near: ScatterLayer = null
			for other in all:
				if String(other.id) == id.trim_suffix("_mid"):
					near = other
			assert_not_null(near, "%s stands in for a near layer" % id)
			assert_eq(layer.count(), near.count())
			assert_almost_eq(layer.draw_from, near.draw_distance, 0.01, "%s takes over where the near patch stops" % id)
			assert_not_null(layer.impostor_mesh, "%s has its far cushion" % id)


## The sward grows a cell from the land: grass on open ground, none in the
## pool or on a path, and the same cell every time.
func test_the_sward_reads_the_land() -> void:
	var glen := _content(&"starlight_glen")
	var sward := CourtSward.new()
	sward.content = glen
	add_child_autofree(sward)
	var open_cell := Vector2i(floori(-1266.0 / CourtSward.CELL), floori(270.0 / CourtSward.CELL))
	var grown := sward._grow(open_cell)
	var tufts: int = (grown["sward"] as PackedFloat32Array).size() / 12
	assert_gt(tufts, 300, "an open cell by the pool is grass")
	assert_eq(grown["sward"], sward._grow(open_cell)["sward"], "a cell grows the same every time")
	var in_pool := Vector2i(floori(-1300.0 / CourtSward.CELL), floori(262.0 / CourtSward.CELL))
	var wet := sward._grow(in_pool)
	var mid: Vector3 = wet["mid"]
	for kind: String in ["sward", "fine", "tall", "daisy"]:
		var buffer: PackedFloat32Array = wet[kind]
		for i in buffer.size() / 12:
			var at := Vector2(buffer[i * 12 + 3] + mid.x, buffer[i * 12 + 11] + mid.z)
			assert_gt(at.distance_to(CourtGlenPlanting.POOL), CourtGlenPlanting.POOL_RADIUS, "no grass in the pool")
	sward.settle(Vector3(-1266.0, 0.0, 270.0))
	var census := sward.census()
	assert_gt(int(census["cells"]), 60, "the sward is laid round a standpoint")
	assert_eq(int(census["growing"]), 0)
	assert_true(CourtMotes.out_at(0.8), "the hollow's lights are out at dusk")
	assert_false(CourtMotes.out_at(0.45), "and gone by late morning")


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
			if layer.tags.has("place"):
				# place_tree_<species>_<build letter>
				var species := StringName(String(layer.id).trim_prefix("place_tree_").left(-2))
				tall = CourtGreatTrees.height_of(species) if CourtGreatTrees.has(species) else FloraLib.height_of(species)
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
