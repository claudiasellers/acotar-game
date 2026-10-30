## The stables (canon: Feyre rides with Tamlin and Lucien): a U-shaped stable
## block round a cobbled yard open to the south. West and east ranges hold
## sixteen stalls; the north range holds the carriage house, the clock tower
## (estate landmark), the tack room and the feed room. A hayloft over the west
## range is reached by a timber ramp in the grooms' room. West of the stables
## the paddock is fenced, with water troughs, jumps and hay.
class_name ManorStables
extends RefCounted

const WALL_H := 6.0
const LOFT_Y := 3.2
const DEPTH := 10.0
const STALL_W := 4.0
const STALLS_PER_RANGE := 8
const TOWER := Rect2(-134.0, -62.0, 8.0, 8.0)
const TOWER_H := 17.0
## Range footprints.
const NORTH := Rect2(-165.0, -62.0, 70.0, DEPTH)
const WEST := Rect2(-165.0, -52.0, DEPTH, 48.0)
const EAST := Rect2(-105.0, -52.0, DEPTH, 48.0)
const PADDOCK_GATE := Vector2(-185.0, -30.0)
const JUMPS := [Vector2(-280, -40), Vector2(-250, 0), Vector2(-220, -55), Vector2(-260, 20)]


static func stall_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for range_rect: Rect2 in [WEST, EAST]:
		for i in STALLS_PER_RANGE:
			out.append(Rect2(range_rect.position.x, range_rect.position.y + i * STALL_W, DEPTH, STALL_W))
	return out


static func clock_top() -> Vector3:
	var c := TOWER.get_center()
	return Vector3(c.x, ManorGrounds.ground(c.x, c.y) + TOWER_H + 5.5, c.y)


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("stables_plant")
	# owl feathers in the hayloft (a barn owl roosts there)
	for i in 6:
		var p := Vector3(rng.randf_range(WEST.position.x + 1.5, WEST.end.x - 1.5), 0.0, rng.randf_range(WEST.position.y + 2.0, -16.0))
		p.y = ManorGrounds.ground(WEST.get_center().x, WEST.get_center().y) + LOFT_Y + 0.12
		sb.put_at(&"ing_owl_feather", p, rng.randf() * TAU)
	sb.put_at(&"col_tiny_horseshoe", Vector3(WEST.get_center().x, ManorGrounds.ground(WEST.get_center().x, WEST.get_center().y) + LOFT_Y + 0.12, -40.0), 0.0)
	# wisteria on the yard walls, honeysuckle on the paddock fence
	for z: float in [-48.0, -36.0, -24.0, -12.0]:
		sb.put(&"ing_wisteria", WEST.end.x + 0.9, z + 2.0, 0.0, 0.8)
		sb.put(&"ing_wisteria", EAST.position.x - 0.9, z + 2.0, 0.0, 0.8)
	var p := ManorSitePlan.PADDOCK
	var x := p.position.x + 3.0
	while x < p.end.x:
		if rng.randf() < 0.5:
			sb.put(&"ing_honeysuckle", x, p.end.y + 0.8, rng.randf() * TAU, 0.8)
		x += 6.0


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "Stables")
	var s := ManorSitePlan.STABLES
	var y := ManorGrounds.ground(s.get_center().x, s.get_center().y)
	# cobbled yard
	b.box(Vector3(-130.0, y + 0.03, -26.0), Vector3(50.0, 0.06, 52.0), EstateKit.mat(Color(0.96, 0.84, 0.80), 0.9, 0.0, "cobbles"), false)
	_range(b, WEST, "e", y)
	_range(b, EAST, "w", y)
	_range(b, NORTH, "s", y)
	_stall_dressing(b, y)
	_north_rooms(b, y)
	_hayloft(b, y)
	_clock_tower(b, y)
	# yard: trough, horse statue, mounting block, hay, cart, lamps
	b.prop(&"horse_statue", Vector3(-130.0, y + 0.06, -26.0))
	b.prop(&"water_trough", Vector3(-118.0, y + 0.06, -40.0), PI * 0.5)
	b.prop(&"water_trough", Vector3(-142.0, y + 0.06, -40.0), PI * 0.5)
	b.box(Vector3(-140.0, y + 0.3, -10.0), Vector3(1.2, 0.6, 1.2), ManorGrounds.stone())
	b.prop(&"cart_flower", Vector3(-118.0, y + 0.06, -12.0), -0.4)
	for p: Vector2 in [Vector2(-145, -30), Vector2(-115, -24)]:
		b.prop(&"hay_bale", Vector3(p.x, y + 0.06, p.y))
		b.prop(&"hay_bale", Vector3(p.x, y + 0.66, p.y), 0.3)
	for p: Vector2 in [Vector2(-150, -4), Vector2(-110, -4), Vector2(-150, -50), Vector2(-110, -50)]:
		ManorGrounds.lamp(b, p.x, p.y)
	b.drape_path(PackedVector2Array([Vector2(-130.0, 0.0), Vector2(-100.0, 18.0), Vector2(-26.0, 4.0)]), 4.0, ManorGrounds.gravel())
	_paddock(b)
	b.flush()
	var stalls := Node3D.new()
	stalls.name = "Stalls"
	b.root.add_child(stalls)
	var i := 0
	for r in stall_rects():
		var m := Marker3D.new()
		m.name = "Stall_%d" % i
		m.position = Vector3(r.get_center().x, y, r.get_center().y)
		m.add_to_group(&"manor_stall")
		stalls.add_child(m)
		i += 1
	var tower := Node3D.new()
	tower.name = "ClockTower"
	tower.position = clock_top()
	b.root.add_child(tower)
	ManorGrounds.landmark(tower, "stable_clock_tower")
	for room in [["TackRoom", Vector2(-119.0, -57.0)], ["FeedRoom", Vector2(-103.5, -57.0)], ["CarriageHouse", Vector2(-150.0, -57.0)], ["Hayloft", Vector2(-160.0, -30.0)]]:
		var m := Marker3D.new()
		m.name = room[0]
		var p: Vector2 = room[1]
		m.position = Vector3(p.x, y + (LOFT_Y if room[0] == "Hayloft" else 0.0), p.y)
		b.root.add_child(m)


