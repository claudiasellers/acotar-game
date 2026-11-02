## The south lawns as a composed landscape park (L56). They are what Feyre
## steps onto when she gets down from the horse on the drive (ManorSitePlan.SPAWN),
## and the user found them "sporadic": every tree, rose bush and flower clump
## had been dropped one by one at random over 660 x 250 m of lawn, so lone
## lollipop trees and single dark rose bushes stood about on a flat green plain.
##
## Now the same plants are composed the way a landscape garden is:
## - blossom groves (cherry, apple, an oak at the heart of the bigger ones)
##   frame the lawns and the view up the drive, each with a woodland skirt
##   of foxgloves and wild strawberries;
## - flower rivers (crocus, tulips, daisies, buttercups, faelight dandelions)
##   sweep in long colour-banded drifts from the drive out to the groves;
## - four rose islands either side of the arrival point, each a ring of red and
##   white roses round a birdbath, sundial or urn, with a bench;
## - a rose gazebo on the west lawn, hung with wisteria and honeysuckle;
## - two serpentine gravel walks leave the drive under rose arbours and wind
##   past the islands to the gazebo and to the pond shore.
## [X] invented: all of it (canon gives lawns and gardens, not their plan).
##
## Positions are a short hand-authored plan (groves, islands, drift lines);
## every plant inside them is generated with fixed seeds (R8/R15).
class_name ManorParkland
extends RefCounted

## Groves: [centre, radius, [[species, count], ...]]. The first species is the heart.
const GROVES := [
	[Vector2(-44.0, 58.0), 9.0, [[&"deco_cherry_blossom", 5]]],
	[Vector2(44.0, 58.0), 9.0, [[&"deco_cherry_blossom", 5]]],
	[Vector2(-98.0, 118.0), 13.0, [[&"deco_oak", 1], [&"deco_apple_blossom", 5]]],
	[Vector2(96.0, 196.0), 13.0, [[&"deco_oak", 1], [&"deco_apple_blossom", 5]]],
	[Vector2(-158.0, 64.0), 12.0, [[&"deco_oak", 2], [&"deco_apple_blossom", 4]]],
	[Vector2(-128.0, 248.0), 15.0, [[&"deco_oak", 2], [&"deco_apple_blossom", 5]]],
	[Vector2(-64.0, 252.0), 11.0, [[&"deco_cherry_blossom", 5]]],
	[Vector2(64.0, 252.0), 11.0, [[&"deco_cherry_blossom", 5]]],
	[Vector2(150.0, 262.0), 14.0, [[&"deco_oak", 2], [&"deco_apple_blossom", 4]]],
	[Vector2(282.0, 210.0), 14.0, [[&"deco_oak", 3], [&"deco_apple_blossom", 3]]],
	[Vector2(292.0, 64.0), 12.0, [[&"deco_oak", 1], [&"deco_apple_blossom", 4]]],
	[Vector2(-262.0, 258.0), 13.0, [[&"deco_oak", 2], [&"deco_apple_blossom", 3]]],
	[Vector2(-310.0, 62.0), 11.0, [[&"deco_oak", 1], [&"deco_apple_blossom", 3]]],
	[Vector2(108.0, 52.0), 10.0, [[&"deco_apple_blossom", 4]]],
	[Vector2(-98.0, 224.0), 10.0, [[&"deco_cherry_blossom", 4]]],
	# L56-2: the middle distance of the views west and east from the dismount
	[Vector2(-86.0, 160.0), 11.0, [[&"deco_oak", 1], [&"deco_cherry_blossom", 4]]],
	[Vector2(84.0, 146.0), 10.0, [[&"deco_cherry_blossom", 4]]],
	# L56-3: the middle plane of the view west along the walk (it was an empty slope)
	[Vector2(-56.0, 146.0), 13.0, [[&"deco_oak", 1], [&"deco_cherry_blossom", 3], [&"deco_apple_blossom", 3]]],
]
## Groves that get a shrub understorey (lilacs) as well as the flower skirt.
const UNDERSTOREY := [Vector2(-56.0, 146.0), Vector2(-86.0, 160.0)]

## Long meadow grass on the park's outer edges (L56-3): mown near the house,
## longer the further out. Starts this far either side of the drive and this
## far down the lawns, full strength MEADOW_FADE metres further on.
const MEADOW_X := 175.0
const MEADOW_Z := 238.0
const MEADOW_FADE := 60.0
## Tussocks per square metre where the meadow is at full strength.
const MEADOW_DENSITY := 0.16
## Trees in a grove stand at least this far apart (canopies touch, never merge).
const TREE_GAP := 5.2

