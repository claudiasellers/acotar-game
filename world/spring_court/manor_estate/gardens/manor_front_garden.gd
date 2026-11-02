## The front garden either side of the forecourt (canon ch6: the gravel path to
## the main doors between amethyst irises, pale snowdrops and butter-yellow
## daffodils, the whole garden "hushed and sleeping"). Laid out as two mirrored
## box parterres in front of the wings, each four compartments round an urn.
## [X] invented: the parterre form, box edging, topiary and urns; the flowers are [C].
class_name ManorFrontGarden
extends RefCounted

## The east parterre; the west one mirrors it in x.
const EAST := Rect2(32.0, -25.0, 48.0, 21.0)
const WALK := 2.6
const LIFT_WALK := 0.06
const LIFT_BED := 0.1
## The forecourt: turf island out to the gravel ring, a rose bed round the
## fountain, and the outer border bed (inner, outer radius).
const ISLAND_R := 15.0
const ISLAND_BED := Vector2(8.2, 10.4)
const BORDER_R := Vector2(25.0, 28.4)
const FRONT_DOOR_HALF := 11.0


static func parterres() -> Array[Rect2]:
	return [EAST, Rect2(-EAST.end.x, EAST.position.y, EAST.size.x, EAST.size.y)]


## The four compartments of a parterre (inside its walks).
static func compartments(p: Rect2) -> Array[Rect2]:
	var w := (p.size.x - WALK * 3.0) * 0.5
	var d := (p.size.y - WALK * 3.0) * 0.5
	var out: Array[Rect2] = []
	for i in 2:
		for j in 2:
			out.append(Rect2(p.position + Vector2(WALK + i * (w + WALK), WALK + j * (d + WALK)), Vector2(w, d)))
	return out


static func footprints() -> Array[Rect2]:
	return parterres()


## Walks: from the forecourt ring into each parterre's cross walk.
static func walks() -> Array:
	var out := []
	for p in parterres():
		var c := p.get_center()
		var s := signf(c.x)
		var r := ManorSitePlan.FORECOURT_RADIUS - 1.0
		var x0 := sqrt(r * r - c.y * c.y)       # where the walk leaves the forecourt's gravel
		out.append([PackedVector2Array([Vector2(s * x0, c.y), Vector2(c.x + s * p.size.x * 0.5, c.y)]), WALK])
		out.append([PackedVector2Array([Vector2(c.x, p.position.y), Vector2(c.x, p.end.y)]), WALK])
	return out


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "FrontGarden")
	var walk := GardenKit.walk()
	var mulch := GardenKit.mulch()
	for p in parterres():
		var c := p.get_center()
		# a gravel field framed in box, mulch compartments laid over it
		GardenKit.drape_rect(b, p, walk, LIFT_WALK, 3.0, "|walks")
		GardenKit.edging(b, GardenKit.rect_outline(p))
		for r in compartments(p):
			GardenKit.drape_rect(b, r, mulch, LIFT_BED, 3.0)
			GardenKit.edging(b, GardenKit.rect_outline(r))
			# an inner lozenge of box: snowdrops inside, irises round it
			var m := r.get_center()
			var dx := r.size.x * 0.36
			var dz := r.size.y * 0.36
			GardenKit.edging(b, PackedVector2Array([m + Vector2(-dx, 0), m + Vector2(0, -dz), m + Vector2(dx, 0), m + Vector2(0, dz), m + Vector2(-dx, 0)]))
			b.prop_on_ground(&"topiary_ball", m.x, m.y)
		# the centre: an urn on a round stone plinth
		var y := ManorGrounds.ground(c.x, c.y)
		b.cylinder(Vector3(c.x, y, c.y), 1.0, 0.7, GardenKit.stone(), true, 16)
		b.prop(&"urn_overflowing", Vector3(c.x, y + 0.7, c.y))
		# cones at the four outer corners, standard roses mid-side
		for corner: Vector2 in [p.position, Vector2(p.end.x, p.position.y), p.end, Vector2(p.position.x, p.end.y)]:
			# not the corner by the house's front corner: people cut across it
			# from the facade to the stables and the kitchen lawn
			if corner.y == p.position.y and absf(corner.x) < absf(c.x):
				continue
			b.prop_on_ground(&"topiary_cone", corner.x + signf(c.x - corner.x) * 0.9, corner.y + signf(c.y - corner.y) * 0.9)
		for side: float in [-1.0, 1.0]:
			b.prop_on_ground(&"rose_standard_white", c.x + side * (p.size.x * 0.25 + WALK * 0.25), p.position.y + 1.2)
			b.prop_on_ground(&"rose_standard_white", c.x + side * (p.size.x * 0.25 + WALK * 0.25), p.end.y - 1.2)
	for w: Array in walks():
		b.drape_path(w[0], w[1], walk, LIFT_WALK + 0.01)
	_forecourt(b)
	GardenKit.tag_props(b)
	b.flush()


