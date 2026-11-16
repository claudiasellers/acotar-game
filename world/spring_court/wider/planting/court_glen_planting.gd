class_name CourtGlenPlanting
extends RefCounted
## The Starlight Glen's planting (docs/lanes/court-planting-by-place.md; the
## owner passed the pool's hollow on 2026-11-16, "it looks perfect", and the
## rest of the glen was planted the same way). It replaces the glen's decor
## recipe for trees and small plants: CourtScatterGenerator.decor_layers adds
## these layers when the region's content names this planting.
##
## Nothing is placed by area. Every plant answers to something on the land:
##   the pool   pillar birches round the starlight pool in clumps of one to
##              three (book ch 14), open where you come down from the mound
##              and on the line from there to the Glimmerfall; more of them in
##              twos and threes up the hollow's inner slopes; iris, reeds,
##              mint, fern and mossed stones on the far banks; what glows at
##              the water; snowdrops by the water and crocuses in the open
##   knolls     one tree (or one clump) on each knoll top, neighbours never
##              the same kind, so you find your way by them; the mound bare
##              (it is the overlook), the Glimmerfall's knoll its own
##   brooks     trees gathered in clumps along the brooks, on alternate banks;
##              iris, mint, fern and stones at the water, snowdrops beside it
##   the river  willows and birches in clumps along the Thornwater
##   the lake   Looking Lake wooded on its far side, willows where the bank
##              comes down to the water, open where you come to it
##   the mere   Willow Mere willows all round, open toward the Weeping Lady
##              and on the side you come to it from
##   the brae   a clump either side of the way just over the crest, so the
##              glen appears between trunks
##   thorn      a thorn bush or two at the outer edge of every clump (a wood's
##              edge is where the thorn grows)
##   flowers    the book's three (ch 18: crocuses, snowdrops, bluebells) pool
##              in the trees' shade: thick and tall in a clump's heart,
##              feathering to small outliers at its edge, trails of grass
##              winding through, fern and moss at the trunks' feet (owner:
##              "a bluebell grove", not "someone dumped a bunch of flowers
##              here"); the same flower in a crescent at each knoll's shaded
##              north foot; a drift of crocuses on a path's verge now and then
## The open glade between is the sward's (CourtSward), laid round the player.

const ID := &"glen"
const POOL := Vector2(-1300.0, 262.0)
const POOL_RADIUS := 18.0
const FLOOR := 42.0
const MOUND := Vector2(-1208.0, 270.0)
const GLIMMERFALL_KNOLL := Vector2(-1393.0, 260.0)
## Where you come down into the hollow (the bank the mound looks at): bearing
## from the pool, the half-angle kept clear of tall bank plants, and the
## half-angle of the gap in the ring of birches.
const ARRIVAL := 0.14
const ARRIVAL_HALF := 0.55
const ARRIVAL_MOUTH := 0.42
const RING_RADIUS := 30.0
const RING_COUNT := 16
## Groups of birches up the hollow's inner slopes: [bearing, distance from the pool, trees].
const SLOPE_GROUPS := [
	[0.72, 47.0, 3], [1.25, 55.0, 2], [1.75, 46.0, 3], [2.3, 52.0, 3], [2.72, 44.0, 2],
	[-2.7, 46.0, 3], [-2.2, 54.0, 2], [-1.7, 45.0, 3], [-1.15, 52.0, 3], [-0.68, 46.0, 2],
]
## The drifts laid in the hollow where the ground puts them:
## [flower, bearing from the pool, distance, length, depth, patches per m2].
const HOLLOW_DRIFTS := [
	# snowdrops close to the water
	[&"snowdrop", 2.0, 23.0, 16.0, 4.5, 2.4], [&"snowdrop", -1.5, 23.0, 18.0, 4.5, 2.4], [&"snowdrop", 0.8, 22.5, 10.0, 4.0, 2.4],
	[&"snowdrop", -0.55, 22.5, 8.0, 3.5, 2.4],
	# crocuses out in the open, where you come in
	[&"crocus", 0.45, 40.0, 18.0, 8.0, 1.9], [&"crocus", -0.3, 42.0, 16.0, 7.0, 1.9], [&"crocus", 0.1, 30.0, 9.0, 5.0, 1.9],
]
## The knolls' trees, [species, size, the shade it throws (m), how many stand
## together], taken in turn so neighbours differ. Each has its own outline:
## the oak wide, the sycamore a tower of billows, the elm a vase, the aspen a
## column, the thorn wind-blown, the birches a clump of white stems; and one
## blossom tree, the estate's cherry grown near twice its size.
const KNOLL_KINDS := [[&"great_oak", 1.0, 15.0, 1], [&"great_sycamore", 1.0, 12.0, 1], [&"great_elm", 1.0, 12.0, 1],
	[&"aspen_spire", 1.0, 6.0, 2], [&"old_thorn", 1.5, 9.0, 1], [&"pillar_birch", 1.0, 8.0, 3], [&"cherry_blossom", 1.9, 10.0, 1]]
const KNOLL_GAP := 30.0
const FLOWERS: Array[StringName] = [&"bluebell", &"snowdrop", &"crocus"]
## A flower's patches: [the full ones, the small one at a pool's edge].
const PATCHES := {
	&"bluebell": [["bluebell_patch_a"], "bluebell_patch_c"],
	&"snowdrop": [["snowdrop_patch_a"], "snowdrop_patch_b"],
	&"crocus": [["crocus_patch_a"], "crocus_patch_c"],
}
## A tree is its full self within TREE_NEAR and its far form beyond, to TREE_FAR.
## (A layer switches by the chunk, CourtScatterGenerator.NEAR_CHUNK: a tree
## changes somewhere between TREE_NEAR - 45 and TREE_NEAR + 45 m.)
const TREE_NEAR := 180.0
const TREE_FAR := 800.0
## A flower patch is drawn flower by flower within FLOWER_NEAR, as its mid form
## (fewer, bigger plants: about a third of the triangles) to FLOWER_MID, and
## as its far cushion beyond, to FLOWER_FAR. A layer switches by the chunk,
## FINE_CHUNK: within 17 m either way.
const FLOWER_NEAR := 60.0
const FLOWER_MID := 110.0
const FLOWER_FAR := 220.0
## The chunk a place's flowers are drawn by (tag "fine"): small, so the steps
## above fall near where they say.
const FINE_CHUNK := 24.0
## Flower patches tried per m2 of a trunk's shade.
const SHADE_TRIES := 2.1