## Rose islands either side of the arrival: [centre, centrepiece prop, keepsake].
const ISLANDS := [
	[Vector2(-34.0, 104.0), &"birdbath", &"col_glass_marble"],
	[Vector2(34.0, 104.0), &"sundial", &"col_painted_pebble"],
	[Vector2(-58.0, 178.0), &"garden_urn", &"col_lost_ribbon"],
	[Vector2(58.0, 178.0), &"birdbath", &"col_glass_marble"],
]
const ISLAND_R := 4.6          # rose ring radius
const ISLAND_BED := 6.2        # mulch bed radius (lilacs stand on its rim)
const ISLAND_ROSES := 14

const GAZEBO := Vector2(-150.0, 172.0)
const GAZEBO_ROSES := 22

## The walks: from the drive (under an arbour) out past the islands.
const WALK_W := 2.6
const WALKS := [
	[Vector2(-3.6, 154.5), Vector2(-22.0, 158.0), Vector2(-36.0, 172.0), Vector2(-50.0, 192.0), Vector2(-74.0, 194.0), Vector2(-112.0, 180.0), Vector2(-144.0, 172.0)],
	[Vector2(3.6, 154.5), Vector2(22.0, 158.0), Vector2(36.0, 172.0), Vector2(50.0, 192.0), Vector2(74.0, 194.0), Vector2(100.0, 176.0), Vector2(112.0, 160.0)],
]
const WALK_CLEAR := 2.2

## Flower rivers: [points, width, colour bands (species in order along the drift)].
const DRIFTS := [
	[[Vector2(-8.0, 90.0), Vector2(-26.0, 78.0), Vector2(-60.0, 80.0), Vector2(-92.0, 96.0), Vector2(-130.0, 92.0), Vector2(-170.0, 84.0)], 7.0,
		[&"deco_tulip_bed"]],
	[[Vector2(8.0, 90.0), Vector2(26.0, 78.0), Vector2(60.0, 80.0), Vector2(92.0, 70.0), Vector2(130.0, 60.0), Vector2(170.0, 52.0)], 7.0,
		[&"deco_tulip_bed"]],
	[[Vector2(-8.0, 128.0), Vector2(-30.0, 136.0), Vector2(-70.0, 140.0), Vector2(-110.0, 152.0), Vector2(-176.0, 132.0), Vector2(-212.0, 76.0), Vector2(-300.0, 66.0)], 8.0,
		[&"deco_tulip_bed"]],
	[[Vector2(8.0, 128.0), Vector2(30.0, 132.0), Vector2(70.0, 128.0), Vector2(100.0, 124.0)], 7.0,
		[&"deco_tulip_bed"]],
	[[Vector2(-8.0, 214.0), Vector2(-40.0, 222.0), Vector2(-90.0, 212.0), Vector2(-140.0, 214.0), Vector2(-200.0, 228.0), Vector2(-300.0, 222.0)], 8.0,
		[&"deco_tulip_bed"]],
	[[Vector2(8.0, 214.0), Vector2(40.0, 222.0), Vector2(90.0, 232.0), Vector2(140.0, 228.0), Vector2(200.0, 214.0), Vector2(250.0, 186.0), Vector2(320.0, 170.0)], 8.0,
		[&"deco_tulip_bed"]],
]
## The middle lawns, either side of the walks.
const MID_DRIFTS := [
	[[Vector2(-24.0, 182.0), Vector2(-40.0, 206.0), Vector2(-76.0, 206.0), Vector2(-118.0, 196.0), Vector2(-172.0, 200.0)], 7.0,
		[&"deco_tulip_bed"]],
	[[Vector2(24.0, 182.0), Vector2(40.0, 206.0), Vector2(76.0, 210.0), Vector2(118.0, 214.0)], 7.0,
		[&"deco_tulip_bed"]],
]
## Instances per square metre of drift (feathered towards the edges).
const DRIFT_DENSITY := 1.1


static func zone() -> Rect2:
	return ManorSitePlan.SOUTH_LAWNS


## Scatter keeps out of the islands and the gazebo (walks are checked by line).
static func footprints() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for isl: Array in ISLANDS:
		var c: Vector2 = isl[0]
		out.append(Rect2(c - Vector2.ONE * ISLAND_BED, Vector2.ONE * ISLAND_BED * 2.0))
	out.append(Rect2(GAZEBO - Vector2.ONE * 7.0, Vector2.ONE * 14.0))
	return out


