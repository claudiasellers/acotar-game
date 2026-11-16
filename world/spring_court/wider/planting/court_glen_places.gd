class_name CourtGlenPlaces
extends RefCounted
## The Starlight Glen's composed places (docs/lanes/court-planting-by-place.md,
## "The whole glen, composed"; owner, 2026-11-16: "make the ENTIRE thing here
## look intentional ... to make the person FEEL something as they walk
## through", "make sure to make each place feel a little special").
##
## Each place has one feeling, a first sight, ground kept open, and one thing no
## other place has. The glen's colours stay silver, blue and white; a place
## takes one accent and keeps it. This file holds the main walk, the way in
## from the estate to the pool along `glen_way`:
##   1 the Brae gate   bare, windy turf, then two old thorns in full may leaning
##                     in over the way on the crest: the Thorn Gate, the first
##                     thing on the skyline as you climb from the estate; their
##                     petals lie on the path. Thorn bushes down the lee side.
##   2 Brook Dell      close, cool and green: two great elms over the crossing,
##                     oaks and birches by the way so you walk in under them,
##                     birches along the brook, and the glen's only floor of
##                     fern; mossed stones; snowdrops in ribbons
##                     at the water (white overhead on the brae, white underfoot
##                     here). The fern starts before you see the water.
##   3 the Ford        full sun and wide water. Willows in a row on the far
##                     bank, parted where the way lands; iris at the water; and
##                     kingcups on both banks, the only gold in the glen. The
##                     first of them stand in the dell's mouth.
##   4 the Knoll Walk  the knolls beside the way crowned each its own way, in
##                     order: an old thorn, three white birches, two aspens, the
##                     great cherry at Knoll Steps (the one pink tree on the
##                     way, its petals falling), and last a great oak, the
##                     darkest thing, before the bare mound, the lightest. A
##                     crescent of bluebells at each knoll's foot on the side
##                     the way passes, and from the near knolls a spill of them
##                     down to the way's edge.
##   5 the Mound       nothing over the knee, so the climb shows only sky; a
##                     ring of daisies on the crown, where you stand to look.
## And the south loop, pool to mere to river:
##   6 Glimmer Brook   being beckoned. Little lights (faelights, glowcaps) down
##                     the brook's outer bank only, with snowdrops, from the
##                     pool's ring to the mere: at dusk a string of lights going
##                     round the bend ahead of you. A group of three trees at
##                     intervals on that bank, birches by the pool giving way to
##                     willows one for one toward the mere. The inner bank, the
##                     one you walk, stays sward.
##   7 Willow Mere     hush. Willows all round as a curtain, two deep, so you do
##                     not see the water until you step through the one parting
##                     where the brook leaves; from there the Weeping Lady
##                     stands across the water. Nothing between them and her:
##                     no willow near her, no reed in the line. Only white on
##                     the ground (snowdrops under the willows).
##     the mere run    out through open sward to the river, a pair of willows
##                     where it meets it.
## And the north loop, the dell to the oaks to the lake and back:
##   8 River Road      easy company. Where the road runs beside the brae brook
##                     north of the dell, aspens stand in pairs either side of
##                     it: the Aspen Row, the glen's one avenue, 27 m columns
##                     that carry you toward the oaks' dark mass ahead.
##   9 Oak Glade       age and shelter, a hall. Great oaks in a ring round the
##                     clearing with a second rank of oaks behind, parted
##                     where the road goes in and out between two trunks; under
##                     them the only closed shade in the glen and a floor of
##                     white wood anemones, foxgloves in the light at the
##                     clearing's rim. The oldest oak stands alone on the knoll
##                     by the oak knoll.
##  10 Looking Lake    stillness. The lake walk ends between two great elms on
##                     the rim, the whole lake below at once. The far shore is
##                     a dark wood of oak and elm down to the water, and its
##                     reflection lies on the lake (mirror(): the water paints
##                     it). The near shore is open short sward; reeds stand in
##                     two bays only.
##  11 Heron Stones    watching and waiting: the glen's one reed bed, taller
##                     than you, round the stones, with a narrow parting through
##                     it from the lake's side and another toward the Knoll Walk.
## Everything is found from the land (the way's own line, where it meets the
## brook and the river, the knolls' tops), so a change to the land moves the
## planting with it. The rules in CourtGlenPlanting plant only ground this
## file has not claimed.

const WAY := &"glen_way"
## The rules plant no tree and no verge this near the main walk.
const CLAIM := 70.0
## The way every old thorn in the glen leans: east and a little north, the
## wind off the fells. (The two at the brae's gate lean toward each other.)
const WIND := Vector2(0.94, -0.34)

## The Thorn Gate: how far past the brae's crest it stands (m along the way),
## each trunk's distance from the way's middle, and the thorns' size (an old
## thorn is 7 m at size 1).
const GATE_PAST_CREST := 6.0
const GATE_HALF := 5.6
const GATE_SIZE := 1.55
## Thorn bushes down the brae's lee side: how many, over how many metres of way.
const LEE_BUSHES := 10
const LEE_REACH := 78.0

## Brook Dell. Birches along the brae brook: [metres along the brook from the
## crossing (downstream is +), side (+1 the east bank), metres back from the
## water, trees]; and pairs by the way on the dell's east side, this many
## metres before the crossing.
const DELL_BIRCHES := [
	[-56.0, 1.0, 7.0, 2], [-41.0, -1.0, 8.0, 1], [-27.0, 1.0, 6.5, 2], [-13.0, -1.0, 9.5, 1],
	[17.0, 1.0, 7.0, 2], [31.0, -1.0, 7.5, 1], [46.0, 1.0, 8.0, 2], [62.0, -1.0, 7.0, 1],
]
## The trees you walk in under: [metres along the way from the crossing (before
## it is -), side, species]. Oaks for the shade, birches for the white stems.
const DELL_WAY := [
	[-52.0, -1.0, &"birch"], [-51.0, 1.0, &"birch"], [-38.0, -1.0, &"oak"], [-35.0, 1.0, &"birch"], [-23.0, 1.0, &"oak"],
	[-21.0, -1.0, &"birch"], [14.0, 1.0, &"oak"], [16.0, -1.0, &"birch"], [28.0, -1.0, &"oak"], [31.0, 1.0, &"birch"],
]
## And a second rank behind them, so the dell is a grove and not a row: [along, side, metres off the way].
const DELL_BACK := [[-45.0, -1.0, 18.0], [-29.0, 1.0, 19.0], [-12.0, -1.0, 21.0], [21.0, 1.0, 18.0], [23.0, -1.0, 20.0], [40.0, 1.0, 16.0]]
const DELL_FERNS := 1500
## The fern floor's half-width at the brook (m) and how far it runs up and down it.
const DELL_HALF := 26.0
const DELL_UP := 62.0
const DELL_DOWN := 72.0

