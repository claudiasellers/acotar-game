class_name StudyGlen
extends RefCounted
## The rest of the Starlight Glen planted by rule, after the owner passed the
## pool's hollow (StudyPoolHollow; 2026-11-16: "it looks perfect"). Still a
## picture stood up by the shot tool (`study=glen`), not the game's planting.
##
## Nothing here is placed by area. Every plant answers to something on the
## land (docs/lanes/court-planting-by-place.md, Starlight Glen):
##   knolls    one tree on each knoll top, and neighbours never the same kind,
##             so you find your way by them; a pool of one flower in its
##             shade, and the same flower in a crescent round the knoll's
##             shaded north foot
##   brooks    trees gathered in clumps along the brooks, on alternate banks;
##             iris, mint, fern and stones at the water, snowdrops beside it
##   the river willows and birches in clumps along the Thornwater
##   the lake  Looking Lake wooded to the water on its far side, for the
##             reflection, and open where you come to it (its isle has its
##             tree already); reeds and iris only where the bank is low
##   the mere  Willow Mere willows all round, open toward the Weeping Lady
##             and on the side you come to it from
##   the brae  a clump either side of the way just over the crest, so the
##             glen appears between trunks
##   paths     a drift of crocuses on the verge now and then
##   the rest  open glade: sward, and daisies where nothing shades it
## Flowers follow the trees' shade exactly as the pool's bluebells do.

const RECT := Rect2(-1500.0, -500.0, 900.0, 1100.0)
const POOL := Vector2(-1300.0, 262.0)
const MOUND := Vector2(-1208.0, 270.0)
## The pool's hollow is StudyPoolHollow's: nothing of this study inside it.
const HOLLOW := 118.0
const NEAR := 75.0
## The knolls' trees, [species, size, the shade it throws (m), how many stand
## together], taken in turn so neighbours differ. Each has its own outline:
## the oak wide, the sycamore a tower of billows, the elm a vase, the aspen a
## column, the thorn wind-blown, the birches a clump of white stems; and one
## blossom tree, still the estate's cherry grown near twice its size.
const KNOLL_KINDS := [[&"great_oak", 1.0, 15.0, 1], [&"great_sycamore", 1.0, 12.0, 1], [&"great_elm", 1.0, 12.0, 1],
	[&"aspen_spire", 1.0, 6.0, 2], [&"old_thorn", 1.5, 9.0, 1], [&"pillar_birch", 1.0, 8.0, 3], [&"cherry_blossom", 1.9, 10.0, 1]]
const FLOWERS := [&"bluebell", &"snowdrop", &"crocus"]
## A flower's patches: [the full ones, the small one at a pool's edge].
const PATCHES := {
	&"bluebell": [["bluebell_patch_a", "bluebell_patch_b"], "bluebell_patch_c"],
	&"snowdrop": [["snowdrop_patch_a"], "snowdrop_patch_b"],
	&"crocus": [["crocus_patch_a", "crocus_patch_b"], "crocus_patch_c"],
}


static func build(world: Node3D) -> void:
	var root := Node3D.new()
	root.name = "StudyGlen"
	world.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	var wave := FastNoiseLite.new()
	wave.seed = 11
	wave.frequency = 0.035
	# every group of trees, with the flower that pools in its shade: {trunks, reach, flower}
	var groups: Array[Dictionary] = []
	var crescents := _knolls(root, rng, groups)
	_brooks(root, rng, groups)
	_river(root, rng, groups)
	_lake(root, rng, groups)
	_mere(root, rng, groups)
	_brae(root, rng, groups)
	_bushes(root, rng, groups)
	_shade_flowers(root, rng, wave, groups, crescents)
	_verges(root, rng)
	var trees := 0
	for g in groups:
		trees += (g["trunks"] as Array).size()
	print("STUDY glen: %d trees in %d groups" % [trees, groups.size()])


# --- the rules ------------------------------------------------------------------