## What a place's planting hands the region: its layers, and where every
## trunk stands (the sward grows long at a trunk's foot).
class Plan:
	extends RefCounted
	var content: CourtRegionContent
	var layers := {}
	var order: Array[StringName] = []
	var trunks := PackedVector2Array()

	func _layer(id: StringName) -> ScatterLayer:
		if not layers.has(id):
			var l := ScatterLayer.new()
			l.id = id
			layers[id] = l
			order.append(id)
		return layers[id]

	func ground(p: Vector2) -> Vector3:
		return Vector3(p.x, WorldHeight.height_at(p.x, p.y), p.y)

	var _sightlines: Array = []   # [eye, mark]: what the land leaves seen (CourtHeight.SIGHTLINES)
	var _sightlines_ready := false

	## Whether a tree `tall` metres high at p would stand in a sightline: its
	## crown (a drum from a quarter of its height to its top, three tenths of
	## its height in radius, and a metre to spare) across the line of sight.
	func closes_a_sightline(p: Vector2, tall: float) -> bool:
		if not _sightlines_ready:
			_sightlines_ready = true
			for line: Array in CourtHeight.SIGHTLINES:
				if not line[3]:
					continue
				var from: Vector2 = CourtHeight.site(line[0]) if line[0] is StringName else Vector2(line[0][0], line[0][1])
				var to := CourtHeight.site(line[1])
				_sightlines.append([Vector3(from.x, WorldHeight.height_at(from.x, from.y) + 1.7, from.y),
					Vector3(to.x, WorldHeight.height_at(to.x, to.y) + float(line[2]) + 0.5, to.y)])
		var foot := WorldHeight.height_at(p.x, p.y)
		for line: Array in _sightlines:
			var a: Vector3 = line[0]
			var b: Vector3 = line[1]
			var a2 := Vector2(a.x, a.z)
			var b2 := Vector2(b.x, b.z)
			var near := Geometry2D.get_closest_point_to_segment(p, a2, b2)
			if near.distance_to(p) > tall * 0.3 + 1.0:
				continue
			var y := lerpf(a.y, b.y, a2.distance_to(near) / maxf(a2.distance_to(b2), 0.01))
			if y > foot + tall * 0.25 - 1.0 and y < foot + tall + 1.0:
				return true
		return false

	## A tree: its near mesh, its far form beyond. Returns false off the region's
	## ground, wherever the court keeps open (CourtLandHabitats: a path, a gate,
	## a viewpoint, a story's spot, water, a clearing), and where its crown
	## would close one of the court's sightlines.
	func tree(species: StringName, build: int, p: Vector2, yaw: float, size: float, sink: float = 0.0) -> bool:
		if not content.owns(p) or CourtLandHabitats.keep_open(p.x, p.y):
			return false
		var tall := (CourtGreatTrees.height_of(species) if CourtPlacePlants.is_great(species) else FloraLib.height_of(species)) * size
		if closes_a_sightline(p, tall):
			return false
		var b := posmod(build, CourtPlacePlants.builds(species))
		var id := StringName("place_tree_%s_%s" % [species, CourtPlacePlants.LETTERS[b]])
		var l := _layer(id)
		if l.mesh == null:
			l.mesh = CourtPlacePlants.tree(species, b)
			l.impostor_mesh = CourtPlacePlants.tree_far(species, b)
			l.draw_distance = TREE_NEAR
			l.impostor_distance = TREE_FAR
			l.tags = PackedStringArray(["tree", "near", "place"])
			l.wind = 0.5
		l.add(ground(p) - Vector3(0.0, sink, 0.0), yaw, size)
		trunks.append(p)
		return true

	## A flower patch (tools/grove): near, then its mid form (a second layer over
	## the same patches, filled in by out()), then its far cushion.
	func flower(patch: String, p: Vector2, yaw: float, size: float) -> void:
		if not content.owns(p):
			return
		var l := _layer(StringName("place_flower_" + patch))
		if l.mesh == null:
			l.mesh = CourtPlacePlants.glade(patch)
			l.draw_distance = FLOWER_NEAR
			l.cast_shadow = false
			l.tags = PackedStringArray(["fine", "place"])
			l.wind = 0.6
			var mid := _layer(StringName("place_flower_%s_mid" % patch))
			mid.mesh = CourtPlacePlants.glade(patch + "_mid")
			mid.impostor_mesh = CourtPlacePlants.glade(patch + "_far")
			mid.draw_from = FLOWER_NEAR
			mid.draw_distance = FLOWER_MID
			mid.impostor_distance = FLOWER_FAR
			mid.cast_shadow = false
			mid.tags = PackedStringArray(["fine", "place", "mid"])
			mid.wind = 0.6
		l.add(ground(p), yaw, size)

	## A fern (tools/grove), one of three.
	func fern(which: int, p: Vector2, yaw: float, size: float) -> void:
		if not content.owns(p):
			return
		var l := _layer(StringName("place_fern_" + "abc"[posmod(which, 3)]))
		if l.mesh == null:
			l.mesh = CourtPlacePlants.glade("fern_" + "abc"[posmod(which, 3)])
			l.draw_distance = 150.0
			l.cast_shadow = false
			l.tags = PackedStringArray(["place"])
			l.wind = 0.5
		l.add(ground(p), yaw, size)

	## One of the woods' plants (FloraLibrary), as it comes.
	func plant(kind: StringName, p: Vector2, yaw: float, size: float, far: float = 220.0, shadow: bool = false) -> void:
		if not content.owns(p):
			return
		var l := _layer(StringName("place_%s" % kind))
		if l.mesh == null:
			l.mesh = FloraLibrary.mesh(kind)
			l.draw_distance = far
			l.cast_shadow = shadow
			l.tags = PackedStringArray(["place"])
		l.add(ground(p), yaw, size)

	func out() -> Array[ScatterLayer]:
		var all: Array[ScatterLayer] = []
		for id in order:
			if String(id).ends_with("_mid"):
				(layers[id] as ScatterLayer).instances = (layers[StringName(String(id).trim_suffix("_mid"))] as ScatterLayer).instances
			if (layers[id] as ScatterLayer).count() > 0:
				all.append(layers[id])
		return all


