## What the satchel page and the quick bar show: every carried thing as one
## entry, grouped into pockets. Entries are item ids, or "dish:<key>" for
## cooked dishes (they live in Inventory.dishes, not in a container).
class_name SatchelEntries
extends RefCounted

const ALL := &"all"
const DISHES := &"dishes"
const DISH_PREFIX := "dish:"
## Page order of the pockets, with the names the page shows.
const POCKETS: Array[StringName] = [ALL, Inventory.SATCHEL, Inventory.POUCH, DISHES, Inventory.QUIVER,
		Inventory.BOWS, Inventory.KEEPSAKES]
const POCKET_NAMES := {
	ALL: "Everything",
	Inventory.SATCHEL: "Satchel",
	Inventory.POUCH: "Forage pouch",
	DISHES: "Food",
	Inventory.QUIVER: "Quiver",
	Inventory.BOWS: "Bows",
	Inventory.KEEPSAKES: "Keepsakes",
}


## Entries in a pocket, each {id, pocket, count, name, description, icon,
## color, rare, item}. Item entries keep inventory order within a pocket,
## sorted by name so the grid doesn't reshuffle as counts change.
static func list(inv: Inventory, pocket: StringName = ALL) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: StringName in POCKETS:
		if p == ALL or (pocket != ALL and p != pocket):
			continue
		if p == DISHES:
			out.append_array(_dishes(inv))
			continue
		var bucket := inv.contents(p)
		var ids: Array = bucket.keys()
		ids.sort_custom(func(a: StringName, b: StringName) -> bool: return _name(a) < _name(b))
		for id: StringName in ids:
			# An item split between pouch and satchel shows once, in its first pocket.
			if pocket == ALL and out.any(func(e: Dictionary) -> bool: return e.id == id):
				continue
			out.append(item_entry(inv, id, p))
	return out


static func item_entry(inv: Inventory, id: StringName, pocket: StringName) -> Dictionary:
	var item := ItemCatalog.get_item(id)
	return {
		"id": id,
		"pocket": pocket,
		"count": inv.count(id),
		"name": _name(id),
		"description": item.description if item else "",
		"icon": item.icon if item else &"trinket",
		"color": item.color if item else Color.WHITE,
		"rare": item != null and item.is_rare(),
		"item": item,
	}


## The entry for any id (item or dish), or {} when Feyre carries none.
static func find(inv: Inventory, id: StringName) -> Dictionary:
	if is_dish(id):
		for e in _dishes(inv):
			if e.id == id:
				return e
		return {}
	if inv.count(id) <= 0:
		return {}
	var pocket := inv.container_of(ItemCatalog.canonical(id))
	return item_entry(inv, ItemCatalog.canonical(id), pocket)


static func count(inv: Inventory, id: StringName) -> int:
	if is_dish(id):
		return dish_indices(inv, id).size()
	return inv.count(id)


static func is_dish(id: StringName) -> bool:
	return String(id).begins_with(DISH_PREFIX)


static func dish_id(dish: Dictionary) -> StringName:
	return StringName(DISH_PREFIX + String(dish.get("key", dish.get("name", "dish"))))


static func dish_indices(inv: Inventory, id: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in inv.dishes.size():
		if dish_id(inv.dishes[i]) == id:
			out.append(i)
	return out


## Dishes stack by recipe key.
static func _dishes(inv: Inventory) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for dish in inv.dishes:
		var id := dish_id(dish)
		if seen.has(id):
			out[seen[id]].count += 1
			continue
		seen[id] = out.size()
		out.append({
			"id": id,
			"pocket": DISHES,
			"count": 1,
			"name": String(dish.get("name", "A dish")),
			"description": _dish_text(dish),
			"icon": &"drop",
			"color": Color(),  # the page tints dishes with the theme's accent
			"rare": false,
			"item": null,
			"dish": dish,
		})
	return out


static func _dish_text(dish: Dictionary) -> String:
	var parts: Array[String] = []
	if float(dish.get("hunger_relief", 0.0)) > 0.0:
		parts.append("Filling")
	if float(dish.get("heal", 0.0)) > 0.0:
		parts.append("mends")
	var effects: Dictionary = dish.get("effects", {})
	for tag in effects:
		parts.append(String(tag))
	if float(dish.get("harm", 0.0)) > 0.0:
		parts.append("but something in it is wrong")
	return "Cooked by her own hand. " + (", ".join(parts) + "." if parts.size() > 0 else "")


static func _name(id: StringName) -> String:
	var item := ItemCatalog.get_item(id)
	return item.display_name if item and item.display_name != "" else String(id).capitalize()
