## Field crafting with Feyre's knife: shafts, heads, wood and ash arrows.
class_name Crafting
extends RefCounted

const RECIPE_DIR := "res://data/recipes"

static var _recipes: Dictionary = {}


static func recipe(id: StringName) -> CraftRecipe:
	_load()
	return _recipes.get(id) as CraftRecipe


static func all_recipes() -> Array[CraftRecipe]:
	_load()
	var out: Array[CraftRecipe] = []
	for r: CraftRecipe in _recipes.values():
		out.append(r)
	return out


## What each input key resolves to in this inventory, or {} if anything is
## missing. "tag:fletching" picks whichever fletching Feyre has most of.
static func resolve(r: CraftRecipe, inventory: Inventory) -> Dictionary:
	var plan := {}
	for key: String in r.inputs:
		var need := int(r.inputs[key])
		if key.begins_with("tag:"):
			var tag := StringName(key.substr(4))
			var remaining := need
			for id in inventory.ids_with_craft_tag(tag):
				var take := mini(remaining, inventory.count(id) - int(plan.get(id, 0)))
				if take > 0:
					plan[id] = int(plan.get(id, 0)) + take
					remaining -= take
				if remaining == 0:
					break
			if remaining > 0:
				return {}
		else:
			var id := StringName(key)
			if inventory.count(id) < need + int(plan.get(id, 0)):
				return {}
			plan[id] = int(plan.get(id, 0)) + need
	return plan


static func can_craft(r: CraftRecipe, inventory: Inventory, station: StringName = &"") -> bool:
	if r.station != &"" and r.station != station:
		return false
	return not resolve(r, inventory).is_empty()


## Consumes the inputs and adds the output. Returns how many were made (0 on
## failure, with nothing consumed).
static func craft(r: CraftRecipe, inventory: Inventory, station: StringName = &"") -> int:
	if not can_craft(r, inventory, station):
		return 0
	var plan := resolve(r, inventory)
	for id: StringName in plan:
		inventory.remove(id, int(plan[id]))
	if r.wardrobe_piece != &"":
		Gameplay.wardrobe.grant(r.wardrobe_piece)
		Gameplay.emit(&"item_crafted", [r.wardrobe_piece, 1])
		return 1
	var made := inventory.add(r.output, r.output_count)
	if made < r.output_count:
		# No room for all of it: give the inputs back rather than lose them.
		inventory.remove(r.output, made)
		for id: StringName in plan:
			inventory.add(id, int(plan[id]))
		return 0
	Gameplay.emit(&"item_crafted", [r.output, made])
	return made


static func _load() -> void:
	if not _recipes.is_empty():
		return
	for file in ResourceLoader.list_directory(RECIPE_DIR):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var r := load(RECIPE_DIR.path_join(file)) as CraftRecipe
			if r:
				_recipes[r.id] = r
