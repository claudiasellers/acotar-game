## The forecourt's grand tiered fountain, the drive south to the Border Woods
## road lined with an avenue of blossom trees, and the sentry gate across the
## drive (RegionGate "manor_grounds": gilt iron gates on stone piers, flanked by
## thorn-rose hedges and two little sentry lodges).
class_name ManorForecourt
extends RefCounted

const FOUNTAIN_RADIUS := 7.0
const AVENUE_X := 10.5
const AVENUE_STEP := 15.0
const HEDGE_HALF_LENGTH := 75.0
const PIER_X := 5.4


static func footprints() -> Array[Rect2]:
	var g := ManorSitePlan.SENTRY_GATE
	return [
		ManorGrounds.circle_rect(ManorSitePlan.FORECOURT_CENTER, FOUNTAIN_RADIUS + 1.0),
		Rect2(g.x - HEDGE_HALF_LENGTH - 1.0, g.y - 14.0, HEDGE_HALF_LENGTH * 2.0 + 2.0, 16.0),
	]


static func avenue_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	var z := ManorSitePlan.DRIVE_START.y + 16.0
	while z < ManorSitePlan.SENTRY_GATE.y - 16.0:
		out.append(Vector2(-AVENUE_X, z))
		out.append(Vector2(AVENUE_X, z))
		z += AVENUE_STEP
	return out


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("forecourt_plant")
	for p in avenue_positions():
		sb.put(&"deco_cherry_blossom", p.x, p.y, rng.randf() * TAU, rng.randf_range(0.95, 1.1))
		for k in 2:
			sb.put(&"ing_cherry_blossom", p.x + rng.randf_range(-2.5, 2.5), p.y + rng.randf_range(-2.5, 2.5), rng.randf() * TAU)
		# tulips and daisies at the tree feet, toward the lawns
		var out_x := p.x + signf(p.x) * 3.0
		sb.put(&"deco_tulip_bed", out_x, p.y + rng.randf_range(-3, 3), rng.randf() * TAU)
	# thorn-rose hedges: climbing roses and honeysuckle along the sentry hedges
	var g := ManorSitePlan.SENTRY_GATE
	var x := PIER_X + 9.0
	while x < HEDGE_HALF_LENGTH:
		for side: float in [-1.0, 1.0]:
			sb.put(&"deco_rose_climbing", side * x, g.y - 1.0, rng.randf() * TAU, rng.randf_range(0.8, 1.0))
			if rng.randf() < 0.45:
				sb.put(&"ing_honeysuckle", side * (x + 2.0), g.y - 1.6, rng.randf() * TAU)
			if rng.randf() < 0.35:
				sb.put(&"ing_rose_red", side * (x + 1.0), g.y - 1.8, rng.randf() * TAU, 0.9)
		x += 4.0
	# forecourt rose tubs: white roses round the fountain
	for i in 12:
		var a := TAU * i / 12.0 + 0.13
		sb.put(&"ing_rose_white", cos(a) * (FOUNTAIN_RADIUS + 2.2), sin(a) * (FOUNTAIN_RADIUS + 2.2), a, 0.8)


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "Forecourt")
	_fountain(b)
	_drive(b)
	_lamps(b)
	b.flush()
	_sentry_gate(parent)