## Where walks and doors meet the forecourt's edge: the border and kerb open there.
static func forecourt_openings() -> PackedVector2Array:
	var out := PackedVector2Array([Vector2(0.0, 26.0), Vector2(0.0, -26.0), Vector2(-26.0, 4.0), Vector2(26.0, 6.0)])
	for w: Array in walks():
		var pts: PackedVector2Array = w[0]
		if pts[0].length() < ManorSitePlan.FORECOURT_RADIUS:
			out.append(pts[0])
	for w: Array in ManorEastLawn.walks():
		var pts: PackedVector2Array = w[0]
		out.append(pts[pts.size() - 1])
	return out


## Is the angle a (radians, about the forecourt centre) on a walk's opening at radius r?
static func forecourt_open(a: float, r: float) -> bool:
	for o in forecourt_openings():
		var half_m := 3.6
		if o == Vector2(0.0, -26.0):
			half_m = FRONT_DOOR_HALF
		elif o == Vector2(0.0, 26.0):
			half_m = ManorSitePlan.DRIVE_WIDTH * 0.5 + 1.0
		var half := half_m / r
		if absf(angle_difference(a, o.angle())) < half:
			return true
	return false


## The forecourt (audit E1): the terrain paints the whole disc as path, so its
## soil showed brown inside the gravel ring and as a saw-toothed band outside
## it. A turf island with a bed of roses round the fountain covers the inside,
## stone kerbs edge the gravel on both sides, and a flower border on a mulch
## bed runs round the outside, open wherever a walk or the front door meets it.
static func _forecourt(b: GroundsBatch) -> void:
	var c := ManorSitePlan.FORECOURT_CENTER
	var lawn := GardenKit.lawn()
	var mulch := GardenKit.mulch()
	# a true round gravel ring over the forecourt's own (a polyline drape whose
	# mitred corners left saw-teeth of soil at its outer edge)
	GardenKit.drape_sector(b, c, ISLAND_R - 0.1, BORDER_R.x + 0.05, 0.0, TAU, GardenKit.walk(), 0.055, "|forecourt_ring")
	GardenKit.drape_sector(b, c, ManorForecourt.FOUNTAIN_RADIUS + 0.3, ISLAND_R, 0.0, TAU, lawn, 0.05)
	GardenKit.drape_sector(b, c, ISLAND_BED.x, ISLAND_BED.y, 0.0, TAU, mulch, 0.08)
	GardenKit.edge_sector(b, c, ISLAND_BED.x, ISLAND_BED.y, 0.0, TAU)
	_kerb(b, ISLAND_R, false)
	_kerb(b, BORDER_R.x - 0.15, true)
	# the outer bed, in arcs between the openings
	var n := 96
	var start := -1
	for i in n + 1:
		var a := TAU * i / n
		var open := i == n or forecourt_open(a, BORDER_R.x)
		if not open and start < 0:
			start = i
		elif open and start >= 0:
			var a0 := TAU * start / n
			var a1 := TAU * i / n
			GardenKit.drape_sector(b, c, BORDER_R.x, BORDER_R.y, a0, a1, mulch, 0.08)
			GardenKit.edging(b, GardenKit.ring(c, BORDER_R.y, maxi(2, ceili((a1 - a0) * BORDER_R.y / GardenKit.EDGING_MODULE)), a0, a1))
			start = -1


