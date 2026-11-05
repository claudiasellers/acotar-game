extends GutTest
## The wider court's terrain (CourtHeight): it keeps every other lane's
## ground exactly, has no seams, keeps its named ground usable, seals the
## Autumn border and the court's outer edge against Feyre's whole jump chain,
## and its water stands where water can stand. Reads the height field only.
# gate: when:world/spring_court/wider/*,world/shared/terrain/*,tools/court/*

const MANOR := Rect2(-600.0, -500.0, 1200.0, 1000.0)
## Feyre: walkable floor up to 50 degrees; from a floor she can reach a ledge
## up to her triple jump plus a mantle above it, a few metres away.
const FLOOR_DEG := 50.0
const REACH_UP := 9.25 + 1.5
const REACH_OUT := 6.0


func before_all() -> void:
	WorldHeight.set_providers(null)
	WorldHeight.warm_up()
	CourtHeight.prewarm()


func test_estate_ground_is_exactly_as_without_the_court() -> void:
	var all := WorldHeight.providers().duplicate()
	var others: Array[HeightProvider] = []
	for p in all:
		if not String(p.id).begins_with("court_"):
			others.append(p)
	var want := PackedFloat32Array()
	WorldHeight.set_providers(others)
	var x := MANOR.position.x
	while x <= MANOR.end.x:
		var z := MANOR.position.y
		while z <= MANOR.end.y:
			want.append(WorldHeight.height_at(x, z))
			z += 20.0
		x += 20.0
	WorldHeight.set_providers(all)
	var i := 0
	var worst := 0.0
	x = MANOR.position.x
	while x <= MANOR.end.x:
		var z := MANOR.position.y
		while z <= MANOR.end.y:
			worst = maxf(worst, absf(WorldHeight.height_at(x, z) - want[i]))
			i += 1
			z += 20.0
		x += 20.0
	assert_lt(worst, 0.0001, "the estate's ground moved by %.4f m" % worst)


func test_providers_tile_our_ground_without_overlap() -> void:
	var ours: Array[HeightProvider] = []
	for p in WorldHeight.providers():
		if String(p.id).begins_with("court_"):
			ours.append(p)
			assert_eq(p.fade, 0.0, "%s blends itself" % p.id)
	assert_eq(ours.size(), CourtHeight.DOMAIN.size())
	for a in ours.size():
		for b in range(a + 1, ours.size()):
			var o := ours[a].bounds.intersection(ours[b].bounds)
			assert_true(o.size.x <= 0.0 or o.size.y <= 0.0, "%s overlaps %s" % [ours[a].id, ours[b].id])
	for p in WorldHeight.providers():
		if String(p.id).begins_with("court_"):
			continue
		for q in ours:
			var o := p.bounds.intersection(q.bounds)
			assert_true(o.size.x <= 0.0 or o.size.y <= 0.0, "%s overlaps %s" % [q.id, p.id])


func test_no_steps_at_any_seam() -> void:
	# Walk across every provider edge and every other lane's edge in 0.5 m
	# steps: the ground never jumps.
	var lines: Array = []
	for r: Array in CourtHeight.DOMAIN + CourtHeight.FOREIGN:
		for f in 9:
			var t := (f + 0.5) / 9.0
			lines.append([Vector2(r[0], lerpf(r[1], r[3], t)), Vector2(1, 0)])
			lines.append([Vector2(r[2], lerpf(r[1], r[3], t)), Vector2(1, 0)])
			lines.append([Vector2(lerpf(r[0], r[2], t), r[1]), Vector2(0, 1)])
			lines.append([Vector2(lerpf(r[0], r[2], t), r[3]), Vector2(0, 1)])
	var worst := 0.0
	var where := Vector2.ZERO
	for l: Array in lines:
		var p: Vector2 = l[0]
		var n: Vector2 = l[1]
		if p.x <= -2040.0 or p.x >= 2040.0 or p.y <= -2040.0 or p.y >= 3000.0:
			continue
		var prev := WorldHeight.height_at(p.x - n.x * 3.0, p.y - n.y * 3.0)
		for k in range(1, 13):
			var q := p + n * (k * 0.5 - 3.0)
			var h := WorldHeight.height_at(q.x, q.y)
			# Designed crags (the scarp, the rims) are allowed to be steep, not to step.
			var rough := CourtHeight.kind_at(q.x, q.y) in [CourtHeight.Kind.AUTUMN, CourtHeight.Kind.RIM]
			if absf(h - prev) > worst and not rough and _slope(q.x, q.y, 2.0) < 55.0:
				worst = absf(h - prev)
				where = q
			prev = h
	assert_lt(worst, 1.0, "a %.2f m step in half a metre at %s" % [worst, where])


