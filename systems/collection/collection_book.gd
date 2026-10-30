## The collection book (key J): everything Feyre has found, made, learned,
## sketched, painted and worn, by tab, with progress and a "new" badge until
## she looks at it. Discovery happens the first time something reaches her
## inventory, journal, sketchbook, gallery or wardrobe; the book listens to
## those state objects and never touches the world.
class_name CollectionBook
extends RefCounted

signal discovered(entry_id: StringName, tab: StringName)

const TABS: Array[StringName] = [
	&"ingredients", &"keepsakes", &"recipes", &"truths", &"sketches", &"paintings", &"wardrobe",
]
const TITLES := {
	&"ingredients": "Ingredients", &"keepsakes": "Keepsakes", &"recipes": "Recipes",
	&"truths": "Truths", &"sketches": "Sketches", &"paintings": "Paintings", &"wardrobe": "Wardrobe",
}
const STORY_MOMENTS := "res://data/story/moments"

## entry id -> {"tab": String, "day": int}
var found: Dictionary = {}
## entry ids not yet looked at in the book
var fresh: Dictionary = {}

var _inventory: Inventory
var _journal: ProofJournal
var _sketchbook: Sketchbook
var _gallery: Gallery
var _wardrobe: Wardrobe
static var _truth_ids: Array[StringName] = []


## Connects to the state objects and quietly records what they already hold
## (starting clothes, a loaded save), so only later finds show as new.
func watch(inventory: Inventory, journal: ProofJournal, sketchbook: Sketchbook,
		gallery: Gallery, wardrobe: Wardrobe) -> void:
	_inventory = inventory
	_journal = journal
	_sketchbook = sketchbook
	_gallery = gallery
	_wardrobe = wardrobe
	inventory.item_added.connect(func(id: StringName, _n: int, _c: StringName) -> void: mark(id))
	journal.discovered.connect(func(entry: Dictionary) -> void: _on_recipe(String(entry.get("name", ""))))
	sketchbook.sketch_added.connect(func(id: StringName, _t: String) -> void: mark(id, &"sketches"))
	gallery.painting_added.connect(func(r: Dictionary) -> void: mark(StringName(r.get("id", "")), &"paintings"))
	wardrobe.piece_granted.connect(func(id: StringName) -> void: mark(id, &"wardrobe"))
	Gameplay.listen(&"journal_entry_added", func(id: StringName) -> void: mark(id, &"truths"))
	sync()


## Records anything the watched state holds that the book has not, without
## "new" badges.
func sync() -> void:
	if _inventory:
		for container: StringName in [&"satchel", &"forage_pouch", &"keepsakes"]:
			for id: StringName in _inventory.contents(container):
				mark(id, &"", false)
	if _journal:
		for key: String in _journal.entries:
			_on_recipe(String(_journal.entries[key].get("name", "")), false)
		for t in _journal.truths:
			mark(t, &"truths", false)
	if _sketchbook:
		for id: StringName in _sketchbook.sketches:
			mark(id, &"sketches", false)
	if _gallery:
		for r in _gallery.paintings:
			mark(StringName(r.get("id", "")), &"paintings", false)
	if _wardrobe:
		for id in _wardrobe.owned_pieces():
			mark(id, &"wardrobe", false)


## Marks an entry found. `tab` is worked out for items; returns true the first
## time. Items outside the book (arrows, materials, bows) are ignored.
func mark(entry_id: StringName, tab: StringName = &"", is_new: bool = true) -> bool:
	if entry_id == &"" or found.has(entry_id):
		return false
	if tab == &"":
		tab = tab_of(entry_id)
	if tab == &"":
		return false
	var clock := Gameplay.autoload(&"Clock")
	found[entry_id] = {"tab": String(tab), "day": int(clock.get(&"day")) if clock else 0}
	if is_new:
		fresh[entry_id] = true
		discovered.emit(entry_id, tab)
		Gameplay.emit(&"collection_discovered", [entry_id])
	return true


func is_found(entry_id: StringName) -> bool:
	return found.has(entry_id)


func is_new(entry_id: StringName) -> bool:
	return fresh.has(entry_id)


func new_count(tab: StringName = &"") -> int:
	if tab == &"":
		return fresh.size()
	return fresh.keys().filter(func(id: StringName) -> bool: return String(found[id]["tab"]) == String(tab)).size()