## A ring of low stone kerb blocks at radius r (left open at the walks when `open`).
static func _kerb(b: GroundsBatch, r: float, open: bool) -> void:
	var n := ceili(TAU * r / 1.6)
	var stone := GardenKit.stone()
	for i in n:
		var a := TAU * (i + 0.5) / n
		if open and forecourt_open(a, r):
			continue
		var p := Vector2(cos(a), sin(a)) * r
		var y := ManorGrounds.ground(p.x, p.y)
		b.box(Vector3(p.x, y + 0.07, p.y), Vector3(TAU * r / n + 0.02, 0.18, 0.32), stone, false, -a + PI * 0.5)


static func plant(sb: ManorScatter) -> void:
	_plant_forecourt(sb)
	var rng := EstateKit.rng("front_garden_plant_v1")
	for p in parterres():
		for r in compartments(p):
			var m := r.get_center()
			var dx := r.size.x * 0.36
			var dz := r.size.y * 0.36
			var inner := r.grow(-0.7)
			var z := inner.position.y + 0.4
			while z < inner.end.y:
				var x := inner.position.x + 0.4
				while x < inner.end.x:
					var q := Vector2(absf(x - m.x) / dx, absf(z - m.y) / dz)
					var id: StringName
					if q.x + q.y < 0.82:
						id = &"deco_snowdrop"                       # pale snowdrops in the lozenge
					elif q.x + q.y < 1.12:
						x += 0.6
						continue                                    # the box line
					elif (x < m.x) == (z < m.y):
						id = &"deco_iris"                           # amethyst irises
					else:
						id = &"deco_daffodil"                       # butter-yellow daffodils
					if Vector2(x, z).distance_to(m) > 0.9:
						sb.put(id, x + rng.randf_range(-0.1, 0.1), z + rng.randf_range(-0.1, 0.1), rng.randf() * TAU, rng.randf_range(1.15, 1.45))
					x += 0.6 if id == &"deco_snowdrop" else 0.8
				z += 0.7


## Peonies all round the forecourt border with a low blue edge (catmint on the
## house side, forget-me-nots on the drive side: the species each 128 m scatter
## chunk there already carries), peonies between the white rose tubs on the
## island. No new chunk draws.
static func _plant_forecourt(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("forecourt_border_v1")
	var c := ManorSitePlan.FORECOURT_CENTER
	var n := 96
	for i in n:
		var a := TAU * (i + 0.5) / n
		if forecourt_open(a, BORDER_R.x):
			continue
		var dir := Vector2(cos(a), sin(a))
		var edge: StringName = &"deco_catmint" if dir.y < 0.0 else &"deco_forget_me_not"
		var p := c + dir * (BORDER_R.x + 0.6)
		sb.put(edge, p.x, p.y, rng.randf() * TAU, rng.randf_range(0.85, 1.05))
		var p2 := c + dir.rotated(PI / n) * (BORDER_R.x + 1.1)
		sb.put(edge, p2.x, p2.y, rng.randf() * TAU, rng.randf_range(0.8, 1.0))
		GardenKit.drift(sb, &"deco_peony", c + dir * (BORDER_R.x + 2.3), 0.7, 3, rng)
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0
		var p := c + Vector2(cos(a), sin(a)) * (ISLAND_BED.x + ISLAND_BED.y) * 0.5
		sb.put(&"deco_peony", p.x, p.y, rng.randf() * TAU, rng.randf_range(0.9, 1.05))
