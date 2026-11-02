## The east lawn between the front parterre, the kitchen garden's south wall and
## the pond path (L35-4, audit D5): it was a bare plane in front of the house.
## Now a double rose-and-peony border runs east along the foot of the kitchen
## garden's brick wall, crossed by the kitchen walk from the garden's south gate
## to the forecourt. Beyond it a blossom grove of cherry and apple leads to a
## yew exedra with a bench and a cupid, and cherries stand on the lawn below.
## [X] invented: all of it (the book gives the house lawns, not their plan).
##
## Draw budget: the scatter chunk guard is the binding limit (1,297/1,300), so
## every species here is one that already has placements in the same 128 m
## scatter chunk (x 0..128 / 128..256, z -128..0 and 0..128). The borders stop
## at x 127 for that reason: east of it only peony and blossom are free.
class_name ManorEastLawn
extends RefCounted

## The main walk along the borders, from the parterre's east cross walk to the exedra.
const WALK_Z := -10.0
const WALK_W := 3.0
const WALK_END_X := 166.0
## The kitchen walk: the kitchen garden's south gate, south-west to the lawn,
## then west to the forecourt (the way a player walks to the potting shed).
const GATE := Vector2(126.0, -18.5)
const BEND := Vector2(100.0, 14.0)
const KITCHEN_W := 3.0
## The two borders (north against the wall, south facing the lawn).
const NORTH_BED := Rect2(86.0, -16.5, 41.0, 4.5)
const SOUTH_BED := Rect2(86.0, -8.0, 41.0, 4.5)
## Clear of the kitchen walk's centre line by this much on each side.
const WALK_CLEAR := 3.0
const GROVE := Rect2(131.0, -17.0, 33.0, 15.0)
const EXEDRA := Vector2(170.0, WALK_Z)
const EXEDRA_R := 5.5
const LAWN_CHERRIES := [Vector2(92.0, 4.0), Vector2(110.0, 24.0), Vector2(70.0, 2.0)]


static func walks() -> Array:
	var c := ManorFrontGarden.EAST.get_center()
	var x0 := sqrt(pow(ManorSitePlan.FORECOURT_RADIUS - 1.0, 2.0) - BEND.y * BEND.y)
	return [
		[PackedVector2Array([Vector2(ManorFrontGarden.EAST.end.x - 1.0, c.y), Vector2(84.0, WALK_Z), Vector2(WALK_END_X, WALK_Z)]), WALK_W],
		[PackedVector2Array([GATE, BEND, Vector2(x0, BEND.y)]), KITCHEN_W],
	]


## The kitchen walk's line, which the borders and every solid prop keep clear of.
static func kitchen_line() -> PackedVector2Array:
	return walks()[1][0]


static func _clear_of_kitchen_walk(p: Vector2, clear: float = WALK_CLEAR) -> bool:
	var line := kitchen_line()
	for i in line.size() - 1:
		if Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1]).distance_to(p) < clear:
			return false
	return true


## The planted runs of each border: the bed split where the kitchen walk crosses it.
static func bed_runs() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for bed: Rect2 in [NORTH_BED, SOUTH_BED]:
		var x := bed.position.x
		var start := x
		var open := true
		while x <= bed.end.x:
			var ok := _clear_of_kitchen_walk(Vector2(x, bed.position.y)) and _clear_of_kitchen_walk(Vector2(x, bed.end.y)) \
					and _clear_of_kitchen_walk(Vector2(x, bed.get_center().y))
			if ok and not open:
				start = x
				open = true
			elif not ok and open:
				if x - start > 2.0:
					out.append(Rect2(start, bed.position.y, x - start, bed.size.y))
				open = false
			x += 0.5
		if open and bed.end.x - start > 2.0:
			out.append(Rect2(start, bed.position.y, bed.end.x - start, bed.size.y))
	return out


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "EastLawn")
	var walk := GardenKit.walk()
	for w: Array in walks():
		b.drape_path(w[0], w[1], walk, 0.07)
	# the borders: mulch beds framed in box, standard roses along their fronts
	var mulch := GardenKit.mulch()
	for r in bed_runs():
		GardenKit.drape_rect(b, r, mulch, 0.12, 3.0)
		GardenKit.edging(b, GardenKit.rect_outline(r))
		var front_z := r.position.y if r.get_center().y > WALK_Z else r.end.y
		var x := r.position.x + 4.0
		var k := 0
		while x < r.end.x - 2.0:
			var id: StringName = [&"rose_standard_white", &"rose_standard_pink"][k % 2]
			b.prop_on_ground(id, x, front_z + (0.9 if front_z == r.position.y else -0.9))
			x += 8.0
			k += 1
	# urns on stone plinths either side of the walk where the borders begin
	for side: float in [-1.0, 1.0]:
		var p := Vector2(NORTH_BED.position.x - 1.2, WALK_Z + side * (WALK_W * 0.5 + 1.0))
		var y := ManorGrounds.ground(p.x, p.y)
		b.cylinder(Vector3(p.x, y, p.y), 0.75, 0.6, GardenKit.stone(), true, 14)
		b.prop(&"urn_overflowing", Vector3(p.x, y + 0.6, p.y), 0.0, 0.85)
	# topiary cones mark the four corners where the kitchen walk crosses
	for r in bed_runs():
		for corner_x: float in [r.position.x, r.end.x]:
			var near_z := r.end.y if r.get_center().y < WALK_Z else r.position.y
			var p := Vector2(corner_x, near_z)
			if not _clear_of_kitchen_walk(Vector2(corner_x + (2.0 if corner_x == r.end.x else -2.0), near_z)):
				var q := p + Vector2(-0.8 if corner_x == r.end.x else 0.8, 0.0)
				if _clear_of_kitchen_walk(q, KITCHEN_W * 0.5 + 0.9):
					b.prop_on_ground(&"topiary_cone", q.x, q.y)
	# faelight lanterns down the main walk
	var lx := 90.0
	while lx < WALK_END_X - 4.0:
		var lp := Vector2(lx, SOUTH_BED.position.y + 0.4)
		if _clear_of_kitchen_walk(lp):
			b.prop_on_ground(&"faelight_lantern", lp.x, lp.y, GardenKit.yaw_facing(Vector2(0.0, -1.0)))
		lx += 12.0
	# benches on the lawn side of the south border, facing it
	for bx: float in [96.0, 106.0]:
		b.prop_on_ground(&"garden_bench", bx, SOUTH_BED.end.y + 1.6, GardenKit.yaw_facing(Vector2(0.0, -1.0)))
	_exedra(b)
	# a birdbath among the lawn cherries
	b.prop_on_ground(&"birdbath", 82.0, 8.0)
	GardenKit.tag_props(b)
	b.flush()


