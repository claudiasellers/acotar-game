## Contract for every bridge in the game (world/shared/bridges/bridge_span.gd):
## each sits square to its water, its deck ends meet the ground, its road or
## path comes in on its axis, and Feyre runs and sprints across with no stall,
## hop or step. The ground is the height field on the terrain's 1 m grid, so
## this needs no bake.
extends GutTest

const SPEEDS := [10.686, 17.03]
const MAX_STEP_UP := 0.09       # metres of height change in one physics tick
const MIN_SPEED_SHARE := 0.9    # of the running speed, along the surface
const ZONE := 1.0               # measured from this far before the deck to this far after it


## {id, ends, water(tangent), half_width, way, shapes: [[shape, xform]]}
func _bridges() -> Array:
	var out: Array = []
	var L := HumanRealmLayout
	# Village.
	var v := L.creek_bridge()
	var ve := BridgeSpan.ends_on_ground(v, VillagePlan.BRIDGE_LENGTH * 0.5)
	var vy := (ve[0].y + ve[1].y) * 0.5
	var vxf := Transform3D(Basis(Vector3.UP, atan2((v.across as Vector2).x, (v.across as Vector2).y)), Vector3(v.centre.x, vy, v.centre.y))
	var vends: Array[Vector3] = [Vector3(ve[0].x, vy, ve[0].z), Vector3(ve[1].x, vy, ve[1].z)]
	out.append({id = "village", ends = vends, water = v.along, half_width = 2.0, way = L.ROADS[1], shapes = [[VillagePlan.bridge_deck(), vxf]], walk = true})
	# Hunting forest.
	var f := L.frozen_bridge()
	var fe := BridgeSpan.ends_on_ground(f, HuntingForestBuilder.BRIDGE_HALF_LENGTH)
	var fxf := BridgeSpan.frame(fe[0], fe[1])
	fxf.origin -= fxf.basis.y * HuntingForestBuilder.bridge_deck_profile()[0].y
	out.append({id = "frozen", ends = fe, water = f.along, half_width = 1.6, way = L.PATHS[0], shapes = [[BridgeSpan.deck_shape(HuntingForestBuilder.bridge_deck_profile(), 2.0), fxf]], walk = true})
	# Spring Court: every landmark built on the arched footbridge.
	for path in ["res://data/regions/spring_court/content/fae_village.tres", "res://data/regions/spring_court/content/blossom_vale.tres"]:
		var c: CourtRegionContent = load(path)
		for lm in c.landmarks:
			if not lm.asset_ids.has(CourtRegion.BRIDGE_ASSET):
				continue
			var e := CourtRegion.bridge_ends(lm)
			var s := BridgeSpan.square_across(MacroHeight.THORNWATER, lm.position, Vector2.ZERO)
			var shape := BridgeSpan.deck_shape(BridgeSpan.arch_profile(e[0].distance_to(e[1]), CourtRegion.BRIDGE_RISE), CourtRegion.BRIDGE_HALF_WIDTH)
			out.append({id = lm.id, ends = e, water = s.along, half_width = 0.7, shapes = [[shape, BridgeSpan.frame(e[0], e[1])]], walk = true})
	return out


func test_there_are_four_bridges_and_court_ones_are_found() -> void:
	assert_eq(_bridges().size(), 4, "village, frozen, lantern bridge, weir")


func test_each_bridge_is_square_to_its_water() -> void:
	for b: Dictionary in _bridges():
		var d := Vector2(b.ends[1].x - b.ends[0].x, b.ends[1].z - b.ends[0].z).normalized()
		var off := 90.0 - rad_to_deg(acos(absf(d.dot(b.water))))
		assert_lt(off, BridgeSpan.MAX_SKEW_DEGREES, "%s is %.1f deg off square" % [b.id, off])


func test_each_end_meets_the_ground() -> void:
	for b: Dictionary in _bridges():
		for e: Vector3 in b.ends:
			var gap := absf(e.y - WorldHeight.height_at(e.x, e.z))
			assert_lt(gap, BridgeSpan.MAX_END_GAP, "%s end %s is %.2f m off the ground" % [b.id, e, gap])
		var tilt := rad_to_deg(atan2(absf(b.ends[1].y - b.ends[0].y), Vector2(b.ends[1].x - b.ends[0].x, b.ends[1].z - b.ends[0].z).length()))
		assert_lt(tilt, BridgeSpan.MAX_PITCH_DEGREES, "%s tilts %.1f deg" % [b.id, tilt])


func test_the_way_comes_in_on_the_bridge_axis() -> void:
	for b: Dictionary in _bridges():
		if not b.has("way"):
			continue
		for e: Vector3 in b.ends:
			var beyond := Vector2(e.x, e.z) + Vector2(e.x - b.ends[0].x - (b.ends[1].x - e.x), e.z - b.ends[0].z - (b.ends[1].z - e.z)).normalized() * 3.0
			assert_lt(HumanRealmLayout.distance_to_polyline(beyond, b.way), 0.25, "%s: way off the axis past its end" % b.id)


func test_the_manor_footbridge_meets_both_shores_square() -> void:
	var e := ManorPond.bridge_ends()
	var d := (e[1] - e[0]).normalized()
	var shore := (ManorSitePlan.POND_ISLET - ManorSitePlan.POND_ISLAND).normalized()
	assert_almost_eq(d.dot(shore), 1.0, 0.001)
	var il := ManorSitePlan.POND_ISLAND.distance_to(e[0])
	assert_lt(il, ManorPond.ISLAND_R, "end on the island")
	assert_lt(ManorSitePlan.POND_ISLET.distance_to(e[1]), ManorPond.ISLET_R, "end on the islet")