## One range: walls with a door per bay on the yard side, gable roof.
static func _range(b: GroundsBatch, r: Rect2, open_side: String, y: float) -> void:
	var wall := ManorGrounds.plaster()
	var trim := ManorGrounds.wood_dark()
	var t := 0.45
	var base := y - 0.5
	var h := WALL_H + 0.5
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var sides := {
		"n": [Vector2(x0, z0), Vector2(x1, z0)], "s": [Vector2(x0, z1), Vector2(x1, z1)],
		"w": [Vector2(x0, z0), Vector2(x0, z1)], "e": [Vector2(x1, z0), Vector2(x1, z1)],
	}
	for side: String in sides:
		var a: Vector2 = sides[side][0]
		var c: Vector2 = sides[side][1]
		if side != open_side:
			# the north range's south wall is shared with nothing; the side ranges' north ends meet the north range
			b.span(Vector3(a.x, base, a.y), Vector3(c.x, base, c.y), t, h, wall)
			continue
		var length := a.distance_to(c)
		var dir := (c - a) / length
		var bay := STALL_W if r != NORTH else length / 7.0
		var n := roundi(length / bay)
		for k in n:
			var p0 := a + dir * length * k / n
			var p1 := a + dir * length * (k + 1) / n
			var door := 2.2 if r != NORTH else 3.2
			var seg := p0.distance_to(p1)
			var piece := (seg - door) * 0.5
			var q0 := p0 + dir * piece
			var q1 := p1 - dir * piece
			b.span(Vector3(p0.x, base, p0.y), Vector3(q0.x, base, q0.y), t, h, wall)
			b.span(Vector3(q1.x, base, q1.y), Vector3(p1.x, base, p1.y), t, h, wall)
			b.span(Vector3(q0.x, y + 2.8, q0.y), Vector3(q1.x, y + 2.8, q1.y), t, WALL_H - 2.8, wall)
			b.span(Vector3(q0.x, y + 2.7, q0.y), Vector3(q1.x, y + 2.7, q1.y), t + 0.1, 0.18, trim, false)
	# timber frame accents and roof
	var c2 := r.get_center()
	b.box(Vector3(c2.x, y + WALL_H - 0.1, c2.y), Vector3(r.size.x + 0.4, 0.22, r.size.y + 0.4), trim, false)
	var along_x := r.size.x > r.size.y
	if along_x:
		b.gable(Vector3(c2.x, y + WALL_H, c2.y), Vector3(r.size.x + 1.0, 3.2, r.size.y + 1.2), ManorGrounds.roof())
	else:
		b.gable(Vector3(c2.x, y + WALL_H, c2.y), Vector3(r.size.y + 1.0, 3.2, r.size.x + 1.2), ManorGrounds.roof(), PI * 0.5)
	b.box(Vector3(c2.x, y + 0.05, c2.y), Vector3(r.size.x - 0.5, 0.1, r.size.y - 0.5), EstateKit.mat(Color(1.0, 0.88, 0.6), 0.95, 0.0, "straw_floor"), true)


