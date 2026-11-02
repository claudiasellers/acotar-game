## The rose garden Tamlin's father planted for his mother as a mating gift
## (canon ch19), "dozens of hues of crimson and pink and white and yellow" seen
## from the study (ch13), round the book's only fountain: a great heron flapping
## its wings in a small pool, near iris beds (ch24).
##
## A circular rose garden (garden-designer pass, L35). From the centre out:
## the heron fountain; a ring of irises edged with snowdrops; a walk with curved
## benches; eight petal beds of soft roses round standard roses; a ring of 24
## rose-swag pillars over a walk; a twelve-hue rose colour wheel cut by four
## rose tunnels on the axes; an outer walk ringed with standard roses and
## faelight lanterns. Outside the circle: an outer yew wall (ch19) lined with a
## herbaceous border, the birdcage pavilion east, the window garden under
## Feyre's window (puca, ch10) south-west, and the gilt gate north.
## Invented structure and planting are canon:"X". Story anchors are unchanged.
class_name ManorRoseGarden
extends RefCounted

const CENTER := Vector2(0.0, -152.0)
const POOL_R := 4.95
const IRIS := Vector2(5.4, 9.0)
## Outer edge of the inner walk; the manor_fountain anchor stands on it.
const CIRCLE_R := 14.0
const INNER_WALK := Vector2(9.0, 14.0)
const RING_A := Vector2(14.0, 23.5)
const SWAG_R := 24.0
const SWAG_BAYS := 24
const RING_C := Vector2(27.5, 39.0)
const OUTER_WALK := Vector2(39.0, 43.0)
const OUTER_R := 43.0
const AXIS_W := 5.0
const RADIAL_W := 3.0
const SECTOR_GAP := 1.2
const ROSE_STEP := 1.1
## The colour wheel, clockwise from north (crimson to coral): one hue a sector.
const WHEEL: Array[StringName] = [&"crimson", &"red", &"raspberry", &"mauve", &"pink", &"blush", &"white", &"cream",
		&"butter", &"gold", &"apricot", &"coral"]
## Soft hues of the eight petal beds round the inner walk, clockwise from north.
const PETALS: Array[StringName] = [&"white", &"blush", &"red", &"peach", &"cream", &"blush", &"gold", &"peach"]
const TUNNEL_RADII := [28.7, 31.5, 34.3, 37.1]
const NORTH_GATE := Vector2(0.0, -200.0)
const WEST_GATE := Vector2(-80.0, -152.0)
const EAST_GATE := Vector2(80.0, -152.0)
const PAVILION := Vector2(62.0, -152.0)
## Arbors: [position, yaw]. The one by the house hides the Attor (ch19 anchor).
## The cutting beds of the three forage roses (picking roses for the manor's vases).
const CUTTING_BEDS := [[&"ing_rose_white", Rect2(51.0, -138.0, 16.5, 17.0)], [&"ing_rose_red", Rect2(-72.0, -194.5, 18.0, 14.5)],
		[&"ing_rose_gold", Rect2(54.0, -195.5, 18.0, 15.5)]]
const ARBORS := [[Vector2(-40.0, -105.5), 0.0], [Vector2(40.0, -105.5), 0.0]]


static func north() -> float:
	return -PI * 0.5


## Angle span [a0, a1] of colour-wheel sector k, trimmed for the axis walks
## (k*30 deg from north; axes fall on k = 0, 3, 6, 9) and the stepping gaps.
static func wheel_span(k: int, r: float) -> Vector2:
	var a0 := north() + k * PI / 6.0
	var a1 := a0 + PI / 6.0
	var g0 := (AXIS_W * 0.5 if k % 3 == 0 else SECTOR_GAP * 0.5) / r
	var g1 := (AXIS_W * 0.5 if (k + 1) % 3 == 0 else SECTOR_GAP * 0.5) / r
	return Vector2(a0 + g0, a1 - g1)


