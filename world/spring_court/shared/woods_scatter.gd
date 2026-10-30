## Deterministic scatter generator for the woods regions (engineering rule R15:
## fixed seeds, same output every run). Turns a WoodsRegionDef's biomes into
## ScatterLayers (docs/contracts/world.md §4): one layer per tree or shrub
## species and one per gatherable id.
##
## Points come from a jittered grid per layer kind; each point asks the
## provider for its biome, keeps itself with probability density * cell area,
## then picks a species by the biome's weights. Ground height comes from
## WorldHeight so placement matches the final Terrain3D bake.
class_name WoodsScatter
extends RefCounted

## Grid cell (m) per kind. Smaller cells for denser layers.
const CELL := {"tree": 4.0, "shrub": 2.5, "forage": 5.0, "detail": 0.9}
## Species allowed on water (everything else is skipped there).
const WATER_OK := [&"reed_clump", &"cattail", &"lily_pad", &"pebbles", &"trout_pool", &"silt_patch", &"river_glass"]
## Tree layers draw fully to this distance, then as their low-poly impostor.
const TREE_DRAW := 160.0
const TREE_IMPOSTOR := 900.0
const FORAGE_DRAW := 90.0
## ScatterField chunk sizes per kind (WoodsRegion builds one field per kind).
const CHUNK_TREE := 256.0
const CHUNK_SHRUB := 128.0
const CHUNK_FORAGE := 64.0
## Forage comes in drifts (experience-bar §1.3.5): up to DRIFT_TRIES drifts
## per DRIFT_CELL square, and every 100 m block gets at least one.
const DRIFT_CELL := 50.0
const DRIFT_TRIES := 4
const DRIFT_SIZE := Vector2i(5, 30)
## Finds that lie alone or in pairs rather than in drifts.
const LONE_VISUALS := [&"feather_hawk", &"feather_owl", &"feather_jay", &"snail_shell", &"shed_antler",
		&"egg_shell", &"wild_hive", &"trout_pool", &"odd_stone", &"painted_pebble", &"river_glass",
		&"old_arrowhead", &"mask_ribbon", &"bone_charm", &"rusted_iron", &"acorn_caps", &"silt_patch"]


## Every scatter layer for a region (trees, shrubs, forage), sorted by id.
static func generate(def: WoodsRegionDef, bounds: Rect2) -> Array[ScatterLayer]:
	var layers: Array[ScatterLayer] = []
	for kind in ["tree", "shrub", "forage"]:
		var points := place(def, bounds, kind)
		var ids := points.keys()
		ids.sort()
		for id: StringName in ids:
			layers.append(_make_layer(def, kind, id, points[id]))
	return layers