## One tree on each knoll top, neighbours never the same kind.
static func _knolls(root: Node3D, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> Array:
	var crescents: Array = []   # [spot, flower, heart of the crescent or not]
	var placed: Array = []   # [top, kind index]
	for top: Vector2 in knoll_tops():
		if top.distance_to(POOL) < HOLLOW or CourtLandHabitats.keep_open(top.x, top.y):
			continue
		var kind := rng.randi() % KNOLL_KINDS.size()
		var nearest := -1
		var best := INF
		for e: Array in placed:
			if (e[0] as Vector2).distance_to(top) < best:
				best = (e[0] as Vector2).distance_to(top)
				nearest = e[1]
		if kind == nearest:
			kind = (kind + 1) % KNOLL_KINDS.size()
		placed.append([top, kind])
		var k: Array = KNOLL_KINDS[kind]
		var trunks: Array = []
		for n in int(k[3]):
			var p := top if n == 0 else top + Vector2.from_angle(TAU * float(n) / float(k[3]) + rng.randf()) * rng.randf_range(2.6, 4.2)
			trunks.append(p)
			var size := float(k[1]) * (rng.randf_range(0.94, 1.08) if n == 0 else rng.randf_range(0.78, 0.95))
			if CourtGreatTrees.TREES.has(k[0]):
				_great(root, rng, k[0], p, size)
			else:
				_estate(root, rng, k[0], p, size)
		var flower: StringName = FLOWERS[placed.size() % 3]
		groups.append({"trunks": trunks, "reach": float(k[2]), "flower": flower})
		# the knoll's north foot, where its slope eases: the same flower in a crescent, in its shade
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
			crescents.append([top + Vector2.from_angle(-PI * 0.5 + turn) * (foot + 2.0 + out), flower, absf(turn) < 0.6 and absf(out) < 4.0])
	print("STUDY glen knolls: ", placed.size())
	return crescents


## Trees gathered in clumps along the brooks, on alternate banks, and the
## banks' own plants.
static func _brooks(root: Node3D, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var bank := {&"iris_clump": [], &"water_mint": [], &"reed_clump": [], &"mossy_rock": [], &"moss_mound": []}
	var ferns: Array = [[], [], []]
	var snow: Array = [[], []]
	for brook: Dictionary in CourtHeight.brooks():
		var pts: PackedVector2Array = brook["points"]
		var half: float = brook["half_width"]
		var until := rng.randf_range(10.0, 30.0)
		var side_of := 1.0
		for k in pts.size() - 1:
			var along := pts[k + 1] - pts[k]
			if along.length() < 0.01 or not RECT.has_point(pts[k]):
				continue
			var side := along.normalized().orthogonal()
			var own := pts[k].distance_to(POOL) < HOLLOW
			# a clump of trees every so often
			until -= along.length()
			if until < 0.0 and not own:
				until = rng.randf_range(34.0, 62.0)
				side_of = -side_of
				var willow := rng.randf() < 0.45
				var heart := pts[k] + side * side_of * (half + rng.randf_range(4.0, 7.5))
				var trunks := _clump(root, rng, heart, [1, 2, 2, 3][rng.randi() % 4], &"willow" if willow else &"birch", 1.0, 3.2)
				if not trunks.is_empty():
					groups.append({"trunks": trunks, "reach": 8.0, "flower": &"snowdrop" if willow else &"bluebell"})
			if own:
				continue
			# the banks: a place to plant every 0.7 m or so
			var want := along.length() / 0.7
			for j in int(want) + (1 if rng.randf() < fmod(want, 1.0) else 0):
				var on := pts[k] + along * rng.randf()
				var b := side * (1.0 if rng.randf() < 0.5 else -1.0)
				var roll := rng.randf()
				if roll < 0.13:
					bank[&"iris_clump"].append(_at(rng, on + b * (half + rng.randf_range(-0.3, 0.5)), 0.8, 1.2))
				elif roll < 0.27:
					bank[&"water_mint"].append(_at(rng, on + b * (half + rng.randf_range(-0.4, 0.4)), 0.9, 1.4))
				elif roll < 0.3:
					bank[&"reed_clump"].append(_at(rng, on + b * (half + rng.randf_range(-0.5, 0.1)), 0.6, 0.9))
				elif roll < 0.4:
					ferns[rng.randi() % 3].append(_at(rng, on + b * (half + rng.randf_range(0.3, 1.8)), 0.5, 0.85))
				elif roll < 0.43:
					bank[&"mossy_rock"].append(_at(rng, on + b * (half + rng.randf_range(-0.6, 0.8)), 0.5, 1.0))
				elif roll < 0.48:
					bank[&"moss_mound"].append(_at(rng, on + b * (half + rng.randf_range(0.0, 1.2)), 0.7, 1.2))
				if sin(on.x * 0.07 + on.y * 0.05) > 0.45 and rng.randf() < 0.5:
					snow[rng.randi() % 2].append(_at(rng, on + b * (half + rng.randf_range(0.7, 3.2)), 1.0, 1.4))
	for kind: StringName in bank:
		StudyPoolHollow._cells(root, "GlenBank_%s" % kind, FloraLibrary.mesh(kind), bank[kind], 260.0)
	for k in 3:
		StudyPoolHollow._cells(root, "GlenBank_fern%d" % k, StudyPoolHollow._glade("fern_" + "abc"[k]), ferns[k], 150.0)
	for k in 2:
		var patch := "snowdrop_patch_" + "ab"[k]
		StudyPoolHollow._cells(root, "GlenBank_snowdrop%d" % k, StudyPoolHollow._glade(patch), snow[k], NEAR)
		StudyPoolHollow._cells(root, "GlenBank_snowdrop%d_far" % k, StudyPoolHollow._glade(patch + "_far"), snow[k], 420.0, NEAR)


## Willows and birches in clumps along the Thornwater.
static func _river(root: Node3D, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
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
			if until > 0.0 or not RECT.has_point(on) or on.distance_to(POOL) < HOLLOW:
				continue
			until = rng.randf_range(42.0, 76.0)
			side_of = -side_of
			var side := (b - a).normalized().orthogonal() * side_of
			# the first dry, open ground back from the water
			for back in [10.0, 13.0, 16.0, 20.0, 25.0]:
				var heart: Vector2 = on + side * back
				if CourtLandHabitats.keep_open(heart.x, heart.y):
					continue
				var willow := rng.randf() < 0.6
				var trunks := _clump(root, rng, heart, [2, 2, 3, 3][rng.randi() % 4], &"willow" if willow else &"birch", 1.05, 3.4)
				if not trunks.is_empty():
					groups.append({"trunks": trunks, "reach": 8.0, "flower": &"snowdrop" if willow else &"bluebell"})
				break


## Looking Lake: wooded to the water on the far side from where the lake
## walk reaches it, open on the near side; reeds and iris along the wooded
## shore; one clump of pillar birches on the isle.
static func _lake(root: Node3D, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var centre := CourtHeight.site(&"looking_lake")
	var radius := 85.0
	var come := (Vector2(-1150.0, -200.0) - centre).angle()   # the lake walk's end
	var level := 0.0
	for l: Dictionary in CourtHeight.lakes():
		if l["id"] == &"looking_lake":
			level = l["level"]
	var far_side := come + PI
	var wood: Array = []
	var tries := 0
	while wood.size() < 52 and tries < 900:
		tries += 1
		var a := far_side + rng.randfn(0.0, 0.62)
		if absf(angle_difference(a, far_side)) > 1.45:
			continue
		# thick at the water, thinning back from it
		var back := 3.0 + absf(rng.randfn(0.0, 13.0))
		var p := centre + Vector2.from_angle(a) * (radius + back)
		if back > 36.0 or CourtLandHabitats.keep_open(p.x, p.y) or StudyPoolHollow._steep(p):
			continue
		var ok := true
		for q: Vector2 in wood:
			if q.distance_to(p) < 4.2:
				ok = false
		if not ok:
			continue
		wood.append(p)
		var species: StringName = &"willow" if back < 7.0 and rng.randf() < 0.6 else (&"oak" if rng.randf() < 0.4 else &"birch")
		_estate(root, rng, species, p, rng.randf_range(0.85, 1.15))
	groups.append({"trunks": wood, "reach": 8.5, "flower": &"bluebell"})
	# willows at the water wherever the bank comes down to it (the far bank is a cliff: its wood crowns it)
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
		if ok:
			low.append(p)
			_estate(root, rng, &"willow", p, rng.randf_range(0.95, 1.2))
	if not low.is_empty():
		groups.append({"trunks": low, "reach": 7.5, "flower": &"snowdrop"})
	# the shore: thick on the wooded side, a few groups on the open one
	var shore := {&"reed_clump": [], &"cattail": [], &"iris_clump": [], &"water_mint": []}
	for i in 620:
		var a := rng.randf() * TAU
		var wooded := absf(angle_difference(a, far_side)) < 1.5
		if not wooded and sin(a * 7.0) < 0.6:
			continue
		if absf(angle_difference(a, come)) < 0.35:
			continue    # where you come to the water stays clear
		# they stand in the shallows on the lake's shelf, and not under the west cliff
		var edge := centre + Vector2.from_angle(a) * (radius + 2.0)
		if CourtHeight.height_at(edge.x, edge.y) - level > 9.0:
			continue
		var kind: StringName = shore.keys()[rng.randi() % 4]
		shore[kind].append(_at(rng, centre + Vector2.from_angle(a) * (radius + rng.randf_range(-2.6, -0.4)), 0.95, 1.4))
	for kind: StringName in shore:
		StudyPoolHollow._cells(root, "Lake_%s" % kind, FloraLibrary.mesh(kind), shore[kind], 320.0)


## Willow Mere: willows all round, open toward the Weeping Lady and where
## the mere run leaves; reeds and cattails at their feet.
static func _mere(root: Node3D, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var centre := CourtHeight.site(&"willow_mere")
	var radius := 32.0
	var lady := (CourtHeight.site(&"weeping_lady") - centre).angle()
	var willows: Array = []
	for i in 13:
		var a := TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / 13.0
		if absf(angle_difference(a, lady)) < 0.5 or absf(angle_difference(a, 0.0)) < 0.22 or absf(angle_difference(a, lady + PI)) < 0.42:
			continue
		var p := centre + Vector2.from_angle(a) * (radius + rng.randf_range(2.5, 6.5))
		if CourtLandHabitats.keep_open(p.x, p.y):
			continue
		willows.append(p)
		_estate(root, rng, &"willow", p, rng.randf_range(0.9, 1.2))
	groups.append({"trunks": willows, "reach": 7.5, "flower": &"snowdrop"})
	var shore := {&"reed_clump": [], &"cattail": [], &"iris_clump": []}
	for i in 90:
		var a := rng.randf() * TAU
		if absf(angle_difference(a, lady)) < 0.35:
			continue
		var kind: StringName = shore.keys()[rng.randi() % 3]
		shore[kind].append(_at(rng, centre + Vector2.from_angle(a + rng.randfn(0.0, 0.04)) * (radius + rng.randf_range(-2.2, -0.3)), 0.9, 1.35))
	for kind: StringName in shore:
		StudyPoolHollow._cells(root, "Mere_%s" % kind, FloraLibrary.mesh(kind), shore[kind], 320.0)


## The brae: a clump either side of the line you look along as you come over
## the crest, so the glen appears between trunks.
static func _brae(root: Node3D, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var top := CourtHeight.site(&"brae_top")
	var look := (Vector2(-1400.0, -300.0) - top).normalized()
	for side: float in [-1.0, 1.0]:
		var heart := top + look * rng.randf_range(36.0, 48.0) + look.orthogonal() * side * rng.randf_range(15.0, 21.0)
		var trunks := _clump(root, rng, heart, 4, &"oak" if side < 0.0 else &"birch", 1.05, 4.5)
		if not trunks.is_empty():
			groups.append({"trunks": trunks, "reach": 9.0, "flower": &"bluebell"})


## Thorn bushes, white with may: one or two at the outer edge of every clump
## of trees (a wood's edge is where the thorn grows), and now and then a pair
## on a lone tree's knoll, down its flank.
static func _bushes(root: Node3D, rng: RandomNumberGenerator, groups: Array[Dictionary]) -> void:
	var stood := 0
	for g in groups:
		var trunks: Array = g["trunks"]
		if trunks.is_empty() or (trunks.size() == 1 and rng.randf() > 0.4):
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
				if CourtLandHabitats.keep_open(p.x, p.y) or StudyPoolHollow._steep(p) or StudyPoolHollow._wet(p, 1.5) \
						or CourtLandHabitats.path_distance(p.x, p.y) < 4.0 or p.distance_to(POOL) < HOLLOW:
					continue
				_great(root, rng, &"thorn_bush", p, rng.randf_range(0.8, 1.25))
				stood += 1
				break
	print("STUDY glen thorn bushes: ", stood)


## A drift of crocuses on a path's verge now and then.
static func _verges(root: Node3D, rng: RandomNumberGenerator) -> void:
	var xs: Array = [[], [], []]
	for path: Dictionary in CourtHeight.paths():
		var pts: PackedVector2Array = path["points"]
		var half: float = path["half_width"]
		var until := rng.randf_range(20.0, 60.0)
		for k in pts.size() - 1:
			var along := pts[k + 1] - pts[k]
			until -= along.length()
			if until > 0.0 or along.length() < 0.01 or not RECT.has_point(pts[k]) or pts[k].distance_to(POOL) < HOLLOW:
				continue
			until = rng.randf_range(70.0, 120.0)
			var side := along.normalized().orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
			var length := rng.randf_range(9.0, 16.0)
			for i in int(length * 3.2):
				var p := pts[k] + along.normalized() * rng.randfn(0.0, length * 0.3) + side * (half + 0.8 + absf(rng.randfn(0.0, 1.6)))
				if CourtLandHabitats.path_distance(p.x, p.y) < 0.6 or StudyPoolHollow._wet(p, 0.8) or StudyPoolHollow._steep(p) \
						or _water(p):
					continue
				xs[rng.randi() % 3].append(_at(rng, p, 1.0, 1.45))
	for k in 3:
		var patch := "crocus_patch_" + "abc"[k]
		StudyPoolHollow._cells(root, "Verge_crocus%d" % k, StudyPoolHollow._glade(patch), xs[k], NEAR)
		StudyPoolHollow._cells(root, "Verge_crocus%d_far" % k, StudyPoolHollow._glade(patch + "_far"), xs[k], 420.0, NEAR)


## Each group's flower pools in its shade: thick and tall in the heart,
## feathering to small outliers at the edge, trails of grass through it, fern
## and moss at the trunks' feet (the pool's bluebells, for any tree and flower).
static func _shade_flowers(root: Node3D, rng: RandomNumberGenerator, wave: FastNoiseLite, groups: Array[Dictionary],
		crescents: Array) -> void:
	var trail := FastNoiseLite.new()
	trail.seed = 31
	trail.frequency = 0.045
	trail.fractal_octaves = 2
	var out := {}    # patch -> [transforms, tints]
	var ferns: Array = [[], [], []]
	var moss: Array = []
	for g in groups:
		var trunks: Array = g["trunks"]
		var reach: float = g["reach"]
		var patches: Array = PATCHES[g["flower"]]
		for t: Vector2 in trunks:
			for i in int(PI * reach * reach * 2.1):
				var p := t + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * reach
				var shade := 0.0
				var over := 0
				var foot := INF
				for u: Vector2 in trunks:
					var d := p.distance_to(u)
					if d < reach:
						over += 1
						shade += pow(1.0 - d / reach, 1.4)
						foot = minf(foot, d)
				shade = minf(shade, 1.0)
				# a spot under several trees is tried once for each: thin it back
				if over > 1 and rng.randf() > 1.0 / float(over):
					continue
				if shade <= 0.02 or StudyPoolHollow._steep(p) or StudyPoolHollow._wet(p, 1.2) or _water(p) \
						or CourtLandHabitats.path_distance(p.x, p.y) < 0.6:
					continue
				var at := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), StudyPoolHollow._ground(p))
				if foot < 1.1:
					if rng.randf() < 0.1:
						ferns[rng.randi() % 3].append(at.scaled_local(Vector3.ONE * rng.randf_range(0.5, 0.8)))
					elif rng.randf() < 0.04:
						moss.append(at.scaled_local(Vector3.ONE * rng.randf_range(0.6, 1.0)))
					continue
				var on_trail := absf(trail.get_noise_2d(p.x, p.y)) < 0.06
				var thick := pow(shade, 1.3) * (0.62 + 0.38 * wave.get_noise_2d(p.x * 3.0, p.y * 3.0)) * (0.04 if on_trail else 1.0)
				if rng.randf() > thick:
					continue
				var deep := clampf(0.5 + 0.9 * wave.get_noise_2d(p.x * 1.3 + 300.0, p.y * 1.3), 0.0, 1.0)
				var tint := Color(1.0, 1.0, 1.0).lerp(Color(0.8, 0.8, 0.98), deep) if g["flower"] == &"bluebell" else Color(1.0, 1.0, 1.0)
				var patch: String
				if thick > 0.42:
					patch = (patches[0] as Array)[rng.randi() % (patches[0] as Array).size()]
					at = at.scaled_local(Vector3.ONE * lerpf(1.0, 1.5, shade) * rng.randf_range(0.9, 1.1))
				else:
					patch = patches[1]
					at = at.scaled_local(Vector3.ONE * rng.randf_range(0.7, 1.05))
				if not out.has(patch):
					out[patch] = [[], []]
				out[patch][0].append(at)
				out[patch][1].append(tint)
	for c: Array in crescents:
		var p: Vector2 = c[0]
		if StudyPoolHollow._steep(p) or StudyPoolHollow._wet(p, 1.2) or _water(p) or CourtLandHabitats.path_distance(p.x, p.y) < 0.6 \
				or p.distance_to(POOL) < HOLLOW or wave.get_noise_2d(p.x * 4.0, p.y * 4.0) < -0.2:
			continue
		var patches: Array = PATCHES[c[1]]
		var patch: String = (patches[0] as Array)[rng.randi() % (patches[0] as Array).size()] if c[2] else patches[1]
		if not out.has(patch):
			out[patch] = [[], []]
		out[patch][0].append(_at(rng, p, 1.0 if c[2] else 0.7, 1.4 if c[2] else 1.05))
		out[patch][1].append(Color(0.92, 0.92, 1.0))
	for patch: String in out:
		StudyPoolHollow._cells(root, "Shade_" + patch, StudyPoolHollow._glade(patch), out[patch][0], NEAR, 0.0, out[patch][1])
		StudyPoolHollow._cells(root, "Shade_%s_far" % patch, StudyPoolHollow._glade(patch + "_far"), out[patch][0], 420.0, NEAR, out[patch][1])
	for k in 3:
		StudyPoolHollow._cells(root, "ShadeFern%d" % k, StudyPoolHollow._glade("fern_" + "abc"[k]), ferns[k], 150.0)
	StudyPoolHollow._cells(root, "ShadeMoss", FloraLibrary.mesh(&"moss_mound"), moss, 150.0)


## The open glade's sward round a standpoint: the game would lay this by the
## cell as you walk; a picture lays it round the eye. None in water, on a
## path or on rock, and none where the pool's hollow has its own.
static func sward_round(world: Node3D, eye: Vector3) -> void:
	var old := world.get_node_or_null(^"GlenSward")
	if old != null:
		old.free()
	var root := Node3D.new()
	root.name = "GlenSward"
	world.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(eye.x), roundi(eye.z)))
	var wave := FastNoiseLite.new()
	wave.seed = 7
	wave.frequency = 0.035
	var here := Vector2(eye.x, eye.z)
	var short: Array = [[], [], []]
	var fine: Array = [[], [], []]
	var tall: Array = [[], []]
	var daisies: Array = []
	var reach := 86.0
	for i in int(PI * reach * reach * 4.6):
		var p := here + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * reach
		var d := p.distance_to(here)
		if p.distance_to(POOL) < 74.0 or p.distance_to(MOUND) < 30.0:
			continue
		var keep := lerpf(1.0, 0.2, clampf((d - 38.0) / (reach - 38.0), 0.0, 1.0)) * (0.84 + 0.16 * wave.get_noise_2d(p.x * 2.0, p.y * 2.0))
		if rng.randf() > keep or CourtLandHabitats.path_distance(p.x, p.y) < 0.2 or StudyPoolHollow._wet(p, 0.15) or _water(p) \
				or StudyPoolHollow._steep(p):
			continue
		var size := rng.randf_range(0.85, 1.4) * (1.0 + 0.3 * wave.get_noise_2d(p.x * 5.0, p.y * 5.0))
		var x := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.8, 1.3), size)),
			StudyPoolHollow._ground(p))
		var roll := rng.randf()
		# the dips hold the long grass; the slopes that face the sun hold the daisies
		var h := CourtHeight.height_at(p.x, p.y)
		var dip := (CourtHeight.height_at(p.x + 14.0, p.y) + CourtHeight.height_at(p.x - 14.0, p.y) + CourtHeight.height_at(p.x, p.y + 14.0)
			+ CourtHeight.height_at(p.x, p.y - 14.0)) * 0.25 - h
		var sunny := h - CourtHeight.height_at(p.x, p.y + 3.0) > 0.25
		if (StudyPoolHollow._wet(p, 1.6) and roll < 0.5) or (dip > 0.8 and roll < 0.5):
			tall[rng.randi() % 2].append(x.scaled_local(Vector3(1.2, 1.25, 1.2)) if dip > 0.8 else x)
		elif roll < (0.07 if sunny else 0.008) and wave.get_noise_2d(p.x * 3.0, p.y * 3.0) > -0.1:
			daisies.append(x)
		elif roll < 0.3:
			fine[rng.randi() % 3].append(x)
		else:
			short[rng.randi() % 3].append(x)
	for k in 3:
		StudyPoolHollow._cells(root, "GlenSward%d" % k, StudyPoolHollow._glade("grass_sward_" + "abc"[k]), short[k], 200.0)
		StudyPoolHollow._cells(root, "GlenFine%d" % k, StudyPoolHollow._glade("grass_glade_" + "abc"[k]), fine[k], 200.0)
	for k in 2:
		StudyPoolHollow._cells(root, "GlenTall%d" % k, StudyPoolHollow._glade("grass_tall_" + "ab"[k]), tall[k], 200.0)
	StudyPoolHollow._cells(root, "GlenDaisy", FloraLibrary.mesh(&"daisy"), daisies, 200.0)