func test_named_ground_is_usable() -> void:
	for id: StringName in CourtHeight.SITES:
		var s: Array = CourtHeight.SITES[id]
		var p := Vector2(s[0], s[1])
		var kind: StringName = s[3]
		if kind == &"water" or id in [&"ember_crown", &"sealed_pass", &"glimmerfall", &"thornwater_falls", &"thornwater_spring", &"lantern_bridge", &"bonfire_terraces", &"cave_of_the_rite", &"rainbow_cascade", &"summers_window", &"arch_avenue", &"vale_weir", &"thornwater_ford", &"border_markers", &"potion_house", &"west_brink", &"calanmai_cave_mouth"]:
			continue
		var limit := 12.0 if kind == &"anchor" else 24.0
		assert_lt(_slope(p.x, p.y, 2.0), limit, "%s stands on a %.0f° slope" % [id, _slope(p.x, p.y, 2.0)])
		var h := WorldHeight.height_at(p.x, p.y)
		if MacroHeight.distance_to_river(p.x, p.y) < 40.0:
			assert_gt(h, CourtHeight.river_level_at(p.x, p.y), "%s is under the Thornwater" % id)
		for l in CourtHeight.lakes():
			if p.distance_to(l["center"]) < float(l["radius"]) and id != &"looking_lake_isle":
				fail_test("%s is in %s" % [id, l["id"]])


func test_the_book_shapes() -> void:
	var H := func(x: float, z: float) -> float: return WorldHeight.height_at(x, z)
	# The plateau for the dancing is flat-topped and above the vast low meadow.
	var top: float = H.call(-150.0, -1060.0)
	for k in 8:
		var q := Vector2(-150.0, -1060.0) + Vector2.from_angle(k * TAU / 8.0) * 45.0
		assert_almost_eq(H.call(q.x, q.y), top, 0.6, "plateau top at %s" % q)
	assert_gt(top - H.call(-250.0, -1270.0), 25.0, "the plateau stands over the vast meadow")
	# The vast meadow is flat and low.
	for q: Vector2 in [Vector2(-450.0, -1280.0), Vector2(-150.0, -1290.0), Vector2(100.0, -1260.0), Vector2(-480.0, -1050.0)]:
		assert_almost_eq(H.call(q.x, q.y), 21.0, 1.5, "vast meadow at %s" % q)
	# The rite's crown is broad and bald, the highest ground in the east, and
	# stands well above the meadow and the first foothill.
	var crown: float = H.call(870.0, -1140.0)
	assert_gt(crown - H.call(200.0, -900.0), 60.0)
	assert_gt(H.call(800.0, -1100.0) - H.call(200.0, -900.0), 60.0)
	assert_gt(crown - H.call(620.0, -1055.0), 30.0)
	# The trench: steep banks either side, the cave mouth cut into its end.
	var floor_y: float = H.call(600.0, -985.0)
	assert_gt(H.call(600.0, -1005.0) - floor_y, 5.0, "north bank")
	assert_gt(H.call(600.0, -965.0) - floor_y, 5.0, "south bank")
	assert_gt(H.call(702.0, -982.0) - H.call(690.0, -982.0), 6.0, "the soft hillside rises behind the cave mouth")
	# The sycamore's knoll stands out of its ground.
	assert_gt(H.call(520.0, -880.0) - H.call(520.0, -840.0), 6.0)
	# Starlight Glen: a sunken hollow ringed by knolls; the mound overlooks it.
	var pool_floor: float = H.call(-1300.0, 230.0)
	assert_gt(H.call(-1208.0, 270.0) - pool_floor, 10.0, "the mound overlooks the clearing")
	assert_gt(H.call(-1394.0, 262.0) - pool_floor, 14.0, "the glimmer crag")
	# The towering hill in the west, with the pond at its foot.
	assert_gt(H.call(-1630.0, -650.0) - H.call(-1520.0, -400.0), 100.0)
	# The western woods are close to flat.
	var lo := INF
	var hi := -INF
	for k in 20:
		var q := Vector2(-1650.0 + (k % 5) * 30.0, 500.0 + (k / 5) * 40.0)
		lo = minf(lo, H.call(q.x, q.y))
		hi = maxf(hi, H.call(q.x, q.y))
	assert_lt(hi - lo, 14.0, "the western woods roll gently, not hill to hill")
	# The court's west edge: the woods end at a lip over a gorge.
	assert_gt(H.call(-1760.0, 300.0) - H.call(-1840.0, 300.0), 60.0)
	# The village green is level; the potion house stands on its bank (~20°)
	# and its potion room (house + (18, 20)) on the level green below.
	var house := CourtHeight.site(&"potion_house")
	var room := house + Vector2(18.0, 20.0)
	assert_between(_slope(house.x, house.y, 3.0), 12.0, 30.0, "the potion house's bank")
	assert_lt(_slope(room.x, room.y, 3.0), 8.0, "the potion room's level ground")
	assert_gt(H.call(house.x, house.y) - H.call(room.x, room.y), 3.0, "the house is up the bank")


