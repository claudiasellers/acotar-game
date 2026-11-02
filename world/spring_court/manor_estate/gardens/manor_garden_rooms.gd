## The garden rooms west of the rose garden (L35): four yew-walled rooms off an
## 84 m Wisteria Walk, and the buttercup meadow beyond.
##
##   Topiary Court (NW)          | White Moon Garden (NE)
##   ---------- Wisteria Walk (z = -152) -----------> rose garden west gate
##   Crab Apple & Lamb Lawn (SW) | Lilac & Swing Room (SE)
##       open west onto the buttercup meadow
##
## Canon (book 1, ch8): the bench in an alcove blooming with foxglove, the gnarled
## crab apple shedding petals like snow, the lanky meadow buttercups and the
## weathered statue of two bounding lambs all live in the SW room and its meadow.
## Wisteria (ch10-11) drips from the walk.
## [X] invented: the room layout and names, the walk as a pergola, the topiary,
## the moon garden, the swing, the dovecote. Not book material.
class_name ManorGardenRooms
extends RefCounted

const AREA := Rect2(-172.0, -200.0, 88.0, 108.0)
const WALK_Z := -152.0
const WALK_W := 4.0
const WALK_EAST := -84.0
const WALK_WEST := -170.0
const BAY := 3.0                 # wisteria_bay length along the walk
## Drape heights over the terrain: lawn under walks under beds, far enough apart
## that the terrain's own triangles never poke through on the slopes.
const LAWN_LIFT := 0.06
const WALK_LIFT := 0.11
const BED_LIFT := 0.15

## Rooms: id -> Rect2 (the yew wall runs along each edge).
const ROOMS := {
	&"topiary_court": Rect2(-168.0, -198.0, 40.0, 42.0),
	&"white_moon_garden": Rect2(-124.0, -198.0, 40.0, 42.0),
	&"crab_apple_lawn": Rect2(-168.0, -148.0, 40.0, 50.0),
	&"lilac_swing_room": Rect2(-124.0, -148.0, 40.0, 50.0),
}

## Openings (yew arches) on each room's walls, as points on the wall line.
const ARCHES := [
	Vector2(-148.0, -156.0), Vector2(-104.0, -156.0),     # north rooms onto the walk
	Vector2(-148.0, -148.0), Vector2(-104.0, -148.0),     # south rooms onto the walk
	Vector2(-128.0, -177.0), Vector2(-124.0, -177.0),     # topiary court <-> moon garden
	Vector2(-128.0, -123.0), Vector2(-124.0, -123.0),     # lamb lawn <-> lilac room
	Vector2(-104.0, -98.0),                               # lilac room from the rear lawn path
]
## The lamb lawn opens wide onto the meadow (no hedge here).
const MEADOW_OPENING := Vector2(-136.0, -110.0)     # z range on the west wall
const BUTTERCUP_MEADOW := Rect2(-258.0, -164.0, 86.0, 70.0)

const LAMBS := Vector2(-157.0, -123.0)
const ALCOVE := Vector2(-129.8, -138.0)             # against the lamb lawn's east wall, facing west
const CRAB_APPLES := [Vector2(-158.0, -136.0), Vector2(-140.0, -112.0), Vector2(-160.0, -106.0), Vector2(-138.0, -140.0)]
const SWING := Vector2(-94.0, -118.0)
const DOVECOTE := Vector2(-148.0, -177.0)
const ROSE_ROUND := Vector2(-114.0, -134.0)
const ARMILLARY := Vector2(-104.0, -177.0)
const MOON_GAP := 0.25

## The rear lawn path from the terrace's west end round to the lilac room (the
## old pale maze path is gone; this one keeps under the glare cap).
const REAR_PATH := [Vector2(-48.0, -90.0), Vector2(-104.0, -90.0), Vector2(-104.0, -97.0)]
## The walk's west end on to the hedge maze's entrance.
const MAZE_PATH := [Vector2(-170.0, -152.0), Vector2(-172.0, -158.0), Vector2(-172.0, -206.5), Vector2(-175.0, -206.5)]


static func walk_length() -> float:
	return WALK_EAST - WALK_WEST


