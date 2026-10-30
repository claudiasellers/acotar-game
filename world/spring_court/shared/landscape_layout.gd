## Shared tree and shrub composition for the Spring Court generators
## (plans/landscape-brief.md): groves and open meadow from one stand map,
## feathered edges that step down through flowering pioneers and a shrub
## mantle, species in patches, trunks kept apart, specimen clumps of odd
## numbers out in the open, and rows where a habitat is planted (orchards).
## Pure and deterministic from the seed (R15); WoodsScatter and
## CourtScatterGenerator call it from worker threads.
##
## A layout is a Dictionary from make(): its noises, the stand map's
## percentile table and the spacing hash of trees placed so far.
extends RefCounted

## Candidate grid for trees (m); one jittered candidate per cell.
const TREE_CELL := 4.0
## Candidates lost to trunk spacing, path verges and clearing rims are made
## up by this factor, so a region keeps about the count it had.
const COUNT_MAKEUP := 1.13
## No two trunks closer than this (m); big trees claim more.
const TRUNK_SPACING := 3.2
const BIG_TREES := {&"ancient_oak": 7.0, &"woods_ancient_oak": 7.0, &"willow": 4.5, &"woods_willow": 4.5}
## Stand map: wavelength of groves and glades (m) and the domain warp that
## bends their outlines.
const STAND_WAVELENGTH := 210.0
const WARP_AMPLITUDE := 55.0
## Width of the feathered edge in percentile units, below and above the cut.
const EDGE_OUT := 0.05
const EDGE_IN := 0.08
## Grove core: from the edge to this far above the cut, trees grow denser and taller.
const CORE_DEPTH := 0.3
## Species patches (m across) and the share of the dominant species in one.
const PATCH := 90.0
const COMPANION := 90.0 * 0.6
const COMPANION_SHARE := 0.10
const STRAY_SHARE := 0.03
## Flowering pioneers lead a wood's edge; oaks and beeches hold the interior.
const EDGE_SPECIES := ["crab_apple", "hawthorn", "lilac_tree", "silver_birch", "wild_cherry", "rowan", "hazel", "elder"]
const EDGE_PREFERENCE := 0.4
## Specimen clumps out in the open: one candidate per CLUMP_CELL square.
## Sizes follow the rule of odds (weights for 1, 3, 5, 7).
const CLUMP_CELL := 32.0
const CLUMP_SIZES := [[1, 0.15], [3, 0.50], [5, 0.28], [7, 0.07]]
## Shrubs: share of the mantle density they keep in the open and under canopy,
## and the drift noise that gathers them into one-kind groups.
const SHRUB_OPEN := 0.22
const SHRUB_CORE := 0.45
const SHRUB_DRIFT := 14.0
const SHRUB_PATCH := 22.0
const SHRUB_DOMINANT := 0.75
## Paths: tree-free verge, then density ramps back over this distance (m).
const PATH_VERGE := 3.0
const PATH_RAMP := 15.0
## Planted rows (orchards, walks): row and tree spacing limits (m), jitter and gaps.
const ROW_SPACING := Vector2(7.0, 14.0)
const ROW_JITTER := 0.35
const ROW_GAPS := 0.08
const FORMAL_TAGS := ["orchard", "_rows", "_walk", "allee", "avenue"]


## A layout over `rect` for `seed`.
static func make(seed_value: int, rect: Rect2) -> Dictionary:
	var stand := FastNoiseLite.new()
	stand.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	stand.seed = seed_value
	stand.frequency = 1.0 / STAND_WAVELENGTH
	stand.fractal_type = FastNoiseLite.FRACTAL_FBM
	stand.fractal_octaves = 3
	stand.fractal_gain = 0.45
	stand.domain_warp_enabled = true
	stand.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	stand.domain_warp_amplitude = WARP_AMPLITUDE
	stand.domain_warp_frequency = 1.0 / 260.0
	var patch := _cellular(seed_value + 11, PATCH)
	var companion := _cellular(seed_value + 23, COMPANION)
	var shrub_patch := _cellular(seed_value + 37, SHRUB_PATCH)
	var drift := FastNoiseLite.new()
	drift.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	drift.seed = seed_value + 41
	drift.frequency = 1.0 / SHRUB_DRIFT
	# Percentile table, so a cut of 0.3 leaves 30 % of the ground open
	# whatever the noise's distribution.
	var samples := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "stand_cdf"])
	for i in 4096:
		var p := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		samples.append(stand.get_noise_2d(p.x, p.y))
	samples.sort()
	return {"stand": stand, "patch": patch, "companion": companion, "shrub_patch": shrub_patch,
			"drift": drift, "cdf": samples, "trunks": {}, "seed": seed_value}


