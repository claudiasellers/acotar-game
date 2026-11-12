## What the court's ground is like at a point, read from CourtHeight (finish
## plan P1, docs/lanes/wider-court-finish-plan.md): the landform (crest, knoll
## crown, hollow, valley floor, slope by steepness), the water's edges (lake
## shore, river and brook banks) and the path verges. Planting reads it so a
## wood follows the land (P2), and keep-open zones say where no trunk may
## stand at all: the clearings, the gates, the paths, the water, where you stand
## to look, and the story's spots (docs/contracts/wider_court.md).
##
## Static and read-only after CourtHeight is built, so it is safe from the
## scatter worker threads (call CourtHeight.prewarm() first, as the court does).
## It reads CourtHeight's built tables (the clearings, the path lines) rather
## than adding to CourtHeight: any edit there rebakes the terrain (14 minutes,
## tools/mq/generated.conf), and so would a file here named *terrain* or
## *height*.
class_name CourtLandHabitats
extends RefCounted

enum Form { FLOOR, SLOPE, STEEP, VALLEY, HOLLOW, CREST, KNOLL, VERGE, BROOK_BANK, RIVER_BANK, SHORE, WATER }
const NAMES := [&"floor", &"slope", &"steep", &"valley", &"hollow", &"crest", &"knoll", &"verge",
	&"brook_bank", &"river_bank", &"shore", &"water"]

## Slope (degrees) where open ground becomes a slope, and a slope steep.
const SLOPE_DEG := 12.0
const STEEP_DEG := 28.0
## Curvature ring (m) and how far above or below its mean a point must stand
## to be a crest or knoll (above) or a hollow (below).
const RING := 28.0
const RISE := 1.8
## Valley floor: this far below the mean of a wide ring (m), on gentle ground.
const WIDE_RING := 120.0
const VALLEY_DROP := 7.0
const VALLEY_SLOPE := 9.0
## Bands from the water's or the path's edge (m).
const SHORE_BAND := 14.0
const RIVER_BAND := 18.0
const BROOK_BAND := 8.0
const VERGE_BAND := 6.0
## No trunk this close to a path's edge (m).
const PATH_CLEAR := 2.0

## Keep-open radii (m).
const GATE_CLEAR := 8.0       # beyond the gate's half-width
const VIEW_CLEAR := 8.0       # round a standpoint
## The sentries shoot 20, 35 and 55 m (SentryRange.BUTTS); the lane runs past
## the last butt and is as wide as the butts' spread plus room either side.
const SENTRY_LANE := 62.0
const SENTRY_HALF := 7.0
const POTION_TERRACE := 12.0
const POOL_RIM := 6.0         # beyond the starlight pool's radius

## Where you stand to look: the court's 18 ground views in
## tools/court/court_terrain_shots.gd, id -> [x, z]. Kept clear of trunks, as is
## every CourtHeight.SIGHTLINES standpoint.
const VIEWPOINTS := {
	&"exit_north": [0.0, -480.0], &"exit_west": [-560.0, -90.0], &"glen_saddle": [-850.0, 30.0],
	&"brae_top": [-760.0, -70.0], &"the_mound": [-1208.0, 270.0], &"village_pinch": [-700.0, -705.0],
	&"village_green": [-930.0, -780.0], &"plateau_north": [-180.0, -1112.0], &"plateau_east": [-120.0, -1060.0],
	&"rite_way": [555.0, -800.0], &"rite_trench": [520.0, -986.0], &"rite_crown": [870.0, -1140.0],
	&"vale_rim": [734.0, 707.0], &"tower_hill": [-1630.0, -650.0], &"western_woods": [-1500.0, 900.0],
	&"west_brink": [-1782.0, 180.0], &"sealed_pass": [-900.0, -1180.0], &"reaches": [1450.0, -1250.0],
}

## Zones are bucketed on this grid (m) so a query only tests its neighbours.
const BUCKET := 64.0

static var _mutex := Mutex.new()
static var _zones: Array[Dictionary] = []
static var _buckets := {}