static func applies(content: CourtRegionContent) -> bool:
	return content.place_planting == ID


static var _lock := Mutex.new()
static var _trunks := {}


## The trunks of the region's planting as last laid (for its sward).
static func trunks(region_id: StringName) -> PackedVector2Array:
	_lock.lock()
	var t: PackedVector2Array = _trunks.get(region_id, PackedVector2Array())
	_lock.unlock()
	return t


## The glen's planting as scatter layers. Deterministic for a content's seed.
static func layers(content: CourtRegionContent) -> Array[ScatterLayer]:
	var plan := Plan.new()
	plan.content = content
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([content.seed, "glen planting"])
	var wave := FastNoiseLite.new()
	wave.seed = 11
	wave.frequency = 0.035
	# every group of trees, with the flower that pools in its shade:
	# {trunks: Array[Vector2], reach: Array[float], flower, grove (the pool's: the odd white one, deeper and paler parts)}
	var groups: Array[Dictionary] = []
	var steps: Array[Callable] = [
		func() -> void: _pool_ring(plan, rng, groups),
		func() -> void: _knolls(plan, rng, groups),
		func() -> void: _brooks(plan, rng, groups),
		func() -> void: _river(plan, rng, groups),
		func() -> void: _lake(plan, rng, groups),
		func() -> void: _mere(plan, rng, groups),
		func() -> void: _brae(plan, rng, groups),
		func() -> void: _thorn(plan, rng, groups),
		func() -> void: _hollow_ground(plan, rng, wave),
		func() -> void: _shade_flowers(plan, rng, wave, groups),
		func() -> void: _knoll_crescents(plan, rng, wave, groups),
		func() -> void: _verges(plan, rng),
	]
	for step in steps:
		if BuildCancel.requested(content.region_id):
			return []
		step.call()
	_lock.lock()
	_trunks[content.region_id] = plan.trunks
	_lock.unlock()
	return plan.out()


# --- the pool's hollow ----------------------------------------------------------

## The pillar birches round the pool, in clumps of one to three with gaps
## between: a ring you can see is a ring from the mound, and a grove when you
## stand in it. And more in twos and threes up the hollow's inner slopes
## behind: they close the hollow in, their trunks at different heights, a
## stand of foxgloves in the light at each group's inner edge.
static func _pool_ring(plan: Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var trunks: Array = []
	var reach: Array = []
	var build := 0
	for i in RING_COUNT:
		var a := TAU * (float(i) + rng.randf_range(-0.28, 0.28)) / float(RING_COUNT)
		if absf(angle_difference(a, ARRIVAL)) < 0.2 or absf(angle_difference(a, PI)) < 0.17:
			continue    # the way in stays open, and the line from it to the Glimmerfall
		var heart := POOL + Vector2.from_angle(a) * (RING_RADIUS + rng.randf_range(-1.5, 4.0))
		var count := [1, 2, 2, 3, 3][rng.randi() % 5] as int
		var stood: Array[Vector2] = []
		var tries := 0
		while stood.size() < count and tries < 30:
			tries += 1
			var p := heart if stood.is_empty() else heart + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.4, 5.2)
			var ok := p.distance_to(POOL) > POOL_RADIUS + 6.0 and not wet(p, 3.0)
			for q in stood:
				if p.distance_to(q) < 2.4:
					ok = false
			if not ok:
				continue
			stood.append(p)
			var turn := rng.randf() * TAU
			# the clump's first tree the tallest, its fellows slighter
			var size := rng.randf_range(0.98, 1.14) if stood.size() == 1 else rng.randf_range(0.76, 0.98)
			build += 1
			# no clump stands in the mouth of the way in: you come down to the pool across open grass
			if absf(angle_difference((heart - POOL).angle(), ARRIVAL)) < ARRIVAL_MOUTH:
				continue
			if plan.tree(&"pillar_birch", build, p, turn, size):
				trunks.append(p)
				reach.append(9.5)
	for g: Array in SLOPE_GROUPS:
		var mid := POOL + Vector2.from_angle(g[0]) * float(g[1])
		var stood_here: Array[Vector2] = []
		for k in int(g[2]):
			var p := mid + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 6.5)
			if steep(p) or wet(p, 3.0):
				continue
			build += 1
			# set a little into the slope
			if plan.tree(&"pillar_birch", build, p, rng.randf() * TAU, rng.randf_range(0.78, 1.05), 0.25):
				trunks.append(p)
				reach.append(7.5)
				stood_here.append(p)
		var out := Vector2.from_angle(g[0])
		var stand := POOL + out * (float(g[1]) - rng.randf_range(5.0, 8.0)) + out.orthogonal() * rng.randf_range(-5.0, 5.0)
		for k in 6:
			var p := stand + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.2, 1.8)
			var clear := not steep(p)
			for t in stood_here:
				if p.distance_to(t) < 1.2:
					clear = false
			if clear:
				plan.plant(&"foxglove", p, rng.randf() * TAU, rng.randf_range(0.9, 1.4), 220.0, true)
	groups.append({"trunks": trunks, "reach": reach, "flower": &"bluebell", "grove": true, "hollow": true})