static func _cellular(seed_value: int, size: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.seed = seed_value
	n.frequency = 1.0 / size
	n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	n.cellular_jitter = 0.9
	# Warped a little so patch borders aren't straight Voronoi edges.
	n.domain_warp_enabled = true
	n.domain_warp_amplitude = size * 0.35
	n.domain_warp_frequency = 1.0 / (size * 1.6)
	return n


## Share of ground left open for a tree density (per m²): dense woods keep
## about 30 %, thin meadow woods about 72 %.
static func open_share(tree_density: float) -> float:
	return clampf(0.80 - 45.0 * tree_density, 0.28, 0.78)


## Stand percentile at (x, z): 0..1, uniform over the region.
static func stand_at(layout: Dictionary, x: float, z: float) -> float:
	var cdf: PackedFloat32Array = layout["cdf"]
	var v: float = (layout["stand"] as FastNoiseLite).get_noise_2d(x, z)
	return float(cdf.bsearch(v)) / cdf.size()


## { grove: 0..1 (0 open, 1 inside), core: 0..1 (deep interior), edge: 0..1 (peaks in the edge band) }
static func zone(u: float, open: float) -> Dictionary:
	var grove := smoothstep(open - EDGE_OUT, open + EDGE_IN, u)
	var core := smoothstep(open + EDGE_IN, open + EDGE_IN + CORE_DEPTH, u)
	return {"grove": grove, "core": core, "edge": grove * (1.0 - core)}


## Relative tree weight for a zone: none in the open, thinner at the edge.
static func tree_weight(z: Dictionary) -> float:
	return z["grove"] * lerpf(0.55, 1.0, z["core"])


## Relative shrub weight: peaks in the edge mantle, half under canopy, a
## quarter in the open; gathered into drifts by a fine noise.
static func shrub_weight(layout: Dictionary, z: Dictionary, x: float, y: float) -> float:
	var mantle: float = SHRUB_OPEN * (1.0 - z["grove"]) + z["grove"] * lerpf(1.0, SHRUB_CORE, z["core"])
	var d: float = (layout["drift"] as FastNoiseLite).get_noise_2d(x, y)
	return mantle * smoothstep(-0.15, 0.35, d) * 2.2


## Mean of a weight over a region's ground, per key (biome or habitat), from
## a stratified sample. `classify(p) -> key or &""`, `weigh(key, p) -> float`.
static func mean_weights(layout: Dictionary, rect: Rect2, classify: Callable, weigh: Callable) -> Dictionary:
	var sums := {}
	var counts := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout["seed"], "means"])
	var n := 80
	for iz in n:
		for ix in n:
			var p := rect.position + Vector2((ix + rng.randf()) / n, (iz + rng.randf()) / n) * rect.size
			var key: StringName = classify.call(p)
			if key == &"":
				continue
			sums[key] = sums.get(key, 0.0) + float(weigh.call(key, p))
			counts[key] = counts.get(key, 0) + 1
	var out := {}
	for key in sums:
		out[key] = maxf(sums[key] / counts[key], 0.02)
	return out


## Picks a species: the patch's dominant one, sometimes the neighbouring
## patch's companion or a stray, and at a wood's edge mostly a flowering
## pioneer. `table` and `edge_table` are [[cumulative weight, id], ...].
static func tree_species(layout: Dictionary, table: Array, edge_table: Array, x: float, z: float,
		edge: float, r1: float, r2: float) -> StringName:
	var v1 := _unit((layout["patch"] as FastNoiseLite).get_noise_2d(x, z))
	if not edge_table.is_empty() and r2 < EDGE_PREFERENCE * edge:
		return pick(edge_table, v1)
	if r1 < STRAY_SHARE:
		return pick(table, r2)
	if r1 < STRAY_SHARE + COMPANION_SHARE:
		return pick(table, _unit((layout["companion"] as FastNoiseLite).get_noise_2d(x, z)))
	return pick(table, v1)


static func shrub_species(layout: Dictionary, table: Array, x: float, z: float, r1: float, r2: float) -> StringName:
	if r1 >= SHRUB_DOMINANT:
		return pick(table, r2)
	return pick(table, _unit((layout["shrub_patch"] as FastNoiseLite).get_noise_2d(x, z)))


## The edge-species subset of a cumulative table (renormalised), or [].
static func edge_table(table: Array) -> Array:
	var kept: Array = []
	var prev := 0.0
	var total := 0.0
	for entry in table:
		var w: float = entry[0] - prev
		prev = entry[0]
		if is_edge_species(entry[1]):
			kept.append([w, entry[1]])
			total += w
	if kept.is_empty() or kept.size() == table.size():
		return []
	var acc := 0.0
	var out: Array = []
	for k in kept:
		acc += k[0] / total
		out.append([acc, k[1]])
	return out


static func is_edge_species(id: StringName) -> bool:
	var s := String(id)
	for e in EDGE_SPECIES:
		if s.ends_with(e):
			return true
	return false