## Angle span of petal bed j in ring A (between the eight radial walks).
static func petal_span(j: int, r: float) -> Vector2:
	var a0 := north() + j * PI / 4.0
	var w0 := (AXIS_W if j % 2 == 0 else RADIAL_W) * 0.5 / r
	var w1 := (AXIS_W if (j + 1) % 2 == 0 else RADIAL_W) * 0.5 / r
	return Vector2(a0 + w0, a0 + PI / 4.0 - w1)


## Beds: [bounding Rect2, colour] (test: >= 8 beds, red/white/gold/pink present).
static func beds() -> Array:
	var out := []
	for j in PETALS.size():
		var s := petal_span(j, RING_A.x)
		out.append([_sector_bounds(RING_A.x, RING_A.y, s.x, s.y), PETALS[j]])
	for k in WHEEL.size():
		var s := wheel_span(k, RING_C.x)
		out.append([_sector_bounds(RING_C.x, RING_C.y, s.x, s.y), WHEEL[k]])
	return out


static func _sector_bounds(r0: float, r1: float, a0: float, a1: float) -> Rect2:
	var r := Rect2(GardenKit.on_circle(CENTER, r0, a0), Vector2.ZERO)
	for i in 9:
		var a := lerpf(a0, a1, i / 8.0)
		r = r.expand(GardenKit.on_circle(CENTER, r0, a)).expand(GardenKit.on_circle(CENTER, r1, a))
	return r


## Story anchors: name -> [position x/z, yaw]. -Z of the marker faces the scene.
static func story_anchors() -> Dictionary:
	return {
		&"manor_fountain": [CENTER + Vector2(0, CIRCLE_R - 1.5), 0.0],      # south of the fountain, facing it
		&"rose_garden_bush": [Vector2(40.0, -147.0), PI],                   # on the outer walk, facing the white-rose corner
		&"garden_gate": [NORTH_GATE + Vector2(0, 6.0), 0.0],                # facing the gate to the woods side
		&"attor_hiding_spot": [Vector2(-40.0, -105.5), 0.0],                # under the arbor near the house
	}


## The scatter layer for a rose hue: the three forage roses stay forage.
static func rose_layer(colour: StringName) -> StringName:
	match colour:
		&"red", &"white", &"gold":
			return StringName("ing_rose_" + String(colour))
	return StringName("deco_rose_" + String(colour))


## The garden look mixed through a forage-rose bed (none for the other hues).
static func rose_mix(colour: StringName) -> StringName:
	return StringName("deco_rose_" + String(colour)) if rose_layer(colour).begins_with("ing_") else &""


# --- Planting (scatter) ----------------------------------------------------------