static func _stall_dressing(b: GroundsBatch, y: float) -> void:
	for range_rect: Rect2 in [WEST, EAST]:
		var back_x: float = range_rect.position.x + 0.8 if range_rect == WEST else range_rect.end.x - 0.8
		var front_dir := 1.0 if range_rect == WEST else -1.0
		for i in STALLS_PER_RANGE + 1:
			var z: float = range_rect.position.y + i * STALL_W
			# partition between stalls (and the grooms' room beyond the last stall)
			b.prop(&"stall_divider", Vector3(range_rect.get_center().x - front_dir * 1.2, y + 0.1, z))
		for i in STALLS_PER_RANGE:
			var zc: float = range_rect.position.y + (i + 0.5) * STALL_W
			b.prop(&"feed_bin", Vector3(back_x + front_dir * 0.4, y + 0.1, zc - 1.0), PI * 0.5 * front_dir)
			b.prop(&"hay_pile", Vector3(back_x + front_dir * 1.6, y + 0.1, zc + 0.6), 0.0, 0.6)
	# grooms' rooms at the south ends: tack wall and bench
	for range_rect: Rect2 in [WEST, EAST]:
		var gz: float = range_rect.position.y + STALLS_PER_RANGE * STALL_W + 8.0
		b.prop(&"saddle_rack", Vector3(range_rect.get_center().x + (2.5 if range_rect == EAST else -2.5), y + 0.1, gz + 4.0))


static func _north_rooms(b: GroundsBatch, y: float) -> void:
	var wall := ManorGrounds.plaster()
	# partitions: carriage house | tower | tack room | feed room
	for x: float in [TOWER.position.x, TOWER.end.x, -112.0]:
		b.span(Vector3(x, y - 0.5, NORTH.position.y), Vector3(x, y - 0.5, NORTH.end.y), 0.35, WALL_H + 0.5, wall)
	b.prop(&"carriage_gilt", Vector3(-152.0, y + 0.1, -57.0), PI * 0.5)
	b.prop(&"carriage_gilt", Vector3(-143.0, y + 0.1, -57.0), PI * 0.5)
	b.prop(&"tack_wall", Vector3(-119.0, y + 0.1, NORTH.position.y + 0.4), 0.0)
	b.prop(&"saddle_rack", Vector3(-122.0, y + 0.1, -57.5), 0.0)
	b.prop(&"saddle_rack", Vector3(-116.0, y + 0.1, -57.5), 0.0)
	b.prop(&"chest_trunk", Vector3(-119.0, y + 0.1, -55.0), 0.0)
	for k in 3:
		b.prop(&"feed_bin", Vector3(-108.0 + k * 3.5, y + 0.1, NORTH.position.y + 1.0))
		b.prop(&"sack_flour", Vector3(-108.0 + k * 3.5, y + 0.1, -56.0))
	b.prop(&"barrel", Vector3(-98.0, y + 0.1, -55.0))


static func _hayloft(b: GroundsBatch, y: float) -> void:
	var wood := ManorGrounds.wood()
	var loft_end := -14.0
	var loft := Rect2(WEST.position.x + 0.3, WEST.position.y + 0.3, WEST.size.x - 0.6, loft_end - WEST.position.y - 0.3)
	var c := loft.get_center()
	b.box(Vector3(c.x, y + LOFT_Y - 0.1, c.y), Vector3(loft.size.x, 0.2, loft.size.y), wood)
	for i in 6:
		var z := loft.position.y + 2.0 + i * (loft.size.y - 4.0) / 5.0
		b.box(Vector3(c.x, y + LOFT_Y * 0.5, z), Vector3(0.25, LOFT_Y, 0.25), ManorGrounds.wood_dark(), true)
	# loft railing along its open south edge (beside the ramp)
	b.box(Vector3(c.x + 1.8, y + LOFT_Y + 0.5, loft_end), Vector3(loft.size.x - 3.6, 1.0, 0.12), ManorGrounds.wood_dark(), true)
	# the ramp: from the grooms' room floor up to the loft edge
	var rx := WEST.position.x + 1.8
	b.ramp(Vector3(rx, y, loft_end + 8.6), 2.4, 8.6, LOFT_Y, 0.0, wood)
	for k in 10:
		var z := loft_end + 8.6 - (k + 0.5) * 0.86
		b.box(Vector3(rx, y + LOFT_Y * (k + 0.5) / 10.0 + 0.05, z), Vector3(2.4, 0.05, 0.12), ManorGrounds.wood_dark(), false)
	# hay up there
	var ly := y + LOFT_Y
	for k in 5:
		b.prop(&"hay_bale", Vector3(WEST.position.x + 2.0, ly, -48.0 + k * 1.2))
		b.prop(&"hay_bale", Vector3(WEST.position.x + 2.0, ly + 0.6, -47.5 + k * 1.2), 0.1)
	b.prop(&"hay_pile", Vector3(c.x + 1.0, ly, -30.0))
	b.prop(&"hay_pile", Vector3(c.x, ly, -22.0), 0.6)
	# hoist beam over the loft door on the yard side
	b.box(Vector3(WEST.end.x + 0.8, y + WALL_H - 0.5, -30.0), Vector3(2.0, 0.25, 0.25), ManorGrounds.wood_dark(), false)