## Raw placements for one kind inside `rect`: { id: PackedFloat32Array of
## x, y, z, yaw, scale }. "detail" is the near-player ground cover.
static func place(def: WoodsRegionDef, rect: Rect2, kind: String, seed_offset: int = 0) -> Dictionary:
	if kind == "forage":
		return _place_drifts(def, rect, seed_offset)
	var provider: Variant = def.provider
	var biomes := def.biome_map()
	var tables := _tables(def, kind)
	var cell: float = CELL[kind]
	var area := cell * cell
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([def.seed, kind, seed_offset, rect.position, rect.size])
	var out := {}
	var nx := ceili(rect.size.x / cell)
	var nz := ceili(rect.size.y / cell)
	for iz in nz:
		for ix in nx:
			# Always draw the same number of randoms per cell (determinism).
			var jx := rng.randf()
			var jz := rng.randf()
			var roll := rng.randf()
			var pick := rng.randf()
			var yaw := rng.randf() * TAU
			var sc := rng.randf()
			var x := rect.position.x + (ix + jx) * cell
			var z := rect.position.y + (iz + jz) * cell
			var biome_id: StringName = provider.biome_at(x, z)
			var table: Array = tables.get(biome_id, [])
			if table.is_empty():
				continue
			var b: WoodsBiome = biomes[biome_id]
			var density := _density(b, kind)
			# Composition (WoodsComposition): clearings and vista cones stay
			# open; clearing floors and path edges carpet in one-colour drifts.
			var drift := &""
			if kind == "tree" or kind == "shrub":
				if WoodsComposition.in_vista(def, x, z):
					continue
				if not WoodsComposition.clearing_at(def, x, z, 1.0 if kind == "tree" else 0.7).is_empty():
					continue
			elif kind == "detail":
				var glade := WoodsComposition.clearing_at(def, x, z)
				if not glade.is_empty() and sc < 0.7:
					drift = glade["flower"]
				elif sc < 0.75:
					drift = WoodsComposition.path_drift(def, x, z, biome_id)
				if drift != &"":
					density *= 2.0
			if roll >= density * area:
				continue
			var id: StringName = drift if drift != &"" else _pick(table, pick)
			var clear: float = provider.clearance(x, z)
			var wet: bool = provider.is_water(x, z)
			if wet and not (_visual(def, kind, id) in WATER_OK):
				continue
			if kind == "tree" and clear < 0.95:
				continue
			if kind == "shrub" and clear < 0.6 and not wet:
				continue
			if kind != "tree" and kind != "shrub" and clear < 0.15 and not wet:
				continue
			var visual := _visual(def, kind, id)
			var range_: Vector2 = FloraLibrary.info(visual).get("scale", Vector2.ONE)
			var s := lerpf(range_.x, range_.y, sc)
			var y := WorldHeight.height_at(x, z)
			if not out.has(id):
				out[id] = PackedFloat32Array()
			out[id].append_array(PackedFloat32Array([x, y, z, yaw, s]))
	return out


## Forage as drifts of 5-30 of one kind around a centre (finds alone or in
## pairs), with gaps between. Same randoms per cell and try (determinism).
static func _place_drifts(def: WoodsRegionDef, rect: Rect2, seed_offset: int) -> Dictionary:
	var provider: Variant = def.provider
	var biomes := def.biome_map()
	var tables := _tables(def, "forage")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([def.seed, "drifts", seed_offset, rect.position, rect.size])
	var out := {}
	var nx := ceili(rect.size.x / DRIFT_CELL)
	var nz := ceili(rect.size.y / DRIFT_CELL)
	var counters := {}  # biome id -> drifts tried
	var mean_size := 7.0  # mix of lone finds and drifts
	for iz in nz:
		for ix in nx:
			for t in DRIFT_TRIES:
				var jx := rng.randf()
				var jz := rng.randf()
				var keep := rng.randf()
				var pick := rng.randf()
				var size_roll := rng.randf()
				var drift_seed := rng.randi()
				var c := Vector2(rect.position.x + (ix + jx) * DRIFT_CELL, rect.position.y + (iz + jz) * DRIFT_CELL)
				var b: WoodsBiome = biomes.get(provider.biome_at(c.x, c.y))
				if b == null or not tables.has(b.id):
					continue
				var expected := b.forage_per_hectare / 10000.0 * DRIFT_CELL * DRIFT_CELL
				if keep >= expected / (DRIFT_TRIES * mean_size):
					continue
				# Stratified picks (golden-ratio sequence per biome) so even a
				# small region shows every kind its table lists.
				var n: int = counters.get(b.id, 0)
				counters[b.id] = n + 1
				pick = fposmod(n * 0.6180339887 + pick * 0.05, 1.0)
				_drift(def, out, tables[b.id], c, pick, size_roll, drift_seed)
	# R1 floor: every 100 m block holds at least one drift.
	var filled := {}
	for id: StringName in out:
		var inst: PackedFloat32Array = out[id]
		for o in range(0, inst.size(), ScatterLayer.STRIDE):
			filled[Vector2i(floori((inst[o] - rect.position.x) / 100.0), floori((inst[o + 2] - rect.position.y) / 100.0))] = true
	for bz in ceili(rect.size.y / 100.0):
		for bx in ceili(rect.size.x / 100.0):
			var block := Vector2i(bx, bz)
			if filled.has(block):
				continue
			var brng := RandomNumberGenerator.new()
			brng.seed = hash([def.seed, "forced", seed_offset, block])
			var area := Rect2(rect.position + Vector2(block) * 100.0, Vector2.ONE * 100.0).intersection(rect)
			for attempt in 24:
				var c := area.position + Vector2(brng.randf(), brng.randf()) * area.size
				var pick := brng.randf()
				var size_roll := brng.randf()
				var drift_seed := brng.randi()
				var b: WoodsBiome = biomes.get(provider.biome_at(c.x, c.y))
				if b != null and tables.has(b.id) and _drift(def, out, tables[b.id], c, pick, size_roll, drift_seed, area) > 0:
					break
	return out