static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("rose_garden_plant_v2")
	var c := CENTER
	# irises round the heron's pool (canon ch24), snowdrops at their feet
	GardenKit.fill_sector(sb, &"deco_iris", c, IRIS.x + 0.2, IRIS.y - 0.5, 0.0, TAU, 0.85, rng)
	GardenKit.fill_line(sb, &"deco_snowdrop", GardenKit.ring(c, IRIS.y - 0.25, 64), 0.55, rng, 0.08)
	for i in 24:
		var a := TAU * i / 24.0
		sb.put(&"ing_iris", c.x + cos(a) * (POOL_R + 1.3), c.y + sin(a) * (POOL_R + 1.3), a, 0.9)
		if i % 2 == 0:
			sb.put(&"ing_rose_maze_dew", c.x + cos(a + 0.1) * (POOL_R + 0.5), c.y + sin(a + 0.1) * (POOL_R + 0.5), a)
	# ring A: petal beds of soft roses, a catmint ribbon on the inner edge
	for j in PETALS.size():
		var s := petal_span(j, RING_A.x + 1.0)
		GardenKit.fill_sector(sb, &"deco_catmint", c, RING_A.x + 0.4, RING_A.x + 1.4, s.x, s.y, 0.9, rng)
		var s2 := petal_span(j, RING_A.x + 2.0)
		var mid := (s2.x + s2.y) * 0.5
		var hole := 1.4 / ((RING_A.x + RING_A.y) * 0.5)
		GardenKit.fill_sector(sb, rose_layer(PETALS[j]), c, RING_A.x + 1.6, RING_A.y - 0.3, s2.x, mid - hole, ROSE_STEP, rng, Vector2(0.9, 1.1), rose_mix(PETALS[j]))
		GardenKit.fill_sector(sb, rose_layer(PETALS[j]), c, RING_A.x + 1.6, RING_A.y - 0.3, mid + hole, s2.y, ROSE_STEP, rng, Vector2(0.9, 1.1), rose_mix(PETALS[j]))
		if rng.randf() < 0.7:
			var p := GardenKit.on_circle(c, (RING_A.x + RING_A.y) * 0.5 + 2.0, mid + 0.12)
			sb.put(&"ing_rose_maze_dew", p.x, p.y, rng.randf() * TAU)
	# ring C: the colour wheel, lavender along its outer rim
	for k in WHEEL.size():
		var s := wheel_span(k, RING_C.x + 1.0)
		GardenKit.fill_sector(sb, rose_layer(WHEEL[k]), c, RING_C.x + 0.3, RING_C.y - 1.4, s.x, s.y, ROSE_STEP, rng, Vector2(0.9, 1.1), rose_mix(WHEEL[k]))
		var s3 := wheel_span(k, RING_C.y)
		GardenKit.fill_sector(sb, &"ing_lavender" if k % 2 == 0 else &"deco_catmint", c, RING_C.y - 1.3, RING_C.y - 0.2, s3.x, s3.y, 1.25, rng, Vector2(0.75, 0.9))
	# the outer yew wall's herbaceous border (inside faces of W, E and N walls)
	_border(sb, rng, Vector2(-78.0, -196.0), Vector2(-78.0, -156.0))
	_border(sb, rng, Vector2(-78.0, -148.0), Vector2(-78.0, -112.0))
	_border(sb, rng, Vector2(78.0, -196.0), Vector2(78.0, -156.0))
	_border(sb, rng, Vector2(78.0, -148.0), Vector2(78.0, -98.0))
	_border(sb, rng, Vector2(-76.0, -197.5), Vector2(-4.0, -197.5))
	_border(sb, rng, Vector2(4.0, -197.5), Vector2(76.0, -197.5))
	_ring_border(sb, rng)
	# the corners: drifts of hydrangea, peony and foxglove between standard roses
	for corner: Vector2 in [Vector2(-46.0, -184.0), Vector2(46.0, -184.0), Vector2(-60.0, -122.0)]:
		GardenKit.drift(sb, &"deco_hydrangea_pink" if corner.x < 0.0 else &"deco_hydrangea", corner, 5.0, 9, rng)
		GardenKit.drift(sb, &"deco_peony", corner + Vector2(8.0 * signf(-corner.x), 3.0), 3.5, 7, rng)
		GardenKit.drift(sb, &"ing_foxglove", corner + Vector2(-6.0 * signf(-corner.x), 6.0), 3.0, 4, rng)
	# the cutting beds (the white one by the outer walk: the rose_garden_bush anchor faces it)
	for bed: Array in CUTTING_BEDS:
		GardenKit.fill_rect(sb, bed[0], bed[1], ROSE_STEP, rng)
	# round the birdcage pavilion: blue and pink hydrangea, white foxglove
	GardenKit.fill_sector(sb, &"deco_hydrangea", PAVILION, 5.0, 7.4, -PI * 0.25, PI * 0.25 + PI, 1.5, rng)
	GardenKit.fill_line(sb, &"deco_foxglove_white", GardenKit.ring(PAVILION, 8.3, 24, PI * 0.35, PI * 1.65), 1.2, rng)
	# the window garden under Feyre's window: lilac, lavender and peonies by the hedges
	for p: Vector2 in [Vector2(-70.0, -100.0), Vector2(-54.0, -99.0)]:
		sb.put(&"ing_lilac", p.x, p.y, rng.randf() * TAU, 0.9)
	GardenKit.fill_line(sb, &"deco_peony", PackedVector2Array([Vector2(-78.0, -97.0), Vector2(-50.0, -97.0)]), 1.6, rng)
	GardenKit.fill_line(sb, &"deco_peony", PackedVector2Array([Vector2(50.0, -97.0), Vector2(78.0, -97.0)]), 1.6, rng)
	# the terrace foot: lavender and catmint either side of the steps
	for side: float in [-1.0, 1.0]:
		GardenKit.fill_line(sb, &"deco_catmint", PackedVector2Array([Vector2(side * 13.0, -105.0), Vector2(side * 36.0, -105.0)]), 0.9, rng)
		GardenKit.fill_line(sb, &"deco_rose_blush", PackedVector2Array([Vector2(side * 13.0, -106.5), Vector2(side * 36.0, -106.5)]), 1.3, rng)
	# canon: the crab-apple, foxglove alcove and lambs moved to the garden rooms
	# (ManorGardenRooms); dew on the roses either side of the north gate
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		sb.put(&"ing_rose_maze_dew", side * (6.0 + 2.2 * i), -195.5 + rng.randf() * 1.5, rng.randf() * TAU)


