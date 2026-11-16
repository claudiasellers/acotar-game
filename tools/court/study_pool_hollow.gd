class_name StudyPoolHollow
extends RefCounted
## A study of one place planted whole: the starlight pool's hollow in the
## Starlight Glen (docs/lanes/court-planting-by-place.md; owner, 2026-11-16:
## the feel of a place is judged with every layer in at once, not from one
## tree on bare ground). It is a picture for the owner, stood up by the shot
## tool (`study=pool_hollow`) over the court with today's scatter hidden; it
## is not yet how the game plants anything.
##
## The land: the pool (18 m across its radius) lies in a level floor 40 m out
## from its centre, and eight knolls ring the floor at about 95 m, the mound
## (the way in, east) and the Glimmerfall's knoll (west) among them.
##
## The layers, from the ground up:
##   floor     short glade grass over the whole floor, thinning up the slopes;
##             taller tufts at the water and round the birches' feet
##   flowers   the book's three (ch 18: crocuses, snowdrops, bluebells), each
##             kind in drifts of its own, with daisies through the grass
##   the bank  iris, reeds, fern, water mint and mossed stones on the pool's
##             far sides; the near bank, where you arrive, left clear
##   the ring  the pillar birches (book ch 14) round the pool, and more of
##             them in twos and threes up the inner slopes behind, bluebells
##             at their feet
##   knolls    one tree on each knoll, and each a different kind; the mound
##             bare (it is the overlook), the Glimmerfall's knoll its own
##   between   fern and a stand of foxgloves with each group of slope
##             birches. (The glen has no shrub fit to stand here yet: the
##             woods kit's hazel and bracken are too crude beside the rest.)
##   the mound its top in sward and crocus, and no tree: it is the overlook
##   glow      starmoss, glowcaps and faelights by the water, and small
##             lights adrift in the air over the floor

const POOL := Vector2(-1300.0, 262.0)
const POOL_RADIUS := 18.0
const FLOOR := 42.0
## Where you come down into the hollow (the bank the mound looks at): bearing
## from the pool, and the half-angle kept clear of tall bank plants.
const ARRIVAL := 0.14
const ARRIVAL_HALF := 0.55
const GLADE := "res://world/spring_court/wider/assets/flora/glade/%s.glb"
## Knoll tops round the hollow (surveyed), and the one tree each carries:
## [x, z, "estate" or "great", species, build, size].
const KNOLL_TREES := [
	[-1298.0, 162.0, "estate", &"oak", 0, 1.15],
	[-1368.0, 192.0, "estate", &"cherry_blossom", 1, 1.2],
	[-1368.0, 330.0, "estate", &"crab_apple", 0, 1.25],
	[-1286.0, 355.0, "estate", &"oak", 2, 1.0],
	[-1236.0, 338.0, "estate", &"apple_blossom", 1, 1.25],
	[-1231.0, 199.0, "estate", &"pear_tree", 2, 1.2],
]
const RING_RADIUS := 30.0
const RING_COUNT := 16
const MOUND := Vector2(-1208.0, 270.0)
## A flower patch is drawn flower by flower within this many metres, and as
## its far cushion beyond.
const FLOWERS_NEAR := 75.0
## Bearings from the pool kept clear of slope birches, [bearing, half-angle]:
## the way in from the mound, and the Glimmerfall.
const OPEN_LINES := [[0.09, 0.42], [PI, 0.3]]
## Groups of birches up the inner slopes: [bearing, distance from the pool, trees].
const SLOPE_GROUPS := [
	[0.72, 47.0, 3], [1.25, 55.0, 2], [1.75, 46.0, 3], [2.3, 52.0, 3], [2.72, 44.0, 2],
	[-2.7, 46.0, 3], [-2.2, 54.0, 2], [-1.7, 45.0, 3], [-1.15, 52.0, 3], [-0.68, 46.0, 2],
]


static func build(world: Node3D) -> void:
	var root := Node3D.new()
	root.name = "StudyPoolHollow"
	world.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261116
	var wave := FastNoiseLite.new()
	wave.seed = 7
	wave.frequency = 0.035
	var trunks := _ring(root, rng)
	var slope_trunks := _slopes(root, rng)
	_knolls(root)
	_floor(root, rng, wave, trunks)
	_flowers(root, rng, wave, slope_trunks)
	_mound(root, rng, wave)
	_between(root, rng, slope_trunks)
	_bank(root, rng)
	_glow(root, rng)