## Points that must be reachable on foot from the terrace (test: path graph).
static func room_doors() -> Dictionary:
	return {
		&"topiary_court": Vector2(-148.0, -156.0),
		&"white_moon_garden": Vector2(-104.0, -156.0),
		&"crab_apple_lawn": Vector2(-148.0, -148.0),
		&"lilac_swing_room": Vector2(-104.0, -148.0),
	}


## The walks as polylines [points, width]: the path graph for reachability.
static func walks() -> Array:
	var rg := ManorRoseGarden.WEST_GATE
	return [
		[PackedVector2Array([Vector2(rg.x - 1.0, WALK_Z), Vector2(WALK_WEST, WALK_Z)]), WALK_W],
		[PackedVector2Array(REAR_PATH), 3.0],
		[PackedVector2Array(MAZE_PATH), 3.0],
		# inside the rooms: cross walks from each arch to the room's middle
		[PackedVector2Array([Vector2(-148.0, WALK_Z), Vector2(-148.0, -177.0), Vector2(-124.0, -177.0), Vector2(-104.0, -177.0), Vector2(-104.0, WALK_Z)]), 2.4],
		[PackedVector2Array([Vector2(-148.0, WALK_Z), Vector2(-148.0, -123.0), Vector2(-124.0, -123.0), Vector2(-104.0, -123.0), Vector2(-104.0, WALK_Z)]), 2.4],
		[PackedVector2Array([Vector2(-104.0, -123.0), Vector2(-104.0, -98.0)]), 2.4],
	]


# --- Building ---------------------------------------------------------------------

static func build(parent: Node3D, pace: BuildPace = null) -> void:
	var b := GroundsBatch.new(parent, "GardenRooms")
	var walk := GardenKit.walk()
	for w: Array in walks():
		b.drape_path(w[0], w[1], walk, WALK_LIFT)
		if pace:
			await pace.tick()
	for step: Callable in [_walls.bind(pace), _wisteria_walk.bind(pace), _topiary_court, _moon_garden, _lamb_lawn, _lilac_room]:
		await step.call(b)
		if pace:
			await pace.tick()
	GardenKit.tag_props(b)
	await b.finish(pace)


static func _walls(b: GroundsBatch, pace: BuildPace) -> void:
	for id: StringName in ROOMS:
		if pace:
			await pace.tick()
		var r: Rect2 = ROOMS[id]
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			var a: Vector2 = corners[i]
			var c: Vector2 = corners[(i + 1) % 4]
			var ops: Array = []
			for o: Vector2 in ARCHES:
				if _on_segment(o, a, c):
					ops.append(o)
			if id == &"crab_apple_lawn" and i == 3:
				# west wall: a wide opening onto the meadow, flanked by urns
				var top := Vector2(r.position.x, MEADOW_OPENING.x)
				var bottom := Vector2(r.position.x, MEADOW_OPENING.y)
				GardenKit.hedge_line(b, r.end * Vector2(0, 1) + Vector2(r.position.x, 0), bottom)
				GardenKit.hedge_line(b, top, r.position)
				for p: Vector2 in [top, bottom]:
					b.prop_on_ground(&"urn_overflowing", p.x + 0.6, p.y + (2.0 if p == top else -2.0), PI * 0.5)
				continue
			GardenKit.hedge_with_openings(b, a, c, ops, 4.0)
			for o: Vector2 in ops:
				_arch_piers(b, o, (c - a).normalized())


static func _on_segment(p: Vector2, a: Vector2, c: Vector2) -> bool:
	var ab := c - a
	var t := (p - a).dot(ab) / ab.length_squared()
	return t > 0.0 and t < 1.0 and (a + ab * t).distance_to(p) < 0.05


static func _arch_piers(b: GroundsBatch, o: Vector2, dir: Vector2) -> void:
	var y := ManorGrounds.ground(o.x, o.y)
	for side: float in [-1.0, 1.0]:
		var q := o + dir * side * 1.5
		b.add_box_shape(Transform3D(Basis(Vector3.UP, GardenKit.yaw_along(dir)), Vector3(q.x, y + 1.5, q.y)), Vector3(1.0, 3.0, 1.25))


