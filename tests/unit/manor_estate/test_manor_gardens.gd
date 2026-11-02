## The manor gardens (L35): the circular rose garden, the garden rooms off the
## Wisteria Walk, the reflecting pool and temple, the front parterres. One
## contract per system: what is there, that it is reachable, that it keeps the
## story anchors where the story lanes put them, and that it never glares.
extends GutTest

var root: Node3D
var grounds: Node3D
var layers: Array[ScatterLayer]


func before_all() -> void:
	root = Node3D.new()
	add_child(root)
	grounds = ManorGrounds.build(root)
	layers = ManorScatter.build_all()


func after_all() -> void:
	root.free()


func _props(node: String) -> Dictionary:
	var n := grounds.get_node(node)
	assert_true(n.has_meta(&"props"), "%s records its props" % node)
	return n.get_meta(&"props", {})


func test_garden_props_and_flowers_have_models() -> void:
	var garden := 0
	for id: StringName in PropCatalog.ENTRIES:
		if PropCatalog.ENTRIES[id][0] == &"garden_rooms":
			garden += 1
			assert_true(ResourceLoader.exists(PropModels.PROP_DIR + String(id) + ".glb"), "%s has a model" % id)
	assert_gte(garden, 20, "garden structures")
	var flowers := [&"rose_crimson", &"rose_raspberry", &"rose_blush", &"rose_cream", &"rose_butter", &"rose_apricot", &"rose_peach",
		&"rose_coral", &"rose_mauve", &"snowdrop", &"daffodil", &"hydrangea", &"hydrangea_pink", &"delphinium", &"lupin",
		&"hollyhock", &"allium", &"catmint", &"foxglove_white", &"peony_white", &"meadow_buttercup"]
	for id: StringName in flowers:
		assert_true(FloraLib.SPECIES.has(id), "%s is a species" % id)
		assert_true(ResourceLoader.exists(PropModels.FLORA_DIR + String(id) + ".glb"), "%s has a model" % id)


func test_rose_garden_wheel_fountain_swags_and_tunnels() -> void:
	var hues := {}
	for h: StringName in ManorRoseGarden.WHEEL:
		hues[h] = true
	assert_gte(hues.size(), 12, "a colour wheel of 12 rose hues")
	var p := _props("RoseGarden")
	assert_eq(int(p.get(&"heron_fountain", 0)), 1, "the heron fountain (canon ch24)")
	assert_gte(int(p.get(&"rose_swag_bay", 0)), 20)
	assert_gte(int(p.get(&"rose_tunnel_arch", 0)), 16)
	assert_gt(int(p.get(&"yew_hedge", 0)), 60, "the outer hedge wall (ch19)")
	# every hue is actually planted
	var planted := {}
	for l in layers:
		planted[l.id] = l.count()
	for h: StringName in hues:
		assert_gt(int(planted.get(ManorRoseGarden.rose_layer(h), 0)), 20, "%s roses planted" % h)


func test_story_anchors_stay_where_the_story_lanes_put_them() -> void:
	var expect := {
		&"manor_fountain": Vector2(0.0, -139.5), &"rose_garden_bush": Vector2(40.0, -147.0),
		&"garden_gate": Vector2(0.0, -194.0), &"attor_hiding_spot": Vector2(-40.0, -105.5),
	}
	var anchors := ManorRoseGarden.story_anchors()
	for id: StringName in expect:
		assert_true(anchors.has(id), String(id))
		assert_almost_eq((anchors[id][0] as Vector2).distance_to(expect[id]), 0.0, 0.01, String(id))
	assert_eq(ManorSitePlan.PUCA_GARDEN_SPOT, Vector2(-62.0, -106.0))


func test_garden_rooms_and_the_wisteria_walk() -> void:
	assert_gte(ManorGardenRooms.ROOMS.size(), 4, "four hedged rooms")
	assert_gte(ManorGardenRooms.walk_length(), 60.0, "the Wisteria Walk")
	var p := _props("GardenRooms")
	assert_gte(int(p.get(&"wisteria_bay", 0)), 20)
	assert_gt(int(p.get(&"yew_hedge", 0)), 80, "yew walls round the rooms")
	assert_gte(int(p.get(&"yew_hedge_arch", 0)), 8, "arched openings")
	# canon ch8, all in the lamb lawn: the alcove bench, the lambs, the crab apples
	for id: StringName in [&"alcove_niche", &"lamb_statue", &"garden_bench"]:
		assert_gte(int(p.get(id, 0)), 1, String(id))
	var lawn: Rect2 = ManorGardenRooms.ROOMS[&"crab_apple_lawn"]
	assert_true(lawn.has_point(ManorGardenRooms.LAMBS) and lawn.has_point(ManorGardenRooms.ALCOVE))
	for c: Vector2 in ManorGardenRooms.CRAB_APPLES:
		assert_true(lawn.has_point(c))
	# rooms never overlap each other, the rose garden or the maze
	var rects: Array[Rect2] = [ManorSitePlan.ROSE_GARDEN, ManorSitePlan.HEDGE_MAZE]
	for id: StringName in ManorGardenRooms.ROOMS:
		var r: Rect2 = ManorGardenRooms.ROOMS[id]
		for o in rects:
			assert_false(r.intersects(o), "%s clear of %s" % [id, o])
		rects.append(r)
	assert_gt(grounds.get_node("GardenRooms/Collision").get_child_count(), 80, "the yew walls are solid")


