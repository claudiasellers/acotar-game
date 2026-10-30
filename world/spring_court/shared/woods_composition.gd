## Composition for a woods region (plans/experience-bar.md §1.3, §2.3, §2.4):
## where the clearings and their hero objects go, which flower drift lines a
## path, which view cones stay open. Pure and deterministic, so the worker
## that places scatter and the main thread that builds nodes agree.
##
## - Clearings: along every path and road, one every 150-250 m, set to one
##   side, 14-24 m across. Trees stay out, shrubs thin, one flower colour
##   carpets the floor. Each has a hero object (an ancient oak, a blossom
##   tree, a standing stone or a mossy log seat looking out: the refuge spots)
##   and a light shaft. Horror biomes get none: the light leaves there.
## - Path edges: a band each side of a path planted in drifts of one flower
##   colour that changes every ~40 m (English drift planting).
## - Beacons: between clearings, a lit blossom tree every 60-85 m (a dead
##   tree in horror biomes), so a magnet is always in view ahead.
## - Vistas: a provider may list VISTAS = [[from, to, half_angle_deg, length]];
##   no tree or shrub stands in those cones (the wall-crossing reveal).
class_name WoodsComposition
extends RefCounted

const SPACING := Vector2(150.0, 250.0)
const RADIUS := Vector2(14.0, 24.0)
## Heroes cycle through these (refuge seats every other clearing or so).
const HEROES: Array[StringName] = [&"ancient_oak", &"crab_apple", &"fallen_log", &"lilac_tree",
		&"standing_stone", &"crab_apple", &"fallen_log", &"ancient_oak", &"lilac_tree", &"hawthorn"]
## One colour per clearing floor or path drift.
const DRIFTS: Array[StringName] = [&"bluebell", &"crocus", &"buttercup", &"primrose", &"wood_anemone",
		&"violet", &"cowslip", &"snowdrop", &"daisy"]
const PATH_KINDS: Array[StringName] = [&"road", &"path"]
## Between clearings, a beacon every 60-85 m keeps a magnet in view
## (§1.3.1: one within 150 m ahead): a lit blossom tree just off the path, a
## mini-glade of one flower colour. In horror biomes it is a dead tree.
const BEACON_SPACING := Vector2(60.0, 85.0)
const BEACON_RADIUS := 5.0
const BEACONS: Array[StringName] = [&"crab_apple", &"lilac_tree", &"hawthorn", &"crab_apple", &"standing_stone"]
const DREAD_BEACONS: Array[StringName] = [&"twisted_dead"]
## The flower band beside a path, in metres past its edge.
const EDGE_BAND := Vector2(0.4, 3.2)
const HORROR_AMBIENCE := ["mist", "ash_motes"]
const BUCKET := 64.0

static var _cache: Dictionary = {}
static var _lock := Mutex.new()


## { clearings: Array of {center, radius, hero, flower, yaw}, buckets, vistas }.
static func of(def: WoodsRegionDef) -> Dictionary:
	_lock.lock()
	var c: Variant = _cache.get(def.region_id)
	_lock.unlock()
	if c != null:
		return c
	var built := _build(def)
	_lock.lock()
	_cache[def.region_id] = built
	_lock.unlock()
	return built


static func clearings(def: WoodsRegionDef) -> Array:
	return of(def)["clearings"]


## The clearing (x, z) is in, or {} when none. `scale` shrinks the radius.
static func clearing_at(def: WoodsRegionDef, x: float, z: float, scale: float = 1.0) -> Dictionary:
	var comp := of(def)
	var key := Vector2i(floori(x / BUCKET), floori(z / BUCKET))
	for i: int in comp["buckets"].get(key, PackedInt32Array()):
		var c: Dictionary = comp["clearings"][i]
		if Vector2(x, z).distance_to(c["center"]) < float(c["radius"]) * scale:
			return c
	return {}


## True inside a kept-open vista cone.
static func in_vista(def: WoodsRegionDef, x: float, z: float) -> bool:
	return _in_cones(of(def)["vistas"], Vector2(x, z))


static func _in_cones(vistas: Array, p: Vector2) -> bool:
	for v: Array in vistas:
		var from: Vector2 = v[0]
		var to: Vector2 = v[1]
		var d := p - from
		var length := d.length()
		if length < 4.0 or length > float(v[3]):
			continue
		if rad_to_deg(absf(d.angle_to(to - from))) < float(v[2]):
			return true
	return false


## Distance past the nearest path or road edge (negative on it).
static func path_distance(def: WoodsRegionDef, x: float, z: float) -> float:
	var f: WoodsFeatures = def.provider.features()
	var best := INF
	for kind in PATH_KINDS:
		best = minf(best, f.distance(kind, x, z))
	return best


## The flower drift planted beside a path at (x, z), or &"" off the band.
static func path_drift(def: WoodsRegionDef, x: float, z: float, biome_id: StringName) -> StringName:
	if of(def)["horror"].has(biome_id):
		return &""
	var d := path_distance(def, x, z)
	if d < EDGE_BAND.x or d > EDGE_BAND.y:
		return &""
	# Drifts change colour every ~40 m along the path.
	var cell := Vector2i(floori(x / 40.0), floori(z / 40.0))
	return DRIFTS[absi(hash([def.seed, cell])) % DRIFTS.size()]