func test_lakes_are_clear_and_deep() -> void:
	for l in CourtHeight.lakes():
		var c: Vector2 = l["center"]
		var r: float = l["radius"]
		var lv: float = l["level"]
		assert_lt(WorldHeight.height_at(c.x, c.y), lv - 4.0, "%s is deep" % l["id"])
		# A shelf, then a steep drop-off.
		var shelf := c + Vector2(r * 0.92, 0.0)
		assert_between(lv - WorldHeight.height_at(shelf.x, shelf.y), 0.2, 2.0, "%s shelf" % l["id"])
		for k in 12:
			var q := c + Vector2.from_angle(k * TAU / 12.0) * r * 1.3
			if MacroHeight.distance_to_river(q.x, q.y) < 30.0 or CourtHeight.distance_to_brook(q.x, q.y) < 4.0:
				continue
			assert_gt(WorldHeight.height_at(q.x, q.y), lv, "%s shore at %s" % [l["id"], q])


func test_brooks_only_run_downhill_in_their_beds() -> void:
	var brooks := CourtHeight.brooks()
	assert_gte(brooks.size(), 6)
	for b in brooks:
		var lv: PackedFloat32Array = b["levels"]
		var pts: PackedVector2Array = b["points"]
		for k in range(1, lv.size()):
			assert_true(lv[k] <= lv[k - 1] + 0.001, "%s runs uphill at %s" % [b["id"], pts[k]])
		for k in range(0, pts.size(), 8):
			if CourtHeight.own_weight(pts[k].x, pts[k].y) < 1.0 or _in_lake(pts[k]):
				continue
			var bed := WorldHeight.height_at(pts[k].x, pts[k].y)
			assert_between(lv[k] - bed, 0.05, 0.9, "%s water over its bed at %s" % [b["id"], pts[k]])


func test_gates_stand_on_the_ways_out() -> void:
	var gates := 0
	for id in CourtMap.region_ids():
		for g in CourtHeight.gates_for(id):
			gates += 1
			var p: Vector2 = g["position"]
			assert_eq(CourtMap.region_at(p.x, p.y), id, "gate %s stands in its own region" % g["target"])
	assert_gte(gates, 6)
	# At least four paths leave the estate, each through a gate.
	var out := 0
	for path in CourtHeight.paths():
		var pts: PackedVector2Array = path["points"]
		if MANOR.grow(4.0).has_point(pts[0]) and CourtHeight.own_weight(pts[0].x, pts[0].y) <= 0.0:
			out += 1
	assert_gte(out, 4)


