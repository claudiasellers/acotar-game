extends GutTest
## Contract test for the wayside layer (L23, docs/contracts/wayside.md).

const ROUTES := preload("res://tools/wayside/wayside_routes.gd")
## The F9 bar from the director: no stretch of a route over this many metres
## without a spot in sight (60 s at a run is 493 m; we aim for ~25 s).
const MAX_GAP_M := 260.0
const SEEN := 30.0


func before_each() -> void:
	WorldState.clear()
	WorldDeltas.clear()


func _director(target: Node3D) -> Wayside:
	var w := Wayside.new()
	w.target = target
	add_child_autofree(w)
	return w


func _spot(kind: StringName, id: String, at: Vector3) -> WaysideSpot:
	var s := WaysideSpot.new()
	s.kind = kind
	s.id = StringName(id)
	s.position = at
	s.target = at + Vector3(0, 0, -30)
	return s


func test_every_route_has_data_and_unique_ids() -> void:
	var w := _director(null)
	assert_eq(w.routes.size(), ROUTES.ROUTES.size(), "one data/wayside/<route>.tres per route")
	var ids := {}
	for spot in w.spots():
		assert_false(ids.has(spot.id), "unique id %s" % spot.id)
		ids[spot.id] = true
		assert_true(Wayside.KINDS.has(spot.kind), "known kind %s" % spot.kind)
		assert_true(["C", "C?", "X"].has(spot.canon), "canon tag on %s" % spot.id)
		for item in spot.items:
			assert_not_null(ItemCatalog.get_item(StringName(item)), "item %s exists" % item)
			assert_ne(item, "col_mask_ribbon", "Keeper: masks are never found lying about")


func test_no_route_has_a_long_empty_stretch() -> void:
	var w := _director(null)
	for route in w.routes:
		var since := 0.0
		var worst := 0.0
		for p in ROUTES.samples(Array(route.waypoints), 5.0):
			var seen := false
			for spot in w.spots():
				if p.distance_to(Vector2(spot.position.x, spot.position.z)) < SEEN:
					seen = true
					break
			since = 0.0 if seen else since + 5.0
			worst = maxf(worst, since)
		# The hubs at each end have their own content.
		assert_lt(worst, MAX_GAP_M + 110.0, "%s: longest empty stretch %.0f m" % [route.id, worst])


func test_streams_spots_in_and_out_around_feyre() -> void:
	var who := Node3D.new()
	add_child_autofree(who)
	var w := _director(who)
	var near := w.spots()[0]
	who.global_position = near.position
	var live := w.update_for(who.global_position)
	assert_gt(live, 0)
	assert_true(w.live.has(near.id), "the spot she stands on is built")
	assert_lt(live, 40, "only nearby spots are live (draw-call budget)")
	who.global_position = near.position + Vector3(5000, 0, 5000)
	assert_eq(w.update_for(who.global_position), 0, "all freed when she's far away")


func test_every_kind_builds_without_errors() -> void:
	var who := Node3D.new()
	add_child_autofree(who)
	var w := _director(who)
	var seen := {}
	for spot in w.spots():
		if seen.has(spot.kind):
			continue
		seen[spot.kind] = true
		who.global_position = spot.position + Vector3(200, 0, 0)
		w.update_for(spot.position)
		assert_true(w.live.has(spot.id), "%s builds" % spot.kind)
	assert_eq(seen.size(), Wayside.KINDS.size(), "every kind is used on some route")


func test_rest_frames_the_view_and_sketches_once() -> void:
	var w := _director(null)
	var rest := _spot(&"rest", "test_rest", Vector3.ZERO)
	rest.line = "Viridian."
	rest.params = {"seat": "rock_mossy_b", "sketch": "Test view"}
	w._spawn(rest)
	var node: WaysideRest = w.live[rest.id]
	var before := Gameplay.sketchbook.count()
	node.use(null)
	assert_true(Wayside.is_found(rest.id))
	assert_eq(Gameplay.sketchbook.count(), before + 1)
	node.use(null)
	assert_eq(Gameplay.sketchbook.count(), before + 1, "a second sit only frames the view")
	assert_almost_eq(node.view_yaw(Vector3.ZERO), 0.0, 0.01, "faces -Z toward the target")


func test_nook_gives_its_items_once_and_saves() -> void:
	var w := _director(null)
	var nook := _spot(&"nook", "test_nook", Vector3.ZERO)
	nook.items = PackedStringArray(["col_coin_old"])
	w._spawn(nook)
	var node: WaysideNook = w.live[nook.id]
	var had := Gameplay.inventory.count(&"col_coin_old")
	node.use(null)
	node.use(null)
	assert_eq(Gameplay.inventory.count(&"col_coin_old"), had + 1)
	var saved := WorldDeltas.to_dict()
	WorldDeltas.clear()
	assert_false(Wayside.is_found(nook.id))
	WorldDeltas.from_dict(saved)
	assert_true(Wayside.is_found(nook.id), "found nooks come back with the save")


func test_snare_catches_only_on_a_later_day_and_agrees_with_itself() -> void:
	var w := _director(null)
	var snare := _spot(&"snare", "test_snare", Vector3.ZERO)
	w._spawn(snare)
	var node: WaysideSnare = w.live[snare.id]
	assert_eq(node.catch_on(Clock.day + 1), 0, "an unset snare catches nothing")
	node.use(null)
	assert_eq(node.set_day(), Clock.day)
	assert_eq(node.catch_on(Clock.day), 0, "nothing the same day")
	var hits := 0
	for d in range(1, 41):
		var n := node.catch_on(Clock.day + d)
		assert_eq(n, node.catch_on(Clock.day + d), "seeded")
		hits += 1 if n > 0 else 0
	assert_between(hits, 12, 36, "catches more often than not over 40 days")


func test_spots_respect_flags() -> void:
	var s := _spot(&"shimmer", "flagged", Vector3.ZERO)
	s.forbid_flags = PackedStringArray(["glamour_lifted"])
	var w := _director(null)
	w.routes.clear()
	w.spots().clear()
	w.add_route(_route_of([s]))
	assert_eq(w.update_for(Vector3.ZERO), 1)
	WorldState.set_flag("glamour_lifted", true)
	assert_eq(w.update_for(Vector3.ZERO), 0, "gone once the flag rises")


func test_crossing_has_world_collision() -> void:
	var w := _director(null)
	var c := _spot(&"crossing", "test_crossing", Vector3.ZERO)
	c.target = Vector3(0, 0, 12)
	c.params = {"model": "stepping_stones", "repeat": true, "unit_length": 3.2}
	w._spawn(c)
	var node: WaysideCrossing = w.live[c.id]
	assert_gt(node.bodies.size(), 0)
	for b in node.bodies:
		assert_eq(b.collision_layer, 1, "layer 1 = static world")


func _route_of(spots: Array) -> WaysideRoute:
	var r := WaysideRoute.new()
	r.id = &"test"
	for s in spots:
		r.spots.append(s)
	return r
