## Turns a CourtRegionContent into ScatterLayers (docs/contracts/world.md §4)
## and the coverage report (§5). Deterministic: the same content and seed give
## the same instances, so WorldDeltas keys ("<layer id>:<index>") stay stable.
class_name CourtScatterGenerator
extends RefCounted

const FORAGE_CELL := 25.0
const DECOR_CELL := 10.0
const REPORT_CELL := 100.0
const SMALL_CHUNK := 64.0
const TREE_CHUNK := 256.0
## Share of ground the drift mask keeps, and the noise cut that gives it.
const DRIFT_KEEP := 0.35
const DRIFT_CUT := 0.12
const FORAGE_DRAW := 120.0
const TREE_DRAW := 260.0
const TREE_FAR := 600.0
## Each forage type appears in at least this many separate clusters per region.
const MIN_CLUSTERS := 8


static func forage_layers(content: CourtRegionContent) -> Array[ScatterLayer]:
	var layers := {}
	var avg_cluster := 0.0
	var total_w := 0.0
	for e in content.forage:
		avg_cluster += (e.cluster_min + e.cluster_max) * 0.5 * e.weight
		total_w += e.weight
	avg_cluster = maxf(avg_cluster / maxf(total_w, 0.001), 1.0)
	var lambda := content.forage_density * FORAGE_CELL * FORAGE_CELL / 1_000_000.0 / avg_cluster
	var r := content.bounding_rect()
	var cx := 0
	var x := r.position.x
	while x < r.end.x:
		var cz := 0
		var z := r.position.y
		while z < r.end.y:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([content.seed, cx, cz])
			var clusters := _poisson(rng, lambda)
			for _k in clusters:
				var p := Vector2(x + rng.randf() * FORAGE_CELL, z + rng.randf() * FORAGE_CELL)
				_place_cluster(content, layers, rng, p)
			z += FORAGE_CELL
			cz += 1
		x += FORAGE_CELL
		cx += 1
	_meet_quotas(content, layers)
	_fill_empty_cells(content, layers)
	var out: Array[ScatterLayer] = []
	var ids := layers.keys()
	ids.sort()
	for id in ids:
		out.append(layers[id])
	return out


## Trees cluster into groves, flower carpets into drifts; grass, rocks and
## props stay even.
static func _drift_noise(e: CourtDecorEntry, seed_value: int) -> FastNoiseLite:
	var s := String(e.mesh_id)
	if not (e.is_tree or s.contains("carpet")):
		return null
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value
	n.frequency = 1.0 / (90.0 if e.is_tree else 45.0)
	n.fractal_octaves = 2
	return n


static func decor_layers(content: CourtRegionContent) -> Array[ScatterLayer]:
	var out: Array[ScatterLayer] = []
	var r := content.bounding_rect()
	for di in content.decor.size():
		var e := content.decor[di]
		var layer := ScatterLayer.new()
		layer.id = StringName("decor_%02d_%s" % [di, e.mesh_id])
		layer.mesh = CourtAssets.mesh(e.mesh_id)
		layer.wind = e.wind
		layer.cast_shadow = e.cast_shadow
		if e.is_tree:
			layer.draw_distance = TREE_DRAW
			layer.impostor_mesh = CourtAssets.mesh(e.mesh_id, true)
			layer.impostor_distance = TREE_FAR
			layer.tags = PackedStringArray(["tree"])
		else:
			layer.draw_distance = e.draw_distance
		# Sparse things (trees, rocks) are placed per 100 m² cell with a probability;
		# dense ones (grass, flowers) as several per cell.
		var cell := DECOR_CELL if e.density >= 0.2 else 50.0
		var lambda := e.density * cell * cell / 100.0
		# Groves and one-colour drifts instead of an even sprinkle (experience
		# bar 2.4): a low-frequency mask keeps about a third of the ground and
		# triples the density there, so the total stays the same.
		var drift := _drift_noise(e, content.seed + di)
		if drift != null:
			lambda *= 1.0 / DRIFT_KEEP
		var cx := 0
		var x := r.position.x
		while x < r.end.x:
			var cz := 0
			var z := r.position.y
			while z < r.end.y:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([content.seed, di, cx, cz])
				for _k in _poisson(rng, lambda):
					var p := Vector2(x + rng.randf() * cell, z + rng.randf() * cell)
					if not content.owns(p):
						continue
					if drift != null and drift.get_noise_2d(p.x, p.y) < DRIFT_CUT:
						continue
					var hab := content.habitat_at(p)
					if not _fits(e.habitats, hab, content):
						continue
					if MacroHeight.distance_to_river(p.x, p.y) < MacroHeight.RIVER_HALF_WIDTH + 1.0 and not e.habitats.has("river"):
						continue
					if (e.is_tree or e.cast_shadow) and content.in_anchor_clearing(p):
						continue
					if e.max_slope < 90.0 and (e.is_tree or e.cast_shadow) and WorldHeight.slope_at(p.x, p.y) > e.max_slope:
						continue
					var y := _ground_y(content, hab, p)
					layer.add(Vector3(p.x, y, p.y), rng.randf() * TAU, rng.randf_range(e.scale_min, e.scale_max))
				z += cell
				cz += 1
			x += cell
			cx += 1
		if layer.count() > 0:
			out.append(layer)
	return out