## A deep ring of perennials round the outer walk, in drifts ~5 m long, broken at
## the four axes and where the side-step walks come in.
static func _ring_border(sb: ManorScatter, rng: RandomNumberGenerator) -> void:
	const R0 := OUTER_R + 2.0
	const R1 := OUTER_R + 6.5
	var kinds: Array[StringName] = [&"deco_delphinium", &"deco_peony", &"deco_foxglove_white", &"deco_lupin",
		&"deco_hydrangea", &"deco_catmint", &"deco_allium", &"deco_peony_white", &"deco_hollyhock", &"deco_hydrangea_pink"]
	var gap := 6.0 / R0
	var skips := [Vector2(PI * 0.25, PI * 0.36), Vector2(PI * 0.64, PI * 0.75)]    # the side-step walks (south-east, south-west)
	var drift_a := 5.0 / R0
	var k := 0
	for q in 4:
		var a0 := north() + q * PI * 0.5 + gap
		var a1 := north() + (q + 1) * PI * 0.5 - gap
		var a := a0
		while a < a1 - drift_a * 0.5:
			var b := minf(a + drift_a, a1)
			var mid := fposmod((a + b) * 0.5, TAU)
			var clear := true
			for sk: Vector2 in skips:
				if mid > sk.x and mid < sk.y:
					clear = false
			if clear:
				GardenKit.fill_sector(sb, kinds[k % kinds.size()], CENTER, R0, R1, a, b, 1.15, rng, Vector2(0.85, 1.15))
				k += 3
			a = b


static func _border(sb: ManorScatter, rng: RandomNumberGenerator, a: Vector2, b: Vector2) -> void:
	# back row tall (delphinium, hollyhock, foxglove), front row lower (lupin, allium, peony, catmint)
	var dir := (b - a).normalized()
	var inward := Vector2(-signf(a.x) if absf(a.x - b.x) < 0.1 else 0.0, 1.0 if absf(a.y - b.y) < 0.1 else 0.0)
	var back: Array[StringName] = [&"deco_delphinium", &"deco_hollyhock", &"deco_foxglove_white", &"deco_delphinium", &"deco_hollyhock"]
	var front: Array[StringName] = [&"deco_lupin", &"deco_allium", &"deco_peony", &"deco_catmint", &"deco_peony_white"]
	var length := a.distance_to(b)
	var t := 0.0
	var k := 0
	while t < length:
		var drift := rng.randf_range(2.5, 4.0)
		var id_b: StringName = back[k % back.size()]
		var id_f: StringName = front[(k + 2) % front.size()]
		var u := 0.0
		while u < drift and t + u < length:
			var p := a + dir * (t + u)
			sb.put(id_b, p.x + rng.randf_range(-0.2, 0.2), p.y + rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(0.85, 1.1))
			var q := p + inward * 1.3 + dir * 0.4
			sb.put(id_f, q.x, q.y, rng.randf() * TAU, rng.randf_range(0.85, 1.1))
			u += 0.85
		t += drift
		k += 1


# --- Structures ---------------------------------------------------------------