## The pillar birches round the pool: their builds in turn, each turned and
## sized a little differently, a little in or out of the true circle.
static func _ring(root: Node3D, rng: RandomNumberGenerator) -> Array[Vector2]:
	var trunks: Array[Vector2] = []
	for i in RING_COUNT:
		var a := TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / float(RING_COUNT)
		if absf(angle_difference(a, ARRIVAL)) < 0.16:
			continue    # the way in stays open
		var r := RING_RADIUS + rng.randf_range(-2.5, 2.5)
		var p := POOL + Vector2(cos(a), sin(a)) * r
		trunks.append(p)
		var mi := MeshInstance3D.new()
		mi.mesh = CourtGreatTrees.mesh(&"pillar_birch", i)
		mi.position = _ground(p)
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * rng.randf_range(0.9, 1.12)
		root.add_child(mi)
	return trunks


## Birches in twos and threes up the hollow's inner slopes, behind the ring:
## they close the hollow in, and their trunks stand at different heights.
static func _slopes(root: Node3D, rng: RandomNumberGenerator) -> Array[Vector2]:
	var trunks: Array[Vector2] = []
	var build := 0
	for g: Array in SLOPE_GROUPS:
		var mid := POOL + Vector2.from_angle(g[0]) * float(g[1])
		for k in int(g[2]):
			var p := mid + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 6.5)
			if _steep(p):
				continue
			trunks.append(p)
			var mi := MeshInstance3D.new()
			mi.mesh = CourtGreatTrees.mesh(&"pillar_birch", build)
			build += 1
			mi.position = _ground(p) - Vector3(0.0, 0.25, 0.0)
			mi.rotation.y = rng.randf() * TAU
			mi.scale = Vector3.ONE * rng.randf_range(0.78, 1.05)
			root.add_child(mi)
	return trunks


## A stand of foxgloves in the light at the inner edge of each group of slope
## birches: the one height between the grass and the crowns.
static func _between(root: Node3D, rng: RandomNumberGenerator, slope_trunks: Array[Vector2]) -> void:
	var xs: Array = []
	for g: Array in SLOPE_GROUPS:
		var out := Vector2.from_angle(g[0])
		var stand := POOL + out * (float(g[1]) - rng.randf_range(5.0, 8.0)) + out.orthogonal() * rng.randf_range(-5.0, 5.0)
		for k in 6:
			var p := stand + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.2, 1.8)
			var clear := not _steep(p)
			for t in slope_trunks:
				if p.distance_to(t) < 1.2:
					clear = false
			if clear:
				xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.4)), _ground(p)))
	_multi(root, "Between_foxglove", FloraLibrary.mesh(&"foxglove"), xs, true)


## The mound you arrive on: sward and crocuses over its top, tall grass at the
## brow, and no tree.
static func _mound(root: Node3D, rng: RandomNumberGenerator, wave: FastNoiseLite) -> void:
	var sward: Array = [[], [], []]
	var tall: Array = [[], []]
	var crocus: Array = [[], [], []]
	for i in 13000:
		var p := MOUND + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 30.0
		var d := p.distance_to(MOUND)
		if rng.randf() > lerpf(1.0, 0.15, clampf((d - 14.0) / 16.0, 0.0, 1.0)) or _steep(p):
			continue
		var size := rng.randf_range(0.85, 1.4)
		var x := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.8, 1.3), size)), _ground(p))
		var n := wave.get_noise_2d(p.x * 6.0, p.y * 6.0)
		if n > 0.3 and d > 4.0 and rng.randf() < 0.2:
			crocus[rng.randi() % 3].append(x)
		elif d > 9.0 and rng.randf() < 0.06:
			tall[rng.randi() % 2].append(x)
		else:
			sward[rng.randi() % 3].append(x)
	for k in 3:
		_cells(root, "MoundSward%d" % k, _glade("grass_sward_" + "abc"[k]), sward[k], 80.0)
		_cells(root, "MoundCrocus%d" % k, _glade("crocus_patch_" + "abc"[k]), crocus[k], FLOWERS_NEAR)
		_cells(root, "MoundCrocus%d_far" % k, _glade("crocus_patch_%s_far" % "abc"[k]), crocus[k], 420.0, FLOWERS_NEAR)
	for k in 2:
		_cells(root, "MoundTall%d" % k, _glade("grass_tall_" + "ab"[k]), tall[k], 110.0)


