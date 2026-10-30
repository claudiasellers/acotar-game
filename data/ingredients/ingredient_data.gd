## One forageable or harvested ingredient (lore/05-foraging-chemistry).
##
## Tags drive the chemistry engine (root design doc §5); the rest tells the
## world lanes where and when it grows so they can scatter it.
class_name IngredientData
extends ItemData

## Chemistry tags: vital warm cool bright quiet swift strong steady keen
## bitter bind fae ash, plus non-chemical "preserve". (Iron does nothing to
## fae in canon; only humans believe it does.)
@export var tags: Array[StringName] = []
## Region ids (lore/01-world) where it grows or is found.
@export var regions: Array[StringName] = []
## "winter", "spring" or "any". The human realm is winter in M1.
@export var season: StringName = &"any"
## Only pickable at night (moonflower).
@export var night_only: bool = false
## Gone by dawn once picked (starlight water).
@export var perishes_at_dawn: bool = false
## Game days before a picked scatter instance grows back.
@export var respawn_days: float = 2.0
## "common", "uncommon" or "rare": a density hint for scatter.
@export var abundance: StringName = &"common"
## Can be eaten or cooked. False for hides, sinew, wood, pigments, minerals.
@export var edible: bool = true
## Hunger relieved when eaten raw or cooked, 0 to 1 of a full stomach.
@export var nutrition: float = 0.05
## Days of family food it adds to the cottage tally.
@export var food_days: float = 0.0
## Pigment colour name for the painting system ("", "blue", "red", ...).
@export var pigment: StringName = &""


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


## Ash harms fae: it is applied (arrows, ward-breaking), never eaten.
func is_apply_only() -> bool:
	return tags.has(&"ash")
