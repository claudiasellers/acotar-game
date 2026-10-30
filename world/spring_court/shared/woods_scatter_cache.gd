## Baked output of a woods region's generator (tools/generators/woods_scatter.gd,
## run by `make update`). Lives in world/spring_court/<id>/_generated/ and is
## git-ignored (R15). A region uses it only when its fingerprint matches, so a
## stale cache is regenerated instead of trusted.
class_name WoodsScatterCache
extends Resource

## Bump when the generator's output format or placement rules change.
const GENERATOR_VERSION := 2

@export var fingerprint: String
## kind ("tree", "shrub", "forage") -> { id: PackedFloat32Array (x, y, z, yaw, scale) }
@export var placements: Dictionary = {}
@export var grid: Vector2i
@export var heights: PackedFloat32Array
## Terrain stand-in vertex colours, RGB8.
@export var colors: PackedByteArray


static func path_for(region_id: StringName) -> String:
	return "res://world/spring_court/%s/_generated/woods_cache.res" % region_id


## What the cache must match: generator version, the biome data, and the
## terrain at a few sample points (catches provider and macro-map changes).
static func fingerprint_for(def: WoodsRegionDef) -> String:
	var parts := PackedStringArray([str(GENERATOR_VERSION), def.region_id, str(def.seed)])
	for b in def.biomes:
		parts.append(var_to_str([b.id, b.tree_density, b.trees, b.shrub_density, b.shrubs, b.forage_per_hectare, b.forage]))
	parts.append(var_to_str(def.forage_visuals))
	var bounds: Rect2 = def.provider.BOUNDS
	for i in 9:
		var x := bounds.position.x + bounds.size.x * (0.1 + 0.4 * (i % 3))
		var z := bounds.position.y + bounds.size.y * (0.1 + 0.4 * (i / 3))
		parts.append("%.2f:%s" % [WorldHeight.height_at(x, z), def.provider.biome_at(x, z)])
	return str(hash("|".join(parts)))