func test_the_autumn_border_is_sealed() -> void:
	# Flood Feyre's reach from the village over the border country.
	var area := Rect2(-1880.0, -1760.0, 1360.0, 960.0)
	var reached := _flood(area, 3.0, [Vector2(-1000.0, -1000.0), Vector2(-560.0, -1300.0), Vector2(-1560.0, -860.0)])
	var leaks := 0
	var first := Vector2.ZERO
	for p: Vector2 in reached:
		if CourtHeight._autumn_depth(p.x, p.y) > 60.0:
			if leaks == 0:
				first = p
			leaks += 1
	assert_eq(leaks, 0, "Feyre can climb into the sealed Autumn hills (first at %s)" % first)


func test_the_court_edge_is_closed() -> void:
	# Strips along the north, east and west edges (the Wall's ends are the
	# human realm's): from the court side, Feyre never gets near the map's edge.
	var strips := [
		[Rect2(-560.0, -2046.0, 2540.0, 460.0), [Vector2(1000.0, -1600.0), Vector2(300.0, -1640.0), Vector2(1500.0, -1640.0)]],
		[Rect2(1480.0, -1700.0, 566.0, 2950.0), [Vector2(1600.0, -1000.0), Vector2(1500.0, 900.0), Vector2(1560.0, -1600.0)]],
		[Rect2(-2046.0, -880.0, 400.0, 2130.0), [Vector2(-1700.0, 0.0), Vector2(-1700.0, 800.0)]],
	]
	for st: Array in strips:
		var reached := _flood(st[0], 3.0, st[1])
		var leaks := 0
		var first := Vector2.ZERO
		for p: Vector2 in reached:
			if p.x < -2006.0 or p.x > 2006.0 or p.y < -2006.0:
				if leaks == 0:
					first = p
				leaks += 1
		assert_eq(leaks, 0, "the court's edge is open (first at %s)" % first)


func test_what_you_see_from_where() -> void:
	for line: Array in CourtHeight.SIGHTLINES:
		var from := _where(line[0])
		var to := _where(line[1])
		var seen := _visible(from, 1.7, to, float(line[2]) + 0.5)
		var name := "%s -> %s" % [str(line[0]), line[1]]
		if line[3]:
			assert_true(seen, "%s should be in view" % name)
		else:
			assert_false(seen, "%s should be hidden (a triangle in the way)" % name)


func test_the_weenies_are_seen_from_the_ways() -> void:
	# Sampled along every path: the North Watchtower is "the landmark seen from
	# most places"; the crowns and the village's tree are seen from a good part
	# of the court; the heart of the blight is stumbled on, not seen from afar.
	var pts: Array[Vector2] = []
	for p in CourtHeight.paths():
		var line: PackedVector2Array = p["points"]
		for i in range(0, line.size(), 15):
			pts.append(line[i])
	var want := {&"north_watchtower": [28.0, 0.5, 1.0], &"ember_crown": [14.0, 0.5, 1.0], &"stone_ring": [14.0, 0.33, 1.0],
		&"great_lantern_tree": [30.0, 0.3, 1.0], &"blight_heart": [20.0, 0.0, 0.15]}
	for id: StringName in want:
		var n := 0
		for p in pts:
			if _visible(p, 1.7, CourtHeight.site(id), want[id][0]):
				n += 1
		var share := float(n) / pts.size()
		assert_between(share, want[id][1], want[id][2], "%s seen from %d%% of the ways" % [id, int(share * 100.0)])