## Report in the keys tools/world_smoke.gd reads, over the region's own cells.
static func report(content: CourtRegionContent, forage: Array[ScatterLayer], decor: Array[ScatterLayer]) -> Dictionary:
	var types := {}
	var placements := 0
	var filled := {}
	for layer in forage:
		types[layer.ingredient_id] = true
		placements += layer.count()
		for i in layer.count():
			filled[_report_cell(content, layer.position_of(i))] = true
	for lm in content.landmarks:
		filled[_report_cell(content, Vector3(lm.position.x, 0.0, lm.position.y))] = true
	var cells := _region_cells(content)
	var empty := 0
	for c in cells:
		if not filled.has(c):
			empty += 1
	var area := content.area_m2()
	var decor_instances := 0
	for layer in decor:
		decor_instances += layer.count()
	return {
		"region": String(content.region_id),
		"types": types.size(),
		"placements": placements,
		"placements_per_km2": int(round(placements / maxf(area / 1_000_000.0, 0.0001))),
		"empty_cells": empty,
		"cells": cells.size(),
		"landmarks": content.landmarks.size(),
		"draw_calls": estimate_draw_calls(content, forage, decor),
		"decor_instances": decor_instances,
		"area_km2": snappedf(area / 1_000_000.0, 0.001),
	}


## Draw calls seen from the busiest spot (the first landmark): one per visible
## chunk per layer, near and far, plus the landmark models, plus 30 % for the
## neighbours' scatter over the seam.
static func estimate_draw_calls(content: CourtRegionContent, forage: Array[ScatterLayer], decor: Array[ScatterLayer]) -> int:
	var cam := content.landmarks[0].position if not content.landmarks.is_empty() else content.bounding_rect().get_center()
	var calls := 0
	for layer in forage + decor:
		var chunk := TREE_CHUNK if layer.tags.has("tree") else SMALL_CHUNK
		var keys := {}
		for i in layer.count():
			var p := layer.position_of(i)
			keys[Vector2i(floori(p.x / chunk), floori(p.z / chunk))] = true
		for k: Vector2i in keys:
			var centre := Vector2((k.x + 0.5) * chunk, (k.y + 0.5) * chunk)
			var d := centre.distance_to(cam) - chunk * 0.71
			if d < layer.draw_distance:
				calls += 1
			elif layer.impostor_mesh != null and d < layer.impostor_distance:
				calls += 1
	for lm in content.landmarks:
		calls += lm.asset_ids.size() * 2
	return int(calls * 1.3)


static func _place_cluster(content: CourtRegionContent, layers: Dictionary, rng: RandomNumberGenerator, p: Vector2) -> int:
	if not content.owns(p):
		return 0
	var hab := content.habitat_at(p)
	var entry := _pick(content, hab, rng)
	if entry == null:
		return 0
	return _place_entry(content, layers, rng, p, entry)


static func _place_entry(content: CourtRegionContent, layers: Dictionary, rng: RandomNumberGenerator, p: Vector2, entry: CourtForageEntry) -> int:
	var hab := content.habitat_at(p)
	var n := rng.randi_range(entry.cluster_min, entry.cluster_max)
	var placed := 0
	for j in n:
		var q := p
		if j > 0:
			var a := rng.randf() * TAU
			q += Vector2(cos(a), sin(a)) * rng.randf() * entry.cluster_radius
		if not content.owns(q):
			continue
		var qh := content.habitat_at(q)
		if qh != hab and not _fits(entry.habitats, qh, content):
			continue
		var layer := _layer_for(layers, entry)
		layer.add(Vector3(q.x, _ground_y(content, qh, q), q.y), rng.randf() * TAU, rng.randf_range(entry.scale_min, entry.scale_max))
		placed += 1
	return placed