static func _knolls(root: Node3D) -> void:
	for t: Array in KNOLL_TREES:
		var mi := MeshInstance3D.new()
		mi.mesh = FloraLib.mesh(t[3], int(t[4]))
		mi.position = _ground(Vector2(t[0], t[1]))
		mi.rotation.y = float(t[0]) * 0.37
		mi.scale = Vector3.ONE * float(t[5])
		root.add_child(mi)


## The sward over the floor, thick near the pool and thinning up the slopes
## (none on the rock faces); taller tufts at the water's edge and round the
## birches' feet.
static func _floor(root: Node3D, rng: RandomNumberGenerator, wave: FastNoiseLite, trunks: Array[Vector2]) -> void:
	var short: Array = [[], [], []]
	var fine: Array = [[], [], []]
	var tall: Array = [[], []]
	var reach := 74.0
	var tries := int(PI * reach * reach * 5.4)
	for i in tries:
		var p := POOL + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * reach
		var d := p.distance_to(POOL)
		if d < POOL_RADIUS + 0.2:
			continue
		# thick on the floor, thinner up the slopes, in soft patches everywhere
		var up := clampf((d - FLOOR) / (reach - FLOOR), 0.0, 1.0)
		var keep := lerpf(1.0, 0.1, sqrt(up)) * (0.84 + 0.16 * wave.get_noise_2d(p.x * 2.0, p.y * 2.0))
		if rng.randf() > keep or _steep(p):
			continue
		var by_water := d < POOL_RADIUS + 2.4 and absf(angle_difference((p - POOL).angle(), ARRIVAL)) > 0.3
		var by_trunk := false
		for t in trunks:
			if p.distance_to(t) < 1.6:
				by_trunk = true
		var size := rng.randf_range(0.85, 1.4) * (1.0 + 0.3 * wave.get_noise_2d(p.x * 5.0, p.y * 5.0))
		var x := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.8, 1.3), size)), _ground(p))
		if (by_water or by_trunk) and rng.randf() < 0.5:
			tall[rng.randi() % 2].append(x)
		elif rng.randf() < 0.3:
			fine[rng.randi() % 3].append(x)
		else:
			short[rng.randi() % 3].append(x)
	for k in 3:
		_cells(root, "Sward%d" % k, _glade("grass_sward_" + "abc"[k]), short[k], 80.0)
		_cells(root, "Fine%d" % k, _glade("grass_glade_" + "abc"[k]), fine[k], 40.0)
	for k in 2:
		_cells(root, "TallGrass%d" % k, _glade("grass_tall_" + "ab"[k]), tall[k], 110.0)


