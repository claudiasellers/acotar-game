## A field-craft recipe (knife work, no station): arrows, shafts, heads.
##
## Inputs are item ids or "tag:<craft_tag>" for "any item with this tag"
## (any fletching feather, for example).
class_name CraftRecipe
extends Resource

@export var id: StringName
@export var display_name: String
## Input key -> count. Keys: item id, or "tag:fletching".
@export var inputs: Dictionary = {}
@export var output: StringName
@export var output_count: int = 1
## Station id needed, or &"" for anywhere.
@export var station: StringName = &""
## When set, the recipe makes this wardrobe piece instead of an item.
@export var wardrobe_piece: StringName = &""