## Clears the "new" badges of a tab once Feyre has looked at it.
func seen(tab: StringName) -> void:
	for id: StringName in fresh.keys():
		if String(found[id]["tab"]) == String(tab):
			fresh.erase(id)


## The book tab an item belongs in, or &"" when it has none.
static func tab_of(item_id: StringName) -> StringName:
	var item := ItemCatalog.get_item(item_id)
	if item is IngredientData:
		return &"ingredients"
	if item is CollectibleData:
		return &"keepsakes"
	return &""


## Every entry of a tab, found or not, as {id, name, color, found, new, note}.
## Sketches and paintings have no fixed list: only what exists is shown.
func entries(tab: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match tab:
		&"ingredients":
			for i in ItemCatalog.ingredients():
				out.append(_entry(i.id, i.display_name, i.color, i.description))
		&"keepsakes":
			for id in ItemCatalog.all_ids():
				var item := ItemCatalog.get_item(id)
				if item is CollectibleData:
					out.append(_entry(id, item.display_name, item.color, item.description))
		&"recipes":
			for d in Chemistry.dishes():
				out.append(_entry(d.id, d.display_name, Color(1.0, 0.86, 0.62), d.journal_note))
		&"truths":
			for id in truth_ids():
				out.append(_entry(id, String(id).capitalize(), Color(0.82, 0.76, 1.0), ""))
		&"sketches":
			if _sketchbook:
				for id in _sketchbook.order:
					out.append(_entry(id, String(_sketchbook.sketches[id].get("title", id)), Color(0.95, 0.93, 0.88), ""))
		&"paintings":
			if _gallery:
				for r in _gallery.paintings:
					out.append(_entry(StringName(r.id), String(r.title), Color(1.0, 0.9, 0.7), "", String(r.path)))
		&"wardrobe":
			for p in WardrobeCatalog.all_pieces():
				out.append(_entry(p.id, p.display_name, p.color, p.description))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.found and not b.found) if a.found != b.found else String(a.name) < String(b.name))
	return out


## Vector2i(found, total). Total is -1 for open-ended tabs (sketches, paintings).
func progress(tab: StringName) -> Vector2i:
	if tab == &"sketches" or tab == &"paintings":
		return Vector2i(found.values().filter(func(v: Dictionary) -> bool: return v.tab == String(tab)).size(), -1)
	var list := entries(tab)
	return Vector2i(list.filter(func(e: Dictionary) -> bool: return e.found).size(), list.size())


## Story truths the story lane's moments can write, read from their steps.
static func truth_ids() -> Array[StringName]:
	if not _truth_ids.is_empty():
		return _truth_ids
	if not DirAccess.dir_exists_absolute(STORY_MOMENTS):
		return _truth_ids
	for file in ResourceLoader.list_directory(STORY_MOMENTS):
		if not file.ends_with(".tres"):
			continue
		var res := load(STORY_MOMENTS.path_join(file))
		var steps: Variant = res.get(&"steps") if res else null
		if steps is Array:
			for step: Variant in steps:
				if step is Dictionary and step.get("do", "") == "journal":
					var id := StringName(step.get("entry", ""))
					if id != &"" and not _truth_ids.has(id):
						_truth_ids.append(id)
	_truth_ids.sort()
	return _truth_ids


func save_state() -> Dictionary:
	return {"found": found.duplicate(true), "fresh": fresh.keys().map(func(k: StringName) -> String: return String(k))}


func load_state(data: Dictionary) -> void:
	found.clear()
	for key: Variant in data.get("found", {}):
		found[StringName(key)] = (data.found[key] as Dictionary).duplicate()
	fresh.clear()
	for key: Variant in data.get("fresh", []):
		fresh[StringName(key)] = true
	sync()


func _on_recipe(dish_name: String, is_new: bool = true) -> void:
	for d in Chemistry.dishes():
		if d.display_name == dish_name:
			mark(d.id, &"recipes", is_new)


func _entry(id: StringName, entry_name: String, color: Color, note: String, image: String = "") -> Dictionary:
	return {"id": id, "name": entry_name, "color": color, "found": found.has(id),
		"new": fresh.has(id), "note": note, "image": image}
