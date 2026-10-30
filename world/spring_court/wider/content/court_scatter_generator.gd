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


## Flower carpets gather into drifts; grass, rocks and props stay even.
## (Trees are composed separately by _tree_layers.)
static func _drift_noise(e: CourtDecorEntry, seed_value: int) -> FastNoiseLite:
	var s := String(e.mesh_id)
	if not s.contains("carpet"):
		return null
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value
	n.frequency = 1.0 / 45.0
	n.fractal_octaves = 2
	return n


static func decor_layers(content: CourtRegionContent) -> Array[ScatterLayer]:
	var all: Array[ScatterLayer] = []
	var trees := {}
	var r := content.bounding_rect()
	for di in content.decor.size():
		var e := content.decor[di]
		var layer := ScatterLayer.new()
		all.append(layer)
		layer.id = StringName("decor_%02d_%s" % [di, e.mesh_id])
		layer.mesh = CourtAssets.mesh(e.mesh_id)
		layer.wind = e.wind
		layer.cast_shadow = e.cast_shadow
		if e.is_tree:
			layer.draw_distance = TREE_DRAW
			layer.impostor_mesh = CourtAssets.mesh(e.mesh_id, true)
			layer.impostor_distance = TREE_FAR
			layer.tags = PackedStringArray(["tree"])
			trees[di] = layer
			continue
		layer.draw_distance = e.draw_distance
		# Sparse things (rocks, logs) are placed per 100 m² cell with a probability;
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
					if e.cast_shadow and content.in_anchor_clearing(p):
						continue
					if e.max_slope < 90.0 and e.cast_shadow and WorldHeight.slope_at(p.x, p.y) > e.max_slope:
						continue
					var y := _ground_y(content, hab, p)
					layer.add(Vector3(p.x, y, p.y), rng.randf() * TAU, rng.randf_range(e.scale_min, e.scale_max))
				z += cell
				cz += 1
			x += cell
			cx += 1
	if not trees.is_empty():
		_tree_layers(content, trees)
	var out: Array[ScatterLayer] = []
	for layer in all:
		if layer.count() > 0:
			out.append(layer)
	return out