## The book's three, each in drifts of its own, and daisies through the grass.
static func _flowers(root: Node3D, rng: RandomNumberGenerator, wave: FastNoiseLite, slope_trunks: Array[Vector2]) -> void:
	# [species, bearing from the pool, distance, length, depth, plants per m2]
	var drifts := [
		# bluebells under the birches, the widest drifts, most of the way round
		[&"bluebell", 1.2, 31.0, 34.0, 13.0, 1.5], [&"bluebell", 2.75, 30.5, 38.0, 13.0, 1.5],
		[&"bluebell", -2.25, 31.5, 32.0, 12.0, 1.5], [&"bluebell", -0.85, 31.0, 26.0, 11.0, 1.5],
		# snowdrops close to the water, in the birches' shade
		[&"snowdrop", 2.0, 23.5, 16.0, 5.0, 2.4], [&"snowdrop", -1.5, 24.0, 18.0, 5.0, 2.4], [&"snowdrop", 0.8, 23.0, 10.0, 4.0, 2.4],
		[&"snowdrop", -0.55, 22.5, 8.0, 3.5, 2.4],
		# crocuses out in the open, where you come in and across the far side
		[&"crocus", 0.45, 39.0, 18.0, 8.0, 1.9], [&"crocus", -0.3, 41.0, 16.0, 7.0, 1.9], [&"crocus", 3.6, 39.0, 18.0, 7.0, 1.9],
		[&"crocus", 0.1, 30.0, 9.0, 5.0, 1.9],
	]
	var by_kind := {}
	for dr: Array in drifts:
		var mid := POOL + Vector2.from_angle(dr[1]) * float(dr[2])
		var along := Vector2.from_angle(float(dr[1]) + PI * 0.5)    # a drift lies along the ring
		var out := Vector2.from_angle(dr[1])
		var n := int(float(dr[3]) * float(dr[4]) * float(dr[5]))
		for i in n:
			var u := rng.randfn(0.0, 0.33)
			var v := rng.randfn(0.0, 0.33)
			if absf(u) > 1.0 or absf(v) > 1.0:
				continue
			var p := mid + along * (u * float(dr[3]) * 0.5) + out * (v * float(dr[4]) * 0.5)
			# a ragged edge, and gaps inside
			if wave.get_noise_2d(p.x * 6.0, p.y * 6.0) < -0.25:
				continue
			if p.distance_to(POOL) < POOL_RADIUS + 1.0 or _steep(p):
				continue
			var size := rng.randf_range(1.0, 1.5)
			var x := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), _ground(p))
			if not by_kind.has(dr[0]):
				by_kind[dr[0]] = []
			by_kind[dr[0]].append(x)
	# bluebells and fern at the feet of the birches up the slopes
	var ferns: Array = [[], [], []]
	for t in slope_trunks:
		for i in 40:
			# thick at the trunk, thinning out
			var p := t + Vector2.from_angle(rng.randf() * TAU) * (0.5 + rng.randf() * 5.0)
			if _steep(p):
				continue
			var x := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.5)), _ground(p))
			if i < 3:
				ferns[rng.randi() % 3].append(x)
			else:
				by_kind[&"bluebell"].append(x)
	for k in 3:
		_cells(root, "SlopeFern%d" % k, _glade("fern_" + "abc"[k]), ferns[k], 150.0)
	var daisies: Array = []
	for i in 900:
		var p := POOL + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(POOL_RADIUS + 1.5, FLOOR + 6.0)
		if wave.get_noise_2d(p.x * 3.0, p.y * 3.0) > 0.05:
			daisies.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.1)), _ground(p)))
	by_kind[&"daisy"] = daisies
	for kind: StringName in by_kind:
		if kind == &"daisy":
			_cells(root, "Drift_daisy", FloraLibrary.mesh(kind), by_kind[kind], 90.0)
			continue
		# a drift is laid from the kind's patches, in turn
		var n := 3 if kind != &"snowdrop" else 2
		var split: Array = []
		for k in n:
			split.append([])
		for i in (by_kind[kind] as Array).size():
			split[i % n].append(by_kind[kind][i])
		for k in n:
			var patch := "%s_patch_%s" % [kind, "abc"[k]]
			_cells(root, "Drift_%s%d" % [kind, k], _glade(patch), split[k], FLOWERS_NEAR)
			_cells(root, "Drift_%s%d_far" % [kind, k], _glade(patch + "_far"), split[k], 420.0, FLOWERS_NEAR)


## The pool's far banks: iris, reeds, fern, water mint, mossed stones. The
## bank you arrive at is left to the grass.
static func _bank(root: Node3D, rng: RandomNumberGenerator) -> void:
	var kinds := {&"iris_clump": 26, &"reed_clump": 20, &"cattail": 10, &"fern": 30, &"water_mint": 24, &"mossy_rock": 9, &"moss_mound": 12}
	for kind: StringName in kinds:
		var xs: Array = []
		var tries := 0
		while xs.size() < int(kinds[kind]) and tries < 400:
			tries += 1
			var a := rng.randf() * TAU
			if absf(angle_difference(a, ARRIVAL)) < ARRIVAL_HALF:
				continue
			# reeds and iris at the very edge, in groups; fern and stone a step back
			var at_edge := kind in [&"iris_clump", &"reed_clump", &"cattail", &"water_mint"]
			var group := a + rng.randfn(0.0, 0.05) if at_edge else a
			var r := POOL_RADIUS + (rng.randf_range(-0.3, 1.2) if at_edge else rng.randf_range(0.8, 4.0))
			var p := POOL + Vector2.from_angle(group) * r
			var size := rng.randf_range(0.85, 1.35)
			xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), _ground(p)))
		if kind == &"fern":
			for k in 3:
				var some: Array = []
				for i in range(k, xs.size(), 3):
					some.append(xs[i])
				_multi(root, "Bank_fern%d" % k, _glade("fern_" + "abc"[k]), some)
			continue
		_multi(root, "Bank_%s" % kind, FloraLibrary.mesh(kind), xs, kind in [&"mossy_rock", &"moss_mound"])


