## The estate grounds: maze, stables, orchard, rose garden, glass houses, the
## sentry gate, landmarks, story anchors, ambient life and the region data.
extends GutTest

var root: Node3D
var grounds: Node3D


func before_all() -> void:
	root = Node3D.new()
	add_child(root)
	var t := Time.get_ticks_msec()
	grounds = ManorGrounds.build(root)
	gut.p("grounds built in %d ms" % (Time.get_ticks_msec() - t))


func after_all() -> void:
	root.free()


func test_maze_is_big_and_solvable_from_entrance_to_centre() -> void:
	var size := ManorHedgeMaze.N * ManorHedgeMaze.CELL
	assert_gte(size, 80.0, "maze at least 80 x 80 m")
	assert_almost_eq(ManorHedgeMaze.WALL_H, 2.6, 0.01)
	var steps := ManorHedgeMaze.path_length(ManorHedgeMaze.entrance_cell(), ManorHedgeMaze.court_center_cell())
	assert_gt(steps, 20, "BFS finds a real path to the centre court (%d cells)" % steps)
	# every cell is reachable (no sealed pockets)
	var seen := 0
	for r in ManorHedgeMaze.N:
		for c in ManorHedgeMaze.N:
			if ManorHedgeMaze.path_length(ManorHedgeMaze.entrance_cell(), Vector2i(r, c)) >= 0:
				seen += 1
	assert_eq(seen, ManorHedgeMaze.N * ManorHedgeMaze.N)
	assert_gt(ManorHedgeMaze.dead_ends().size(), 20)
	var maze := grounds.get_node("HedgeMaze")
	assert_gt(maze.get_node("Collision").get_child_count(), 100, "hedge walls are solid")
	assert_not_null(maze.get_node_or_null("MazeDewPool"))


func test_stables_have_stalls_rooms_loft_and_tower() -> void:
	var stalls := grounds.get_node("Stables/Stalls").get_children()
	assert_gte(stalls.size(), 8)
	for n in ["TackRoom", "FeedRoom", "CarriageHouse", "Hayloft", "ClockTower"]:
		assert_not_null(grounds.get_node_or_null("Stables/" + n), n)
	# the loft is reachable: ramp rises the full loft height
	assert_almost_eq(ManorStables.LOFT_Y, 3.2, 0.01)


func test_orchard_has_rows_of_trees_inside_its_walls() -> void:
	var trees := ManorOrchard.trees()
	assert_gte(trees.size(), 48)
	for t in trees:
		assert_true(ManorSitePlan.WALLED_ORCHARD.grow(-2.0).has_point(t[0]))
	assert_eq(ManorOrchard.gates().size(), 2)
	assert_eq(grounds.get_node("WalledOrchard").get_meta(&"tree_count"), trees.size())


func test_rose_garden_beds_colours_and_features() -> void:
	var beds := ManorRoseGarden.beds()
	assert_gte(beds.size(), 8)
	var colours := {}
	for b in beds:
		colours[b[1]] = true
		assert_true(ManorSitePlan.ROSE_GARDEN.encloses(b[0]))
	for c in [&"red", &"white", &"gold", &"pink"]:
		assert_true(colours.has(c), "has %s roses" % c)
	assert_gte(ManorRoseGarden.ARBORS.size(), 2)
	var puca := grounds.get_node_or_null("puca_garden_spot") as Node3D
	assert_not_null(puca)
	assert_true(ManorSitePlan.ROSE_GARDEN.has_point(Vector2(puca.position.x, puca.position.z)))


func test_two_walkable_glass_houses_with_a_landmark_dome() -> void:
	var gh := grounds.get_node("GlassHouses")
	assert_eq(gh.get_meta(&"house_count"), 2)
	assert_gt(gh.get_node("Collision").get_child_count(), 40, "panes collide")
	assert_gt(ManorGlassHouses.dome_top().y - WorldHeight.height_at(ManorGlassHouses.dome_top().x, ManorGlassHouses.dome_top().z), 18.0)