## A semicircle of clipped yew open to the west, a curved bench inside it and a
## cupid on a plinth before it: the walk's end.
static func _exedra(b: GroundsBatch) -> void:
	var c := EXEDRA
	var n := 6
	for k in n + 1:
		var a := -PI * 0.5 + PI * k / n
		var p := c + Vector2(cos(a), sin(a)) * EXEDRA_R
		b.prop_on_ground(&"yew_hedge", p.x, p.y, GardenKit.yaw_along(Vector2(-sin(a), cos(a))), 0.82, -0.05)
	b.prop_on_ground(&"bench_curved", c.x + EXEDRA_R - 1.6, c.y, GardenKit.yaw_facing(Vector2(-1.0, 0.0)))
	var s := c + Vector2(-EXEDRA_R - 2.5, 0.0)
	var y := ManorGrounds.ground(s.x, s.y)
	b.cylinder(Vector3(s.x, y, s.y), 0.7, 0.5, GardenKit.stone(), true, 14)
	b.prop(&"cupid_statue", Vector3(s.x, y + 0.5, s.y), GardenKit.yaw_facing(Vector2(-1.0, 0.0)))
	for side: float in [-1.0, 1.0]:
		b.prop_on_ground(&"topiary_cone", c.x - EXEDRA_R + 0.6, c.y + side * (EXEDRA_R + 0.4))


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("east_lawn_plant_v1")
	# the borders, back to front: blush roses and peonies in alternating drifts
	# against the wall, irises through the middle, catmint along the front,
	# daffodils and snowdrops tucked in at the walk's edge
	for r in bed_runs():
		var north := r.get_center().y < WALK_Z
		var back_z := r.position.y + 1.2 if north else r.end.y - 1.2
		var front_z := r.end.y - 0.5 if north else r.position.y + 0.5
		var mid_z := (back_z + front_z) * 0.5
		var x := r.position.x + 1.6
		var k := 0
		while x < r.end.x - 1.0:
			var id: StringName = &"deco_rose_blush" if k % 2 == 0 else &"deco_peony"
			GardenKit.drift(sb, id, Vector2(x, back_z), 1.3, 4 if id == &"deco_rose_blush" else 5, rng)
			GardenKit.drift(sb, &"deco_iris", Vector2(x + 1.6, mid_z), 1.0, 6, rng)
			x += 3.4
			k += 1
		GardenKit.fill_line(sb, &"deco_catmint", PackedVector2Array([Vector2(r.position.x + 0.6, front_z), Vector2(r.end.x - 0.6, front_z)]), 0.9, rng)
		var dx := r.position.x + 2.5
		while dx < r.end.x - 1.5:
			GardenKit.drift(sb, &"deco_daffodil" if int(dx) % 2 == 0 else &"deco_snowdrop", Vector2(dx, (mid_z + front_z) * 0.5), 0.6, 5, rng)
			dx += 5.0
	# the blossom grove: a row of cherry and apple either side of the walk,
	# staggered, peonies beneath
	var k := 0
	for row: int in 2:
		var z: float = [GROVE.position.y + 1.5, GROVE.end.y - 1.0][row]
		var gx := GROVE.position.x + (2.5 if row == 0 else 6.0)
		while gx < GROVE.end.x - 1.0:
			sb.put(&"deco_apple_blossom" if k % 3 == 2 else &"deco_cherry_blossom", gx, z, rng.randf() * TAU, rng.randf_range(0.9, 1.05))
			GardenKit.drift(sb, &"deco_peony", Vector2(gx + 1.4, z + (1.0 if row == 0 else -1.0)), 1.2, 4, rng)
			gx += 7.0
			k += 1
	# cherries on the lawn below the borders, forget-me-nots at their feet
	for c: Vector2 in LAWN_CHERRIES:
		sb.put(&"deco_cherry_blossom", c.x, c.y, rng.randf() * TAU, rng.randf_range(0.95, 1.1))
		GardenKit.drift(sb, &"deco_forget_me_not", c + Vector2(1.0, 1.5), 2.2, 10, rng)