static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "RoseGarden")
	var c := CENTER
	var walk := GardenKit.walk()
	var mulch := GardenKit.mulch()
	# the gravel field of the circle (walks), with mulch beds laid over it
	GardenKit.drape_sector(b, c, POOL_R - 0.2, OUTER_R, 0.0, TAU, walk, 0.035, "|walks")
	GardenKit.drape_sector(b, c, IRIS.x, IRIS.y, 0.0, TAU, mulch, 0.07)
	GardenKit.edging(b, GardenKit.ring(c, IRIS.y, 40))
	for j in PETALS.size():
		var s := petal_span(j, RING_A.x)
		GardenKit.drape_sector(b, c, RING_A.x, RING_A.y, s.x, s.y, mulch, 0.07)
		GardenKit.edge_sector(b, c, RING_A.x, RING_A.y, s.x, s.y)
	for k in WHEEL.size():
		var s := wheel_span(k, RING_C.x)
		GardenKit.drape_sector(b, c, RING_C.x, RING_C.y, s.x, s.y, mulch, 0.07)
		GardenKit.edge_sector(b, c, RING_C.x, RING_C.y, s.x, s.y)
	# axis walks out to the outer wall and the steps
	b.drape_path(PackedVector2Array([Vector2(0.0, -103.0), Vector2(0.0, c.y + OUTER_R - 1.0)]), AXIS_W, walk, 0.035)
	b.drape_path(PackedVector2Array([Vector2(0.0, c.y - OUTER_R + 1.0), NORTH_GATE + Vector2(0.0, -1.0)]), AXIS_W, walk, 0.035)
	b.drape_path(PackedVector2Array([WEST_GATE + Vector2(-1.0, 0.0), Vector2(-OUTER_R + 1.0, c.y)]), AXIS_W, walk, 0.035)
	b.drape_path(PackedVector2Array([Vector2(OUTER_R - 1.0, c.y), EAST_GATE + Vector2(1.0, 0.0)]), AXIS_W, walk, 0.035)
	b.drape_path(PackedVector2Array([Vector2(-40.0, -103.0), Vector2(-40.0, -108.0), Vector2(-28.0, -118.0)]), 3.0, walk, 0.035)
	b.drape_path(PackedVector2Array([Vector2(40.0, -103.0), Vector2(40.0, -108.0), Vector2(28.0, -118.0)]), 3.0, walk, 0.035)
	b.drape_path(PackedVector2Array([Vector2(-50.0, -104.0), Vector2(50.0, -104.0)]), 3.0, walk, 0.035)
	for bed: Array in CUTTING_BEDS:
		GardenKit.drape_rect(b, bed[1], mulch, 0.07)
		GardenKit.edging(b, GardenKit.rect_outline(bed[1]))
	_fountain(b)
	_swags(b)
	_tunnels(b)
	# curved benches on the inner walk's diagonals, facing the heron
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var p := GardenKit.on_circle(c, CIRCLE_R - 0.9, a)
		b.prop_on_ground(&"bench_curved", p.x, p.y, GardenKit.yaw_facing(c - p))
	# standard roses: one in each petal bed, and a ring round the outer walk
	for j in PETALS.size():
		var s := petal_span(j, RING_A.x)
		var p := GardenKit.on_circle(c, (RING_A.x + RING_A.y) * 0.5 + 0.5, (s.x + s.y) * 0.5)
		b.prop_on_ground(&"rose_standard_white" if j % 2 == 0 else &"rose_standard_pink", p.x, p.y, j * 0.7)
	var std: Array[StringName] = [&"rose_standard_pink", &"rose_standard_white", &"rose_standard_apricot"]
	for i in 24:
		var a := north() + (i + 0.5) * TAU / 24.0
		if fmod(i + 0.5, 6.0) < 1.0 or fmod(i + 0.5, 6.0) > 5.0:
			continue    # keep the axis openings clear
		var p := GardenKit.on_circle(c, OUTER_R + 0.9, a)
		b.prop_on_ground(std[i % 3], p.x, p.y, a)
	# faelight lanterns round the swag walk and at the axis mouths (glow at dusk)
	for i in 12:
		var a := north() + (i + 0.5) * TAU / 12.0
		var p := GardenKit.on_circle(c, RING_C.x - 0.5, a)
		b.prop_on_ground(&"faelight_lantern", p.x, p.y, GardenKit.yaw_facing(c - p))
	# overflowing urns flanking each axis where it leaves the circle
	for i in 4:
		var a := north() + i * PI * 0.5
		for side: float in [-1.0, 1.0]:
			var p := GardenKit.on_circle(c, OUTER_R + 1.4, a + side * 4.2 / OUTER_R)
			b.prop_on_ground(&"urn_overflowing", p.x, p.y, a)
	# the birdcage pavilion east, opening toward the heron
	b.prop_on_ground(&"birdcage_pavilion", PAVILION.x, PAVILION.y, GardenKit.yaw_facing(c - PAVILION))
	b.add_cyl_shape(Vector3(PAVILION.x, ManorGrounds.ground(PAVILION.x, PAVILION.y), PAVILION.y), 0.4, 3.0)
	for side: float in [-1.0, 1.0]:
		b.prop_on_ground(&"topiary_spiral", PAVILION.x - 5.0, PAVILION.y + side * 4.0)
	# arbors (the south-west one hides the Attor, ch19)
	for arbor in ARBORS:
		var p: Vector2 = arbor[0]
		b.prop_on_ground(&"rose_arbor", p.x, p.y, arbor[1])
	# topiary at the terrace steps' foot and the gates
	for side: float in [-1.0, 1.0]:
		b.prop_on_ground(&"topiary_tiered", side * 12.5, -104.5)
		b.prop_on_ground(&"topiary_cone", side * 44.0, -104.5)
		b.prop_on_ground(&"topiary_peacock", WEST_GATE.x + 4.5, WEST_GATE.y + side * 4.2, -PI * 0.5)
		b.prop_on_ground(&"topiary_peacock", EAST_GATE.x - 4.5, EAST_GATE.y + side * 4.2, PI * 0.5)
		b.prop_on_ground(&"topiary_ball", NORTH_GATE.x + side * 5.0, NORTH_GATE.y + 4.0)
	# standard roses and box balls in the corners
	for corner: Vector2 in [Vector2(-66.0, -172.0), Vector2(66.0, -172.0), Vector2(-66.0, -126.0), Vector2(70.0, -108.0)]:
		for i in 4:
			var p := corner + Vector2((i % 2) * 8.0 - 4.0, (i / 2) * 8.0 - 4.0)
			b.prop_on_ground(std[(i + int(corner.y)) % 3], p.x, p.y, i * 1.3)
	_hedges(b)
	_north_gate(b)
	b.flush()
	_markers(parent)