func test_feyre_crosses_every_bridge_both_ways_without_a_catch() -> void:
	for b: Dictionary in _bridges():
		var body := _world(b)
		for speed: float in SPEEDS:
			for way in 2:
				await _cross(b, speed, way == 1)
		body.free()


func test_feyre_crosses_the_manor_footbridge() -> void:
	var y := ManorPond.level()
	var xf := ManorPond.bridge_frame(y)
	var e := ManorPond.bridge_ends()
	var length := e[0].distance_to(e[1])
	var a := xf * Vector3(0, 0, -length * 0.5)
	var c := xf * Vector3(0, 0, length * 0.5)
	var ends: Array[Vector3] = [a, c]
	var body := StaticBody3D.new()
	add_child(body)
	var deck := CollisionShape3D.new()
	deck.shape = BridgeSpan.deck_shape(BridgeSpan.arch_profile(length, ManorPond.BRIDGE_RISE), 0.9)
	deck.transform = xf
	body.add_child(deck)
	# Island tops, as ManorPond._island builds their collision.
	for spec: Vector2 in [Vector2(ManorSitePlan.POND_ISLAND), Vector2(ManorSitePlan.POND_ISLET)]:
		var top := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(12, 1, 12)
		top.shape = box
		top.position = Vector3(spec.x, y + 0.45 - 0.5, spec.y)
		body.add_child(top)
	for speed: float in SPEEDS:
		await _cross({id = "manor", ends = ends, half_width = 0.7}, speed, false, 0.14)
	body.free()


## The ground near the bridge as a height map on the terrain's grid.
func _world(b: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	add_child(body)
	var c: Vector3 = (b.ends[0] + b.ends[1]) * 0.5
	var size := 81
	var map := HeightMapShape3D.new()
	map.map_width = size
	map.map_depth = size
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	var ox := roundf(c.x)
	var oz := roundf(c.z)
	for j in size:
		for i in size:
			heights[j * size + i] = WorldHeight.height_at(ox + i - 40, oz + j - 40)
	map.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = map
	cs.position = Vector3(ox, 0, oz)
	body.add_child(cs)
	for s: Array in b.shapes:
		var d := CollisionShape3D.new()
		d.shape = s[0]
		d.transform = s[1]
		body.add_child(d)
	return body


## Runs a capsule tuned like Feyre across: constant wish speed along the axis,
## through the same move_and_slide she uses.
func _cross(b: Dictionary, speed: float, reverse: bool, allow_step := MAX_STEP_UP) -> void:
	var from: Vector3 = b.ends[1] if reverse else b.ends[0]
	var to: Vector3 = b.ends[0] if reverse else b.ends[1]
	var dir := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	var run := 8.0
	var mover := CharacterBody3D.new()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	mover.add_child(col)
	mover.floor_snap_length = 0.4
	mover.floor_max_angle = deg_to_rad(50.0)
	mover.floor_stop_on_slope = false
	add_child(mover)
	var start := from - dir * run
	var ground := _down(start + Vector3.UP * 4.0)
	mover.global_position = Vector3(start.x, ground + 0.05, start.z)
	await get_tree().physics_frame
	for t in 20:
		mover.velocity = Vector3.DOWN
		mover.move_and_slide()
		await get_tree().physics_frame
		if mover.is_on_floor():
			break
	var total := start.distance_to(to + dir * run) * 1.02
	var span := Vector2(to.x - from.x, to.z - from.z).length()
	var worst_rise := 0.0
	var worst_speed := INF
	var airborne := 0
	var last := mover.global_position
	var ticks := int(total / speed * 60.0) + 90
	var done := 0
	var gone := 0.0
	for t in ticks:
		var v := mover.velocity
		mover.velocity = Vector3(dir.x * speed, v.y - 9.8 / 60.0 if not mover.is_on_floor() else 0.0, dir.z * speed)
		mover.move_and_slide()
		await get_tree().physics_frame
		var p := mover.global_position
		var along := Vector2(p.x - from.x, p.z - from.z).dot(Vector2(dir.x, dir.z))
		if along > -ZONE and along < span + ZONE:
			worst_speed = minf(worst_speed, p.distance_to(last) * 60.0)
			worst_rise = maxf(worst_rise, absf(p.y - last.y))
			if not mover.is_on_floor():
				airborne += 1
		gone += Vector2(p.x - last.x, p.z - last.z).length()
		last = p
		done = t
		if gone >= total:
			break
	var label := "%s at %.2f %s" % [b.id, speed, "back" if reverse else "out"]
	gut.p("%s: min speed %.2f, biggest tick height change %.3f, %d ticks off the floor, %d ticks" % [label, worst_speed, worst_rise, airborne, done])
	assert_gt(gone, total * 0.97, "%s: stalled" % label)
	assert_gt(worst_speed, speed * MIN_SPEED_SHARE, "%s: slowed to %.2f" % [label, worst_speed])
	assert_lt(worst_rise, allow_step * (speed / SPEEDS[0]), "%s: height jumped %.3f in a tick" % [label, worst_rise])
	assert_lt(airborne, 6, "%s: left the floor for %d ticks" % [label, airborne])
	mover.free()


func _down(from: Vector3) -> float:
	var space := get_tree().root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0))
	return hit.position.y if not hit.is_empty() else from.y