## The Ford. Willows on the far bank: metres along the river from the crossing
## (downstream +); none within the gap where the way lands.
const FORD_WILLOWS := [-67.0, -53.0, -40.0, -28.0, -16.0, 30.0, 43.0, 56.0, 69.0]
## No willow this near the way on the far bank: the landing is open, and no frond hangs in your face.
const FORD_GAP := 20.0
const FORD_GOLD := 900
## How far up and down the river the gold runs, and how far back from the water.
const FORD_REACH := 58.0
const FORD_BACK := 7.5

## The Knoll Walk, and the knolls round it. [near x, near z (the knoll's top is
## found from the land), species, trees, size, the shade each throws (m; 0: no
## flowers); then, for a knoll off the main walk, its flower and the site its
## flowers face]. In the order you pass them.
const KNOLLS := [
	[-1027.0, 192.0, &"old_thorn", 1, 1.6, 8.0],        # south of the way, the first at hand: the mark from mid-river
	[-1082.0, 44.0, &"pillar_birch", 3, 1.0, 8.0],      # north, far off: white stems, the pool's tree seen before the pool
	[-1023.0, 257.0, &"aspen_spire", 2, 1.0, 6.0],      # south, far off: two columns
	[-1128.0, 142.0, &"great_cherry", 1, 1.0, 12.0],    # Knoll Steps: the Blossom Knoll
	[-1159.0, 218.0, &"great_oak", 1, 1.08, 15.0],      # hard by the way, the last and darkest
	[-1231.0, 198.0, &"pillar_birch", 2, 0.95, 8.0],    # north of the mound, toward the pool
	[-779.0, 113.0, &"old_thorn", 1, 1.5, 0.0],         # the brae's outer knolls: a thorn each, leaning with the wind
	[-815.0, -89.0, &"old_thorn", 1, 1.45, 0.0],
	[-885.0, -267.0, &"great_oak", 1, 1.3, 16.0, &"anemone", &"oak_glade"],   # by the oak knoll: the oldest oak, alone, looking down on the glade
]
const KNOLL_SNAP := 14.0
## A knoll this near the way spills its bluebells down to it; patches tried per metre of the spill.
const SPILL_REACH := 70.0
const SPILL_TRIES := 16.0
const CHERRY_PETALS := 190

## The Mound's daisy ring: its radius and how many daisies.
const RING := 3.4
const RING_DAISIES := 46


## Glimmer Brook's tree groups, on its outer bank: [metres down the brook from
## the mere, species of each of the three].
const GLIMMER_GROUPS := [
	[214.0, [&"pillar_birch", &"pillar_birch", &"pillar_birch"]],
	[152.0, [&"birch", &"birch", &"willow"]],
	[97.0, [&"birch", &"willow", &"willow"]],
	[46.0, [&"willow", &"willow", &"willow"]],
]
## The lights: a cluster this often along the brook (m), from this far down it
## (just outside the pool's ring) to this near the mere.
const GLIMMER_STEP := 2.3
## And a light in the air this often (CourtMotes draws them from dusk).
const LIGHT_STEP := 2.8
const GLIMMER_FROM := 252.0
const GLIMMER_TO := 12.0
## The rules plant no clump this near the Glimmer Brook or the mere run, or this far out from the mere's shore.
const BROOK_CLAIM := 45.0
const MERE_CLAIM := 34.0
## Willow Mere's curtain: willows in the inner ring, the half-width (radians)
## of the parting, of the ground kept clear before the Weeping Lady, and of
## the gap the mere run leaves by.
const MERE_WILLOWS := 25
const MERE_PARTING := 0.2
const MERE_LADY := 0.56
const MERE_OUTLET := 0.13

## The Aspen Row: along the river road, from this far north of where it leaves
## the main walk to this far (m), a pair every so often, each this far from the
## road's middle.
const ROW_FROM := 88.0
const ROW_TO := 250.0
const ROW_STEP := 14.5
const ROW_HALF := 6.4
## The Oak Glade: great oaks in the ring and oaks in the rank behind, the
## rings' radii (the clearing kept open is 55 m), and no trunk this near a path.
const GLADE_OAKS := 13
const GLADE_RING := 64.0
const GLADE_BACK := 17
const GLADE_BACK_RING := 81.0
const GLADE_DOOR := 9.0
## Looking Lake's far wood: trees, its half-arc (radians) round the shore from
## straight across, and how far back from the water it runs (m).
const LAKE_WOOD := 78
const LAKE_ARC := 1.25
const LAKE_DEPTH := 40.0
## Its reflection, as the water paints it: the wood's front rank's distance
## from the shore, the height of its crowns over the water, its colour.
const MIRROR_BACK := 7.0
const MIRROR_HEIGHT := 19.0
const MIRROR_COLOUR := Color(0.07, 0.25, 0.2)
const MIRROR_STRENGTH := 0.8
## The Heron Stones' reed bed: reeds, its inner and outer radii, the partings' half-width (radians).
const REEDS := 520
const REED_INNER := 6.5
const REED_OUTER := 21.0
const REED_PARTING := 0.13

static var _lock := Mutex.new()
static var _way := PackedVector2Array()
static var _lengths := PackedFloat32Array()


## The main walk's line (glen_way), and the length along it to each point.
static func way() -> PackedVector2Array:
	_lock.lock()
	if _way.is_empty():
		for path: Dictionary in CourtHeight.paths():
			if path["id"] == WAY:
				_way = path["points"]
		var run := 0.0
		_lengths.resize(_way.size())
		for i in _way.size():
			if i > 0:
				run += _way[i].distance_to(_way[i - 1])
			_lengths[i] = run
	var w := _way
	_lock.unlock()
	return w


static func way_length() -> float:
	way()
	return _lengths[_lengths.size() - 1] if not _lengths.is_empty() else 0.0


## The point `s` metres along the way from the estate.
static func at(s: float) -> Vector2:
	var w := way()
	if w.is_empty():
		return Vector2.ZERO
	s = clampf(s, 0.0, way_length())
	for i in range(1, w.size()):
		if _lengths[i] >= s:
			var span := _lengths[i] - _lengths[i - 1]
			return w[i - 1].lerp(w[i], (s - _lengths[i - 1]) / span if span > 0.001 else 0.0)
	return w[w.size() - 1]


