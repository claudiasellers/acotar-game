## Decorative scatter (grass, flowers, trees, rocks) for a region's beauty.
class_name CourtDecorEntry
extends Resource

@export var mesh_id: StringName
@export var habitats: PackedStringArray = []
## Instances per 100 m² of matching ground.
@export var density: float = 1.0
@export var scale_min: float = 0.8
@export var scale_max: float = 1.25
@export var wind: float = 0.5
@export var cast_shadow: bool = false
@export var draw_distance: float = 120.0
## Trees: draw further and stand on a card impostor beyond draw_distance.
@export var is_tree: bool = false
## Skip ground steeper than this, degrees.
@export var max_slope: float = 35.0