func test_reflecting_pool_temple_and_front_parterres() -> void:
	assert_gte(ManorReflectingPool.length(), 80.0)
	var pool := _props("ReflectingPool")
	assert_eq(int(pool.get(&"temple_of_love", 0)), 1)
	# the canal sits level: water above all the ground inside its basin
	var wy := ManorReflectingPool.water_y()
	var b := ManorReflectingPool.basin()
	for i in 5:
		for j in 9:
			var x := b.position.x + b.size.x * i / 4.0
			var z := b.position.y + b.size.y * j / 8.0
			assert_gt(wy, WorldHeight.height_at(x, z), "water over the ground at %.0f, %.0f" % [x, z])
	var parterres := ManorFrontGarden.parterres()
	assert_eq(parterres.size(), 2)
	assert_true(parterres[0].get_center().x * parterres[1].get_center().x < 0.0, "one each side of the forecourt")
	for p in parterres:
		assert_false(p.intersects(ManorSitePlan.HOUSE_MAIN.grow(1.0)) or p.intersects(ManorSitePlan.HOUSE_WEST) or p.intersects(ManorSitePlan.HOUSE_SERVICE))
		assert_gt(p.get_center().distance_to(ManorSitePlan.FORECOURT_CENTER), ManorSitePlan.FORECOURT_RADIUS)
	assert_gte(int(_props("FrontGarden").get(&"box_edging", 0)), 100)


## Every room, the pool's temple and both parterres are reachable along walks
## from the foot of the terrace steps (walks join where they touch).
func test_every_garden_is_reachable_from_the_terrace() -> void:
	var walks: Array = []
	walks.append_array(ManorRoseGarden.walks())
	walks.append_array(ManorGardenRooms.walks())
	walks.append_array(ManorReflectingPool.walks())
	walks.append_array(ManorFrontGarden.walks())
	# the forecourt ring and the terrace (around the house by the forecourt drive)
	walks.append([GardenKit.ring(ManorSitePlan.FORECOURT_CENTER, ManorSitePlan.FORECOURT_RADIUS - 2.0, 48), 4.0])
	var start := Vector2(0.0, ManorTerraceBuilder.STEPS_BOTTOM_Z)
	var seen := {}
	var queue: Array[int] = []
	for i in walks.size():
		if _near_walk(start, walks[i], 1.0):
			seen[i] = true
			queue.append(i)
	while not queue.is_empty():
		var i: int = queue.pop_back()
		for j in walks.size():
			if not seen.has(j) and _walks_touch(walks[i], walks[j]):
				seen[j] = true
				queue.append(j)
	var targets := ManorGardenRooms.room_doors()
	targets[&"temple"] = ManorReflectingPool.TEMPLE + Vector2(0.0, ManorReflectingPool.TEMPLE_R + 0.5)
	targets[&"maze"] = Vector2(ManorSitePlan.HEDGE_MAZE.end.x + 1.0, -206.5)
	for id: StringName in targets:
		var ok := false
		for i: int in seen:
			ok = ok or _near_walk(targets[id], walks[i], 0.5)
		assert_true(ok, "%s reachable from the terrace" % id)
	# the front parterres hang off the forecourt ring (the house's front door)
	var ring: Array = walks[walks.size() - 1]
	var front := ManorFrontGarden.walks()
	for k in front.size():
		assert_true(_walks_touch(ring, front[k]) if k % 2 == 0 else _walks_touch(front[k - 1], front[k]), "parterre walk %d joins" % k)