# --- the land -------------------------------------------------------------------

## The glen's knoll tops: local high points that stand at least four metres
## over the ground 36 m round them (found from the land, so they follow it).
static func knoll_tops() -> Array[Vector2]:
	CourtHeight.prewarm()
	var found: Array = []   # [height, top]
	var x := RECT.position.x
	while x <= RECT.end.x:
		var z := RECT.position.y
		while z <= RECT.end.y:
			var h := CourtHeight.height_at(x, z)
			var top := true
			var round_it := 0.0
			for k in 8:
				var dir := Vector2.from_angle(TAU * float(k) / 8.0)
				if CourtHeight.height_at(x + dir.x * 12.0, z + dir.y * 12.0) > h:
					top = false
					break
				round_it += CourtHeight.height_at(x + dir.x * 36.0, z + dir.y * 36.0)
			if top and h - round_it / 8.0 > 4.0:
				found.append([h, Vector2(x, z)])
			z += 8.0
		x += 8.0
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var tops: Array[Vector2] = []
	for f: Array in found:
		var p: Vector2 = f[1]
		var fresh := true
		for q in tops:
			if q.distance_to(p) < 30.0:
				fresh = false
		if fresh:
			# climb to the true top from the grid point
			for step in 12:
				var best := p
				for k in 8:
					var q := p + Vector2.from_angle(TAU * float(k) / 8.0) * 2.0
					if CourtHeight.height_at(q.x, q.y) > CourtHeight.height_at(best.x, best.y):
						best = q
				if best == p:
					break
				p = best
			tops.append(p)
	return tops