## Every type shows up all over its habitats, never in just a couple of spots:
## top each entry up to MIN_CLUSTERS clusters at random spots where it grows.
static func _meet_quotas(content: CourtRegionContent, layers: Dictionary) -> void:
	var r := content.bounding_rect()
	for ei in content.forage.size():
		var e := content.forage[ei]
		var id := StringName("forage_%s" % e.item_id)
		var have: int = (layers[id] as ScatterLayer).count() if layers.has(id) else 0
		var want := MIN_CLUSTERS * maxi(1, (e.cluster_min + e.cluster_max) / 2)
		if have >= want:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([content.seed, "quota", ei])
		var attempts := 0
		while have < want and attempts < 6000:
			attempts += 1
			var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			if not content.owns(p) or not _fits(e.habitats, content.habitat_at(p), content):
				continue
			have += _place_entry(content, layers, rng, p, e)


static func _fill_empty_cells(content: CourtRegionContent, layers: Dictionary) -> void:
	var filled := {}
	for id in layers:
		var layer: ScatterLayer = layers[id]
		for i in layer.count():
			filled[_report_cell(content, layer.position_of(i))] = true
	for lm in content.landmarks:
		filled[_report_cell(content, Vector3(lm.position.x, 0.0, lm.position.y))] = true
	var origin := content.bounding_rect().position
	for c in _region_cells(content):
		if filled.has(c):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([content.seed, "fill", c.x, c.y])
		for _attempt in 40:
			var p := origin + Vector2((c.x + rng.randf()) * REPORT_CELL, (c.y + rng.randf()) * REPORT_CELL)
			if _place_cluster(content, layers, rng, p) > 0:
				break


static func _pick(content: CourtRegionContent, hab: StringName, rng: RandomNumberGenerator) -> CourtForageEntry:
	var total := 0.0
	var fits: Array[CourtForageEntry] = []
	for e in content.forage:
		if _fits(e.habitats, hab, content):
			fits.append(e)
			total += e.weight
	if fits.is_empty():
		return null
	var roll := rng.randf() * total
	for e in fits:
		roll -= e.weight
		if roll <= 0.0:
			return e
	return fits[-1]


static func _fits(habitats: PackedStringArray, hab: StringName, content: CourtRegionContent) -> bool:
	if habitats.is_empty():
		return hab == content.default_habitat
	return habitats.has(String(hab))


static func _layer_for(layers: Dictionary, entry: CourtForageEntry) -> ScatterLayer:
	var id := StringName("forage_%s" % entry.item_id)
	if not layers.has(id):
		var layer := ScatterLayer.new()
		layer.id = id
		layer.ingredient_id = entry.item_id
		layer.mesh = CourtAssets.mesh(entry.model_id())
		layer.cast_shadow = false
		layer.wind = 0.0 if entry.collectible else 0.4
		layer.draw_distance = FORAGE_DRAW
		var tags := PackedStringArray(["forage"])
		if entry.collectible:
			tags = PackedStringArray(["collectible"])
		if entry.night_only:
			tags.append("night_only")
		layer.tags = tags
		layers[id] = layer
	return layers[id]


## Ground height, or the water surface for things that float (lilies, starlight water).
static func _ground_y(content: CourtRegionContent, hab: StringName, p: Vector2) -> float:
	if content.habitat_is_exclusive(hab):
		for lake in CourtHeight.lakes():
			if p.distance_to(lake["center"]) <= lake["radius"]:
				return lake["level"]
		if MacroHeight.distance_to_river(p.x, p.y) < MacroHeight.RIVER_HALF_WIDTH + 0.5:
			return CourtHeight.river_level_at(p.x, p.y)
	return WorldHeight.height_at(p.x, p.y)


static func _report_cell(content: CourtRegionContent, pos: Vector3) -> Vector2i:
	var o := content.bounding_rect().position
	return Vector2i(floori((pos.x - o.x) / REPORT_CELL), floori((pos.z - o.y) / REPORT_CELL))


## 100 m cells with at least a fifth of their ground owned by the region.
static func _region_cells(content: CourtRegionContent) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := content.bounding_rect()
	var cols := ceili(r.size.x / REPORT_CELL)
	var rows := ceili(r.size.y / REPORT_CELL)
	for cx in cols:
		for cz in rows:
			var owned := 0
			for sx in 5:
				for sz in 5:
					var p := r.position + Vector2((cx + (sx + 0.5) / 5.0) * REPORT_CELL, (cz + (sz + 0.5) / 5.0) * REPORT_CELL)
					if content.owns(p):
						owned += 1
			if owned >= 5:
				out.append(Vector2i(cx, cz))
	return out


static func _poisson(rng: RandomNumberGenerator, lambda: float) -> int:
	if lambda <= 0.0:
		return 0
	var l := exp(-lambda)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l:
			break
		k += 1
		if k > 200:
			break
	return k
