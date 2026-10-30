## Anything Feyre can carry. Ingredients, collectibles, arrows, materials and
## story objects all extend or use this, so one catalogue answers "what is X".
class_name ItemData
extends Resource

## How heavy and bulky an item is. Decides which container it goes in and how
## much of the container it fills.
enum WeightClass { TINY, SMALL, MEDIUM, LARGE, HEAVY }

## Weight units each class takes in a container.
const WEIGHT_UNITS := {
	WeightClass.TINY: 0.25,
	WeightClass.SMALL: 1.0,
	WeightClass.MEDIUM: 3.0,
	WeightClass.LARGE: 8.0,
	WeightClass.HEAVY: 20.0,
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var weight_class: WeightClass = WeightClass.SMALL
## Free-form tags used by crafting recipes ("fletching", "arrowhead", ...).
@export var craft_tags: Array[StringName] = []
## Coin the village market pays for one. 0 means the market will not buy it.
@export var base_price: int = 0
## Lore canon status from the Keeper: "C", "C?" or "X".
@export var canon: String = "X"
## Placeholder colour for scatter meshes and icons until art arrives.
@export var color: Color = Color(0.8, 0.8, 0.8)


func weight_units() -> float:
	return WEIGHT_UNITS[weight_class]


func has_craft_tag(tag: StringName) -> bool:
	return craft_tags.has(tag)