func test_people_and_wayside_spots_stand_on_dry_walkable_ground() -> void:
	# Fixed positions other lanes keep on our ground (the presence roster, the
	# wayside walks) must follow the terrain when it changes.
	var points: Array = []
	var roster := load("res://data/dialogue/presence.tres") as PresenceRoster
	for s in roster.spots:
		if s.room == &"" and CourtHeight.own_weight(s.at.x, s.at.y) > 0.0:
			points.append([String(s.id), s.at, s.wander])
	var dir := DirAccess.open("res://data/wayside")
	for f in dir.get_files():
		if not f.begins_with("manor_") or not f.ends_with(".tres"):
			continue
		var route := load("res://data/wayside/" + f)
		for spot: Resource in route.get(&"spots"):
			var p: Vector3 = spot.get(&"position")
			if CourtHeight.own_weight(p.x, p.z) > 0.0 and spot.get(&"kind") not in [&"pond_faeries", &"stepping_stones", &"crossing"]:
				points.append([String(spot.get(&"id")), Vector2(p.x, p.z), 2.0])
	assert_gt(points.size(), 20)
	for e: Array in points:
		var p: Vector2 = e[1]
		var clear: float = float(e[2]) + 3.0
		assert_lt(_slope(p.x, p.y, 2.0), 24.0, "%s stands on a steep bank" % e[0])
		assert_gt(MacroHeight.distance_to_river(p.x, p.y), CourtHeight.CHANNEL + clear, "%s is in the Thornwater" % e[0])
		assert_false(_in_lake(p), "%s is in a lake" % e[0])


func test_you_cannot_see_the_whole_court_from_one_place() -> void:
	# From every gate and clearing on the ways, at most a third of the court's
	# open ground (sampled every 80 m) is in view.
	var targets: Array[Vector2] = []
	var x := -1760.0
	while x < 1700.0:
		var z := -1700.0
		while z < 1360.0:
			if CourtHeight.own_weight(x, z) >= 1.0:
				targets.append(Vector2(x, z))
			z += 80.0
		x += 80.0
	var spots: Array[Vector2] = []
	for g: Array in CourtHeight.GATES:
		spots.append(Vector2(g[2], g[3]))
	for id in [&"solstice_dance_floor", &"stone_ring", &"brae_top", &"village_green", &"the_mound", &"bee_tower", &"blight_heart"]:
		spots.append(CourtHeight.site(id))
	for p in spots:
		var n := 0
		for t in targets:
			if _visible(p, 1.7, t, 1.0):
				n += 1
		assert_lt(float(n) / targets.size(), 0.34, "from %s you can see %d%% of the court" % [p, int(100.0 * n / targets.size())])


func _where(v: Variant) -> Vector2:
	if v is StringName:
		return CourtHeight.site(v)
	return Vector2(v[0], v[1])


## Line of sight over the height field (4 m steps, the last 6 m excluded so a
## target's own knoll doesn't hide it).
func _visible(from: Vector2, eye: float, to: Vector2, tall: float) -> bool:
	var a := Vector3(from.x, _surface(from) + eye, from.y)
	var b := Vector3(to.x, _surface(to) + tall, to.y)
	var d := Vector2(b.x - a.x, b.z - a.z).length()
	var steps := int(d / 4.0)
	for k in range(1, steps):
		var t := float(k) / steps
		if t * d > d - 8.0:
			break
		var p := a.lerp(b, t)
		if WorldHeight.height_at(p.x, p.z) > p.y:
			return false
	return true


## Ground or, on a lake, its water.
func _surface(p: Vector2) -> float:
	var h := WorldHeight.height_at(p.x, p.y)
	for l in CourtHeight.lakes():
		if p.distance_to(l["center"]) < float(l["radius"]):
			h = maxf(h, float(l["level"]))
	return h


func _in_lake(p: Vector2) -> bool:
	for l in CourtHeight.lakes():
		if p.distance_to(l["center"]) < float(l["radius"]) * 1.1:
			return true
	return false


func _slope(x: float, z: float, step: float) -> float:
	var dx := WorldHeight.height_at(x + step, z) - WorldHeight.height_at(x - step, z)
	var dz := WorldHeight.height_at(x, z + step) - WorldHeight.height_at(x, z - step)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz) / (2.0 * step)))


# --- Feyre's reach on a grid --------------------------------------------------

var _fh := PackedFloat32Array()
var _fw := 0
var _fd := 0
var _farea := Rect2()
var _fstep := 3.0