## The way's heading there (toward the pool).
static func heading(s: float) -> Vector2:
	var d := at(s + 3.0) - at(s - 3.0)
	return d.normalized() if d.length() > 0.01 else Vector2.RIGHT


## How far along the way its nearest point to `p` lies, and how far off `p` is: [s, distance].
static func along(p: Vector2) -> Array:
	var w := way()
	var best := INF
	var s := 0.0
	for i in range(1, w.size()):
		var q := Geometry2D.get_closest_point_to_segment(p, w[i - 1], w[i])
		var d := q.distance_to(p)
		if d < best:
			best = d
			s = _lengths[i - 1] + w[i - 1].distance_to(q)
	return [s, best]


## Ground the main walk holds (its own sides, and the ford's reach of the
## river): the rules crown no knoll and plant no clump here.
static func claims_way(p: Vector2) -> bool:
	if way().is_empty():
		return false
	if float(along(p)[1]) < CLAIM:
		return true
	var f := ford()
	return not f.is_empty() and p.distance_to(f[1]) < FORD_REACH + 45.0


## Ground any composed place holds: the rules plant no clump of trees here.
static func claims(p: Vector2) -> bool:
	if claims_way(p):
		return true
	var mere := CourtGlenPlanting._lake_named(&"willow_mere")
	if not mere.is_empty() and p.distance_to(mere["center"]) < float(mere["radius"]) + MERE_CLAIM:
		return true
	for id: StringName in [&"glimmer_brook", &"mere_run", &"lake_run"]:
		if _near(p, brook(id), BROOK_CLAIM):
			return true
	# the north loop: the Aspen Row, the Oak Glade's rings, the lake walk's bare rise, the lake's shores, the reed bed
	var lake := CourtGlenPlanting._lake_named(&"looking_lake")
	if not lake.is_empty() and p.distance_to(lake["center"]) < float(lake["radius"]) + LAKE_DEPTH + 12.0:
		return true
	if p.distance_to(CourtHeight.site(&"oak_glade")) < GLADE_BACK_RING + 16.0 or p.distance_to(CourtHeight.site(&"heron_stones")) < REED_OUTER + 14.0:
		return true
	if _near(p, path(&"lake_walk"), 40.0):
		return true
	var road := path(&"river_road")
	if not road.is_empty() and _near(p, road, 30.0):
		var from_start := p.distance_to(road[road.size() - 1])
		return from_start > ROW_FROM - 25.0 and from_start < ROW_TO + 25.0
	return false


static func _near(p: Vector2, line: PackedVector2Array, within: float) -> bool:
	for i in range(1, line.size()):
		if Geometry2D.get_closest_point_to_segment(p, line[i - 1], line[i]).distance_to(p) < within:
			return true
	return false


## A path's line by name (empty if the land has none).
static func path(id: StringName) -> PackedVector2Array:
	for q: Dictionary in CourtHeight.paths():
		if q["id"] == id:
			return q["points"]
	return PackedVector2Array()


## A brook's line by name (empty if the land has none).
static func brook(id: StringName) -> PackedVector2Array:
	for b: Dictionary in CourtHeight.brooks():
		if b["id"] == id:
			return b["points"]
	return PackedVector2Array()


## Whether a knoll's top is one this file crowns (further from the way than it claims).
static func crowns(top: Vector2) -> bool:
	for k: Array in KNOLLS:
		if top.distance_to(Vector2(k[0], k[1])) < KNOLL_SNAP:
			return true
	return false


## The turn that leans an old thorn toward `to` (its model leans to +X).
static func lean_yaw(to: Vector2) -> float:
	return atan2(-to.y, to.x)


static func wind_yaw(rng: RandomNumberGenerator) -> float:
	return lean_yaw(WIND) + rng.randf_range(-0.14, 0.14)


## Where the way tops the brae (the highest point of its first stretch).
static func crest() -> float:
	var best := 0.0
	var high := -INF
	var s := 0.0
	while s < minf(320.0, way_length()):
		var p := at(s)
		var h := WorldHeight.height_at(p.x, p.y)
		if h > high + 0.05:
			high = h
			best = s
		s += 3.0
	return best


## Where the way crosses the brae brook: [s along the way, the brook's line, the index of its nearest point].
static func brook_crossing() -> Array:
	for brook: Dictionary in CourtHeight.brooks():
		if brook["id"] != &"brae_brook":
			continue
		var pts: PackedVector2Array = brook["points"]
		var best := INF
		var at_i := 0
		var s := 0.0
		for i in pts.size():
			var a := along(pts[i])
			if float(a[1]) < best:
				best = a[1]
				at_i = i
				s = a[0]
		return [s, pts, at_i, float(brook["half_width"])]
	return []


## Where the way crosses the Thornwater: [s along the way, the point, the river's heading there (downstream)].
static func ford() -> Array:
	var line: Array = MacroHeight.THORNWATER
	var w := way()
	for i in range(1, w.size()):
		for k in line.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(w[i - 1], w[i], line[k], line[k + 1])
			if hit != null:
				return [_lengths[i - 1] + w[i - 1].distance_to(hit), hit as Vector2, ((line[k + 1] as Vector2) - (line[k] as Vector2)).normalized()]
	return []


## The point `t` metres along a line from its point `from` (negative: back along it), and the line's heading there.
static func _on_line(pts: PackedVector2Array, from: int, t: float) -> Array:
	var i := from
	var left := absf(t)
	var step := 1 if t >= 0.0 else -1
	while i + step >= 0 and i + step < pts.size():
		var d := pts[i].distance_to(pts[i + step])
		if d >= left and d > 0.001:
			var dir := (pts[i + step] - pts[i]).normalized()
			return [pts[i] + dir * left, dir * float(step)]
		left -= d
		i += step
	var j := clampi(i - step, 0, pts.size() - 1)
	var end_dir := (pts[i] - pts[j]).normalized() if i != j else Vector2.DOWN
	return [pts[i], end_dir * float(step)]


## The nearest ground to `want` (within `reach`) a trunk may stand on: the
## region's own, open, not rock, `brook` metres clear of a brook and
## `path` metres from any path's middle. Vector2.INF if there is none.
static func _spot(plan: CourtGlenPlanting.Plan, want: Vector2, reach: float, path: float, brook: float, apart: float = 3.2) -> Vector2:
	for ring in 9:
		var r := reach * float(ring) / 8.0
		for k in maxi(1, ring * 6):
			var p := want + Vector2.from_angle(TAU * float(k) / float(maxi(1, ring * 6)) + float(ring) * 0.7) * r
			if not plan.content.owns(p) or CourtLandHabitats.keep_open(p.x, p.y) or CourtGlenPlanting.steep(p) \
					or CourtGlenPlanting.wet(p, brook) or CourtLandHabitats.path_distance(p.x, p.y) < path:
				continue
			var clear := true
			for q in plan.trunks:
				if q.distance_to(p) < apart:
					clear = false
					break
			if clear:
				return p
	return Vector2.INF