static func _fountain(b: GroundsBatch) -> void:
	var c := CENTER
	var y := ManorGrounds.ground(c.x, c.y)
	b.prop(&"heron_fountain", Vector3(c.x, y, c.y), PI)
	# the basin rim collides; the heron's rock in the middle too
	for i in 16:
		var a := TAU * i / 16.0
		b.add_box_shape(Transform3D(Basis(Vector3.UP, -a), Vector3(c.x + cos(a) * POOL_R, y + 0.35, c.y + sin(a) * POOL_R)), Vector3(0.6, 0.7, 2.1))
	b.add_cyl_shape(Vector3(c.x, y, c.y), 1.3, 3.5)


## The swag ring: 24 pillars, rope swags of roses between them.
static func _swags(b: GroundsBatch) -> void:
	var c := CENTER
	var off := PI / SWAG_BAYS     # pillars sit between the radial walks
	var chord := 2.0 * SWAG_R * sin(PI / SWAG_BAYS)
	var model_w: float = PropCatalog.ENTRIES[&"rose_swag_bay"][1].x
	for i in SWAG_BAYS:
		var a0 := north() + off + TAU * i / SWAG_BAYS
		var p0 := GardenKit.on_circle(c, SWAG_R, a0)
		var p1 := GardenKit.on_circle(c, SWAG_R, a0 + TAU / SWAG_BAYS)
		var m := (p0 + p1) * 0.5
		b.prop_on_ground(&"rose_swag_bay", m.x, m.y, GardenKit.yaw_along((p1 - p0).normalized()), chord / model_w * 1.03)
		b.add_cyl_shape(Vector3(p0.x, ManorGrounds.ground(p0.x, p0.y), p0.y), 0.25, 2.8)