## 28 pergola bays dripping wisteria, the walk running beneath them.
static func _wisteria_walk(b: GroundsBatch, pace: BuildPace) -> void:
	var n := floori(walk_length() / BAY)
	var yaw := GardenKit.yaw_facing(Vector2(-1.0, 0.0))
	var turn := Basis(Vector3.UP, yaw)
	for i in n:
		if pace:
			await pace.tick()
		var x := WALK_EAST - 1.0 - BAY * (i + 0.5)
		# each bay is sheared to run from the ground at its east end to the
		# ground at its west end, its piers still plumb, so neighbouring bays
		# meet at one height and the roof climbs the slope as one canopy with
		# no step to look under (L35-7: the steps of up to half a metre showed
		# from above as dark stripes between the bays)
		var y_east := WorldHeight.height_at(x + BAY * 0.5, WALK_Z)
		var y_west := WorldHeight.height_at(x - BAY * 0.5, WALK_Z)
		var shear := Basis(Vector3(1.0, (y_east - y_west) / BAY, 0.0), Vector3.UP, Vector3.BACK)
		b.prop_xform(&"wisteria_bay", Transform3D(shear * turn, Vector3(x, (y_east + y_west) * 0.5, WALK_Z)))
		for side: float in [-1.0, 1.0]:
			var px := x + BAY * 0.5 - 0.25
			b.add_cyl_shape(Vector3(px, ManorGrounds.ground(px, WALK_Z + side * 2.25), WALK_Z + side * 2.25), 0.26, 2.9)
	# urns at both ends, a bench every third of the way, facing across
	for x: float in [WALK_EAST - 0.2, WALK_WEST + 2.0 - BAY * 0.0]:
		for side: float in [-1.0, 1.0]:
			b.prop_on_ground(&"urn_overflowing", x, WALK_Z + side * 3.0)
	for x: float in [-112.0, -140.0]:
		b.prop_on_ground(&"bench_curved", x, WALK_Z - 2.9, PI)
		b.prop_on_ground(&"bench_curved", x, WALK_Z + 2.9, 0.0)


static func _topiary_court(b: GroundsBatch) -> void:
	var r: Rect2 = ROOMS[&"topiary_court"]
	GardenKit.drape_rect(b, r.grow(-1.0), GardenKit.lawn(), LAWN_LIFT, 2.0, "|lawn")
	GardenKit.drape_sector(b, DOVECOTE, 0.0, 6.5, 0.0, TAU, GardenKit.walk(), WALK_LIFT, "|walks")
	GardenKit.drape_sector(b, DOVECOTE, 0.0, 2.6, 0.0, TAU, GardenKit.mulch(), BED_LIFT)
	GardenKit.edging(b, GardenKit.ring(DOVECOTE, 2.6, 12))
	b.prop_on_ground(&"dovecote", DOVECOTE.x, DOVECOTE.y, 0.3)
	b.add_cyl_shape(Vector3(DOVECOTE.x, ManorGrounds.ground(DOVECOTE.x, DOVECOTE.y), DOVECOTE.y), 0.3, 2.4)
	# a chessboard of clipped shapes in box-edged squares round the dovecote
	var kinds: Array[StringName] = [&"topiary_spiral", &"topiary_cone", &"topiary_tiered", &"topiary_lollipop", &"topiary_ball",
		&"topiary_heart_ribbon", &"topiary_peacock"]
	var k := 0
	for ix in 4:
		for iz in 4:
			var p := r.position + Vector2(6.0 + ix * 9.3, 6.0 + iz * 10.0)
			if p.distance_to(DOVECOTE) < 7.0 or absf(p.x - DOVECOTE.x) < 2.5 or absf(p.y - DOVECOTE.y) < 2.5:
				continue
			GardenKit.edging(b, GardenKit.rect_outline(Rect2(p - Vector2(2.2, 2.2), Vector2(4.4, 4.4))))
			b.prop_on_ground(kinds[k % kinds.size()], p.x, p.y, (k % 4) * PI * 0.5)
			k += 1
	for side: float in [-1.0, 1.0]:
		b.prop_on_ground(&"obelisk_sweetpea", DOVECOTE.x + side * 4.5, DOVECOTE.y - 4.5)
		b.prop_on_ground(&"obelisk_sweetpea", DOVECOTE.x + side * 4.5, DOVECOTE.y + 4.5)


