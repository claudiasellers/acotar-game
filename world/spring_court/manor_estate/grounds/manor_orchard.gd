## The walled orchard: 3 m blush brick walls with pearl coping and buttresses,
## two gated arches (east toward the house, north toward the paddock), 64
## blossom and fruit trees in rows either side of a cross walk, a sundial at the
## crossing, benches, and a row of beehives along the south wall.
class_name ManorOrchard
extends RefCounted

const WALL_H := 3.0
const WALL_T := 0.8
const GATE_W := 4.0
const COLS := [-292.0, -280.0, -268.0, -256.0, -229.0, -217.0, -205.0, -193.0]
const ROWS := [103.0, 115.0, 127.0, 139.0, 166.0, 178.0, 190.0, 202.0]
const SPECIES := [&"deco_cherry_blossom", &"deco_apple_blossom", &"deco_pear_tree"]
const UNDER := {&"deco_cherry_blossom": &"ing_cherry_blossom", &"deco_apple_blossom": &"ing_crab_apple", &"deco_pear_tree": &"ing_manor_fruit"}
const CROSS := Vector2(-242.5, 152.5)


static func gates() -> Array[Vector2]:
	var r := ManorSitePlan.WALLED_ORCHARD
	return [Vector2(r.end.x, CROSS.y), Vector2(CROSS.x, r.position.y)]


static func hives() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in 6:
		out.append(Vector2(-288.0 + i * 4.0, ManorSitePlan.WALLED_ORCHARD.end.y - 2.2))
	return out


## [position, species layer] for every tree (test: >= 48).
static func trees() -> Array:
	var out := []
	for j in ROWS.size():
		for i in COLS.size():
			out.append([Vector2(COLS[i], ROWS[j]), SPECIES[(i + j) % SPECIES.size()]])
	return out


static func footprints() -> Array[Rect2]:
	var r := ManorSitePlan.WALLED_ORCHARD
	var t := WALL_T + 0.6
	return [Rect2(r.position.x - t * 0.5, r.position.y - t * 0.5, r.size.x + t, t), Rect2(r.position.x - t * 0.5, r.end.y - t * 0.5, r.size.x + t, t),
			Rect2(r.position.x - t * 0.5, r.position.y, t, r.size.y), Rect2(r.end.x - t * 0.5, r.position.y, t, r.size.y)]


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("orchard_plant")
	for t in trees():
		var p: Vector2 = t[0]
		sb.put(t[1], p.x + rng.randf_range(-0.4, 0.4), p.y + rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(0.9, 1.1))
		if rng.randf() < 0.8:
			sb.put(UNDER[t[1]], p.x + rng.randf_range(-2.5, 2.5), p.y + rng.randf_range(-2.5, 2.5), rng.randf() * TAU)
		sb.put(&"deco_daisy", p.x + rng.randf_range(-3, 3), p.y + rng.randf_range(-3, 3), rng.randf() * TAU)
	for h in hives():
		sb.put(&"ing_honey", h.x + 1.0, h.y - 1.0, rng.randf() * TAU)
	# wisteria trained on the inside of the walls
	var r := ManorSitePlan.WALLED_ORCHARD
	for i in 24:
		var t := (i + 0.5) / 24.0
		var side := i % 4
		var p: Vector2
		match side:
			0: p = Vector2(lerpf(r.position.x + 3, r.end.x - 3, t), r.position.y + 1.2)
			1: p = Vector2(lerpf(r.position.x + 3, r.end.x - 3, t), r.end.y - 1.2)
			2: p = Vector2(r.position.x + 1.2, lerpf(r.position.y + 3, r.end.y - 3, t))
			_: p = Vector2(r.end.x - 1.2, lerpf(r.position.y + 3, r.end.y - 3, t))
		var near_gate := false
		for g in gates():
			if p.distance_to(g) < GATE_W:
				near_gate = true
		if not near_gate:
			sb.put(&"ing_wisteria", p.x, p.y, rng.randf() * TAU, 0.9)


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "WalledOrchard")
	var r := ManorSitePlan.WALLED_ORCHARD
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		_wall(b, corners[i], corners[(i + 1) % 4])
	for g in gates():
		_arch(b, g, absf(g.x - r.end.x) < 0.1)
	# cross walks, sundial, benches
	b.drape_path(PackedVector2Array([Vector2(r.position.x + 1.0, CROSS.y), Vector2(r.end.x + 6.0, CROSS.y)]), 3.0, ManorGrounds.gravel())
	b.drape_path(PackedVector2Array([Vector2(CROSS.x, r.position.y - 6.0), Vector2(CROSS.x, r.end.y - 1.0)]), 3.0, ManorGrounds.gravel())
	b.prop_on_ground(&"sundial", CROSS.x, CROSS.y)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		b.prop_on_ground(&"garden_bench", CROSS.x + cos(a) * 5.0, CROSS.y + sin(a) * 5.0, -a - PI * 0.5)
	# beehives: white and butter skeps on stands
	for h in hives():
		var y := ManorGrounds.ground(h.x, h.y)
		b.box(Vector3(h.x, y + 0.25, h.y), Vector3(0.8, 0.5, 0.8), ManorGrounds.wood())
		b.sphere(Vector3(h.x, y + 0.9, h.y), 0.45, EstateKit.mat(Color(1.0, 0.86, 0.5), 0.8, 0.0, "skep"), 0.9)
		b.torus(Vector3(h.x, y + 0.75, h.y), 0.36, 0.48, EstateKit.mat(Color(0.95, 0.76, 0.4), 0.8, 0.0, "skep_band"))
	b.prop_on_ground(&"cart_flower", -200.0, 108.0, 0.6)
	for p: Vector2 in [Vector2(-296, 99), Vector2(-189, 99), Vector2(-296, 206), Vector2(-189, 206)]:
		ManorGrounds.lamp(b, p.x, p.y)
	b.flush()
	b.root.set_meta(&"tree_count", trees().size())