func test_sentry_gate_is_a_region_gate_for_manor_grounds() -> void:
	var gate := grounds.get_node("Gate_manor_grounds") as RegionGate
	assert_not_null(gate)
	assert_eq(gate.region_id, &"manor_grounds")
	assert_gt(gate.find_children("*", "CollisionShape3D", true, false).size(), 0)
	assert_almost_eq(ManorSitePlan.SENTRY_GATE.y, 280.0, 0.1)


func test_landmarks() -> void:
	var marks := get_tree().get_nodes_in_group(ManorGrounds.LANDMARK_GROUP)
	assert_gte(marks.size(), 3, "belvedere, dome, clock tower (+ manor towers from the house)")
	for m in marks:
		var n := m as Node3D
		assert_gt(n.global_position.y - WorldHeight.height_at(n.global_position.x, n.global_position.z), 15.0, "%s is tall" % n.name)


func test_story_anchors_exist_and_are_clear() -> void:
	var names := {}
	for n in get_tree().get_nodes_in_group(&"story_anchor"):
		names[String(n.name)] = n
	for want in ["garden_gate", "manor_fountain", "rose_garden_bush", "attor_hiding_spot"]:
		assert_true(names.has(want), want)
	var layers := ManorScatter.load_or_build()
	for want in names:
		var p: Vector3 = (names[want] as Node3D).position
		for l in layers:
			if not (l.tags.has("tree") or l.tags.has("tall")):
				continue
			for i in l.count():
				var q := l.position_of(i)
				assert_gt(Vector2(q.x - p.x, q.z - p.z).length(), 12.0, "%s clear of %s" % [want, l.id])


func test_ambient_life_has_day_and_dusk_effects() -> void:
	var life := grounds.get_node("AmbientLife") as ManorAmbientLife
	for kind in [&"petals", &"pollen", &"butterflies", &"fireflies"]:
		assert_gt(life.emitters(kind).size(), 0, String(kind))
	var keep := Clock.time_of_day
	Clock.time_of_day = 0.9
	life._update(true)
	assert_true(life.emitters(&"fireflies")[0].emitting, "fireflies at night")
	assert_false(life.emitters(&"butterflies")[0].emitting)
	Clock.time_of_day = 0.5
	life._update(true)
	assert_false(life.emitters(&"fireflies")[0].emitting)
	assert_true(life.emitters(&"butterflies")[0].emitting, "butterflies by day")
	Clock.time_of_day = keep


func test_no_sky_or_sun_in_the_region_and_a_manor_grade() -> void:
	assert_eq(grounds.find_children("*", "WorldEnvironment", true, false).size(), 0)
	assert_eq(grounds.find_children("*", "DirectionalLight3D", true, false).size(), 0)
	var grade := grounds.get_node("ManorGrade") as RegionGrade
	assert_eq(grade.grade, &"manor")
	assert_eq(GradeDirector.load_preset(&"manor").id, &"manor")


func test_pond_water_sits_at_pond_level() -> void:
	assert_not_null(grounds.get_node_or_null("Pond"))
	assert_lt(ManorTerrain.pond_level(), WorldHeight.height_at(ManorSitePlan.POND_CENTER.x, ManorSitePlan.POND_CENTER.y + ManorSitePlan.POND_RADII.y * 1.3))
	assert_gt(ManorTerrain.pond_level(), WorldHeight.height_at(ManorSitePlan.POND_CENTER.x, ManorSitePlan.POND_CENTER.y))


func test_structures_collide_on_the_world_layer() -> void:
	for body in grounds.find_children("*", "StaticBody3D", true, false):
		assert_eq((body as StaticBody3D).collision_layer, 1)


func test_region_def() -> void:
	var def := load("res://data/regions/spring_court/manor_estate.tres") as RegionDef
	assert_eq(def.id, &"manor_estate")
	assert_true(ResourceLoader.exists(def.scene_path))
	assert_true(FileAccess.file_exists(def.report_path))
	for n in ["border_woods", "eastern_woods"]:   # rosewild once it has a RegionDef
		assert_true(def.neighbors.has(n))
