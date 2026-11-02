## The front garden either side of the forecourt (canon ch6: the gravel path to
## the main doors between amethyst irises, pale snowdrops and butter-yellow
## daffodils, the whole garden "hushed and sleeping"). Laid out as two mirrored
## box parterres in front of the wings, each four compartments round an urn.
class_name ManorFrontGarden
extends RefCounted

## The east parterre; the west one mirrors it in x.
const EAST := Rect2(32.0, -30.0, 48.0, 24.0)
const WALK := 2.6
const LIFT_WALK := 0.06
const LIFT_BED := 0.1


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
		out.append([PackedVector2Array([Vector2(s * (ManorSitePlan.FORECOURT_RADIUS - 1.0), c.y), Vector2(c.x + s * p.size.x * 0.5, c.y)]), WALK])
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
			b.prop_on_ground(&"topiary_cone", corner.x + signf(c.x - corner.x) * 0.9, corner.y + signf(c.y - corner.y) * 0.9)
		for side: float in [-1.0, 1.0]:
			b.prop_on_ground(&"rose_standard_white", c.x + side * (p.size.x * 0.25 + WALK * 0.25), p.position.y + 1.2)
			b.prop_on_ground(&"rose_standard_white", c.x + side * (p.size.x * 0.25 + WALK * 0.25), p.end.y - 1.2)
	for w: Array in walks():
		b.drape_path(w[0], w[1], walk, LIFT_WALK + 0.01)
	b.flush()


static func plant(sb: ManorScatter) -> void:
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