## The landform at a point (Form). Water and the bands round it come first,
## then the path verge, then the shape of the ground.
static func form_at(x: float, z: float) -> int:
	var h := CourtHeight.height_at(x, z)
	var water := _water_form(x, z, h)
	if water >= 0:
		return water
	if path_distance(x, z) < VERGE_BAND:
		return Form.VERGE
	var ring := PackedFloat32Array()
	ring.resize(8)
	for k in 8:
		var a := TAU * float(k) / 8.0
		ring[k] = CourtHeight.height_at(x + cos(a) * RING, z + sin(a) * RING)
	var wide := func() -> float:
		var sum := 0.0
		for k in 8:
			var a := TAU * (float(k) + 0.5) / 8.0
			sum += CourtHeight.height_at(x + cos(a) * WIDE_RING, z + sin(a) * WIDE_RING)
		return sum / 8.0
	return shape_of(h, ring, slope_deg(x, z), wide)


## The ground's shape (FLOOR .. KNOLL) from heights already read: h at the
## point, the eight heights round it at RING, the slope in degrees; `wide`
## gives the mean height at WIDE_RING and is only called on gentle ground.
## form_at reads the heights itself; CourtPlanting reads them from a grid.
static func shape_of(h: float, ring: PackedFloat32Array, slope: float, wide: Callable) -> int:
	var above := 0
	var below := 0
	var mean := 0.0
	for hk in ring:
		mean += hk
		if hk < h - RISE * 0.5:
			above += 1
		elif hk > h + RISE * 0.5:
			below += 1
	mean /= 8.0
	var rel := h - mean
	if rel > RISE and above == 8:
		return Form.KNOLL
	if rel > RISE and above >= 5:
		return Form.CREST
	if rel < -RISE and below >= 6:
		return Form.HOLLOW
	if slope >= STEEP_DEG:
		return Form.STEEP
	if slope < VALLEY_SLOPE and float(wide.call()) - h > VALLEY_DROP:
		return Form.VALLEY
	if slope >= SLOPE_DEG:
		return Form.SLOPE
	return Form.FLOOR


static func form_name(x: float, z: float) -> StringName:
	return NAMES[form_at(x, z)]


## Ground slope in degrees from a 4 m central difference.
static func slope_deg(x: float, z: float) -> float:
	var e := 2.0
	var dx := (CourtHeight.height_at(x + e, z) - CourtHeight.height_at(x - e, z)) / (2.0 * e)
	var dz := (CourtHeight.height_at(x, z + e) - CourtHeight.height_at(x, z - e)) / (2.0 * e)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz)))


## True where no trunk may stand: water, on or beside a path, and inside
## every keep-open zone (zones()).
static func keep_open(x: float, z: float) -> bool:
	return keep_open_reason(x, z) != &""


## Why a point is kept open ("" when it isn't): the zone's id, or "water" /
## "path".
static func keep_open_reason(x: float, z: float) -> StringName:
	var p := Vector2(x, z)
	zones()
	var key := Vector2i(floori(x / BUCKET), floori(z / BUCKET))
	for i: int in _buckets.get(key, []):
		var zn := _zones[i]
		if _in_zone(zn, p):
			return zn["id"]
	if path_distance(x, z) < PATH_CLEAR:
		return &"path"
	if _water_form(x, z, CourtHeight.height_at(x, z)) == Form.WATER:
		return &"water"
	return &""


## The keep-open zones: {id, kind, a: Vector2, b: Vector2, r}. A disc has
## a == b; a capsule runs a to b. Kinds: clearing, gate, view, story.
static func zones() -> Array[Dictionary]:
	_mutex.lock()
	if _zones.is_empty():
		var built := _build_zones()
		var buckets := {}
		for i in built.size():
			var zn := built[i]
			var a: Vector2 = zn["a"]
			var b: Vector2 = zn["b"]
			var r: float = zn["r"]
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r, r)
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r, r)
			for bx in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
				for bz in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
					var k := Vector2i(bx, bz)
					if not buckets.has(k):
						buckets[k] = []
					(buckets[k] as Array).append(i)
		_buckets = buckets
		_zones = built
	var out := _zones
	_mutex.unlock()
	return out


