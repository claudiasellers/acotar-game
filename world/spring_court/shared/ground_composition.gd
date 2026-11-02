## Ground layers that read the layer above them (lane L32, "make the landscape
## feel intentional"; plans/landscape-brief.md "big things first, small things
## read the big ones"). Once the trees stand, every smaller decoration asks how
## far it is from the nearest trunk and places itself by role:
##   shrub     a mantle along wood edges and around specimen clumps, in one-kind drifts
##   deadwood  logs and stumps lie under and beside the trees that dropped them
##   rock      outcrops of 3/5/7 around one big anchor stone, never a sprinkle
##   flower    carpets move out of the shade into the meadow and the edge fringe
##   grass     thins under the canopy
##   other     unchanged (fences, reeds, terrace walls, poles ...)
## The weights are renormalised over the region so every layer keeps its count.
## Pure and deterministic (R15); runs on region worker threads.
## Loaded by path (no class_name), like LandscapeLayout.
extends RefCounted

## Canopy raster cell (m) and the distance it saturates at.
const CELL := 4.0
const FAR := 64.0

## Role weights by distance to the nearest trunk (m): [[d, w], ...], linear between.
const WEIGHTS := {
	&"shrub": [[0.0, 0.3], [3.0, 0.55], [6.0, 1.0], [13.0, 1.0], [26.0, 0.25], [FAR, 0.12]],
	&"deadwood": [[0.0, 1.0], [7.0, 1.0], [16.0, 0.45], [28.0, 0.04], [FAR, 0.02]],
	&"flower": [[0.0, 0.12], [4.0, 0.3], [10.0, 0.8], [16.0, 1.0], [FAR, 1.0]],
	&"grass": [[0.0, 0.4], [5.0, 0.7], [9.0, 1.0], [FAR, 1.0]],
	&"rock": [[0.0, 0.7], [6.0, 1.0], [FAR, 1.0]],
}
## Clustered roles: [[members, weight], ...] (rule of odds for rocks), and the
## radius one cluster spreads over (m) for its first and each further member.
const CLUSTERS := {
	&"rock": {"sizes": [[3, 0.45], [5, 0.4], [7, 0.15]], "radius": Vector2(1.6, 0.55), "anchor": 1.45},
	&"pebble": {"sizes": [[2, 0.5], [3, 0.35], [4, 0.15]], "radius": Vector2(1.5, 0.5), "anchor": 1.0},
	&"shrub": {"sizes": [[3, 0.25], [5, 0.35], [7, 0.28], [9, 0.12]], "radius": Vector2(1.7, 0.5), "anchor": 1.15},
	&"deadwood": {"sizes": [[1, 0.55], [2, 0.35], [3, 0.1]], "radius": Vector2(2.5, 1.2), "anchor": 1.1},
}

const ROCK_WORDS := ["rock_mossy", "escarpment_rock", "bone_rock", "boulder"]
const PEBBLE_WORDS := ["pebble"]
const SHRUB_WORDS := ["bush_", "fern_", "heather", "thicket", "thorn_brake", "ivy_curtain"]
const DEADWOOD_WORDS := ["fallen_log", "stump", "leaning_trunk"]
const FLOWER_WORDS := ["carpet_", "toadstool"]
const GRASS_WORDS := ["grass_clump"]


## The role a decoration mesh plays in the composition.
static func role(mesh_id: StringName) -> StringName:
	var s := String(mesh_id)
	for pair: Array in [[PEBBLE_WORDS, &"pebble"], [ROCK_WORDS, &"rock"], [DEADWOOD_WORDS, &"deadwood"],
			[SHRUB_WORDS, &"shrub"], [FLOWER_WORDS, &"flower"], [GRASS_WORDS, &"grass"]]:
		for w: String in pair[0]:
			if s.contains(w):
				return pair[1]
	return &"other"