static func _fountain(b: GroundsBatch) -> void:
	var c := ManorSitePlan.FORECOURT_CENTER
	var y := ManorGrounds.ground(c.x, c.y)
	var marble := ManorGrounds.marble()
	var gold := ManorGrounds.gold()
	var water := ManorGrounds.water()
	var base := Vector3(c.x, y, c.y)
	# octagonal outer basin: curb ring of 16 blocks
	for i in 16:
		var a := TAU * i / 16.0
		var p := base + Vector3(cos(a), 0, sin(a)) * FOUNTAIN_RADIUS
		b.box(p + Vector3.UP * 0.4, Vector3(2.9, 0.8, 0.7), marble, true, -a + PI * 0.5)
	b.cylinder(base + Vector3.UP * 0.02, FOUNTAIN_RADIUS - 0.3, 0.2, EstateKit.mat(EstateKit.PERIWINKLE, 0.4), false, 24)
	b.disc(base + Vector3.UP * 0.6, Vector2.ONE * (FOUNTAIN_RADIUS - 0.25), water)
	# tiers
	b.cylinder(base, 1.4, 2.2, marble, true, 16, 1.0)
	b.cylinder(base + Vector3.UP * 2.2, 1.0, 0.25, marble, false, 16, 3.6)
	b.cylinder(base + Vector3.UP * 2.45, 3.6, 0.35, marble, false, 24)
	b.disc(base + Vector3.UP * 2.75, Vector2.ONE * 3.4, water, 32)
	b.cylinder(base + Vector3.UP * 2.8, 0.6, 1.6, marble, false, 12, 0.45)
	b.cylinder(base + Vector3.UP * 4.4, 0.5, 0.2, marble, false, 12, 1.9)
	b.cylinder(base + Vector3.UP * 4.6, 1.9, 0.25, marble, false, 20)
	b.disc(base + Vector3.UP * 4.82, Vector2.ONE * 1.75, water, 24)
	b.cylinder(base + Vector3.UP * 4.85, 0.3, 1.0, marble, false, 10, 0.22)
	b.sphere(base + Vector3.UP * 6.05, 0.32, gold)
	b.cone(base + Vector3.UP * 6.3, 0.12, 0.7, gold, 8)
	# gold rims
	b.torus(base + Vector3.UP * 2.8, 3.45, 3.65, gold)
	b.torus(base + Vector3.UP * 4.85, 1.8, 1.95, gold)
	# four rose-pink swans... urns of roses on the curb
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		b.prop(&"garden_urn", base + Vector3(cos(a), 0, sin(a)) * FOUNTAIN_RADIUS + Vector3.UP * 0.8, a)


static func _drive(b: GroundsBatch) -> void:
	var s := ManorSitePlan.DRIVE_START
	var e := ManorSitePlan.DRIVE_END
	b.drape_path(PackedVector2Array([s, e]), ManorSitePlan.DRIVE_WIDTH, ManorGrounds.gravel(), 0.04, 3.0)
	# forecourt ring of gravel round the fountain
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a), sin(a)) * (ManorSitePlan.FORECOURT_RADIUS - 6.0))
	b.drape_path(pts, 10.0, ManorGrounds.gravel(), 0.035, 3.0)
	# pearl kerbs along the drive
	var z := s.y + 4.0
	while z < e.y - 4.0:
		for side: float in [-1.0, 1.0]:
			var x: float = side * (ManorSitePlan.DRIVE_WIDTH * 0.5 + 0.15)
			var y0 := ManorGrounds.ground(x, z)
			var y1 := ManorGrounds.ground(x, z + 6.0)
			var pitch := atan2(y1 - y0, 6.0)
			b.box(Vector3(x, (y0 + y1) * 0.5 + 0.08, z + 3.0), Vector3(0.3, 0.22, 6.0), ManorGrounds.pearl(), false, 0.0, Basis(Vector3.RIGHT, -pitch))
		z += 6.0


static func _lamps(b: GroundsBatch) -> void:
	for i in 8:
		var a := TAU * i / 8.0 + TAU / 16.0
		var p := Vector2(cos(a), sin(a)) * (ManorSitePlan.FORECOURT_RADIUS - 0.8)
		ManorGrounds.lamp(b, p.x, p.y)
		if i % 2 == 0:
			b.prop_on_ground(&"garden_bench", p.x * 0.86, p.y * 0.86, -a - PI * 0.5)
	var z := ManorSitePlan.DRIVE_START.y + 23.5
	while z < ManorSitePlan.SENTRY_GATE.y - 10.0:
		ManorGrounds.lamp(b, -ManorSitePlan.DRIVE_WIDTH * 0.5 - 1.2, z)
		ManorGrounds.lamp(b, ManorSitePlan.DRIVE_WIDTH * 0.5 + 1.2, z)
		z += 30.0