func _flood(area: Rect2, step: float, seeds: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r in _flood_traced(area, step, seeds, {}):
		out.append(r[0])
	return out


## [position, cell] in reach order; `parent` maps cell -> the cell it was reached from.
func _flood_traced(area: Rect2, step: float, seeds: Array, parent: Dictionary) -> Array:
	_farea = area
	_fstep = step
	_fw = int(area.size.x / step)
	_fd = int(area.size.y / step)
	_fh.resize(_fw * _fd)
	var id := WorkerThreadPool.add_group_task(_flood_row, _fd, -1, true, "flood")
	WorkerThreadPool.wait_for_group_task_completion(id)
	var blocked := PackedByteArray()
	blocked.resize(_fw * _fd)
	for region in CourtMap.region_ids():
		for g in CourtHeight.gates_for(region):
			_block_gate(blocked, g["position"], g["width"], g["yaw_degrees"])
	_block_gate(blocked, Vector2(300.0, -1694.0), 34.0, 0.0)
	var floor_ok := PackedByteArray()
	floor_ok.resize(_fw * _fd)
	var walk := step * tan(deg_to_rad(FLOOR_DEG))
	for iz in range(1, _fd - 1):
		for ix in range(1, _fw - 1):
			var i := iz * _fw + ix
			var gx := (_fh[i + 1] - _fh[i - 1]) * 0.5
			var gz := (_fh[i + _fw] - _fh[i - _fw]) * 0.5
			floor_ok[i] = 1 if sqrt(gx * gx + gz * gz) <= walk else 0
	var seen := PackedByteArray()
	seen.resize(_fw * _fd)
	var queue := PackedInt32Array()
	for s: Vector2 in seeds:
		var i := int((s.y - area.position.y) / step) * _fw + int((s.x - area.position.x) / step)
		queue.append(i)
		seen[i] = 1
	var reach := maxi(1, int(REACH_OUT / step))
	var head := 0
	var out: Array = []
	while head < queue.size():
		var i := queue[head]
		head += 1
		var ix := i % _fw
		var iz := i / _fw
		out.append([Vector2(area.position.x + ix * step, area.position.y + iz * step), i])
		var h := _fh[i]
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				if dx == 0 and dz == 0:
					continue
				var jx := ix + dx
				var jz := iz + dz
				if jx < 1 or jz < 1 or jx >= _fw - 1 or jz >= _fd - 1:
					continue
				var j := jz * _fw + jx
				if seen[j] or blocked[j]:
					continue
				var adjacent := absi(dx) <= 1 and absi(dz) <= 1
				var rise := _fh[j] - h
				var ok := false
				# She can only stand on floor (50 degrees or less): from a floor
				# she walks or jumps onto another floor; anywhere, she can slide
				# or drop down. Steepness is the ground's, not her direction's,
				# so no zig-zag climbs a crag.
				if adjacent and rise < 0.0:
					ok = true
				elif floor_ok[i] and floor_ok[j]:
					ok = rise <= (walk * (1.42 if dx != 0 and dz != 0 else 1.0) if adjacent else REACH_UP)
				if ok:
					seen[j] = 1
					parent[j] = i
					queue.append(j)
	return out


func _flood_row(row: int) -> void:
	var z := _farea.position.y + row * _fstep
	for col in _fw:
		_fh[row * _fw + col] = WorldHeight.height_at(_farea.position.x + col * _fstep, z)


func _block_gate(blocked: PackedByteArray, p: Vector2, width: float, yaw_deg: float) -> void:
	var yaw := deg_to_rad(yaw_deg)
	var across := Vector2(cos(yaw), -sin(yaw))
	var along := Vector2(sin(yaw), cos(yaw))
	var t := -width * 0.5
	while t <= width * 0.5:
		for a in [-1.5, 0.0, 1.5]:
			var q: Vector2 = p + across * t + along * a
			var ix := int((q.x - _farea.position.x) / _fstep)
			var iz := int((q.y - _farea.position.y) / _fstep)
			if ix >= 0 and iz >= 0 and ix < _fw and iz < _fd:
				blocked[iz * _fw + ix] = 1
		t += _fstep * 0.5
