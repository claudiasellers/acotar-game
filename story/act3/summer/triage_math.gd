## How well something staunches a wing stump (L29, ch 17), from L12's
## chemistry tags. A rating in [-0.5, 0.65]: the share of the bleeding a
## dressing stops on a read, cleaned stump. Negative makes it worse.
##   vital + bind + cool help; warm thins the blood; bitter over vital harms.
## A salve from the stillroom (a dish from Chemistry.combine) beats raw forage
## pressed straight in (canon "X": the book has no salve; Feyre only holds him).
class_name TriageMath
extends RefCounted

const MAX_RATING := 0.65
const MIN_RATING := -0.5
## Raw forage pressed in by hand works at this share of a ground salve.
const RAW_SHARE := 0.6
## Blood lost at once when a harmful dressing goes in.
const HARM_LOSS := 10.0
## Herbs, not meat: forage heavier on nutrition than this is never a dressing.
const MAX_DRESSING_NUTRITION := 0.1
const DRESSING_TAGS: Array[StringName] = [&"vital", &"bind", &"cool", &"warm", &"bitter"]


## Rating of one raw ingredient pressed into the wound.
static func rate_ingredient(item: IngredientData) -> float:
	if item == null:
		return 0.0
	var totals := Chemistry.tag_totals([item] as Array[IngredientData])
	var vital := float(totals.get(&"vital", 0.0))
	var bitter := float(totals.get(&"bitter", 0.0))
	if bitter > vital:
		return MIN_RATING
	var s := 0.3 * minf(vital - bitter, 1.0) + 0.25 * minf(float(totals.get(&"bind", 0.0)), 1.0) \
		+ 0.15 * minf(float(totals.get(&"cool", 0.0)), 1.0) - 0.5 * minf(float(totals.get(&"warm", 0.0)), 1.0)
	return clampf(s * RAW_SHARE, MIN_RATING, MAX_RATING)


## Rating of a salve or steep result (a dish dictionary from Chemistry.combine).
static func rate_dish(dish: Dictionary) -> float:
	if not bool(dish.get("ok", false)):
		return 0.0
	if float(dish.get("harm", 0.0)) > 0.0:
		return MIN_RATING
	var effects: Dictionary = dish.get("effects", {})
	var bind := 0.25 if StringName(dish.get("method", &"")) in Chemistry.BIND_METHODS else 0.0
	var s := bind + 0.6 * minf(float(dish.get("heal", 0.0)), 0.6) \
		+ 0.15 * minf(float(effects.get(&"cool", 0.0)), 1.0) - 0.5 * minf(float(effects.get(&"warm", 0.0)), 1.0)
	return clampf(s, MIN_RATING, MAX_RATING)


## Whether Feyre would press this into a wound at all.
static func is_dressing(item: IngredientData) -> bool:
	if item == null or item.is_apply_only() or item.nutrition > MAX_DRESSING_NUTRITION:
		return false
	for tag in DRESSING_TAGS:
		if item.has_tag(tag):
			return true
	return false


## Whether a dish is a wound dressing (a salve or steep, not food).
static func is_dressing_dish(dish: Dictionary) -> bool:
	return StringName(dish.get("method", &"")) in Chemistry.BIND_METHODS


## The best dressing she carries: {"kind": "dish"|"item"|"", "index", "id", "rating"}.
## She reaches for the strongest; with nothing that helps she uses what she has.
static func best_dressing(inventory: Inventory) -> Dictionary:
	var best := {"kind": "", "index": -1, "id": &"", "rating": -INF}
	if inventory == null:
		return best
	for i in inventory.dishes.size():
		var dish: Dictionary = inventory.dishes[i]
		if is_dressing_dish(dish):
			var r := rate_dish(dish)
			if r > float(best.rating):
				best = {"kind": "dish", "index": i, "id": StringName(dish.get("key", "")), "rating": r}
	for container: StringName in [Inventory.POUCH, Inventory.SATCHEL]:
		for id: StringName in inventory.contents(container):
			var item := ItemCatalog.get_item(id) as IngredientData
			if is_dressing(item):
				var r := rate_ingredient(item)
				if r > float(best.rating):
					best = {"kind": "item", "index": -1, "id": id, "rating": r}
	return best


## Takes the chosen dressing out of the inventory. Returns false when it's gone.
static func use_dressing(inventory: Inventory, choice: Dictionary) -> bool:
	match String(choice.get("kind", "")):
		"dish":
			return not inventory.take_dish(int(choice.index)).is_empty()
		"item":
			return inventory.remove(StringName(choice.id), 1) == 1
	return false