static func _build_zones() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var disc := func(id: StringName, kind: StringName, c: Vector2, r: float) -> void:
		out.append({"id": id, "kind": kind, "a": c, "b": c, "r": r})
	var i := 0
	CourtHeight.prewarm()
	for pd: Array in CourtHeight._pads:  # PADS plus a small clearing at each site
		disc.call(StringName("clearing_%d" % i), &"clearing", Vector2(pd[0], pd[1]), float(pd[2]))
		i += 1
	for g: Array in CourtHeight.GATES:
		disc.call(StringName("gate_%s" % g[0]), &"gate", Vector2(g[2], g[3]), float(g[4]) * 0.5 + GATE_CLEAR)
	for id: StringName in VIEWPOINTS:
		var v: Array = VIEWPOINTS[id]
		disc.call(StringName("view_%s" % id), &"view", Vector2(v[0], v[1]), VIEW_CLEAR)
	var n := 0
	for line: Array in CourtHeight.SIGHTLINES:
		var from: Variant = line[0]
		var at := CourtHeight.site(from) if from is StringName else Vector2(from[0], from[1])
		if not is_nan(at.x):
			disc.call(StringName("sightline_%d" % n), &"view", at, VIEW_CLEAR)
		n += 1
	# The story's spots (wider_court.md), from the story lane's own anchor table.
	var sentry: Array = WiderCourtAnchors.PLACES[&"fells_sentry_range"]
	var line_at := CourtHeight.site(sentry[1]) + (sentry[3] as Vector2)
	var yaw := deg_to_rad(float(sentry[4]))
	var aim := Vector2(-sin(yaw), -cos(yaw))
	out.append({"id": &"story_sentry_range", "kind": &"story", "a": line_at - aim * 6.0,
		"b": line_at + aim * SENTRY_LANE, "r": SENTRY_HALF})
	var potion: Array = WiderCourtAnchors.PLACES[&"fae_potion_room"]
	disc.call(&"story_potion_room", &"story", CourtHeight.site(potion[1]) + (potion[3] as Vector2), POTION_TERRACE)
	for l: Dictionary in CourtHeight.lakes():
		if l["id"] == &"starlight_pool":
			disc.call(&"story_starlight_rim", &"story", l["center"], float(l["radius"]) + POOL_RIM)
	return out


## Distance from the nearest path's edge (m; negative on the path).
static func path_distance(x: float, z: float) -> float:
	CourtHeight.prewarm()
	var d := CourtHeight._path_distance(x, z)
	return d.x - d.y


static func _in_zone(zn: Dictionary, p: Vector2) -> bool:
	var a: Vector2 = zn["a"]
	var b: Vector2 = zn["b"]
	var r: float = zn["r"]
	if a == b:
		return p.distance_squared_to(a) <= r * r
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= r


## WATER, SHORE, RIVER_BANK, BROOK_BANK, or -1 away from water.
static func _water_form(x: float, z: float, h: float) -> int:
	var p := Vector2(x, z)
	var shore := false
	for l: Dictionary in CourtHeight.lakes():
		var d := p.distance_to(l["center"])
		var r: float = l["radius"]
		if d > r + SHORE_BAND + 20.0:
			continue
		if h < float(l["level"]) + 0.15:
			return Form.WATER
		shore = shore or d < r + SHORE_BAND
	var river := MacroHeight.distance_to_river(x, z) - MacroHeight.RIVER_HALF_WIDTH
	if river < 1.0:
		return Form.WATER
	var brook := CourtHeight.distance_to_brook(x, z)
	if brook < 0.5:
		return Form.WATER
	if shore:
		return Form.SHORE
	if river < RIVER_BAND:
		return Form.RIVER_BANK
	if brook < BROOK_BAND:
		return Form.BROOK_BANK
	return -1
