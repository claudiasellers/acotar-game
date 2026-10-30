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
			if roll >= density * area:
				continue
			var id: StringName = _pick(table, pick)
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


static func _make_layer(def: WoodsRegionDef, kind: String, id: StringName, instances: PackedFloat32Array) -> ScatterLayer:
	var layer := ScatterLayer.new()
	layer.instances = instances
	var visual := _visual(def, kind, id)
	layer.mesh = FloraLibrary.mesh(visual)
	var info := FloraLibrary.info(visual)
	match kind:
		"tree":
			layer.id = StringName("tree_" + String(id))
			layer.draw_distance = TREE_DRAW
			layer.impostor_mesh = FloraLibrary.far_mesh(visual)
			layer.impostor_distance = TREE_IMPOSTOR
			layer.cast_shadow = true
			layer.wind = 0.35
		"shrub":
			layer.id = StringName("shrub_" + String(id))
			layer.draw_distance = float(info.get("range", 140.0))
			layer.cast_shadow = FloraLibrary.look_of(visual) == &"plain"
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
## water, landmarks).
static func estimate_draw_calls(layers: Array[ScatterLayer], bounds: Rect2, extra: int = 0) -> int:
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
		worst = maxi(worst, calls)
	return worst + extra