## The hollow's own ground plants: the laid drifts of snowdrop and crocus,
## crocuses over the mound's top, the pool's far banks, and what glows.
static func _hollow_ground(plan: Plan, rng: RandomNumberGenerator, wave: FastNoiseLite) -> void:
	for dr: Array in HOLLOW_DRIFTS:
		var mid := POOL + Vector2.from_angle(dr[1]) * float(dr[2])
		var along := Vector2.from_angle(float(dr[1]) + PI * 0.5)    # a drift lies along the ring
		var out := Vector2.from_angle(dr[1])
		var patches: Array = PATCHES[dr[0]]
		for i in int(float(dr[3]) * float(dr[4]) * float(dr[5])):
			var u := rng.randfn(0.0, 0.33)
			var v := rng.randfn(0.0, 0.33)
			if absf(u) > 1.0 or absf(v) > 1.0:
				continue
			var p := mid + along * (u * float(dr[3]) * 0.5) + out * (v * float(dr[4]) * 0.5)
			# a ragged edge, and gaps inside
			if wave.get_noise_2d(p.x * 6.0, p.y * 6.0) < -0.25:
				continue
			if p.distance_to(POOL) < POOL_RADIUS + 1.0 or steep(p) or not dry(p, 0.6):
				continue
			var full := absf(u) < 0.6 and absf(v) < 0.6
			var patch: String = (patches[0] as Array)[rng.randi() % (patches[0] as Array).size()] if full else patches[1]
			plan.flower(patch, p, rng.randf() * TAU, rng.randf_range(1.0, 1.5))
	# the mound you arrive on: crocuses over its top, and no tree
	for i in 2600:
		var p := MOUND + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 30.0
		var d := p.distance_to(MOUND)
		if d < 4.0 or rng.randf() > lerpf(1.0, 0.15, clampf((d - 14.0) / 16.0, 0.0, 1.0)):
			continue
		if wave.get_noise_2d(p.x * 6.0, p.y * 6.0) > 0.3 and dry(p, 0.6) and not steep(p):
			plan.flower("crocus_patch_" + "ac"[rng.randi() % 2], p, rng.randf() * TAU, rng.randf_range(0.85, 1.4))
	# the pool's far banks; the bank you arrive at is left to the grass
	var kinds := {&"iris_clump": 26, &"reed_clump": 20, &"cattail": 10, &"fern": 30, &"water_mint": 24, &"mossy_rock": 9, &"moss_mound": 12}
	for kind: StringName in kinds:
		var placed := 0
		var tries := 0
		while placed < int(kinds[kind]) and tries < 400:
			tries += 1
			var a := rng.randf() * TAU
			if absf(angle_difference(a, ARRIVAL)) < ARRIVAL_HALF:
				continue
			# reeds and iris at the very edge, in groups; fern and stone a step back
			var at_edge := kind in [&"iris_clump", &"reed_clump", &"cattail", &"water_mint"]
			var group := a + rng.randfn(0.0, 0.05) if at_edge else a
			var r := POOL_RADIUS + (rng.randf_range(-0.3, 1.2) if at_edge else rng.randf_range(0.8, 4.0))
			var p := POOL + Vector2.from_angle(group) * r
			placed += 1
			if kind == &"fern":
				plan.fern(placed, p, rng.randf() * TAU, rng.randf_range(0.85, 1.35))
			else:
				plan.plant(kind, p, rng.randf() * TAU, rng.randf_range(0.85, 1.35), 220.0, kind in [&"mossy_rock", &"moss_mound"])
	# what glows, near the water
	for spec: Array in [[&"starmoss", 26, 0.6, 3.5], [&"glowcap", 22, 1.5, 9.0], [&"faelight_dandelion", 60, 2.0, 20.0]]:
		for i in int(spec[1]):
			var p := POOL + Vector2.from_angle(rng.randf() * TAU) * (POOL_RADIUS + rng.randf_range(float(spec[2]), float(spec[3])))
			plan.plant(spec[0], p, rng.randf() * TAU, rng.randf_range(0.9, 1.4))


# --- the rest of the glen -------------------------------------------------------

## The top of every knoll on the region's ground, highest first (as
## CourtPlanting.knoll_tops, but whatever habitat was authored there: the
## planting reads the land, not the old habitat map).
static func knoll_tops(content: CourtRegionContent) -> Array[Vector2]:
	var g := CourtPlanting.grid(content)
	var r: Rect2 = g["rect"]
	var nx: int = g["nx"]
	var forms: PackedByteArray = g["forms"]
	var found: Array[Vector3] = []
	for i in forms.size():
		if forms[i] != CourtLandHabitats.Form.KNOLL:
			continue
		var p := Vector2(r.position.x + (i % nx + 0.5) * CourtPlanting.STEP, r.position.y + (i / nx + 0.5) * CourtPlanting.STEP)
		var h := CourtHeight.height_at(p.x, p.y)
		var stride := 6.0
		while stride > 0.7:
			var moved := false
			for k in 8:
				var q := p + Vector2.from_angle(TAU * k / 8.0) * stride
				var hq := CourtHeight.height_at(q.x, q.y)
				if hq > h + 0.01:
					p = q
					h = hq
					moved = true
			if not moved:
				stride *= 0.5
		found.append(Vector3(p.x, h, p.y))
	found.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y > b.y)
	var out: Array[Vector2] = []
	for f in found:
		var p := Vector2(f.x, f.z)
		var fresh := content.owns(p)
		for q in out:
			if q.distance_to(p) < KNOLL_GAP:
				fresh = false
				break
		if fresh:
			out.append(p)
	return out