## The composed places, into the glen's plan. Their flower groups join `groups`
## (CourtGlenPlanting pools each group's flower in its shade).
static func plant(plan: CourtGlenPlanting.Plan, groups: Array[Dictionary]) -> void:
	if way().is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([plan.content.seed, "glen places"])
	_brae_gate(plan, rng)
	_brook_dell(plan, rng)
	_the_ford(plan, rng)
	_knoll_walk(plan, rng, groups)
	_the_mound(plan, rng)
	_glimmer_brook(plan, rng, groups)
	_willow_mere(plan, rng, groups)
	_mere_run(plan, rng, groups)
	_river_road(plan, rng)
	_oak_glade(plan, rng, groups)
	_looking_lake(plan, rng, groups)
	_heron_stones(plan, rng)


# --- 1: the Brae gate ---------------------------------------------------------

static func _brae_gate(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator) -> void:
	var s := crest() + GATE_PAST_CREST
	var mid := at(s)
	var d := heading(s)
	var n := d.orthogonal()
	var stood := 0
	for side: float in [-1.0, 1.0]:
		var p := _spot(plan, mid + n * side * GATE_HALF + d * rng.randf_range(-0.8, 0.8), 3.0, GATE_HALF - 1.0, 2.0)
		if p != Vector2.INF and plan.tree(&"old_thorn", 0 if side < 0.0 else 1, p, lean_yaw(-n * side) + rng.randf_range(-0.1, 0.1),
				GATE_SIZE * rng.randf_range(0.97, 1.05)):
			stood += 1
	# their petals on the turf and on the path beneath
	if stood > 0:
		for i in 110:
			var p := mid + d * rng.randfn(0.0, 4.2) + n * rng.randfn(0.0, 3.4)
			plan.litter("white", p, rng.randf() * TAU, rng.randf_range(0.8, 1.3))
	# thorn bushes down the lee side, thickening toward the dell: the height between the turf and the dell's crowns
	var from := s + 34.0
	for i in LEE_BUSHES:
		var t := float(i) / float(LEE_BUSHES - 1)
		var on := from + LEE_REACH * pow(t, 0.8)
		var side := 1.0 if i % 2 == 0 else -1.0
		var want := at(on) + heading(on).orthogonal() * side * rng.randf_range(6.5, lerpf(24.0, 12.0, t))
		var p := _spot(plan, want, 5.0, 5.0, 1.5)
		if p != Vector2.INF and plan.tree(&"thorn_bush", rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.85, 1.3)):
			plan.trunks.resize(plan.trunks.size() - 1)   # a bush is no trunk to grow long grass round


# --- 2: Brook Dell ------------------------------------------------------------

static func _brook_dell(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator) -> void:
	var x := brook_crossing()
	if x.is_empty():
		return
	var s: float = x[0]
	var pts: PackedVector2Array = x[1]
	var i0: int = x[2]
	var half: float = x[3]
	var cross := pts[i0]
	var down: Vector2 = _on_line(pts, i0, 1.0)[1]
	var east := down.orthogonal() * (1.0 if down.orthogonal().x > 0.0 else -1.0)
	# two great elms, their plates of leaves over the crossing: on the west bank just upstream and the east bank just down
	var elm := _spot(plan, cross - down * 11.0 - east * 8.5, 6.0, 8.0, 4.0)
	if elm != Vector2.INF:
		plan.tree(&"great_elm", 0, elm, rng.randf() * TAU, 1.0)
	var elm_two := _spot(plan, cross + down * 13.0 + east * 9.0, 6.0, 8.0, 4.0)
	if elm_two != Vector2.INF:
		plan.tree(&"great_elm", 1, elm_two, rng.randf() * TAU, 0.9)
	# birches along the brook, alternate banks
	for b: Array in DELL_BIRCHES:
		var on: Array = _on_line(pts, i0, b[0])
		var side: Vector2 = (on[1] as Vector2).orthogonal()
		side *= (1.0 if side.dot(east) > 0.0 else -1.0) * float(b[1])
		var heart := (on[0] as Vector2) + side * (half + float(b[2]))
		for k in int(b[3]):
			var p := _spot(plan, heart + (Vector2.ZERO if k == 0 else Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.6, 3.8)), 4.0, 6.5, 3.0, 2.6)
			if p != Vector2.INF and (elm == Vector2.INF or p.distance_to(elm) > 9.0) and (elm_two == Vector2.INF or p.distance_to(elm_two) > 9.0):
				plan.tree(&"birch", rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.95, 1.2) if k == 0 else rng.randf_range(0.8, 0.95))
	# and by the way as you come down into it: you walk in under them
	for w: Array in DELL_WAY:
		var on := s + float(w[0]) + rng.randf_range(-1.5, 1.5)
		var oak: bool = w[2] == &"oak"
		var p := _spot(plan, at(on) + heading(on).orthogonal() * float(w[1]) * (rng.randf_range(8.0, 9.2) if oak else rng.randf_range(6.6, 8.0)),
			4.0, 7.0 if oak else 6.2, 3.0, 5.0 if oak else 3.2)
		if p != Vector2.INF:
			plan.tree(w[2], rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.9, 1.05) if oak else rng.randf_range(0.95, 1.25))
	for w: Array in DELL_BACK:
		var on := s + float(w[0]) + rng.randf_range(-2.0, 2.0)
		var p := _spot(plan, at(on) + heading(on).orthogonal() * float(w[1]) * (float(w[2]) + rng.randf_range(-1.5, 1.5)), 5.0, 7.0, 3.0, 5.5)
		if p != Vector2.INF:
			plan.tree(&"oak", rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.85, 1.05))
	# the fern floor: thick at the water, thinning to nothing at the dell's edge; it reaches up the way toward the brae
	for i in DELL_FERNS:
		var p: Vector2
		var edge: float
		if i % 4 == 0:
			var on := s + rng.randf_range(-40.0, 26.0)
			var off := rng.randfn(0.0, 6.5)
			p = at(on) + heading(on).orthogonal() * off
			edge = absf(off) / 16.0
		else:
			var t := rng.randf_range(-DELL_UP, DELL_DOWN)
			var on: Array = _on_line(pts, i0, t)
			var off := rng.randfn(0.0, DELL_HALF * 0.42)
			p = (on[0] as Vector2) + (on[1] as Vector2).orthogonal() * off
			edge = maxf(absf(off) / DELL_HALF, (absf(t) - 40.0) / 30.0)
		if rng.randf() < edge or not CourtGlenPlanting.growable(p, 0.9):
			continue
		plan.fern(rng.randi(), p, rng.randf() * TAU, lerpf(1.9, 0.9, clampf(edge, 0.0, 1.0)) * rng.randf_range(0.8, 1.15))
	# mossed stones and moss at the water
	for i in 70:
		var on: Array = _on_line(pts, i0, rng.randf_range(-DELL_UP, DELL_DOWN))
		var p := (on[0] as Vector2) + (on[1] as Vector2).orthogonal() * (half + absf(rng.randfn(0.0, 2.6))) * (1.0 if rng.randf() < 0.5 else -1.0)
		if CourtLandHabitats.path_distance(p.x, p.y) < 2.6:
			continue
		if i % 4 == 0:
			plan.plant(&"mossy_rock", p, rng.randf() * TAU, rng.randf_range(0.6, 1.3), 220.0, true)
		else:
			plan.plant(&"moss_mound", p, rng.randf() * TAU, rng.randf_range(0.8, 1.4), 150.0)
	# snowdrops in ribbons along both banks
	var run := -DELL_UP
	while run < DELL_DOWN:
		var on: Array = _on_line(pts, i0, run)
		for bank: float in [-1.0, 1.0]:
			if rng.randf() < 0.72 and sin(run * 0.19 + bank) > -0.55:
				var p := (on[0] as Vector2) + (on[1] as Vector2).orthogonal() * bank * (half + rng.randf_range(0.8, 3.4))
				if CourtGlenPlanting.growable(p, 0.5):
					plan.flower("snowdrop_patch_" + "ab"[rng.randi() % 2], p, rng.randf() * TAU, rng.randf_range(1.0, 1.45))
		run += 0.85


