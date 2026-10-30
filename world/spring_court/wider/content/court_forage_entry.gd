## One gatherable or collectible type in a region's forage table.
class_name CourtForageEntry
extends Resource

## Gameplay id: an ing_* from data/ingredients/ or a col_* from data/collectibles/.
@export var item_id: StringName
## Model id under world/spring_court/wider/assets/ (defaults to item_id).
@export var mesh_id: StringName
## Habitats it grows in; empty = the region's default habitat.
@export var habitats: PackedStringArray = []
## Relative chance among the entries that fit a habitat.
@export var weight: float = 1.0
@export var cluster_min: int = 1
@export var cluster_max: int = 3
@export var cluster_radius: float = 2.5
@export var scale_min: float = 0.85
@export var scale_max: float = 1.2
## Collectibles get the "collectible" tag instead of an ingredient id.
@export var collectible: bool = false
## Night-only blooms (moonflower, dreamcap); the systems lane decides visibility.
@export var night_only: bool = false
## "C" canon, "C?" canon-verify, "X" invented.
@export var canon: String = "X"


func model_id() -> StringName:
	return mesh_id if mesh_id != &"" else item_id