## One tree (or one clump) on each knoll top, neighbours never the same kind.
## The mound stays bare and the Glimmerfall's knoll keeps its fall.
static func _knolls(plan: Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var placed: Array = []   # [top, kind index]
	for top in knoll_tops(plan.content):
		if top.distance_to(MOUND) < 40.0 or top.distance_to(GLIMMERFALL_KNOLL) < 30.0 or top.distance_to(POOL) < FLOOR + 20.0 \
				or CourtLandHabitats.keep_open(top.x, top.y) or CourtLandHabitats.path_distance(top.x, top.y) < 9.0:
			continue
		var kind := rng.randi() % KNOLL_KINDS.size()
		# not the kind of either of its two nearest neighbours
		var near: Array = placed.duplicate()
		near.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).distance_to(top) < (b[0] as Vector2).distance_to(top))
		var taken: Array = []
		for n in mini(2, near.size()):
			taken.append(near[n][1])
		while kind in taken:
			kind = (kind + 1) % KNOLL_KINDS.size()
		placed.append([top, kind])
		var k: Array = KNOLL_KINDS[kind]
		var trunks: Array = []
		var reach: Array = []
		for n in int(k[3]):
			var p := top if n == 0 else top + Vector2.from_angle(TAU * float(n) / float(k[3]) + rng.randf()) * rng.randf_range(2.6, 4.2)
			var size := float(k[1]) * (rng.randf_range(0.94, 1.08) if n == 0 else rng.randf_range(0.78, 0.95))
			if plan.tree(k[0], rng.randi(), p, rng.randf() * TAU, size):
				trunks.append(p)
				reach.append(float(k[2]))
		if not trunks.is_empty():
			groups.append({"trunks": trunks, "reach": reach, "flower": FLOWERS[placed.size() % 3], "knoll": top})


## The same flower as under a knoll's tree in a crescent round the knoll's
## shaded north foot, where its slope eases.
static func _knoll_crescents(plan: Plan, rng: RandomNumberGenerator, wave: FastNoiseLite, groups: Array[Dictionary]) -> void:
	for g in groups:
		if not g.has("knoll"):
			continue
		var top: Vector2 = g["knoll"]
		var patches: Array = PATCHES[g["flower"]]
		var foot := 30.0
		var r := 9.0
		while r < 60.0:
			if CourtHeight.height_at(top.x, top.y - r + 3.0) - CourtHeight.height_at(top.x, top.y - r) < 0.36:
				foot = r
				break
			r += 3.0
		for i in int(foot * 20.0):
			var turn := rng.randfn(0.0, 0.6)
			var out := rng.randfn(0.0, 4.5)
			var p := top + Vector2.from_angle(-PI * 0.5 + turn) * (foot + 2.0 + out)
			if wave.get_noise_2d(p.x * 4.0, p.y * 4.0) < -0.2 or p.distance_to(POOL) < FLOOR + 30.0 or not growable(p, 1.2):
				continue
			var full := absf(turn) < 0.6 and absf(out) < 4.0
			var patch: String = (patches[0] as Array)[rng.randi() % (patches[0] as Array).size()] if full else patches[1]
			plan.flower(patch, p, rng.randf() * TAU, rng.randf_range(1.0, 1.4) if full else rng.randf_range(0.7, 1.05))


## A clump of one species round a heart: the first tree the tallest. Returns
## the trunks that found open ground.
static func _clump(plan: Plan, rng: RandomNumberGenerator, heart: Vector2, count: int, species: StringName, size: float,
		spread: float) -> Array:
	var stood: Array = []
	var tries := 0
	while stood.size() < count and tries < 24:
		tries += 1
		var p := heart if tries == 1 else heart + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(spread * 0.6, spread * 1.5)
		# clear of the water, and far enough from a path that no crown hangs over it
		var ok := not CourtLandHabitats.keep_open(p.x, p.y) and not steep(p) and not wet(p, 2.5) \
				and CourtLandHabitats.path_distance(p.x, p.y) > 9.0 and p.distance_to(POOL) > FLOOR + 30.0
		for q: Vector2 in stood:
			if q.distance_to(p) < spread * 0.6:
				ok = false
		if not ok:
			continue
		if plan.tree(species, rng.randi(), p, rng.randf() * TAU, size * (rng.randf_range(0.98, 1.12) if stood.is_empty() else rng.randf_range(0.78, 0.98))):
			stood.append(p)
	return stood


static func _group(trunks: Array, reach: float, flower: StringName) -> Dictionary:
	var each: Array = []
	each.resize(trunks.size())
	each.fill(reach)
	return {"trunks": trunks, "reach": each, "flower": flower}