static func _moon_garden(b: GroundsBatch) -> void:
	var r: Rect2 = ROOMS[&"white_moon_garden"]
	var c := ARMILLARY
	GardenKit.drape_rect(b, r.grow(-1.0), GardenKit.lawn(), LAWN_LIFT, 2.0, "|lawn")
	# a round gravel court with four quarter beds of white flowers
	GardenKit.drape_sector(b, c, 0.0, 15.0, 0.0, TAU, GardenKit.walk(), WALK_LIFT, "|walks")
	for q in 4:
		var a0 := q * PI * 0.5 + MOON_GAP
		var a1 := (q + 1) * PI * 0.5 - MOON_GAP
		GardenKit.drape_sector(b, c, 5.0, 13.5, a0, a1, GardenKit.mulch(), BED_LIFT)
		GardenKit.edge_sector(b, c, 5.0, 13.5, a0, a1)
		var m := GardenKit.on_circle(c, 14.6, (a0 + a1) * 0.5)
		b.prop_on_ground(&"faelight_lantern", m.x, m.y, GardenKit.yaw_facing(c - m))
	b.prop_on_ground(&"armillary", c.x, c.y)
	b.add_cyl_shape(Vector3(c.x, ManorGrounds.ground(c.x, c.y), c.y), 0.3, 1.8)
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var p := GardenKit.on_circle(c, 16.5, a)
		b.prop_on_ground(&"rose_standard_white", p.x, p.y, a)
	b.prop_on_ground(&"bench_curved", c.x, r.position.y + 3.0, 0.0)
	b.prop_on_ground(&"cupid_statue", c.x, r.position.y + 6.5, 0.0)


static func _lamb_lawn(b: GroundsBatch) -> void:
	var r: Rect2 = ROOMS[&"crab_apple_lawn"]
	GardenKit.drape_rect(b, r.grow(-1.0), GardenKit.lawn(), LAWN_LIFT, 2.0, "|lawn")
	# canon ch8: the weathered statue of two bounding lambs, mid-lawn
	b.prop_on_ground(&"lamb_statue", LAMBS.x, LAMBS.y, PI * 0.5)
	# canon ch8: the bench in an alcove blooming with foxglove (east wall, facing west)
	b.prop_on_ground(&"alcove_niche", ALCOVE.x, ALCOVE.y, GardenKit.yaw_facing(Vector2(-1.0, 0.0)))
	b.prop_on_ground(&"garden_bench", ALCOVE.x - 0.6, ALCOVE.y, GardenKit.yaw_facing(Vector2(-1.0, 0.0)))
	b.add_box_shape(Transform3D(Basis(), Vector3(ALCOVE.x + 0.7, ManorGrounds.ground(ALCOVE.x, ALCOVE.y) + 1.5, ALCOVE.y)), Vector3(0.8, 3.0, 3.6))


static func _lilac_room(b: GroundsBatch) -> void:
	var r: Rect2 = ROOMS[&"lilac_swing_room"]
	GardenKit.drape_rect(b, r.grow(-1.0), GardenKit.lawn(), LAWN_LIFT, 2.0, "|lawn")
	# the swing faces west, out of its ring of lilac toward the cross walk
	var west := GardenKit.yaw_facing(Vector2(-1.0, 0.0))
	b.prop_on_ground(&"garden_swing", SWING.x, SWING.y, west)
	for side: float in [-1.0, 1.0]:
		var z := SWING.y + side * 1.4
		b.add_cyl_shape(Vector3(SWING.x, ManorGrounds.ground(SWING.x, z), z), 0.1, 3.2)
	for p: Vector2 in [Vector2(-118.0, -142.0), Vector2(-110.0, -142.0), Vector2(-118.0, -104.0), Vector2(-110.0, -104.0)]:
		b.prop_on_ground(&"obelisk_sweetpea", p.x, p.y)
	var bench := SWING + Vector2(0.0, -8.5)
	b.prop_on_ground(&"bench_curved", bench.x, bench.y, GardenKit.yaw_facing(SWING - bench))
	# a round rose bed on the west half, with a standard rose at its heart
	GardenKit.drape_sector(b, ROSE_ROUND, 0.0, 5.0, 0.0, TAU, GardenKit.mulch(), BED_LIFT)
	GardenKit.edging(b, GardenKit.ring(ROSE_ROUND, 5.0, 20))
	b.prop_on_ground(&"rose_standard_pink", ROSE_ROUND.x, ROSE_ROUND.y)


# --- Planting -------------------------------------------------------------------