# --- 3: the Ford ----------------------------------------------------------------

static func _the_ford(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator) -> void:
	var f := ford()
	if f.is_empty():
		return
	var s: float = f[0]
	var c: Vector2 = f[1]
	var down: Vector2 = f[2]
	var west := Vector2(-down.y, down.x)
	if west.dot(heading(s)) < 0.0:
		west = -west   # the far bank is the one the way goes on to
	var half := MacroHeight.RIVER_HALF_WIDTH
	# willows in a row on the far bank, parted where the way lands
	for t: float in FORD_WILLOWS:
		var want := c + down * (t + rng.randf_range(-2.5, 2.5)) + west * (half + rng.randf_range(4.6, 6.4))
		var p := _spot(plan, want, 7.0, 6.0, 0.0)
		if p != Vector2.INF and float(along(p)[1]) >= FORD_GAP:
			plan.tree(&"willow", rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.98, 1.28))
	# kingcups on both banks: thickest at the landings, thinning up and down the river and back from the water
	for i in FORD_GOLD:
		var t := clampf(rng.randfn(0.0, FORD_REACH * 0.42), -FORD_REACH, FORD_REACH)
		var back := absf(rng.randfn(0.0, FORD_BACK * 0.5))
		if back > FORD_BACK:
			continue
		var p := c + down * t + west * (1.0 if rng.randf() < 0.5 else -1.0) * (half + 0.2 + back)
		if not CourtGlenPlanting.growable(p, 0.0):
			continue
		plan.flower("kingcup_patch_a" if back < FORD_BACK * 0.45 else "kingcup_patch_b", p, rng.randf() * TAU, rng.randf_range(1.15, 1.7))
	# iris at the water's edge, away from the landings
	for i in 34:
		var t := rng.randf_range(-FORD_REACH, FORD_REACH)
		if absf(t) < 9.0:
			continue
		var p := c + down * t + west * (1.0 if rng.randf() < 0.5 else -1.0) * (half + rng.randf_range(-0.4, 0.7))
		plan.plant(&"iris_clump" if i % 5 != 0 else &"reed_clump", p, rng.randf() * TAU, rng.randf_range(0.85, 1.25), 320.0)
	# gold on the way's verges: the first in the dell's mouth, the last forty metres past the far landing
	var x := brook_crossing()
	var from: float = (float(x[0]) + 28.0) if not x.is_empty() else s - 50.0
	for i in 170:
		var on := rng.randf_range(from, s + 44.0)
		var far := (s - on) / maxf(s - from, 1.0) if on < s else (on - s) / 44.0
		if rng.randf() < far * 0.85:
			continue
		var p := at(on) + heading(on).orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0) * (3.0 + absf(rng.randfn(0.0, 2.6)))
		if CourtGlenPlanting.growable(p, 0.5):
			plan.flower("kingcup_patch_a" if i % 3 == 0 else "kingcup_patch_b", p, rng.randf() * TAU, rng.randf_range(1.1, 1.6))


# --- 4: the Knoll Walk ----------------------------------------------------------