static func _build(def: WoodsRegionDef) -> Dictionary:
	var provider: Variant = def.provider
	var bounds: Rect2 = provider.BOUNDS
	var horror := {}
	for b in def.biomes:
		for a in HORROR_AMBIENCE:
			if a in b.ambience:
				horror[b.id] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([def.seed, "clearings"])
	var f: WoodsFeatures = provider.features()
	var vistas: Array = (provider as Script).get_script_constant_map().get("VISTAS", [])
	var out: Array = []
	var side := 1.0
	for kind in PATH_KINDS:
		var segs: Array = f.segments(kind)
		var next := rng.randf_range(SPACING.x, SPACING.y) * 0.5
		var next_beacon := rng.randf_range(15.0, 50.0)
		var walked := 0.0
		for seg: Array in segs:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			var length := a.distance_to(b)
			var dir := (b - a).normalized()
			var normal := Vector2(-dir.y, dir.x)
			while walked + length >= minf(next, next_beacon):
				var glade := next <= next_beacon
				var at := next if glade else next_beacon
				var p := a.lerp(b, (at - walked) / maxf(length, 0.001))
				var radius := rng.randf_range(RADIUS.x, RADIUS.y) if glade else BEACON_RADIUS
				var off := float(seg[2]) + (radius * 0.7 if glade else 7.0)
				var center := p + normal * side * off
				# Water or the region edge on this side: try the other bank.
				if not _fits(provider, bounds, center, radius):
					center = p - normal * side * off
				side = -side
				var hero_pick := rng.randi()
				var flower_pick := rng.randi()
				var yaw := rng.randf() * TAU
				# Any magnet resets the beacon walk: no long stretch without one.
				next_beacon = at + rng.randf_range(BEACON_SPACING.x, BEACON_SPACING.y)
				if glade:
					next += rng.randf_range(SPACING.x, SPACING.y)
				if not _fits(provider, bounds, center, radius) or _in_cones(vistas, center):
					continue
				var dread := horror.has(provider.biome_at(center.x, center.y))
				if glade and dread:
					continue
				if _near_any(out, center, 90.0 if glade else 30.0, glade):
					continue
				var heroes := HEROES if glade else (DREAD_BEACONS if dread else BEACONS)
				out.append({"center": center, "radius": radius, "yaw": yaw, "beacon": not glade, "dread": dread,
						"hero": heroes[hero_pick % heroes.size()], "flower": DRIFTS[flower_pick % DRIFTS.size()],
						"path_dir": dir})
			walked += length
	# Path ends (a fork's tip, the way out of the region): a beacon just
	# before each, so the last stretch walks toward something too.
	for kind in PATH_KINDS:
		for end: Array in _dangling_ends(f.segments(kind)):
			var tip: Vector2 = end[0]
			var back: Vector2 = end[1]
			var p := tip
			while not bounds.grow(-12.0).has_point(p) and p.distance_to(tip) < 300.0:
				p += back * 5.0
			p += back * 4.0
			var normal := Vector2(-back.y, back.x)
			var off := float(end[2]) + 7.0
			var center := p + normal * side * off
			if not _fits(provider, bounds, center, BEACON_RADIUS):
				center = p - normal * side * off
			side = -side
			var pick := rng.randi()
			if not _fits(provider, bounds, center, BEACON_RADIUS) or _near_any(out, center, 15.0) \
						or _in_cones(vistas, center):
				continue
			var dread := horror.has(provider.biome_at(center.x, center.y))
			var heroes := DREAD_BEACONS if dread else BEACONS
			out.append({"center": center, "radius": BEACON_RADIUS, "yaw": rng.randf() * TAU, "beacon": true,
					"dread": dread, "hero": heroes[pick % heroes.size()], "flower": DRIFTS[pick % DRIFTS.size()],
					"path_dir": -back})
	var buckets := {}
	for i in out.size():
		var c: Dictionary = out[i]
		var r: float = c["radius"]
		var lo: Vector2 = c["center"] - Vector2.ONE * r
		var hi: Vector2 = c["center"] + Vector2.ONE * r
		for bx in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
			for bz in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
				var key := Vector2i(bx, bz)
				if not buckets.has(key):
					buckets[key] = PackedInt32Array()
				buckets[key].append(i)
	return {"clearings": out, "buckets": buckets, "vistas": vistas, "horror": horror}


## [tip, unit direction back along the path, half width] for every segment
## end no other segment shares.
static func _dangling_ends(segs: Array) -> Array:
	var count := {}
	for seg: Array in segs:
		for q: Vector2 in [seg[0], seg[1]]:
			var key := _key(q)
			count[key] = int(count.get(key, 0)) + 1
	var ends: Array = []
	for seg: Array in segs:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		if a.is_equal_approx(b):
			continue
		if count[_key(a)] == 1:
			ends.append([a, (b - a).normalized(), seg[2]])
		if count[_key(b)] == 1:
			ends.append([b, (a - b).normalized(), seg[2]])
	return ends


static func _key(q: Vector2) -> Vector2i:
	return Vector2i(roundi(q.x * 10.0), roundi(q.y * 10.0))


static func _fits(provider: Variant, bounds: Rect2, center: Vector2, radius: float) -> bool:
	return bounds.grow(-radius).has_point(center) and not provider.is_water(center.x, center.y)


## With `glades_only`, beacons count only within their own reach (they sit
## between clearings, so a clearing must not be crowded out by one).
static func _near_any(list: Array, p: Vector2, min_distance: float, glades_only: bool = false) -> bool:
	for c: Dictionary in list:
		var reach := float(c["radius"]) + BEACON_RADIUS if glades_only and c["beacon"] else min_distance
		if p.distance_to(c["center"]) < reach:
			return true
	return false
