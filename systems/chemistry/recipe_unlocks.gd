## Recipes Feyre has the makings of. A recipe unlocks (lands in the book's
## Recipes page with a card) the first time her bags hold every ingredient it
## needs: a brew's witness combo, or a named dish's required list. Making a
## brew she never unlocked also unlocks it. The book does the recording; this
## only knows what each recipe is and whether she has it all.
class_name RecipeUnlocks
extends RefCounted

const VERBS := {
	&"infuse": "Infuse", &"steep": "Steep", &"salve": "Work into a salve", &"distill": "Distil",
	&"tincture": "Make a tincture of", &"stew": "Stew", &"roast": "Roast", &"cook": "Cook",
	&"bake": "Bake", &"preserve": "Preserve",
}
const PLACES := {
	&"hearth": "over a hearth", &"manor_kitchen": "in the manor kitchen", &"stillroom": "in the stillroom",
	&"fae_potion_room": "in the fae potion room", &"starlight_pool": "at the starlight pool",
	&"campfire": "over a campfire", &"rite_cave_fire": "at the rite cave fire",
}
## Where a dish's method is worked, first match wins.
const DISH_STATIONS: Array[StringName] = [&"hearth", &"manor_kitchen", &"stillroom"]
const DISH_COLOR := Color(1.0, 0.86, 0.62)

static var _all: Array[Dictionary] = []


## Every recipe as {id, name, color, note, method, needs, station, brew}.
static func all() -> Array[Dictionary]:
	if not _all.is_empty():
		return _all
	for r in BrewBook.rules():
		var station := load("res://data/stations/%s.tres" % r.witness_station) as StationData
		var usable := r.methods.filter(func(m: StringName) -> bool: return station and station.methods.has(m))
		_all.append({"id": r.id, "name": r.display_name, "color": r.color, "note": r.note,
			"method": usable[0] if not usable.is_empty() else r.methods[0], "needs": r.witness.duplicate(),
			"station": r.witness_station, "brew": true})
	for d in Chemistry.dishes():
		if _covered(d):
			continue
		var at: StringName = &"hearth"
		for s in DISH_STATIONS:
			var data := load("res://data/stations/%s.tres" % s) as StationData
			if data and data.methods.has(d.method):
				at = s
				break
		_all.append({"id": d.id, "name": d.display_name, "color": DISH_COLOR, "note": d.journal_note,
			"method": d.method, "needs": d.required.duplicate(), "station": at, "brew": false})
	return _all


static func get_recipe(id: StringName) -> Dictionary:
	for r in all():
		if r.id == id:
			return r
	return {}


## True when the bags hold at least one of every ingredient.
static func has_makings(recipe: Dictionary, inventory: Inventory) -> bool:
	if inventory == null or recipe.is_empty() or (recipe.needs as Array).is_empty():
		return false
	return (recipe.needs as Array).all(func(id: StringName) -> bool: return inventory.count(id) > 0)


## Ids of recipes she has the makings of and the book has not yet recorded.
static func newly_ready(inventory: Inventory, book: CollectionBook) -> Array[StringName]:
	var out: Array[StringName] = []
	for r in all():
		if not book.is_found(r.id) and has_makings(r, inventory):
			out.append(r.id)
	return out


## "Distil lavender + wild hyacinth in the stillroom."
static func how_to(recipe: Dictionary) -> String:
	var names := PackedStringArray()
	for id: StringName in recipe.needs:
		var item := ItemCatalog.get_item(id)
		names.append(_lower(item.display_name if item else String(id)))
	return "%s %s %s." % [VERBS.get(recipe.method, String(recipe.method).capitalize()), " + ".join(names),
		PLACES.get(recipe.station, "at the %s" % String(recipe.station).replace("_", " "))]


## The book's line for an unfound recipe: the method and how many things,
## never which ones.
static func hint(recipe: Dictionary) -> String:
	var n := (recipe.needs as Array).size()
	return "%s it, from %d thing%s she has gathered" % [String(recipe.method).capitalize(), n, "" if n == 1 else "s"]


## A dish made from exactly a brew's witness combo by one of its methods is
## that brew's page, not a second one.
static func _covered(d: DishData) -> bool:
	for r in BrewBook.rules():
		if r.methods.has(d.method) and r.witness.size() == d.required.size() \
				and d.required.all(func(id: StringName) -> bool: return r.witness.has(id)):
			return true
	return false


static func _lower(s: String) -> String:
	return s if s.length() < 2 or s[1] == s[1].to_upper() else s[0].to_lower() + s.substr(1)