static func _knoll_walk(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var tops := CourtGlenPlanting.knoll_tops(plan.content)
	for k: Array in KNOLLS:
		var near := Vector2(k[0], k[1])
		var top := near
		var best := KNOLL_SNAP
		for t in tops:
			if t.distance_to(near) < best:
				best = t.distance_to(near)
				top = t
		var species: StringName = k[2]
		var a: Array = along(top)
		var toward := (at(a[0]) - top).normalized()
		if k.size() > 7:
			toward = (CourtHeight.site(k[7]) - top).normalized()   # (its flowers face the place it belongs to)
		var trunks: Array = []
		var reach: Array = []
		for n in int(k[3]):
			var want := top if n == 0 else top + Vector2.from_angle(TAU * float(n) / float(k[3]) + rng.randf()) * rng.randf_range(2.8, 4.4)
			var p := _spot(plan, want, 12.0, 9.0, 2.5)
			if p == Vector2.INF:
				continue
			var yaw := wind_yaw(rng) if species == &"old_thorn" else rng.randf() * TAU
			var size := float(k[4]) * (rng.randf_range(0.97, 1.05) if n == 0 else rng.randf_range(0.8, 0.94))
			if plan.tree(species, rng.randi(), p, yaw, size):
				trunks.append(p)
				reach.append(float(k[5]))
		if trunks.is_empty() or float(k[5]) <= 0.0:
			continue
		groups.append({"trunks": trunks, "reach": reach, "flower": k[6] if k.size() > 6 else &"bluebell", "knoll": top, "toward": toward.angle(),
			"composed": true})
		# a knoll within reach of the way spills its bluebells down to it: you walk past blue at hand, and a
		# ribbon of it leads up to the tree
		if float(a[1]) < SPILL_REACH and k.size() <= 6:
			var far: float = a[1]
			for i in int(far * SPILL_TRIES):
				var out := rng.randf_range(7.0, far - 2.6)
				var wide := lerpf(3.6, 6.0, out / far)
				var off := rng.randfn(0.0, wide)
				var p := top + toward * out + toward.orthogonal() * (off + 5.0 * sin(out * 0.11 + top.x))
				if absf(off) > wide * 1.9 or not CourtGlenPlanting.growable(p, 1.2) or p.distance_to(CourtGlenPlanting.POOL) < CourtGlenPlanting.FLOOR + 30.0:
					continue
				var full := absf(off) < wide * 0.9
				plan.flower("bluebell_patch_a" if full else "bluebell_patch_c", p, rng.randf() * TAU,
					rng.randf_range(1.0, 1.4) if full else rng.randf_range(0.7, 1.05))
		if species == &"great_cherry":
			# its petals on the grass beneath, thickest at the trunk
			for i in CHERRY_PETALS:
				var p: Vector2 = (trunks[0] as Vector2) + Vector2.from_angle(rng.randf() * TAU) * absf(rng.randfn(0.0, 5.5))
				plan.litter("pink", p, rng.randf() * TAU, rng.randf_range(0.8, 1.35))


# --- 5: the Mound ---------------------------------------------------------------

static func _the_mound(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator) -> void:
	var crown := CourtHeight.site(&"the_mound")
	for i in RING_DAISIES:
		var p := crown + Vector2.from_angle(TAU * (float(i) + rng.randf_range(-0.25, 0.25)) / float(RING_DAISIES)) * (RING + rng.randfn(0.0, 0.13))
		plan.plant(&"daisy", p, rng.randf() * TAU, rng.randf_range(1.0, 1.4), 120.0)


# --- 6: Glimmer Brook -----------------------------------------------------------

static func _glimmer_brook(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var pts := brook(&"glimmer_brook")
	if pts.size() < 2:
		return
	var half := 1.6
	for b: Dictionary in CourtHeight.brooks():
		if b["id"] == &"glimmer_brook":
			half = b["half_width"]
	# (the brook's line runs from the mere down to the pool; its outer bank is on the left of that)
	for g: Array in GLIMMER_GROUPS:
		var on: Array = _on_line(pts, 0, g[0])
		var outer: Vector2 = (on[1] as Vector2).orthogonal()
		var heart := (on[0] as Vector2) + outer * (half + 7.0)
		var kinds: Array = g[1]
		var trunks: Array = []
		for k in kinds.size():
			var want := heart + (on[1] as Vector2) * (float(k) - 1.0) * rng.randf_range(4.2, 5.4) + outer * rng.randf_range(-1.0, 2.6)
			var p := _spot(plan, want, 6.0, 6.0, half + 2.4, 3.4)
			if p == Vector2.INF:
				continue
			var species: StringName = kinds[k]
			if plan.tree(species, rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.9, 1.15) if species != &"pillar_birch" else rng.randf_range(0.85, 1.0)):
				trunks.append(p)
		if not trunks.is_empty():
			var each: Array = []
			each.resize(trunks.size())
			each.fill(7.5)
			groups.append({"trunks": trunks, "reach": each, "flower": &"snowdrop", "composed": true})
	# the lights, and the snowdrops among them, down the outer bank
	var run := GLIMMER_TO
	while run < GLIMMER_FROM:
		var on: Array = _on_line(pts, 0, run + rng.randf_range(-0.6, 0.6))
		var outer: Vector2 = (on[1] as Vector2).orthogonal()
		for k in 1 + rng.randi() % 3:
			var p := (on[0] as Vector2) + outer * (half + rng.randf_range(0.5, 2.8)) + (on[1] as Vector2) * rng.randf_range(-0.8, 0.8)
			if CourtGlenPlanting.growable(p, 0.2):
				plan.plant(&"faelight_dandelion", p, rng.randf() * TAU, rng.randf_range(1.3, 2.0))
		if int(run / GLIMMER_STEP) % 5 == 0:
			var p := (on[0] as Vector2) + outer * (half + rng.randf_range(0.3, 1.4))
			plan.plant(&"glowcap", p, rng.randf() * TAU, rng.randf_range(1.0, 1.5))
		if int(run / GLIMMER_STEP) % 7 == 3:
			var p := (on[0] as Vector2) + outer * (half + rng.randf_range(-0.3, 0.6))
			plan.plant(&"mossy_rock", p, rng.randf() * TAU, rng.randf_range(0.5, 0.9), 220.0, true)
			plan.plant(&"starmoss", p + outer * 0.4, rng.randf() * TAU, rng.randf_range(0.9, 1.3))
		# a white ribbon by day, thick at the water and feathering back
		for k in 9:
			var back := absf(rng.randfn(0.0, 2.2))
			var p := (on[0] as Vector2) + outer * (half + 0.6 + back) + (on[1] as Vector2) * rng.randf_range(-1.2, 1.2)
			if back < 5.5 and CourtGlenPlanting.growable(p, 0.5) and p.distance_to(CourtGlenPlanting.POOL) > CourtGlenPlanting.POOL_RADIUS + 6.0:
				plan.flower("snowdrop_patch_a" if back < 2.4 else "snowdrop_patch_b", p, rng.randf() * TAU, rng.randf_range(1.05, 1.5))
		run += GLIMMER_STEP


# --- 7: Willow Mere -------------------------------------------------------------

static func _willow_mere(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var mere := CourtGlenPlanting._lake_named(&"willow_mere")
	if mere.is_empty():
		return
	var centre: Vector2 = mere["center"]
	var radius: float = mere["radius"]
	var lady := (CourtHeight.site(&"weeping_lady") - centre).angle()
	# the parting is where the Glimmer Brook leaves; the outlet where the mere run does
	var glimmer := brook(&"glimmer_brook")
	var parting := (glimmer[0] - centre).angle() if not glimmer.is_empty() else PI
	var mere_run := brook(&"mere_run")
	var outlet := (mere_run[0] - centre).angle() if not mere_run.is_empty() else 0.0
	var willows: Array = []
	for ring in 2:
		var n := MERE_WILLOWS if ring == 0 else MERE_WILLOWS / 2
		for i in n:
			var a := TAU * (float(i) + (0.5 if ring == 1 else 0.0) + rng.randf_range(-0.22, 0.22)) / float(n)
			if absf(angle_difference(a, parting)) < MERE_PARTING * (1.0 if ring == 0 else 1.5) or absf(angle_difference(a, lady)) < MERE_LADY \
					or absf(angle_difference(a, outlet)) < MERE_OUTLET:
				continue
			var back := rng.randf_range(3.0, 5.4) if ring == 0 else rng.randf_range(11.0, 15.0)
			var p := _spot(plan, centre + Vector2.from_angle(a) * (radius + back), 3.0, 6.0, 2.6, 5.2)
			if p != Vector2.INF and plan.tree(&"willow", rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.95, 1.25) if ring == 0 else rng.randf_range(0.85, 1.1)):
				willows.append(p)
	if not willows.is_empty():
		var each: Array = []
		each.resize(willows.size())
		each.fill(7.0)
		groups.append({"trunks": willows, "reach": each, "flower": &"snowdrop", "composed": true})
	# reeds and cattails in the shallows, none in the line from the parting to the Lady
	var kinds: Array[StringName] = [&"reed_clump", &"cattail"]
	for i in 80:
		var a := rng.randf() * TAU
		if absf(angle_difference(a, lady)) < 0.45 or absf(angle_difference(a, parting)) < 0.4:
			continue
		plan.plant(kinds[rng.randi() % 2], centre + Vector2.from_angle(a + rng.randfn(0.0, 0.04)) * (radius + rng.randf_range(-2.2, -0.3)),
			rng.randf() * TAU, rng.randf_range(0.9, 1.35), 320.0)


## The mere run: open sward all the way to the river, and a pair of willows where it meets it.
static func _mere_run(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var pts := brook(&"mere_run")
	if pts.size() < 2:
		return
	var mouth := pts[pts.size() - 1]
	var into: Vector2 = _on_line(pts, pts.size() - 1, -1.0)[1]   # the way it runs, into the river
	var trunks: Array = []
	for side: float in [-1.0, 1.0]:
		var p := _spot(plan, mouth - into * 7.0 + into.orthogonal() * side * 9.5, 6.0, 6.0, 3.0, 5.0)
		if p != Vector2.INF and plan.tree(&"willow", rng.randi(), p, rng.randf() * TAU, rng.randf_range(1.05, 1.25)):
			trunks.append(p)
	if not trunks.is_empty():
		groups.append({"trunks": trunks, "reach": [7.5, 7.5].slice(0, trunks.size()), "flower": &"snowdrop", "composed": true})


# --- 8: River Road ----------------------------------------------------------------

static func _river_road(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator) -> void:
	var road := path(&"river_road")
	if road.size() < 2:
		return
	# (the road's line runs south to the main walk: its last point is where it leaves it)
	var run := ROW_FROM
	while run <= ROW_TO:
		var on: Array = _on_line(road, road.size() - 1, -run)
		var side: Vector2 = (on[1] as Vector2).orthogonal()
		for s: float in [-1.0, 1.0]:
			var p := _spot(plan, (on[0] as Vector2) + side * s * ROW_HALF + (on[1] as Vector2) * rng.randf_range(-0.6, 0.6), 2.5, 5.2, 2.2, 4.0)
			if p != Vector2.INF:
				plan.tree(&"aspen_spire", rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.82, 0.98))
		run += ROW_STEP


# --- 9: Oak Glade -----------------------------------------------------------------

static func _oak_glade(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var centre := CourtHeight.site(&"oak_glade")
	var trunks: Array = []
	var reach: Array = []
	for i in GLADE_OAKS:
		var a := TAU * (float(i) + rng.randf_range(-0.16, 0.16)) / float(GLADE_OAKS)
		var want := centre + Vector2.from_angle(a) * (GLADE_RING + rng.randf_range(-1.5, 3.0))
		if CourtLandHabitats.path_distance(want.x, want.y) < GLADE_DOOR:
			continue   # the road goes in and out between two trunks
		var p := _spot(plan, want, 4.0, GLADE_DOOR, 3.0, 9.0)
		if p != Vector2.INF and plan.tree(&"great_oak", i, p, rng.randf() * TAU, rng.randf_range(0.98, 1.14)):
			trunks.append(p)
			reach.append(15.0)
	for i in GLADE_BACK:
		var a := TAU * (float(i) + 0.5 + rng.randf_range(-0.2, 0.2)) / float(GLADE_BACK)
		var want := centre + Vector2.from_angle(a) * (GLADE_BACK_RING + rng.randf_range(-3.0, 5.0))
		if CourtLandHabitats.path_distance(want.x, want.y) < GLADE_DOOR:
			continue
		var p := _spot(plan, want, 5.0, GLADE_DOOR, 3.0, 6.5)
		if p != Vector2.INF and plan.tree(&"oak", rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.95, 1.2)):
			trunks.append(p)
			reach.append(9.0)
	if not trunks.is_empty():
		groups.append({"trunks": trunks, "reach": reach, "flower": &"anemone", "composed": true})
	# foxgloves in the light at the clearing's rim, in stands
	for stand in 9:
		var a := TAU * (float(stand) + rng.randf_range(-0.3, 0.3)) / 9.0
		var heart := centre + Vector2.from_angle(a) * rng.randf_range(47.0, 53.0)
		if CourtLandHabitats.path_distance(heart.x, heart.y) < 7.0:
			continue
		for n in 5 + rng.randi() % 4:
			var p := heart + Vector2.from_angle(rng.randf() * TAU) * absf(rng.randfn(0.0, 1.9))
			if CourtGlenPlanting.growable(p, 1.0):
				plan.plant(&"foxglove", p, rng.randf() * TAU, rng.randf_range(1.0, 1.5), 180.0)


# --- 10: Looking Lake ---------------------------------------------------------------

## Where the lake walk reaches Looking Lake, and the bearing from the lake's middle straight across from there.
static func lake_arrival() -> Array:
	var lake := CourtGlenPlanting._lake_named(&"looking_lake")
	var walk := path(&"lake_walk")
	if lake.is_empty() or walk.is_empty():
		return []
	var centre: Vector2 = lake["center"]
	var end := walk[0] if walk[0].distance_to(centre) < walk[walk.size() - 1].distance_to(centre) else walk[walk.size() - 1]
	return [end, (end - centre).angle() + PI]


static func _looking_lake(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var lake := CourtGlenPlanting._lake_named(&"looking_lake")
	var arrival := lake_arrival()
	if lake.is_empty() or arrival.is_empty():
		return
	var centre: Vector2 = lake["center"]
	var radius: float = lake["radius"]
	var end: Vector2 = arrival[0]
	var far_side: float = arrival[1]
	var come := far_side - PI
	# two great elms on the rim where the walk ends: the lake between them
	var down := (centre - end).normalized()
	for side: float in [-1.0, 1.0]:
		var p := _spot(plan, end + down * 5.0 + down.orthogonal() * side * 12.5, 5.0, 7.5, 3.0, 8.0)
		if p != Vector2.INF:
			plan.tree(&"great_elm", 0 if side < 0.0 else 2, p, rng.randf() * TAU, rng.randf_range(0.98, 1.08))
	# the dark wood across the water: oak at the shore, elms and great oaks standing over them behind
	var wood: Array = []
	var tries := 0
	while wood.size() < LAKE_WOOD and tries < 1800:
		tries += 1
		var a := far_side + clampf(rng.randfn(0.0, LAKE_ARC * 0.5), -LAKE_ARC, LAKE_ARC)
		var back := 2.5 + absf(rng.randfn(0.0, LAKE_DEPTH * 0.36))
		var p := centre + Vector2.from_angle(a) * (radius + back)
		if back > LAKE_DEPTH or CourtLandHabitats.keep_open(p.x, p.y) or CourtGlenPlanting.steep(p):
			continue
		var great := back > 11.0 and rng.randf() < 0.3
		var ok := true
		for q: Vector2 in wood:
			if q.distance_to(p) < (7.0 if great else 4.6):
				ok = false
				break
		if not ok:
			continue
		var species: StringName = (&"great_elm" if rng.randf() < 0.62 else &"great_oak") if great else &"oak"
		if plan.tree(species, rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.9, 1.2) if not great else rng.randf_range(0.9, 1.05)):
			wood.append(p)
	if not wood.is_empty():
		var each: Array = []
		each.resize(wood.size())
		each.fill(8.5)
		groups.append({"trunks": wood, "reach": each, "flower": &"bluebell", "composed": true})
	# reeds in two bays only, either side of the open near shore
	var kinds: Array[StringName] = [&"reed_clump", &"cattail", &"iris_clump"]
	for bay: float in [come + 1.05, come - 1.15]:
		for i in 70:
			var a := bay + rng.randfn(0.0, 0.1)
			plan.plant(kinds[rng.randi() % 3], centre + Vector2.from_angle(a) * (radius + rng.randf_range(-2.8, -0.3)), rng.randf() * TAU,
				rng.randf_range(0.95, 1.45), 320.0)


## The far wood's reflection for a lake's water (CourtRegion hands it to the
## water's shader): {center, radius (of the wood's front rank), bearing, half
## (its half-arc), height (its crowns over the water), colour, strength}.
## Empty for a lake with no wood across it.
static func mirror(content: CourtRegionContent, lake: Dictionary) -> Dictionary:
	if not CourtGlenPlanting.applies(content) or lake.get("id", &"") != &"looking_lake":
		return {}
	var arrival := lake_arrival()
	if arrival.is_empty():
		return {}
	return {"center": lake["center"], "radius": float(lake["radius"]) + MIRROR_BACK, "bearing": float(arrival[1]), "half": LAKE_ARC * 0.86,
		"height": MIRROR_HEIGHT, "colour": MIRROR_COLOUR, "strength": MIRROR_STRENGTH}


# --- 11: Heron Stones -----------------------------------------------------------------

static func _heron_stones(plan: CourtGlenPlanting.Plan, rng: RandomNumberGenerator) -> void:
	var stones := CourtHeight.site(&"heron_stones")
	var lake := CourtGlenPlanting._lake_named(&"looking_lake")
	# the partings: toward the lake's near shore, and toward the Blossom Knoll (the way back to the Knoll Walk)
	var doors: Array[float] = []
	if not lake.is_empty():
		doors.append(((lake["center"] as Vector2) - stones).angle())
	doors.append((CourtHeight.site(&"knoll_steps") - stones).angle())
	for i in REEDS:
		var a := rng.randf() * TAU
		var open := false
		for door in doors:
			if absf(angle_difference(a, door)) < REED_PARTING:
				open = true
		if open:
			continue
		var r := lerpf(REED_INNER, REED_OUTER, sqrt(rng.randf()))
		var p := stones + Vector2.from_angle(a) * r
		if not CourtGlenPlanting.growable(p, 0.5):
			continue
		# tallest in the bed's heart, falling away at its edge
		# (a reed clump stands 1.4 to 2.4 m at size 1)
		var tall := lerpf(1.4, 0.85, clampf((r - REED_INNER) / (REED_OUTER - REED_INNER), 0.0, 1.0)) * rng.randf_range(0.88, 1.12)
		plan.plant(&"cattail" if i % 6 == 0 else &"reed_clump", p, rng.randf() * TAU, tall, 320.0)


## The Glimmer Brook's string of lights, as CourtMotes draws them from the
## golden hour through the night: one every few steps down the outer bank,
## waist to shoulder high, from just outside the pool's ring to the mere.
static func lights(content: CourtRegionContent) -> PackedVector3Array:
	var out := PackedVector3Array()
	var pts := brook(&"glimmer_brook")
	if not CourtGlenPlanting.applies(content) or pts.size() < 2:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([content.seed, "glimmer lights"])
	var run := GLIMMER_TO
	while run < GLIMMER_FROM:
		var on: Array = _on_line(pts, 0, run + rng.randf_range(-0.7, 0.7))
		var p := (on[0] as Vector2) + (on[1] as Vector2).orthogonal() * rng.randf_range(2.6, 4.4)
		if content.owns(p):
			out.append(Vector3(p.x, WorldHeight.height_at(p.x, p.y) + rng.randf_range(0.7, 1.5), p.y))
		run += LIGHT_STEP
	return out


## Falling petals: [particle scene id, where (x, metres over the ground, z)].
static func effects(content: CourtRegionContent) -> Array:
	var out: Array = []
	if not CourtGlenPlanting.applies(content) or way().is_empty():
		return out
	var gate := at(crest() + GATE_PAST_CREST)
	out.append([&"fx_cherry_petals", Vector3(gate.x, 5.5, gate.y)])
	for k: Array in KNOLLS:
		if k[2] == &"great_cherry":
			out.append([&"fx_cherry_petals", Vector3(k[0], 7.0, k[1])])
	return out