static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("garden_rooms_plant_v1")
	_plant_walk(sb, rng)
	_plant_topiary_court(sb, rng)
	_plant_moon_garden(sb, rng)
	_plant_lamb_lawn(sb, rng)
	_plant_lilac_room(sb, rng)
	_plant_meadow(sb, rng)


static func _plant_walk(sb: ManorScatter, rng: RandomNumberGenerator) -> void:
	# alliums and catmint under the pergola, lavender-blue and lilac all the way
	# (broken where the room arches open off the walk)
	var stops := [WALK_EAST - 1.0, -101.6, -106.4, -145.6, -150.4, WALK_WEST + 1.0]
	for side: float in [-1.0, 1.0]:
		for k in range(0, stops.size(), 2):
			var x0: float = stops[k]
			var x1: float = stops[k + 1]
			var z := WALK_Z + side * 3.0
			GardenKit.fill_line(sb, &"deco_catmint", PackedVector2Array([Vector2(x0, z), Vector2(x1, z)]), 1.0, rng)
			var z2 := WALK_Z + side * 3.6
			GardenKit.fill_line(sb, &"deco_allium", PackedVector2Array([Vector2(x0 - 0.5, z2), Vector2(x1 + 0.5, z2)]), 1.6, rng)
	# the pickable wisteria hangs at seven of the piers
	for i in 7:
		var x := WALK_EAST - 6.0 - i * 12.0
		sb.put(&"ing_wisteria", x, WALK_Z + (2.6 if i % 2 == 0 else -2.6), rng.randf() * TAU)


static func _plant_topiary_court(sb: ManorScatter, rng: RandomNumberGenerator) -> void:
	var r: Rect2 = ROOMS[&"topiary_court"]
	_inner_border(sb, rng, r, [&"deco_peony", &"deco_lupin", &"deco_catmint", &"deco_lupin"])
	GardenKit.fill_sector(sb, &"deco_catmint", DOVECOTE, 0.7, 2.4, 0.0, TAU, 0.8, rng)


static func _plant_moon_garden(sb: ManorScatter, rng: RandomNumberGenerator) -> void:
	var c := ARMILLARY
	var whites: Array[StringName] = [&"deco_rose_white", &"deco_peony_white", &"deco_foxglove_white", &"deco_rose_cream"]
	for q in 4:
		var a0 := q * PI * 0.5 + MOON_GAP
		var a1 := (q + 1) * PI * 0.5 - MOON_GAP
		GardenKit.fill_sector(sb, &"deco_snowdrop", c, 5.2, 6.2, a0, a1, 0.55, rng)
		GardenKit.fill_sector(sb, whites[q], c, 6.2, 9.8, a0, a1, 1.15, rng)
		GardenKit.fill_sector(sb, whites[(q + 2) % 4], c, 9.8, 13.3, a0, a1, 1.15, rng)
	_inner_border(sb, rng, ROOMS[&"white_moon_garden"], [&"deco_foxglove_white", &"deco_hydrangea", &"deco_peony_white", &"deco_catmint"])


static func _plant_lamb_lawn(sb: ManorScatter, rng: RandomNumberGenerator) -> void:
	var r: Rect2 = ROOMS[&"crab_apple_lawn"]
	# the gnarled crab apples shedding petals like snow (ch8): petal drifts beneath
	for p: Vector2 in CRAB_APPLES:
		sb.put(&"deco_crab_apple", p.x, p.y, rng.randf() * TAU, rng.randf_range(0.85, 1.05))
	for i in 10:
		var p: Vector2 = CRAB_APPLES[i % CRAB_APPLES.size()]
		var a := rng.randf() * TAU
		sb.put(&"ing_crab_apple", p.x + cos(a) * rng.randf_range(1.5, 3.5), p.y + sin(a) * rng.randf_range(1.5, 3.5), rng.randf() * TAU)
	# foxglove crowding the alcove (ch8)
	GardenKit.drift(sb, &"deco_foxglove", ALCOVE + Vector2(-2.5, -3.0), 1.6, 9, rng)
	GardenKit.drift(sb, &"deco_foxglove", ALCOVE + Vector2(-2.5, 3.0), 1.6, 9, rng)
	GardenKit.fill_line(sb, &"deco_foxglove", PackedVector2Array([Vector2(r.end.x - 2.0, r.position.y + 3.0), Vector2(r.end.x - 2.0, ALCOVE.y - 4.0)]), 0.9, rng)
	GardenKit.fill_line(sb, &"deco_foxglove", PackedVector2Array([Vector2(r.end.x - 2.0, ALCOVE.y + 4.0), Vector2(r.end.x - 2.0, -125.5)]), 0.9, rng)
	_inner_border(sb, rng, r, [&"deco_foxglove", &"deco_peony", &"deco_lupin", &"deco_catmint"])
	# buttercups straying in from the meadow, round the lambs too
	GardenKit.drift(sb, &"deco_buttercup", Vector2(-162.0, -118.0), 7.0, 60, rng)
	GardenKit.drift(sb, &"deco_buttercup", LAMBS + Vector2(-3.0, 4.0), 4.0, 24, rng)
	GardenKit.fill_line(sb, &"deco_peony", PackedVector2Array([Vector2(r.position.x + 2.0, r.position.y + 2.0), Vector2(r.end.x - 2.0, r.position.y + 2.0)]), 1.4, rng)