## True where another garden plants inside the lawns' rect (the walled orchard,
## the pond, the drive's borders and avenue): the parkland's composition rules skip it.
static func is_elsewhere(p: Vector2) -> bool:
	if absf(p.x - ManorSitePlan.DRIVE_START.x) < ManorSitePlan.DRIVE_WIDTH * 0.5 + 8.5:   # the borders and the avenue
		return true
	if ManorSitePlan.WALLED_ORCHARD.grow(4.0).has_point(p) or ManorSitePlan.in_pond(p.x, p.y, 1.5):
		return true
	for r in ManorOrchard.footprints() + ManorPond.footprints() + ManorForecourt.footprints():
		if r.grow(2.0).has_point(p):
			return true
	return false


## A walk's centre line, rounded through its control points (Catmull-Rom, ~2 m steps).
static func walk_line(ctrl: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in ctrl.size() - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, ctrl.size() - 1)]
		var n := maxi(2, ceili(p1.distance_to(p2) / 2.0))
		for k in n:
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[-1])
	return out


static var _lines: Array[PackedVector2Array] = []


static func walk_lines() -> Array[PackedVector2Array]:
	if _lines.is_empty():
		for w: Array in WALKS:
			_lines.append(walk_line(w))
	return _lines


static func near_walk(p: Vector2, clear: float = WALK_CLEAR) -> bool:
	for w in walk_lines():
		for i in w.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, w[i], w[i + 1]).distance_to(p) < WALK_W * 0.5 + clear:
				return true
	return false


static func _open(x: float, z: float) -> bool:
	return ManorScatter.is_free(x, z) and not near_walk(Vector2(x, z))