static func _sentry_gate(parent: Node3D) -> void:
	var g := ManorSitePlan.SENTRY_GATE
	var b := GroundsBatch.new(parent, "SentryGate")
	var stone := ManorGrounds.stone()
	var marble := ManorGrounds.marble()
	var gold := ManorGrounds.gold()
	# piers: inner pair carries the gates, outer pair carries the hedges
	for side: float in [-1.0, 1.0]:
		for px: float in [PIER_X, PIER_X + 8.0]:
			var x: float = side * px
			var y := ManorGrounds.ground(x, g.y)
			b.box(Vector3(x, y + 2.4, g.y), Vector3(1.5, 4.8, 1.5), stone)
			b.box(Vector3(x, y + 4.95, g.y), Vector3(1.8, 0.3, 1.8), marble, false)
			b.sphere(Vector3(x, y + 5.5, g.y), 0.5, gold)
			b.cone(Vector3(x, y + 5.9, g.y), 0.15, 0.8, gold, 8)
		# railing between inner and outer piers: low wall + gilt railings
		var xa: float = side * (PIER_X + 0.75)
		var xb: float = side * (PIER_X + 7.25)
		var ym := ManorGrounds.ground((xa + xb) * 0.5, g.y)
		b.box(Vector3((xa + xb) * 0.5, ym + 0.45, g.y), Vector3(absf(xb - xa), 0.9, 0.8), stone)
		for k in 12:
			var x2: float = lerpf(xa, xb, (k + 0.5) / 12.0)
			b.box(Vector3(x2, ym + 1.9, g.y), Vector3(0.06, 2.0, 0.06), ManorGrounds.iron_gold(), false)
		b.add_box_shape(Transform3D(Basis(), Vector3((xa + xb) * 0.5, ym + 1.9, g.y)), Vector3(absf(xb - xa), 2.0, 0.2))
		# thorn-rose hedge from the outer pier outwards
		var hx0: float = side * (PIER_X + 8.75)
		var hx1: float = side * HEDGE_HALF_LENGTH
		var n := 10
		for k in n:
			var xa2: float = lerpf(hx0, hx1, float(k) / n)
			var xb2: float = lerpf(hx0, hx1, float(k + 1) / n)
			var yh := ManorGrounds.ground((xa2 + xb2) * 0.5, g.y)
			b.box(Vector3((xa2 + xb2) * 0.5, yh + 1.1, g.y), Vector3(absf(xb2 - xa2) + 0.2, 3.0, 1.8), ManorGrounds.hedge())
		# sentry lodge inside the gate
		var lodge := Rect2(side * 18.0 - 2.5, g.y - 12.0, 5.0, 5.0)
		ManorGrounds.cottage(b, lodge, 3.0, ManorGrounds.plaster(), ManorGrounds.rose_roof(), "e" if side < 0 else "w", 1.4)
		ManorGrounds.lamp(b, side * (PIER_X + 1.6), g.y - 2.0)
	b.flush()
	# the lock itself: two gilt gate leaves, solid while manor_grounds is locked
	var gate := RegionGate.new()
	gate.name = "Gate_manor_grounds"
	gate.region_id = ManorSitePlan.REGION_GROUNDS
	parent.add_child(gate)
	var leaves := GroundsBatch.new(gate, "Leaves")
	var y0 := ManorGrounds.ground(0.0, g.y)
	var w := PIER_X * 2.0 - 1.5
	var iron := ManorGrounds.iron_gold()
	for k in 25:
		var x := -w * 0.5 + (k + 0.5) * w / 25.0
		var h := 3.2 + 0.6 * sin(PI * (k + 0.5) / 25.0)     # arched crest
		leaves.box(Vector3(x, y0 + h * 0.5, g.y), Vector3(0.07, h, 0.07), iron, false)
		leaves.cone(Vector3(x, y0 + h, g.y), 0.06, 0.25, gold, 6)
	for hy: float in [0.3, 1.6, 2.9]:
		leaves.box(Vector3(0, y0 + hy, g.y), Vector3(w, 0.1, 0.1), iron, false)
	for side: float in [-1.0, 1.0]:
		leaves.torus(Vector3(side * w * 0.25, y0 + 2.25, g.y), 0.5, 0.62, gold, Basis(Vector3.RIGHT, PI * 0.5))
	leaves.add_box_shape(Transform3D(Basis(), Vector3(0, y0 + 2.0, g.y)), Vector3(w, 4.0, 0.4))
	leaves.flush()
	gate.refresh()
