## One biome of a woods region: what grows there and what can be gathered.
##
## Weights are relative within each dictionary. Densities are per square
## metre (forage per hectare). Species ids are FloraLibrary ids; forage ids
## are ingredient (ing_) or keepsake (col_) ids from the systems lane's data.
class_name WoodsBiome
extends Resource

@export var id: StringName
@export_multiline var notes: String
@export var ground_color: Color = Color(0.34, 0.46, 0.20)
@export var ground_color_alt: Color = Color(0.40, 0.50, 0.22)
@export var tree_density: float = 0.01
@export var trees: Dictionary = {}
@export var shrub_density: float = 0.05
@export var shrubs: Dictionary = {}
@export var detail_density: float = 1.5
@export var detail: Dictionary = {}
@export var forage_per_hectare: float = 12.0
@export var forage: Dictionary = {}
## Ambient effect ids this biome emits near the player (see AmbientLife).
@export var ambience: PackedStringArray = []