## Trees for every is_tree entry together (plans/landscape-brief.md): planted
## habitats (orchards, rows, walks) in rows; elsewhere groves and open meadow
## from LandscapeLayout's stand map at each habitat's summed density, species
## in patches weighted by density, flowering pioneers at the edges, trunks
## kept apart, and specimen clumps of odd numbers in the open. Each habitat
## keeps its expected count, so budgets stay where they were.
## Returns { entry index: ScatterLayer }.
static func _tree_layers(content: CourtRegionContent, layers: Dictionary) -> void:
	var r := content.bounding_rect()
	var layout := LandscapeLayout.make(content.seed, r)
	# habitat -> {table: [[cum, "idx"]], edge: [...], density: per m2}
	var habs := {}
	var hab_of := func(tag: StringName) -> Dictionary:
		if habs.has(tag):
			return habs[tag]
		var total := 0.0
		var fits: Array = []
		for di: int in layers:
			var e := content.decor[di]
			if _fits(e.habitats, tag, content):
				fits.append(di)
				total += e.density
		var table: Array = []
		var acc := 0.0
		for di: int in fits:
			acc += content.decor[di].density / total
			table.append([acc, StringName(str(di))])
		var edge_ids: Array = []
		for entry in table:
			edge_ids.append([entry[0], content.decor[int(String(entry[1]))].mesh_id])
		var edge: Array = []
		for entry in LandscapeLayout.edge_table(edge_ids):
			for t in table:
				if content.decor[int(String(t[1]))].mesh_id == entry[1]:
					edge.append([entry[0], t[1]])
					break
		var info := {"table": table, "edge": edge, "density": total / 100.0}
		habs[tag] = info
		return info
	var classify := func(p: Vector2) -> StringName:
		if not content.owns(p):
			return &""
		var tag := content.habitat_at(p)
		var h: Dictionary = hab_of.call(tag)
		return tag if not h["table"].is_empty() and not LandscapeLayout.is_formal(tag) else &""
	var weigh := func(tag: StringName, p: Vector2) -> float:
		var h: Dictionary = hab_of.call(tag)
		var zn := LandscapeLayout.zone(LandscapeLayout.stand_at(layout, p.x, p.y), LandscapeLayout.open_share(h["density"]))
		return LandscapeLayout.tree_weight(zn)
	var means := LandscapeLayout.mean_weights(layout, r, classify, weigh)
	# Planted rows first: a block of rows per habitat, one fruit per row patch.
	var formal_done := {}
	for h in content.habitats:
		if not LandscapeLayout.is_formal(h.tag) or formal_done.has(h.tag):
			continue
		formal_done[h.tag] = true
		var info: Dictionary = hab_of.call(h.tag)
		if info["table"].is_empty():
			continue
		for p in LandscapeLayout.rows(content.seed, h.tag, r, info["density"]):
			if content.owns(p) and content.habitat_at(p) == h.tag:
				var di := int(String(LandscapeLayout.pick(info["table"], clampf((layout["patch"] as FastNoiseLite).get_noise_2d(p.x, p.y) * 0.5 + 0.5, 0.0, 0.9999))))
				_add_tree(content, layers, layout, di, p, hash([content.seed, "row", p]), 0.6)
	if content.default_habitat != &"" and LandscapeLayout.is_formal(content.default_habitat) and not formal_done.has(content.default_habitat):
		var info: Dictionary = hab_of.call(content.default_habitat)
		if not info["table"].is_empty():
			# Default ground that is planted: rows in parcels (the stand map's
			# groves), meadow strips between them.
			var open := LandscapeLayout.open_share(info["density"])
			for p in LandscapeLayout.rows(content.seed, content.default_habitat, r, info["density"] / (1.0 - open)):
				if content.owns(p) and content.habitat_at(p) == content.default_habitat \
						and LandscapeLayout.zone(LandscapeLayout.stand_at(layout, p.x, p.y), open)["grove"] > 0.5:
					var di := int(String(LandscapeLayout.pick(info["table"], clampf((layout["patch"] as FastNoiseLite).get_noise_2d(p.x, p.y) * 0.5 + 0.5, 0.0, 0.9999))))
					_add_tree(content, layers, layout, di, p, hash([content.seed, "row", p]), 0.6)
	# Specimen clumps in the open.
	var open_at := func(p: Vector2) -> float:
		var tag: StringName = classify.call(p)
		if tag == &"":
			return 0.0
		var h: Dictionary = hab_of.call(tag)
		return 1.0 - LandscapeLayout.zone(LandscapeLayout.stand_at(layout, p.x, p.y), LandscapeLayout.open_share(h["density"]))["grove"]
	var rate_at := func(p: Vector2) -> float:
		var tag: StringName = classify.call(p)
		if tag == &"":
			return 0.0
		var h: Dictionary = hab_of.call(tag)
		return clampf(h["density"] * LandscapeLayout.CLUMP_CELL * LandscapeLayout.CLUMP_CELL * 0.05, 0.02, 0.22)
	for c in LandscapeLayout.clumps(layout, r, open_at, rate_at):
		var centre: Vector2 = c["center"]
		var tag: StringName = classify.call(centre)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([content.seed, "clump", centre])
		var di := int(String(LandscapeLayout.pick(hab_of.call(tag)["table"], rng.randf())))
		var members: PackedVector2Array = c["members"]
		for m in members.size():
			if classify.call(members[m]) == tag:
				_add_tree(content, layers, layout, di, members[m], rng.randi(), 1.0 if m == 0 else 0.6)
	# Groves and meadow.
	var cell := LandscapeLayout.TREE_CELL
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([content.seed, "groves"])
	var nx := ceili(r.size.x / cell)
	var nz := ceili(r.size.y / cell)
	for iz in nz:
		for ix in nx:
			var jx := rng.randf()
			var jz := rng.randf()
			var roll := rng.randf()
			var r1 := rng.randf()
			var r2 := rng.randf()
			var tree_seed := rng.randi()
			var p := Vector2(r.position.x + (ix + jx) * cell, r.position.y + (iz + jz) * cell)
			var tag: StringName = classify.call(p)
			if tag == &"":
				continue
			var h: Dictionary = hab_of.call(tag)
			var zn := LandscapeLayout.zone(LandscapeLayout.stand_at(layout, p.x, p.y), LandscapeLayout.open_share(h["density"]))
			if roll >= h["density"] * cell * cell * LandscapeLayout.tree_weight(zn) / float(means.get(tag, 1.0)):
				continue
			var di := int(String(LandscapeLayout.tree_species(layout, h["table"], h["edge"], p.x, p.y, zn["edge"], r1, r2)))
			_add_tree(content, layers, layout, di, p, tree_seed, lerpf(0.35, 1.0, zn["core"]))


## One tree of entry `di` at p if the ground and spacing allow; `size` < 1
## skews its scale towards the entry's minimum.
static func _add_tree(content: CourtRegionContent, layers: Dictionary, layout: Dictionary, di: int, p: Vector2,
		tree_seed: int, size: float) -> void:
	var e := content.decor[di]
	if MacroHeight.distance_to_river(p.x, p.y) < MacroHeight.RIVER_HALF_WIDTH + 1.0 and not e.habitats.has("river"):
		return
	if content.in_anchor_clearing(p):
		return
	if e.max_slope < 90.0 and WorldHeight.slope_at(p.x, p.y) > e.max_slope:
		return
	if not LandscapeLayout.trunk_free(layout, p, e.mesh_id):
		return
	LandscapeLayout.add_trunk(layout, p, e.mesh_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var hab := content.habitat_at(p)
	var layer: ScatterLayer = layers[di]
	layer.add(Vector3(p.x, _ground_y(content, hab, p), p.y), rng.randf() * TAU, lerpf(e.scale_min, e.scale_max, rng.randf() * size))


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