## Places one drift around `c`; returns how many instances landed.
static func _drift(def: WoodsRegionDef, out: Dictionary, table: Array, c: Vector2, pick: float,
		size_roll: float, drift_seed: int, clip := Rect2()) -> int:
	var provider: Variant = def.provider
	var id: StringName = _pick(table, pick)
	var visual := _visual(def, "forage", id)
	var lone := visual in LONE_VISUALS or String(id).begins_with("col_")
	# Mostly small drifts, the odd big carpet.
	var size := 1 + int(size_roll * 1.99) if lone else DRIFT_SIZE.x + int(size_roll * size_roll * (DRIFT_SIZE.y - DRIFT_SIZE.x))
	var spread := 1.5 if lone else 1.0 + sqrt(float(size)) * 0.9
	var range_: Vector2 = FloraLibrary.info(visual).get("scale", Vector2.ONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = drift_seed
	var placed := 0
	for i in size:
		var off := Vector2(rng.randfn(0.0, spread), rng.randfn(0.0, spread))
		var yaw := rng.randf() * TAU
		var sc := rng.randf()
		var x := c.x + off.x
		var z := c.y + off.y
		if clip.has_area() and not clip.has_point(Vector2(x, z)):
			continue
		var wet: bool = provider.is_water(x, z)
		if wet and not (visual in WATER_OK):
			continue
		if not wet and provider.clearance(x, z) < 0.15:
			continue
		if not out.has(id):
			out[id] = PackedFloat32Array()
		out[id].append_array(PackedFloat32Array([x, WorldHeight.height_at(x, z), z, yaw, lerpf(range_.x, range_.y, sc)]))
		placed += 1
	return placed


static func _make_layer(def: WoodsRegionDef, kind: String, id: StringName, instances: PackedFloat32Array) -> ScatterLayer:
	var layer := layer_without_mesh(def, kind, id, instances)
	var visual := _visual(def, kind, id)
	layer.mesh = FloraLibrary.mesh(visual)
	if kind == "tree":
		layer.impostor_mesh = FloraLibrary.far_mesh(visual)
	return layer


## The layer's settings and instances, without GPU resources (thread-safe).
static func layer_without_mesh(def: WoodsRegionDef, kind: String, id: StringName, instances: PackedFloat32Array) -> ScatterLayer:
	var layer := ScatterLayer.new()
	layer.instances = instances
	var visual := _visual(def, kind, id)
	var info := FloraLibrary.info(visual)
	match kind:
		"tree":
			layer.id = StringName("tree_" + String(id))
			layer.draw_distance = TREE_DRAW
			layer.impostor_distance = TREE_IMPOSTOR
			# Small trees skip the shadow pass (one draw call per chunk saved).
			layer.cast_shadow = info.get("shadow", true)
			layer.wind = 0.35
		"shrub":
			layer.id = StringName("shrub_" + String(id))
			layer.draw_distance = float(info.get("range", 140.0))
			layer.cast_shadow = FloraLibrary.look_of(visual) == &"plain" and info.get("shadow", true)
			layer.wind = 0.0 if FloraLibrary.look_of(visual) == &"plain" else 0.6
		"forage":
			layer.id = StringName("forage_" + String(id))
			layer.ingredient_id = id
			layer.draw_distance = maxf(FORAGE_DRAW, float(info.get("range", 60.0)))
			layer.cast_shadow = false
			layer.wind = 0.5
			if String(id).begins_with("col_"):
				layer.tags = PackedStringArray(["collectible"])
	return layer


## The FloraLibrary species that draws `id`.
static func visual_of(def: WoodsRegionDef, kind: String, id: StringName) -> StringName:
	return _visual(def, kind, id)


static func _visual(def: WoodsRegionDef, kind: String, id: StringName) -> StringName:
	if kind == "forage":
		return def.forage_visuals.get(id, &"odd_stone")
	return id


static func _density(b: WoodsBiome, kind: String) -> float:
	match kind:
		"tree":
			return b.tree_density
		"shrub":
			return b.shrub_density
		"forage":
			return b.forage_per_hectare / 10000.0
		_:
			return b.detail_density


static func _weights(b: WoodsBiome, kind: String) -> Dictionary:
	match kind:
		"tree":
			return b.trees
		"shrub":
			return b.shrubs
		"forage":
			return b.forage
		_:
			return b.detail


## biome id -> Array of [cumulative_weight_normalised, id]
static func _tables(def: WoodsRegionDef, kind: String) -> Dictionary:
	var out := {}
	for b in def.biomes:
		var w := _weights(b, kind)
		var total := 0.0
		for k in w:
			total += maxf(float(w[k]), 0.0)
		if total <= 0.0 or _density(b, kind) <= 0.0:
			continue
		var acc := 0.0
		var table: Array = []
		var keys := w.keys()
		keys.sort()
		for k in keys:
			var v := maxf(float(w[k]), 0.0)
			if v <= 0.0:
				continue
			acc += v / total
			table.append([acc, StringName(k)])
		out[b.id] = table
	return out


static func _pick(table: Array, r: float) -> StringName:
	for entry in table:
		if r <= entry[0]:
			return entry[1]
	return table[table.size() - 1][1]


## A rough draw-call estimate for the region's layers (R9 budget): the worst
## of a few viewpoints, counting each chunk/layer pair within its draw range
## (and impostor range), plus a shadow pass for shadow casters.
## `extra` covers what isn't a ScatterLayer (ground cover cells, particles,
## water, landmarks); `props` are single placed props as (x, z, calls each)
## drawn within `prop_range`.
static func estimate_draw_calls(layers: Array[ScatterLayer], bounds: Rect2, extra: int = 0,
		props := PackedVector3Array(), prop_range := 0.0) -> int:
	var views := [bounds.get_center(), bounds.position + bounds.size * 0.25, bounds.end - bounds.size * 0.25,
			Vector2(bounds.position.x + bounds.size.x * 0.25, bounds.end.y - bounds.size.y * 0.25),
			Vector2(bounds.end.x - bounds.size.x * 0.25, bounds.position.y + bounds.size.y * 0.25)]
	var worst := 0
	for v: Vector2 in views:
		var calls := 0
		for layer in layers:
			var chunk := CHUNK_TREE if layer.id.begins_with("tree_") else (CHUNK_SHRUB if layer.id.begins_with("shrub_") else CHUNK_FORAGE)
			var near := {}
			var far := {}
			for i in layer.count():
				var p := layer.position_of(i)
				var d := Vector2(p.x, p.z).distance_to(v)
				var key := Vector2i(floori(p.x / chunk), floori(p.z / chunk))
				if d < layer.draw_distance + chunk:
					near[key] = true
				elif layer.impostor_mesh != null and d < layer.impostor_distance + chunk:
					far[key] = true
			var per := 2 if layer.cast_shadow else 1
			calls += near.size() * per + far.size()
		for p in props:
			if Vector2(p.x, p.y).distance_to(v) < prop_range:
				calls += int(p.z)
		worst = maxi(worst, calls)
	return worst + extra