static func _wall(b: GroundsBatch, a: Vector2, c: Vector2) -> void:
	var brick := ManorGrounds.brick()
	var cap := ManorGrounds.marble()
	var length := a.distance_to(c)
	var dir := (c - a) / length
	var gate_t := -1.0
	for g in gates():
		var t := (g - a).dot(dir)
		if t > 0.0 and t < length and (a + dir * t).distance_to(g) < 0.5:
			gate_t = t
	var n := ceili(length / 10.0)
	for k in n:
		var t0 := length * k / n
		var t1 := length * (k + 1) / n
		var pieces := [[t0, t1]]
		if gate_t >= 0.0 and t1 > gate_t - GATE_W * 0.5 and t0 < gate_t + GATE_W * 0.5:
			pieces = []
			if t0 < gate_t - GATE_W * 0.5:
				pieces.append([t0, gate_t - GATE_W * 0.5])
			if t1 > gate_t + GATE_W * 0.5:
				pieces.append([gate_t + GATE_W * 0.5, t1])
		for pc in pieces:
			var p0: Vector2 = a + dir * pc[0]
			var p1: Vector2 = a + dir * pc[1]
			var m := (p0 + p1) * 0.5
			var y := ManorGrounds.ground(m.x, m.y)
			b.span(Vector3(p0.x, y - 0.6, p0.y), Vector3(p1.x, y - 0.6, p1.y), WALL_T, WALL_H + 0.6, brick)
			b.span(Vector3(p0.x, y + WALL_H, p0.y), Vector3(p1.x, y + WALL_H, p1.y), WALL_T + 0.2, 0.18, cap, false)
		# buttress pier at each segment start
		var pp := a + dir * t0
		var py := ManorGrounds.ground(pp.x, pp.y)
		if gate_t < 0.0 or absf(t0 - gate_t) > GATE_W:
			b.box(Vector3(pp.x, py + WALL_H * 0.5, pp.y), Vector3(1.2, WALL_H + 0.3, 1.2), brick)
			b.box(Vector3(pp.x, py + WALL_H + 0.3, pp.y), Vector3(1.4, 0.2, 1.4), cap, false)


static func _arch(b: GroundsBatch, g: Vector2, east: bool) -> void:
	var y := ManorGrounds.ground(g.x, g.y)
	var along := Vector2(0, 1) if east else Vector2(1, 0)
	for side: float in [-1.0, 1.0]:
		var p := g + along * side * (GATE_W * 0.5 + 0.5)
		b.box(Vector3(p.x, y + 2.0, p.y), Vector3(1.2, 4.0, 1.2), ManorGrounds.stone())
		b.sphere(Vector3(p.x, y + 4.4, p.y), 0.4, ManorGrounds.gold())
		# gate leaves stand open against the inside of the wall
		var inward := Vector2(-1, 0) if east else Vector2(0, 1)
		var q := g + along * side * (GATE_W * 0.5 + 1.1) + inward * 0.75
		b.prop(&"gate_iron_gilt", Vector3(q.x, y, q.y), (PI * 0.5 if east else 0.0), 0.5)
	var basis := Basis(Vector3.UP, PI * 0.5 if east else 0.0) * Basis(Vector3.RIGHT, PI * 0.5)
	b.torus(Vector3(g.x, y + 4.0, g.y), GATE_W * 0.5 + 0.1, GATE_W * 0.5 + 0.6, ManorGrounds.stone(), basis)
	b.box(Vector3(g.x, y + 0.03, g.y), Vector3(GATE_W, 0.06, GATE_W) , ManorGrounds.marble(), false)