static func pick(table: Array, r: float) -> StringName:
	for entry in table:
		if r <= entry[0]:
			return entry[1]
	return table[table.size() - 1][1]


## Scale roll skewed small at a wood's edge so the canopy steps down to the meadow.
static func edge_scale(sc: float, z: Dictionary) -> float:
	return sc * lerpf(0.35, 1.0, z["core"]) if z["grove"] > 0.0 else sc


## Path verge factor: 0 on the verge, ramping to 1 over PATH_RAMP.
static func path_factor(path_distance: float) -> float:
	return smoothstep(PATH_VERGE, PATH_VERGE + PATH_RAMP, path_distance)


## Feathered clearing rim: 0 inside, ramping to 1 at 1.4 × radius.
static func clearing_factor(distance: float, radius: float) -> float:
	return smoothstep(radius, radius * 1.4, distance)


## True if a trunk at p keeps its spacing from every trunk placed so far.
static func trunk_free(layout: Dictionary, p: Vector2, id: StringName) -> bool:
	var r: float = BIG_TREES.get(id, TRUNK_SPACING)
	var trunks: Dictionary = layout["trunks"]
	var k := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for q: Vector3 in trunks.get(k + Vector2i(dx, dz), []):
				if p.distance_to(Vector2(q.x, q.y)) < maxf(r, q.z):
					return false
	return true


static func add_trunk(layout: Dictionary, p: Vector2, id: StringName) -> void:
	var trunks: Dictionary = layout["trunks"]
	var k := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	if not trunks.has(k):
		trunks[k] = []
	trunks[k].append(Vector3(p.x, p.y, BIG_TREES.get(id, TRUNK_SPACING)))


## Specimen clumps in the open: Array of {center, size, members: PackedVector2Array,
## parent: int}. `open_at(p) -> float` is how open the ground is (1 = meadow),
## `rate_at(p) -> float` the chance a CLUMP_CELL square holds a clump.
static func clumps(layout: Dictionary, rect: Rect2, open_at: Callable, rate_at: Callable) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout["seed"], "clumps"])
	var nx := ceili(rect.size.x / CLUMP_CELL)
	var nz := ceili(rect.size.y / CLUMP_CELL)
	for iz in nz:
		for ix in nx:
			var c := rect.position + Vector2((ix + 0.2 + rng.randf() * 0.6) * CLUMP_CELL, (iz + 0.2 + rng.randf() * 0.6) * CLUMP_CELL)
			var keep := rng.randf()
			var size_roll := rng.randf()
			var turn := rng.randf() * TAU
			var clump_seed := rng.randi()
			if float(open_at.call(c)) < 0.95 or keep >= float(rate_at.call(c)):
				continue
			var size := 1
			var acc := 0.0
			for s in CLUMP_SIZES:
				acc += s[1]
				if size_roll <= acc:
					size = s[0]
					break
			# Loose triangles: members on a golden-angle spiral, jittered.
			var crng := RandomNumberGenerator.new()
			crng.seed = clump_seed
			var members := PackedVector2Array([c])
			for m in range(1, size):
				var a := turn + m * 2.39996 + crng.randf_range(-0.35, 0.35)
				var r := 3.4 + 1.6 * sqrt(float(m)) + crng.randf() * 1.2
				members.append(c + Vector2(cos(a), sin(a)) * r)
			out.append({"center": c, "size": size, "members": members, "parent": 0})
	return out


## True if a habitat tag is planted ground (orchard rows, walks).
static func is_formal(tag: StringName) -> bool:
	var s := String(tag)
	for t in FORMAL_TAGS:
		if s.contains(t):
			return true
	return false


## Planted rows over `rect` for a density (per m²): row angle from the seed and
## tag, spacing from the density, light jitter and a few gaps. Returns
## PackedVector2Array of positions; the caller filters by habitat.
static func rows(seed_value: int, tag: StringName, rect: Rect2, density: float) -> PackedVector2Array:
	var spacing := clampf(sqrt(1.0 / maxf(density, 0.0001)), ROW_SPACING.x, ROW_SPACING.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "rows", tag])
	var angle := rng.randf() * PI
	var along := Vector2(cos(angle), sin(angle))
	var across := Vector2(-along.y, along.x)
	var centre := rect.get_center()
	var half := rect.size.length() * 0.5
	var out := PackedVector2Array()
	var n := ceili(half / spacing)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var jx := rng.randf_range(-ROW_JITTER, ROW_JITTER)
			var jz := rng.randf_range(-ROW_JITTER, ROW_JITTER)
			var gap := rng.randf()
			if gap < ROW_GAPS:
				continue
			var p := centre + along * (j * spacing + jx) + across * (i * spacing * 1.1 + jz)
			if rect.has_point(p):
				out.append(p)
	return out


static func _unit(v: float) -> float:
	return clampf(v * 0.5 + 0.5, 0.0, 0.9999)