## Tree positions of one grove: the heart first, then a jittered spiral out.
static func grove_trees(g: Array) -> Array:
	var c: Vector2 = g[0]
	var r: float = g[1]
	var rng := EstateKit.rng("parkland_grove|%d|%d" % [roundi(c.x), roundi(c.y)])
	var out: Array = []   # [species, Vector2, scale]
	var want: Array = []
	for s: Array in g[2]:
		for k in int(s[1]):
			want.append(s[0])
	var pts: Array[Vector2] = []
	var tries := 0
	while pts.size() < want.size() and tries < 400:
		tries += 1
		var p := c
		if not pts.is_empty():
			var a := rng.randf() * TAU
			p = c + Vector2(cos(a), sin(a)) * rng.randf_range(TREE_GAP * 0.9, r)
		if not _open(p.x, p.y):
			continue
		if pts.any(func(q: Vector2) -> bool: return q.distance_to(p) < TREE_GAP):
			continue
		# each new tree leans on one already there, so the grove reads as one clump
		if not pts.is_empty() and not pts.any(func(q: Vector2) -> bool: return q.distance_to(p) < TREE_GAP * 1.6):
			continue
		pts.append(p)
	for i in pts.size():
		var heart := i == 0
		# the apple model is a small tree: scaled up to stand with the cherries and oaks
		var boost := 1.6 if want[i] == &"deco_apple_blossom" else 1.0
		out.append([want[i], pts[i], boost * (rng.randf_range(1.15, 1.3) if heart else rng.randf_range(0.82, 1.08))])
	return out


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("parkland")
	# Groves, each with a woodland skirt.
	for g: Array in GROVES:
		var c: Vector2 = g[0]
		var r: float = g[1]
		for t: Array in grove_trees(g):
			var p: Vector2 = t[1]
			sb.put(t[0], p.x, p.y, rng.randf() * TAU, t[2])
		# one skirt flower per grove: foxgloves under oaks, wild strawberries under blossom
		var skirt: StringName = &"ing_foxglove" if (g[2] as Array)[0][0] == &"deco_oak" else &"ing_wild_strawberry"
		for k in 14:
			var a := rng.randf() * TAU
			var p := c + Vector2(cos(a), sin(a)) * (r + rng.randf_range(0.0, 4.0))
			if not _open(p.x, p.y):
				continue
			sb.put(skirt, p.x, p.y, rng.randf() * TAU, rng.randf_range(0.9, 1.2))
		if c in UNDERSTOREY:
			for k in 7:
				var a := TAU * (k + rng.randf() * 0.6) / 7.0
				var p := c + Vector2(cos(a), sin(a)) * (r * rng.randf_range(0.55, 0.95))
				if _open(p.x, p.y):
					sb.put(&"ing_lilac", p.x, p.y, rng.randf() * TAU, rng.randf_range(1.0, 1.3))
	# Rose islands.
	for isl: Array in ISLANDS:
		var c: Vector2 = isl[0]
		for k in ISLAND_ROSES:
			var a := TAU * k / ISLAND_ROSES
			# a full ring of flowering rose bushes, the gatherable roses in front of them
			sb.put(&"deco_rose_pink", c.x + cos(a) * ISLAND_R, c.y + sin(a) * ISLAND_R, a, rng.randf_range(1.35, 1.6))
			var b := a + PI / ISLAND_ROSES
			sb.put(&"ing_rose_red" if k % 2 == 0 else &"ing_rose_white", c.x + cos(b) * (ISLAND_R - 1.6), c.y + sin(b) * (ISLAND_R - 1.6), b, rng.randf_range(1.05, 1.2))
		for k in 4:
			var a := TAU * (k + 0.5) / 4.0
			sb.put(&"ing_lilac", c.x + cos(a) * (ISLAND_BED + 0.8), c.y + sin(a) * (ISLAND_BED + 0.8), a, 1.1)
		sb.put(isl[2], c.x + 1.2, c.y + 0.8, rng.randf() * TAU)
	# The gazebo's rose ring, wisteria and honeysuckle.
	for k in GAZEBO_ROSES:
		var a := TAU * k / GAZEBO_ROSES
		if absf(angle_difference(a, 0.0)) < 0.35:
			continue   # the doorway faces east, onto the walk
		sb.put(&"deco_rose_pink", GAZEBO.x + cos(a) * 5.6, GAZEBO.y + sin(a) * 5.6, a, 1.45)
		if k % 2 == 0:
			sb.put(&"ing_rose_red" if k % 4 != 0 else &"ing_rose_white", GAZEBO.x + cos(a) * 4.2, GAZEBO.y + sin(a) * 4.2, a, 1.15)
	for k in 6:
		var a := TAU * (k + 0.5) / 6.0
		sb.put(&"ing_wisteria" if k % 2 == 0 else &"ing_honeysuckle", GAZEBO.x + cos(a) * 3.0, GAZEBO.y + sin(a) * 3.0, a, 1.0)
	sb.put(&"col_lost_ribbon", GAZEBO.x + 0.6, GAZEBO.y - 0.4, 0.0)
	# Wisteria on the arbours where the walks leave the drive.
	for w: Array in WALKS:
		var p: Vector2 = (w[0] as Vector2).lerp(w[1], 0.5)
		var d: Vector2 = ((w[1] as Vector2) - (w[0] as Vector2)).normalized()
		for side: float in [-1.0, 1.0]:
			var q := p + Vector2(-d.y, d.x) * side * 1.8
			sb.put(&"ing_wisteria", q.x, q.y, 0.0, 0.8)
	# Flower rivers.
	for d: Array in DRIFTS + MID_DRIFTS:
		_plant_drift(sb, d, rng)
	_plant_meadow(sb)
	# Keepsakes on the benches and by the drive.
	sb.put(&"col_tiny_horseshoe", -10.0, 236.0, 0.4)
	sb.put(&"col_tiny_horseshoe", 12.0, 62.0, 1.1)
	sb.put(&"col_painted_pebble", 66.0, 176.0, 0.0)


## 0 on the mown lawns, rising to 1 towards the park's outer edges.
static func meadow_weight(p: Vector2) -> float:
	var t := maxf((absf(p.x) - MEADOW_X) / MEADOW_FADE, (p.y - MEADOW_Z) / (MEADOW_FADE * 0.6))
	return clampf(t, 0.0, 1.0)