static func _water(p: Vector2) -> bool:
	return CourtLandHabitats._water_form(p.x, p.y, CourtHeight.height_at(p.x, p.y)) == CourtLandHabitats.Form.WATER


# --- planting helpers -----------------------------------------------------------

static func _at(rng: RandomNumberGenerator, p: Vector2, s0: float, s1: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(s0, s1)), StudyPoolHollow._ground(p))


## A clump of one estate species round a heart: the first tree the tallest.
## Returns the trunks that found open ground.
static func _clump(root: Node3D, rng: RandomNumberGenerator, heart: Vector2, count: int, species: StringName, size: float,
		spread: float) -> Array:
	var stood: Array = []
	var tries := 0
	while stood.size() < count and tries < 24:
		tries += 1
		var p := heart if tries == 1 else heart + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(spread * 0.6, spread * 1.5)
		# clear of the water, and far enough from a path that no crown hangs over it
		var ok := not CourtLandHabitats.keep_open(p.x, p.y) and not StudyPoolHollow._steep(p) and not StudyPoolHollow._wet(p, 2.5) \
				and CourtLandHabitats.path_distance(p.x, p.y) > 9.0
		for q: Vector2 in stood:
			if q.distance_to(p) < spread * 0.6:
				ok = false
		if not ok:
			continue
		_estate(root, rng, species, p, size * (rng.randf_range(0.98, 1.12) if stood.is_empty() else rng.randf_range(0.78, 0.98)))
		stood.append(p)
	return stood


static func _estate(root: Node3D, rng: RandomNumberGenerator, species: StringName, p: Vector2, size: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = FloraLib.mesh(species, rng.randi() % maxi(1, EstateTrees.builds(species)))
	mi.position = StudyPoolHollow._ground(p)
	mi.rotation.y = rng.randf() * TAU
	mi.scale = Vector3.ONE * size
	root.add_child(mi)


static func _great(root: Node3D, rng: RandomNumberGenerator, species: StringName, p: Vector2, size: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = CourtGreatTrees.mesh(species, rng.randi() % maxi(1, CourtGreatTrees.builds(species)))
	mi.position = StudyPoolHollow._ground(p)
	mi.rotation.y = rng.randf() * TAU
	mi.scale = Vector3.ONE * size
	root.add_child(mi)