static func _clock_tower(b: GroundsBatch, y: float) -> void:
	var c := TOWER.get_center()
	var base := Vector3(c.x, y, c.y)
	var w := TOWER.size.x
	var wall := ManorGrounds.plaster()
	b.box(base + Vector3.UP * (TOWER_H * 0.5 - 0.5), Vector3(w, TOWER_H + 1.0, w), wall)
	for k: float in [WALL_H, TOWER_H - 4.0, TOWER_H]:
		b.box(base + Vector3.UP * k, Vector3(w + 0.5, 0.35, w + 0.5), ManorGrounds.marble(), false)
	# clock faces on all four sides
	for i in 4:
		var a := TAU * i / 4.0
		var dir := Vector3(sin(a), 0, cos(a))
		var face := base + Vector3.UP * (TOWER_H - 2.0) + dir * (w * 0.5 + 0.06)
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5)
		b.add_mesh(_disc_mesh(1.9), Transform3D(basis, face), ManorGrounds.pearl())
		b.torus(face + dir * 0.02, 1.8, 2.05, ManorGrounds.gold(), basis)
		b.box(face + dir * 0.08 + Vector3.UP * 0.55, Vector3(0.12, 1.1, 0.05), ManorGrounds.gold(), false, a)
		b.box(face + dir * 0.1 + Vector3(0.35, 0, 0).rotated(Vector3.UP, a), Vector3(0.8, 0.1, 0.05), ManorGrounds.gold(), false, a)
	# open belfry, then a gilt cupola and weather vane
	var bt := base + Vector3.UP * TOWER_H
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(bt + Vector3(sx * (w * 0.5 - 0.5), 1.6, sz * (w * 0.5 - 0.5)), Vector3(0.8, 3.2, 0.8), wall, false)
	b.box(bt + Vector3.UP * 3.35, Vector3(w + 0.3, 0.3, w + 0.3), ManorGrounds.marble(), false)
	b.cylinder(bt + Vector3.UP * 3.5, w * 0.48, 0.6, ManorGrounds.roof(), false, 8)
	b.cone(bt + Vector3.UP * 4.1, w * 0.5, 3.0, ManorGrounds.gold(), 8)
	b.sphere(bt + Vector3.UP * 7.2, 0.3, ManorGrounds.gold())
	b.box(bt + Vector3.UP * 7.7, Vector3(1.2, 0.08, 0.3), ManorGrounds.gold(), false)
	b.sphere(bt + Vector3.UP * 1.4, 0.7, ManorGrounds.gold(), 1.2)    # the bell


static func _disc_mesh(r: float) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.06
	m.radial_segments = 24
	m.rings = 1
	return m


static func _paddock(b: GroundsBatch) -> void:
	var p := ManorSitePlan.PADDOCK
	var pts := PackedVector2Array([p.position, Vector2(p.end.x, p.position.y), p.end, Vector2(p.position.x, p.end.y), p.position])
	ManorGrounds.fence(b, pts, 3.0, 1.3, ManorGrounds.pearl(), ManorGrounds.pearl(), [PADDOCK_GATE])
	b.drape_path(PackedVector2Array([Vector2(-165.0, -30.0), PADDOCK_GATE]), 3.0, ManorGrounds.gravel())
	b.prop_on_ground(&"water_trough", -200.0, -20.0, PI * 0.5)
	b.prop_on_ground(&"water_trough", -290.0, 25.0)
	for i in JUMPS.size():
		var j: Vector2 = JUMPS[i]
		var yaw := i * 0.7
		var dir := Vector2(cos(yaw), -sin(yaw))
		for side: float in [-1.0, 1.0]:
			var q := j + dir * side * 1.8
			var qy := ManorGrounds.ground(q.x, q.y)
			b.box(Vector3(q.x, qy + 0.6, q.y), Vector3(0.3, 1.2, 0.3), ManorGrounds.pearl())
		var jy := ManorGrounds.ground(j.x, j.y)
		for h: float in [0.45, 0.85]:
			b.box(Vector3(j.x, jy + h, j.y), Vector3(3.6, 0.12, 0.12), EstateKit.mat(EstateKit.ROSE if h > 0.5 else EstateKit.PEARL, 0.5), false, yaw)
		b.add_box_shape(Transform3D(Basis(Vector3.UP, yaw), Vector3(j.x, jy + 0.5, j.y)), Vector3(3.6, 1.0, 0.25))
	for q: Vector2 in [Vector2(-300, -80), Vector2(-195, 30), Vector2(-240, -85)]:
		b.prop_on_ground(&"hay_pile", q.x, q.y)