## Audit D5: the east lawn in front of the house is a garden, not a bare plane,
## and it keeps the way to the kitchen garden's gate (the playtest's route to
## the potting shed) clear of anything solid.
func test_east_lawn_is_dressed_and_keeps_the_kitchen_walk_clear() -> void:
	var p := _props("EastLawn")
	assert_gte(int(p.get(&"box_edging", 0)), 40, "box-edged borders")
	for id: StringName in [&"yew_hedge", &"bench_curved", &"cupid_statue", &"garden_bench", &"topiary_cone", &"faelight_lantern", &"urn_overflowing"]:
		assert_gte(int(p.get(id, 0)), 1, String(id))
	assert_gte(ManorEastLawn.bed_runs().size(), 3)
	var flowers := 0
	var area := Rect2(60.0, -18.0, 120.0, 46.0)
	for l in layers:
		if l.tags.has("decoration"):
			for i in l.count():
				var q := l.position_of(i)
				if area.has_point(Vector2(q.x, q.z)):
					flowers += 1
	assert_gte(flowers, 450, "the borders are planted thick")
	# the exedra and the kitchen garden's gate are on walks from the front door
	var walks: Array = [[GardenKit.ring(ManorSitePlan.FORECOURT_CENTER, ManorSitePlan.FORECOURT_RADIUS - 2.0, 48), 4.0]]
	walks.append_array(ManorFrontGarden.walks())
	walks.append_array(ManorEastLawn.walks())
	var seen := {0: true}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var i: int = queue.pop_back()
		for j in walks.size():
			if not seen.has(j) and _walks_touch(walks[i], walks[j]):
				seen[j] = true
				queue.append(j)
	for target: Vector2 in [Vector2(ManorEastLawn.WALK_END_X, ManorEastLawn.WALK_Z), ManorEastLawn.GATE]:
		var ok := false
		for i: int in seen:
			ok = ok or _near_walk(target, walks[i], 0.5)
		assert_true(ok, "%s reachable from the front door" % target)
	# nothing solid within a body's width of the kitchen walk, which follows
	# P3P4Chain.TO_SHED from the lawn to the gate
	var line := ManorEastLawn.kitchen_line()
	var root_node := grounds.get_node("EastLawn/Collision")
	for shape_owner in root_node.get_children():
		if shape_owner is CollisionShape3D:
			var o: Vector3 = (shape_owner as CollisionShape3D).global_position
			var d := INF
			for i in line.size() - 1:
				d = minf(d, Geometry2D.get_closest_point_to_segment(Vector2(o.x, o.z), line[i], line[i + 1]).distance_to(Vector2(o.x, o.z)))
			assert_gt(d, ManorEastLawn.KITCHEN_W * 0.5 + 0.3, "collider at %.1f, %.1f clear of the kitchen walk" % [o.x, o.z])
	var to_shed: Array = P3P4Chain.TO_SHED
	assert_eq(to_shed[1], ManorEastLawn.BEND, "the kitchen walk bends where the chain's walk does")


## The south hedge returns open in line with the wings' garden doors (the chain
## playtest walked into a solid hedge at x -71 coming back from the puca).
func test_south_hedge_returns_open_toward_the_wings() -> void:
	var space := grounds.get_node("RoseGarden/Collision")
	for side: float in [-1.0, 1.0]:
		var gap := Vector2(side * ManorRoseGarden.SOUTH_OPENING_X, -93.0)
		for cs in space.get_children():
			if cs is CollisionShape3D:
				var o: Vector3 = (cs as CollisionShape3D).global_position
				assert_gt(Vector2(o.x, o.z).distance_to(gap), 0.9, "nothing solid in the opening at %s" % gap)


func test_decorations_and_draw_budget() -> void:
	var areas: Array[Rect2] = [ManorSitePlan.ROSE_GARDEN, ManorGardenRooms.AREA, ManorGardenRooms.BUTTERCUP_MEADOW,
		ManorReflectingPool.footprints()[0]]
	areas.append_array(ManorFrontGarden.parterres())
	var n := 0
	for l in layers:
		if not l.tags.has("decoration"):
			continue
		for i in l.count():
			var p := l.position_of(i)
			for a in areas:
				if a.has_point(Vector2(p.x, p.z)):
					n += 1
					break
	gut.p("garden decorations: %d" % n)
	assert_gte(n, 6000, "the gardens are planted thick")


## Manor glare fix: nothing the gardens lay down in the sun is near-white.
func test_garden_surfaces_stay_below_glare() -> void:
	for m: Material in [GardenKit.stone(), GardenKit.stone_shade(), GardenKit.paving(), GardenKit.mulch(), GardenKit.lawn()]:
		var c := (m as StandardMaterial3D).albedo_color
		assert_lte(maxf(c.r, maxf(c.g, c.b)), 0.85, "%s albedo" % m.resource_name)
	assert_eq(GardenKit.walk(), ManorForecourt.drive_gravel(), "walks share the drive's capped gravel")


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _near_walk(p: Vector2, w: Array, slack: float) -> bool:
	var pts: PackedVector2Array = w[0]
	for k in pts.size() - 1:
		if _seg_dist(p, pts[k], pts[k + 1]) <= float(w[1]) * 0.5 + slack:
			return true
	return false


func _walks_touch(a: Array, b: Array) -> bool:
	var pa: PackedVector2Array = a[0]
	var pb: PackedVector2Array = b[0]
	var reach := float(a[1]) * 0.5 + float(b[1]) * 0.5 + 0.5
	for k in pa.size() - 1:
		for m in pb.size() - 1:
			if Geometry2D.segment_intersects_segment(pa[k], pa[k + 1], pb[m], pb[m + 1]) != null:
				return true
			for q in [pb[m], pb[m + 1]]:
				if _seg_dist(q, pa[k], pa[k + 1]) <= reach:
					return true
			for q in [pa[k], pa[k + 1]]:
				if _seg_dist(q, pb[m], pb[m + 1]) <= reach:
					return true
	return false

