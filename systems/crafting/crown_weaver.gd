## Weaves a flower crown from the blooms Feyre has picked (C / d-pad down) and
## puts it on at once (experience-bar §1.4.5). The colour follows the blooms:
## whichever family she holds most of.
class_name CrownWeaver
extends RefCounted

const PREFIX := "weave_crown_"


## The crown recipe she can make now, favouring the family she has most of.
static func best_recipe(inventory: Inventory) -> CraftRecipe:
	var best: CraftRecipe = null
	var best_count := -1
	for r in Crafting.all_recipes():
		if not String(r.id).begins_with(PREFIX) or not Crafting.can_craft(r, inventory):
			continue
		var family := StringName("bloom_" + String(r.id).trim_prefix(PREFIX))
		var n := 0
		for id in inventory.ids_with_craft_tag(family):
			n += inventory.count(id)
		if n > best_count:
			best = r
			best_count = n
	return best


## Blooms still needed for any crown (0 when one can be woven).
static func blooms_missing(inventory: Inventory) -> int:
	if best_recipe(inventory) != null:
		return 0
	var have := 0
	for id in inventory.ids_with_craft_tag(&"bloom"):
		have += inventory.count(id)
	return maxi(5 - have, 1)


## Weaves and equips a crown. Returns the piece id, or &"" when she lacks blooms.
static func weave(inventory: Inventory, wardrobe: Wardrobe) -> StringName:
	var r := best_recipe(inventory)
	if r == null or Crafting.craft(r, inventory) == 0:
		return &""
	wardrobe.equip(r.wardrobe_piece)
	return r.wardrobe_piece