## Trees gathered in clumps along the brooks, on alternate banks, and the
## banks' own plants: iris and water mint at the water, fern and mossed stones
## on the banks, snowdrops beside it in stretches. Thickest where the Glimmer
## Brook comes down into the pool.
static func _brooks(plan: Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	for brook: Dictionary in CourtHeight.brooks():
		var pts: PackedVector2Array = brook["points"]
		var half: float = brook["half_width"]
		var until := rng.randf_range(10.0, 30.0)
		var side_of := 1.0
		for k in pts.size() - 1:
			var along := pts[k + 1] - pts[k]
			if along.length() < 0.01 or not plan.content.owns(pts[k]):
				continue
			var side := along.normalized().orthogonal()
			var from_pool := pts[k].distance_to(POOL)
			var own := from_pool < 95.0   # the hollow's stretch
			# a clump of trees every so often (none inside the hollow: the birches are its trees)
			until -= along.length()
			if until < 0.0 and from_pool > FLOOR + 76.0:
				until = rng.randf_range(34.0, 62.0)
				side_of = -side_of
				var willow := rng.randf() < 0.45
				var heart := pts[k] + side * side_of * (half + rng.randf_range(4.0, 7.5))
				var trunks := _clump(plan, rng, heart, [1, 2, 2, 3][rng.randi() % 4], &"willow" if willow else &"birch", 1.0, 3.2)
				if not trunks.is_empty():
					groups.append(_group(trunks, 8.0, &"snowdrop" if willow else &"bluebell"))
			# the banks: a place to plant every so often, however finely the brook's line is cut
			var want := along.length() / (0.5 if own else 0.7)
			for j in int(want) + (1 if rng.randf() < fmod(want, 1.0) else 0):
				var on := pts[k] + along * rng.randf()
				var far := on.distance_to(POOL)
				if far < POOL_RADIUS + 0.5:
					continue
				var thin := clampf(1.0 - (far - 30.0) / 65.0, 0.25, 1.0) if own else 0.62
				var b := side * (1.0 if rng.randf() < 0.5 else -1.0)
				var roll := rng.randf() / thin
				var yaw := rng.randf() * TAU
				if roll < 0.2:
					plan.plant(&"iris_clump", on + b * (half + rng.randf_range(-0.3, 0.5)), yaw, rng.randf_range(0.8, 1.2))
				elif roll < 0.42:
					plan.plant(&"water_mint", on + b * (half + rng.randf_range(-0.4, 0.4)), yaw, rng.randf_range(0.9, 1.4))
				elif roll < 0.47:
					plan.plant(&"reed_clump", on + b * (half + rng.randf_range(-0.5, 0.1)), yaw, rng.randf_range(0.6, 0.9))
				elif roll < 0.62:
					plan.fern(rng.randi(), on + b * (half + rng.randf_range(0.3, 1.8)), yaw, rng.randf_range(0.5, 0.85))
				elif roll < 0.67:
					plan.plant(&"mossy_rock", on + b * (half + rng.randf_range(-0.6, 0.8)), yaw, rng.randf_range(0.5, 1.0), 220.0, true)
				elif roll < 0.74:
					plan.plant(&"moss_mound", on + b * (half + rng.randf_range(0.0, 1.2)), yaw, rng.randf_range(0.7, 1.2))
				# snowdrops beside it, in stretches
				var stretch := sin(far * 0.22) > 0.1 if own else sin(on.x * 0.07 + on.y * 0.05) > 0.45
				if stretch and rng.randf() < (0.75 * thin if own else 0.5):
					var at := on + b * (half + rng.randf_range(0.7, 3.2))
					var size := rng.randf_range(1.0, 1.4)
					if dry(at, 0.5):
						plan.flower("snowdrop_patch_" + "ab"[rng.randi() % 2], at, yaw, size)


## Willows and birches in clumps along the Thornwater, on the first dry, open
## ground back from the water.
static func _river(plan: Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var line: Array = MacroHeight.THORNWATER
	var until := 20.0
	var side_of := 1.0
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		var steps := int(a.distance_to(b) / 6.0) + 1
		for s in steps:
			var on := a.lerp(b, float(s) / float(steps))
			until -= a.distance_to(b) / float(steps)
			if until > 0.0 or not plan.content.owns(on):
				continue
			until = rng.randf_range(42.0, 76.0)
			side_of = -side_of
			var side := (b - a).normalized().orthogonal() * side_of
			for back: float in [10.0, 13.0, 16.0, 20.0, 25.0]:
				var heart: Vector2 = on + side * back
				if CourtLandHabitats.keep_open(heart.x, heart.y):
					continue
				var willow := rng.randf() < 0.6
				var trunks := _clump(plan, rng, heart, [2, 2, 3, 3][rng.randi() % 4], &"willow" if willow else &"birch", 1.05, 3.4)
				if not trunks.is_empty():
					groups.append(_group(trunks, 8.0, &"snowdrop" if willow else &"bluebell"))
				break


## Looking Lake: a wood on the far side from where the lake walk reaches it,
## willows wherever the bank comes down to the water, open on the near side;
## reeds and iris in the shallows.
static func _lake(plan: Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var lake := _lake_named(&"looking_lake")
	if lake.is_empty():
		return
	var centre: Vector2 = lake["center"]
	var radius: float = lake["radius"]
	var level: float = lake["level"]
	var come := (LAKE_WALK_END - centre).angle()
	var far_side := come + PI
	var wood: Array = []
	var tries := 0
	while wood.size() < LAKE_WOOD and tries < 1600:
		tries += 1
		var a := far_side + rng.randfn(0.0, 0.62)
		if absf(angle_difference(a, far_side)) > 1.45:
			continue
		# thick at the water, thinning back from it
		var back := 3.0 + absf(rng.randfn(0.0, 15.0))
		var p := centre + Vector2.from_angle(a) * (radius + back)
		if back > 44.0 or CourtLandHabitats.keep_open(p.x, p.y) or steep(p):
			continue
		var ok := true
		for q: Vector2 in wood:
			if q.distance_to(p) < 4.2:
				ok = false
		if not ok:
			continue
		var species: StringName = &"willow" if back < 7.0 and rng.randf() < 0.6 else (&"oak" if rng.randf() < 0.4 else &"birch")
		# and a great tree here and there, back from the water, to stand over the rest in the reflection
		if back > 12.0 and rng.randf() < 0.1:
			species = &"great_elm" if rng.randf() < 0.5 else &"great_oak"
		if plan.tree(species, rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.85, 1.15)):
			wood.append(p)
	groups.append(_group(wood, 8.5, &"bluebell"))
	# willows at the water wherever the bank comes down to it
	var low: Array = []
	for i in 72:
		var a := TAU * float(i) / 72.0
		var p := centre + Vector2.from_angle(a) * (radius + rng.randf_range(3.0, 5.0))
		if CourtHeight.height_at(p.x, p.y) - level > 2.2 or absf(angle_difference(a, come)) < 0.35 or CourtLandHabitats.keep_open(p.x, p.y):
			continue
		var ok := low.size() < 8
		for q: Vector2 in low:
			if q.distance_to(p) < 10.0:
				ok = false
		for q: Vector2 in wood:
			if q.distance_to(p) < 5.0:
				ok = false
		if ok and plan.tree(&"willow", rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.95, 1.2)):
			low.append(p)
	if not low.is_empty():
		groups.append(_group(low, 7.5, &"snowdrop"))
	# the shallows: thick on the wooded side, a few groups on the open one, none under a cliff
	var kinds: Array[StringName] = [&"reed_clump", &"cattail", &"iris_clump", &"water_mint"]
	for i in 620:
		var a := rng.randf() * TAU
		var wooded := absf(angle_difference(a, far_side)) < 1.5
		if (not wooded and sin(a * 7.0) < 0.6) or absf(angle_difference(a, come)) < 0.35:
			continue
		var edge := centre + Vector2.from_angle(a) * (radius + 2.0)
		if CourtHeight.height_at(edge.x, edge.y) - level > 3.0:
			continue
		plan.plant(kinds[rng.randi() % 4], centre + Vector2.from_angle(a) * (radius + rng.randf_range(-2.6, -0.4)), rng.randf() * TAU,
			rng.randf_range(0.95, 1.4), 320.0)


## Where the lake walk reaches Looking Lake, and how many trees its far wood holds.
const LAKE_WALK_END := Vector2(-1150.0, -200.0)
const LAKE_WOOD := 90


## Willow Mere: willows all round, open toward the Weeping Lady and on the
## side you come to it from; reeds and cattails in the shallows.
static func _mere(plan: Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var mere := _lake_named(&"willow_mere")
	if mere.is_empty():
		return
	var centre: Vector2 = mere["center"]
	var radius: float = mere["radius"]
	var lady := (CourtHeight.site(&"weeping_lady") - centre).angle()
	var willows: Array = []
	for i in 13:
		var a := TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / 13.0
		if absf(angle_difference(a, lady)) < 0.62 or absf(angle_difference(a, 0.0)) < 0.22 or absf(angle_difference(a, lady + PI)) < 0.42:
			continue
		var p := centre + Vector2.from_angle(a) * (radius + rng.randf_range(2.5, 6.5))
		if CourtLandHabitats.keep_open(p.x, p.y):
			continue
		if plan.tree(&"willow", rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.9, 1.2)):
			willows.append(p)
	groups.append(_group(willows, 7.5, &"snowdrop"))
	var kinds: Array[StringName] = [&"reed_clump", &"cattail", &"iris_clump"]
	for i in 90:
		var a := rng.randf() * TAU
		if absf(angle_difference(a, lady)) < 0.35:
			continue
		plan.plant(kinds[rng.randi() % 3], centre + Vector2.from_angle(a + rng.randfn(0.0, 0.04)) * (radius + rng.randf_range(-2.2, -0.3)),
			rng.randf() * TAU, rng.randf_range(0.9, 1.35), 320.0)


## The brae: a clump either side of the line you look along as you come over
## the crest, so the glen appears between trunks.
static func _brae(plan: Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var top := CourtHeight.site(&"brae_top")
	var look := (Vector2(-1400.0, -300.0) - top).normalized()
	for side: float in [-1.0, 1.0]:
		var heart := top + look * rng.randf_range(36.0, 48.0) + look.orthogonal() * side * rng.randf_range(15.0, 21.0)
		var trunks := _clump(plan, rng, heart, 4, &"oak" if side < 0.0 else &"birch", 1.05, 4.5)
		if not trunks.is_empty():
			groups.append(_group(trunks, 9.0, &"bluebell"))


## Thorn bushes, white with may: one or two at the outer edge of every clump
## of trees, and now and then a pair down a lone tree's knoll.
static func _thorn(plan: Plan, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	for g in groups:
		var trunks: Array = g["trunks"]
		if trunks.is_empty() or g.has("hollow") or (trunks.size() == 1 and rng.randf() > 0.4):
			continue
		var mid := Vector2.ZERO
		for t: Vector2 in trunks:
			mid += t / float(trunks.size())
		var wide := 0.0
		for t: Vector2 in trunks:
			wide = maxf(wide, t.distance_to(mid))
		for n in (2 if trunks.size() == 1 else 1 + rng.randi() % 2):
			for attempt in 6:
				var p := mid + Vector2.from_angle(rng.randf() * TAU) * (wide + rng.randf_range(4.5, 8.0) + (6.0 if trunks.size() == 1 else 0.0))
				if CourtLandHabitats.keep_open(p.x, p.y) or steep(p) or wet(p, 1.5) or CourtLandHabitats.path_distance(p.x, p.y) < 4.0 \
						or p.distance_to(POOL) < FLOOR + 76.0:
					continue
				if plan.tree(&"thorn_bush", rng.randi(), p, rng.randf() * TAU, rng.randf_range(0.8, 1.25)):
					plan.trunks.resize(plan.trunks.size() - 1)   # a bush is no trunk to grow long grass round
				break


## A drift of crocuses on a path's verge now and then.
static func _verges(plan: Plan, rng: RandomNumberGenerator) -> void:
	for path: Dictionary in CourtHeight.paths():
		var pts: PackedVector2Array = path["points"]
		var half: float = path["half_width"]
		var until := rng.randf_range(20.0, 60.0)
		for k in pts.size() - 1:
			var along := pts[k + 1] - pts[k]
			until -= along.length()
			if until > 0.0 or along.length() < 0.01 or not plan.content.owns(pts[k]) or pts[k].distance_to(POOL) < FLOOR + 76.0:
				continue
			until = rng.randf_range(70.0, 120.0)
			var side := along.normalized().orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
			var length := rng.randf_range(9.0, 16.0)
			for i in int(length * 3.2):
				var p := pts[k] + along.normalized() * rng.randfn(0.0, length * 0.3) + side * (half + 0.8 + absf(rng.randfn(0.0, 1.6)))
				if growable(p, 0.8):
					plan.flower("crocus_patch_" + "ac"[rng.randi() % 2], p, rng.randf() * TAU, rng.randf_range(1.0, 1.45))


## Each group's flower pools in its shade: thick and tall in the heart,
## feathering to small outliers at the edge, trails of grass through it, fern
## and moss at the trunks' feet. In the pool's grove there is the odd white
## bluebell too.
static func _shade_flowers(plan: Plan, rng: RandomNumberGenerator, wave: FastNoiseLite, groups: Array[Dictionary]) -> void:
	var trail := FastNoiseLite.new()
	trail.seed = 31
	trail.frequency = 0.045
	trail.fractal_octaves = 2
	for g in groups:
		if BuildCancel.requested(plan.content.region_id):
			return
		var trunks: Array = g["trunks"]
		var reaches: Array = g["reach"]
		var patches: Array = PATCHES[g["flower"]]
		var grove: bool = g.has("grove")
		for ti in trunks.size():
			var t: Vector2 = trunks[ti]
			var reach: float = reaches[ti]
			for i in int(PI * reach * reach * SHADE_TRIES):
				var p := t + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * reach
				var shade := 0.0
				var over := 0
				var foot := INF
				for ui in trunks.size():
					var d := p.distance_to(trunks[ui])
					if d < float(reaches[ui]):
						over += 1
						shade += pow(1.0 - d / float(reaches[ui]), 1.4)
						foot = minf(foot, d)
				shade = minf(shade, 1.0)
				# a spot under several trees is tried once for each: thin it back
				var roll := rng.randf()
				var keep := rng.randf()
				var yaw := rng.randf() * TAU
				var size := rng.randf()
				var pick := rng.randi()
				if (over > 1 and roll > 1.0 / float(over)) or shade <= 0.02:
					continue
				if foot < 1.1:
					# the roots' own ground: fern and moss, no flowers
					if keep < 0.1 and growable(p, 1.2):
						plan.fern(pick, p, yaw, lerpf(0.5, 0.8, size))
					elif keep < 0.14 and growable(p, 1.2):
						plan.plant(&"moss_mound", p, yaw, lerpf(0.6, 1.0, size), 150.0)
					continue
				# trails of grass winding through, and soft thin places
				var on_trail := absf(trail.get_noise_2d(p.x, p.y)) < 0.06
				var thick := pow(shade, 1.3) * (0.62 + 0.38 * wave.get_noise_2d(p.x * 3.0, p.y * 3.0)) * (0.04 if on_trail else 1.0)
				if keep > thick:
					if shade > 0.45 and not on_trail and keep > 0.988 and growable(p, 1.2):
						plan.fern(pick, p, yaw, lerpf(0.6, 0.95, size))
					continue
				if p.distance_to(POOL) < POOL_RADIUS + 5.5 or in_hollow_drift(p) or not growable(p, 1.2):
					continue
				if thick > 0.42:
					if grove and pick % 71 == 0:
						plan.flower("bluebell_white", p, yaw, lerpf(1.0, 1.3, size))
						continue
					# tallest in the heart
					plan.flower((patches[0] as Array)[pick % (patches[0] as Array).size()], p, yaw, lerpf(1.0, 1.5, shade) * lerpf(0.9, 1.1, size))
				else:
					plan.flower(patches[1], p, yaw, lerpf(0.7, 1.05, size))


# --- the land -------------------------------------------------------------------

static func _lake_named(id: StringName) -> Dictionary:
	for l: Dictionary in CourtHeight.lakes():
		if l["id"] == id:
			return l
	return {}


## Whether a spot is in a brook or within `margin` metres of its edge.
static func wet(p: Vector2, margin: float) -> bool:
	return CourtHeight.distance_to_brook(p.x, p.y) < margin


## Too steep to grow on (the knolls' rock faces).
static func steep(p: Vector2) -> bool:
	var h := WorldHeight.height_at(p.x, p.y)
	return maxf(absf(WorldHeight.height_at(p.x + 1.5, p.y) - h), absf(WorldHeight.height_at(p.x, p.y + 1.5) - h)) > 1.05


## Standing water: a lake, the pool, the river.
static func water(p: Vector2) -> bool:
	return CourtLandHabitats._water_form(p.x, p.y, CourtHeight.height_at(p.x, p.y)) == CourtLandHabitats.Form.WATER


## Clear of the paths and `brook` metres clear of a brook (the cheap half of growable).
static func dry(p: Vector2, brook: float) -> bool:
	return CourtLandHabitats.path_distance(p.x, p.y) >= 0.6 and not wet(p, brook)


## Ground a small plant can stand on: not water, not a path, not rock, and
## `brook` metres clear of a brook.
static func growable(p: Vector2, brook: float) -> bool:
	return dry(p, brook) and not water(p) and not steep(p)


## Whether a spot lies in one of the hollow's laid drifts (each kind keeps to itself).
static func in_hollow_drift(p: Vector2) -> bool:
	if p.distance_to(POOL) > FLOOR + 12.0:
		return false
	for dr: Array in HOLLOW_DRIFTS:
		var rel := p - (POOL + Vector2.from_angle(dr[1]) * float(dr[2]))
		var u := rel.dot(Vector2.from_angle(float(dr[1]) + PI * 0.5)) / (float(dr[3]) * 0.5)
		var v := rel.dot(Vector2.from_angle(dr[1])) / (float(dr[4]) * 0.5)
		if u * u + v * v < 0.75:
			return true
	return false