static func _plant_lilac_room(sb: ManorScatter, rng: RandomNumberGenerator) -> void:
	var r: Rect2 = ROOMS[&"lilac_swing_room"]
	# a ring of lilac round the swing lawn, peonies at their feet
	for i in 12:
		var a := TAU * i / 12.0
		var p := GardenKit.on_circle(SWING, 7.5, a)
		if p.x < SWING.x - 5.0:
			continue    # open to the west, toward the cross walk
		sb.put(&"deco_lilac", p.x, p.y, rng.randf() * TAU, rng.randf_range(0.9, 1.15))
		GardenKit.drift(sb, &"deco_peony", GardenKit.on_circle(SWING, 5.6, a), 1.0, 3, rng)
	GardenKit.fill_sector(sb, &"deco_rose_blush", ROSE_ROUND, 1.0, 4.6, 0.0, TAU, 1.0, rng)
	_inner_border(sb, rng, r, [&"deco_hollyhock", &"deco_rose_blush", &"deco_delphinium", &"deco_rose_mauve"])
	GardenKit.fill_sector(sb, &"deco_forget_me_not", SWING, 2.5, 4.4, -PI * 0.4, PI * 0.4, 0.8, rng)


## A mixed border 3 m deep inside a room's yew wall, in drifts, gaps at the arches.
static func _inner_border(sb: ManorScatter, rng: RandomNumberGenerator, r: Rect2, kinds: Array) -> void:
	var g := r.grow(-1.4)
	var corners := [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]
	var k := 0
	for i in 4:
		var a: Vector2 = corners[i]
		var c: Vector2 = corners[(i + 1) % 4]
		var len := a.distance_to(c)
		var dir := (c - a) / len
		var inward := Vector2(-dir.y, dir.x)
		if inward.dot(r.get_center() - a) < 0.0:
			inward = -inward
		var t := 0.0
		while t < len - 1.0:
			var t1 := minf(t + 5.0, len)
			var mid := a + dir * (t + t1) * 0.5
			var clear := true
			for o: Vector2 in ARCHES:
				if o.distance_to(mid - inward * 1.4) < 4.0:
					clear = false
			if r == ROOMS[&"crab_apple_lawn"] and i == 3 and mid.y > MEADOW_OPENING.x - 2.0 and mid.y < MEADOW_OPENING.y + 2.0:
				clear = false
			if r == ROOMS[&"crab_apple_lawn"] and mid.distance_to(ALCOVE) < 5.0:
				clear = false
			if clear:
				for row in 2:
					var id: StringName = kinds[(k + row) % kinds.size()]
					GardenKit.fill_line(sb, id, PackedVector2Array([a + dir * t + inward * (0.4 + row * 1.3), a + dir * t1 + inward * (0.4 + row * 1.3)]), 1.1, rng)
			k += 1
			t = t1


## The open field of lanky meadow buttercups (ch8) beyond the lamb lawn.
static func _plant_meadow(sb: ManorScatter, rng: RandomNumberGenerator) -> void:
	var m := BUTTERCUP_MEADOW
	for i in 70:
		var c := Vector2(rng.randf_range(m.position.x, m.end.x), rng.randf_range(m.position.y, m.end.y))
		GardenKit.drift(sb, &"deco_buttercup", c, 4.0, 22, rng)