## What glows: starmoss, glowcaps and faelights near the water, and small
## lights adrift over the floor (they show at dusk).
static func _glow(root: Node3D, rng: RandomNumberGenerator) -> void:
	for spec: Array in [[&"starmoss", 26, 0.6, 3.5], [&"glowcap", 22, 1.5, 9.0], [&"faelight_dandelion", 60, 2.0, 20.0]]:
		var xs: Array = []
		for i in int(spec[1]):
			var p := POOL + Vector2.from_angle(rng.randf() * TAU) * (POOL_RADIUS + rng.randf_range(float(spec[2]), float(spec[3])))
			xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.4)), _ground(p)))
		_multi(root, "Glow_%s" % spec[0], FloraLibrary.mesh(spec[0]), xs)
	var mote := SphereMesh.new()
	mote.radius = 0.045
	mote.height = 0.09
	mote.radial_segments = 6
	mote.rings = 3
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = Color(2.6, 2.5, 1.9)
	mote.material = lit
	var motes: Array = []
	for i in 280:
		# most over the water and the bluebells, a few out across the floor
		var p := POOL + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * (FLOOR + 4.0)
		var at := _ground(p)
		at.y = maxf(at.y, WorldHeight.height_at(POOL.x + POOL_RADIUS + 1.0, POOL.y)) + rng.randf_range(0.35, 3.2)
		motes.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.6, 1.5)), at))
	_multi(root, "Motes", mote, motes)


## The lights in the air come out as the day goes (time of day 0..1).
static func at_time(world: Node3D, time_of_day: float) -> void:
	var motes := world.get_node_or_null(^"StudyPoolHollow/Motes") as Node3D
	if motes != null:
		motes.visible = time_of_day > 0.7 or time_of_day < 0.22


static func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.y), p.y)


## Too steep to grow on (the knolls' rock faces).
static func _steep(p: Vector2) -> bool:
	var h := WorldHeight.height_at(p.x, p.y)
	return maxf(absf(WorldHeight.height_at(p.x + 1.5, p.y) - h), absf(WorldHeight.height_at(p.x, p.y + 1.5) - h)) > 1.05


static var _glade_meshes := {}


## A glade plant's mesh (tools/grove): its "soft" body under the woods'
## foliage material. Grass takes no rim light (a blade seen along the ground
## is all rim, and the rim is warm cream: a floor of straw); flowers a little.
static func _glade(plant: String) -> Mesh:
	if not _glade_meshes.has(plant):
		var scene := (load(GLADE % plant) as PackedScene).instantiate()
		var found: Mesh = null
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			found = mi.mesh
			break
		scene.free()
		found.surface_set_material(0, _look(0.0 if plant.begins_with("grass") or plant.ends_with("_far") else 0.12))
		_glade_meshes[plant] = found
	return _glade_meshes[plant]


static var _looks := {}


static func _look(rim: float) -> ShaderMaterial:
	if not _looks.has(rim):
		var m := FloraLibrary.material(&"bloom").duplicate() as ShaderMaterial
		m.set_shader_parameter(&"rim_strength", rim)
		# the twinkle lights a whole 14 cm cell: on a blade at your feet that is a white shard
		m.set_shader_parameter(&"sparkle", 0.0 if rim == 0.0 else 0.15)
		_looks[rim] = m
	return _looks[rim]


## Small plants by the cell, each cell drawn only within `far` metres: the
## way the floor of a place has to be laid to be affordable.
static func _cells(root: Node3D, name: String, mesh: Mesh, xforms: Array, far: float, near: float = 0.0, cell: float = 16.0) -> void:
	var by_cell := {}
	for x: Transform3D in xforms:
		var key := Vector2i(floori(x.origin.x / cell), floori(x.origin.z / cell))
		if not by_cell.has(key):
			by_cell[key] = []
		by_cell[key].append(x)
	for key: Vector2i in by_cell:
		var mid := Vector3((key.x + 0.5) * cell, 0.0, (key.y + 0.5) * cell)
		mid.y = WorldHeight.height_at(mid.x, mid.z)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = (by_cell[key] as Array).size()
		for i in mm.instance_count:
			var x: Transform3D = by_cell[key][i]
			x.origin -= mid
			mm.set_instance_transform(i, x)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = mid
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_begin = near
		mmi.visibility_range_end = far
		root.add_child(mmi)
	print("STUDY %s: %d in %d cells" % [name, xforms.size(), by_cell.size()])


static func _multi(root: Node3D, name: String, mesh: Mesh, xforms: Array, shadows: bool = false) -> void:
	if xforms.is_empty() or mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	print("STUDY %s: %d" % [name, xforms.size()])