static func _plant_meadow(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("parkland_meadow")
	var z := zone()
	var step := 1.0 / sqrt(MEADOW_DENSITY)
	var y := z.position.y
	while y < z.end.y:
		var x := z.position.x
		while x < z.end.x:
			var p := Vector2(x, y) + Vector2(rng.randf(), rng.randf()) * step
			var w := meadow_weight(p)
			# patchy, not a uniform carpet: thins in soft swathes
			var patch := 0.6 + 0.4 * sin(p.x * 0.07 + 1.3) * sin(p.y * 0.09)
			if rng.randf() < w * w * (3.0 - 2.0 * w) * patch and not is_elsewhere(p) and _open(p.x, p.y):
				sb.put(&"deco_meadow_grass", p.x, p.y, rng.randf() * TAU, rng.randf_range(0.8, 1.3) * (0.7 + 0.4 * w))
			x += step
		y += step


static func _plant_drift(sb: ManorScatter, d: Array, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array(d[0])
	var width: float = d[1]
	var bands: Array = d[2]
	var lengths: Array[float] = [0.0]
	for i in pts.size() - 1:
		lengths.append(lengths[-1] + pts[i].distance_to(pts[i + 1]))
	var total: float = lengths[-1]
	var n := roundi(total * width * DRIFT_DENSITY)
	for k in n:
		var s := rng.randf() * total
		var i := 0
		while i < pts.size() - 2 and lengths[i + 1] < s:
			i += 1
		var seg := pts[i + 1] - pts[i]
		var t := (s - lengths[i]) / maxf(seg.length(), 0.01)
		var along := pts[i].lerp(pts[i + 1], t)
		var normal := Vector2(-seg.y, seg.x).normalized()
		# soft edges: sum of two uniforms, and the river breathes along its length
		var swell := 0.75 + 0.25 * sin(s * 0.09 + pts[0].x)
		var off := (rng.randf() + rng.randf() - 1.0) * width * 0.5 * swell
		var p := along + normal * off
		if not _open(p.x, p.y):
			continue
		# One colour per 64 m scatter chunk, so the river changes colour in long
		# blocks along its length and each chunk draws one flower layer, not five
		# (the chunk guard is the binding draw budget).
		var ck := Vector2i(floori(p.x / ManorScatter.CHUNK), floori(p.y / ManorScatter.CHUNK))
		var id: StringName = bands[posmod(ck.x * 7 + ck.y * 3, bands.size())]
		# the finds hide among the bloom: crocus and faelight dandelions to gather
		# daisies froth through the tulips (alone they are too small to read as a river)
		if rng.randf() < 0.3:
			id = &"deco_daisy"
		elif rng.randf() < 0.22:
			id = &"ing_crocus" if rng.randf() < 0.55 else &"ing_faelight_dandelion"
		# fuller towards the middle of the river, so it reads as a sweep from afar
		var mid := 1.0 - absf(off) / (width * 0.5)
		sb.put(id, p.x, p.y, rng.randf() * TAU, rng.randf_range(1.2, 1.5) + 0.6 * mid)


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "Parkland")
	ManorLawnStripes.build(b.root)
	for w: Array in WALKS:
		b.drape_ribbon(walk_line(w), WALK_W, ManorForecourt.drive_lanes(), 0.08, 1.0)
		# a rose arbour where each walk leaves the drive
		var p: Vector2 = (w[0] as Vector2).lerp(w[1], 0.5)
		var dir: Vector2 = ((w[1] as Vector2) - (w[0] as Vector2)).normalized()
		b.prop_on_ground(&"rose_arbor", p.x, p.y, atan2(dir.x, dir.y))
	for isl: Array in ISLANDS:
		var c: Vector2 = isl[0]
		var y := ManorGrounds.ground(c.x, c.y)
		b.disc(Vector3(c.x, y + 0.04, c.y), Vector2.ONE * ISLAND_BED, GardenKit.mulch())
		b.torus(Vector3(c.x, y + 0.05, c.y), ISLAND_BED - 0.15, ISLAND_BED + 0.2, ManorGrounds.marble())
		b.prop(isl[1], Vector3(c.x, y + 0.04, c.y))
		# a bench facing the house across the ring
		var to_walk := Vector2(0.0, 1.0) if c.y < 140.0 else Vector2(0.0, -1.0)
		var bp := c + to_walk * (ISLAND_BED + 1.6)
		b.prop_on_ground(&"garden_bench", bp.x, bp.y, atan2(-to_walk.x, -to_walk.y))
	var gy := ManorGrounds.ground(GAZEBO.x, GAZEBO.y)
	b.disc(Vector3(GAZEBO.x, gy + 0.04, GAZEBO.y), Vector2.ONE * 6.4, GardenKit.mulch())
	b.prop(&"gazebo", Vector3(GAZEBO.x, gy + 0.04, GAZEBO.y), PI * 0.5)
	b.prop_on_ground(&"garden_urn", GAZEBO.x + 7.0, GAZEBO.y - 2.6)
	b.prop_on_ground(&"garden_urn", GAZEBO.x + 7.0, GAZEBO.y + 2.6)
	b.flush()