## Rose tunnels where the four axis walks cross the colour wheel.
static func _tunnels(b: GroundsBatch) -> void:
	var c := CENTER
	for i in 4:
		var a := north() + i * PI * 0.5
		var u := Vector2(cos(a), sin(a))
		var across := Vector2(-u.y, u.x)
		for r: float in TUNNEL_RADII:
			var p := c + u * r
			b.prop_on_ground(&"rose_tunnel_arch", p.x, p.y, GardenKit.yaw_along(across))
			for side: float in [-1.0, 1.0]:
				var q := p + across * side * 2.95
				b.add_cyl_shape(Vector3(q.x, ManorGrounds.ground(q.x, q.y), q.y), 0.12, 2.4)


## The outer yew wall (canon ch19), open at the gates and toward the terrace.
static func _hedges(b: GroundsBatch) -> void:
	var g := ManorSitePlan.ROSE_GARDEN
	var w := g.position.x + 0.7
	var e := g.end.x - 0.7
	var n := g.position.y + 0.7
	GardenKit.hedge_with_openings(b, Vector2(w, -93.0), Vector2(w, n), [WEST_GATE], 5.0)
	GardenKit.hedge_with_openings(b, Vector2(e, -93.0), Vector2(e, n), [EAST_GATE], 5.0)
	GardenKit.hedge_with_openings(b, Vector2(w, n), Vector2(e, n), [NORTH_GATE], 7.0, false)
	# low south returns beside the wings: the hedges under Feyre's window (ch10)
	GardenKit.hedge_line(b, Vector2(w, -93.0), Vector2(-50.0, -93.0))
	GardenKit.hedge_line(b, Vector2(50.0, -93.0), Vector2(e, -93.0))


static func _north_gate(b: GroundsBatch) -> void:
	var y := ManorGrounds.ground(NORTH_GATE.x, NORTH_GATE.y)
	var stone := GardenKit.stone()
	for side: float in [-1.0, 1.0]:
		var x: float = NORTH_GATE.x + side * 3.4
		b.box(Vector3(x, y + 1.7, NORTH_GATE.y + 0.7), Vector3(1.0, 3.4, 1.0), stone)
		b.box(Vector3(x, y + 3.5, NORTH_GATE.y + 0.7), Vector3(1.2, 0.2, 1.2), GardenKit.stone_shade(), false)
		b.prop(&"urn_overflowing", Vector3(x, y + 3.6, NORTH_GATE.y + 0.7), 0.0, 0.8)
		# gate leaf swung open against the hedge
		b.prop(&"gate_iron_gilt", Vector3(x - side * 1.0, y, NORTH_GATE.y - 0.3), side * PI * 0.5, 0.5)
	b.box(Vector3(NORTH_GATE.x, y + 3.9, NORTH_GATE.y + 0.7), Vector3(7.6, 0.25, 0.4), ManorGrounds.iron_gold(), false)


static func _markers(parent: Node3D) -> void:
	var anchors := story_anchors()
	for id: StringName in anchors:
		var m := Marker3D.new()
		m.name = String(id)
		var p: Vector2 = anchors[id][0]
		m.position = Vector3(p.x, ManorGrounds.ground(p.x, p.y), p.y)
		m.rotation.y = anchors[id][1]
		m.add_to_group(&"story_anchor")
		parent.add_child(m)
	var puca := Marker3D.new()
	puca.name = "puca_garden_spot"
	var q := ManorSitePlan.PUCA_GARDEN_SPOT
	puca.position = Vector3(q.x, ManorGrounds.ground(q.x, q.y), q.y)
	puca.add_to_group(&"creature_spot")
	puca.set_meta(&"creature_id", &"cre_puca")
	puca.set_meta(&"active", "night")
	parent.add_child(puca)
