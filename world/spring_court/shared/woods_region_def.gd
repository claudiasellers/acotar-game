## Data for one woods region: its biomes, scatter seeds and the visual used
## for each gatherable id. The terrain shape lives in the region's height
## provider script (`provider`), which also classifies biomes.
class_name WoodsRegionDef
extends Resource

@export var region_id: StringName
@export var display_name: String
@export var provider: Script
@export var seed: int = 1
@export var biomes: Array[WoodsBiome] = []
## forage id -> FloraLibrary species used to draw it.
@export var forage_visuals: Dictionary = {}
## forage id -> respawn time in in-game days (0 = never respawns).
@export var respawn_days: Dictionary = {}


func biome(id: StringName) -> WoodsBiome:
	for b in biomes:
		if b.id == id:
			return b
	return null


func biome_map() -> Dictionary:
	var out := {}
	for b in biomes:
		out[b.id] = b
	return out