## Distance-to-nearest-trunk raster over `rect` from tree layers' instances.
## { origin, nx, nz, d: PackedFloat32Array }
static func canopy(rect: Rect2, trees: Array) -> Dictionary:
	var nx := ceili(rect.size.x / CELL) + 1
	var nz := ceili(rect.size.y / CELL) + 1
	var d := PackedFloat32Array()
	d.resize(nx * nz)
	d.fill(FAR)
	for layer: ScatterLayer in trees:
		for i in layer.count():
			var p := layer.position_of(i)
			var cx := int((p.x - rect.position.x) / CELL)
			var cz := int((p.z - rect.position.y) / CELL)
			if cx >= 0 and cz >= 0 and cx < nx and cz < nz:
				d[cz * nx + cx] = 0.0
	# Two-pass chamfer distance (3-4 weights), good to a few percent.
	var a := CELL
	var b := CELL * 1.4142
	for z in nz:
		for x in nx:
			var i := z * nx + x
			var v := d[i]
			if x > 0:
				v = minf(v, d[i - 1] + a)
			if z > 0:
				v = minf(v, d[i - nx] + a)
				if x > 0:
					v = minf(v, d[i - nx - 1] + b)
				if x < nx - 1:
					v = minf(v, d[i - nx + 1] + b)
			d[i] = v
	for z in range(nz - 1, -1, -1):
		for x in range(nx - 1, -1, -1):
			var i := z * nx + x
			var v := d[i]
			if x < nx - 1:
				v = minf(v, d[i + 1] + a)
			if z < nz - 1:
				v = minf(v, d[i + nx] + a)
				if x < nx - 1:
					v = minf(v, d[i + nx + 1] + b)
				if x > 0:
					v = minf(v, d[i + nx - 1] + b)
			d[i] = v
	return {"origin": rect.position, "nx": nx, "nz": nz, "d": d}


## Distance (m) from (x, z) to the nearest trunk, bilinear on the raster.
static func distance(field: Dictionary, x: float, z: float) -> float:
	var o: Vector2 = field["origin"]
	var nx: int = field["nx"]
	var nz: int = field["nz"]
	var fx := clampf((x - o.x) / CELL, 0.0, nx - 1.001)
	var fz := clampf((z - o.y) / CELL, 0.0, nz - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var d: PackedFloat32Array = field["d"]
	var i := iz * nx + ix
	var top := lerpf(d[i], d[mini(i + 1, d.size() - 1)], tx)
	var bottom := lerpf(d[mini(i + nx, d.size() - 1)], d[mini(i + nx + 1, d.size() - 1)], tx)
	return lerpf(top, bottom, tz)


## Weight 0..1 for a role at distance `d` from the nearest trunk.
static func weight(role_id: StringName, d: float) -> float:
	var key := &"rock" if role_id == &"pebble" else role_id
	if not WEIGHTS.has(key):
		return 1.0
	var table: Array = WEIGHTS[key]
	if d <= table[0][0]:
		return table[0][1]
	for i in range(1, table.size()):
		if d <= table[i][0]:
			var t: float = (d - table[i - 1][0]) / maxf(table[i][0] - table[i - 1][0], 0.001)
			return lerpf(table[i - 1][1], table[i][1], t)
	return table[-1][1]


## Mean weight of a role over the points `accept` keeps (sampled, fixed seed),
## so lambda / mean keeps the layer's expected count.
static func mean_weight(field: Dictionary, role_id: StringName, rect: Rect2, accept: Callable, seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "ground_mean", role_id])
	var total := 0.0
	var n := 0
	for i in 3000:
		var p := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		if not accept.call(p):
			continue
		total += weight(role_id, distance(field, p.x, p.y))
		n += 1
	return clampf(total / maxf(n, 1.0), 0.05, 1.0) if n > 0 else 1.0


static func is_clustered(role_id: StringName) -> bool:
	return CLUSTERS.has(role_id)


## Mean members per cluster for a role.
static func mean_members(role_id: StringName) -> float:
	var m := 0.0
	for s: Array in CLUSTERS[role_id]["sizes"]:
		m += s[0] * s[1]
	return m


## Member offsets and scale factors for one cluster: [[Vector2 offset, scale mul], ...].
## The first member is the anchor (largest, at the centre); the rest ring it,
## each a little smaller and further out, in a loose spiral so they never stack.
static func cluster(role_id: StringName, rng: RandomNumberGenerator) -> Array:
	var spec: Dictionary = CLUSTERS[role_id]
	var roll := rng.randf()
	var n := 1
	for s: Array in spec["sizes"]:
		n = s[0]
		roll -= s[1]
		if roll <= 0.0:
			break
	var radius: Vector2 = spec["radius"]
	var out: Array = [[Vector2.ZERO, float(spec["anchor"])]]
	var a := rng.randf() * TAU
	for k in range(1, n):
		a += 2.39996 + rng.randf_range(-0.5, 0.5)  # golden angle
		var r := radius.x + radius.y * k * rng.randf_range(0.6, 1.2)
		out.append([Vector2(cos(a), sin(a)) * r, lerpf(0.95, 0.6, float(k) / n) * rng.randf_range(0.85, 1.1)])
	return out
