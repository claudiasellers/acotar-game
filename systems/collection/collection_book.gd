## The collection book (key J): everything Feyre has found, made, learned,
## sketched, painted and worn, by tab, with progress and a "new" badge until
## she looks at it. Discovery happens the first time something reaches her
## inventory, journal, sketchbook, gallery or wardrobe; the book listens to
## those state objects and never touches the world.
class_name CollectionBook
extends RefCounted

signal discovered(entry_id: StringName, tab: StringName)
signal reward_earned(reward: CollectionReward)

const TABS: Array[StringName] = [
	&"ingredients", &"keepsakes", &"recipes", &"truths", &"sketches", &"paintings", &"wardrobe",
]
const TITLES := {
	&"ingredients": "Ingredients", &"keepsakes": "Keepsakes", &"recipes": "Recipes",
	&"truths": "Truths", &"sketches": "Sketches", &"paintings": "Paintings", &"wardrobe": "Wardrobe",
}
const STORY_MOMENTS := "res://data/story/moments"
const REWARD_DIR := "res://data/collection/rewards"
const SOURCE_HINTS := {
	&"cottage_chest": "In the cottage chest", &"manor_wardrobe": "The manor wardrobe, as the seasons turn",
	&"alis": "Ask Alis", &"alis_gift": "A gift from Alis", &"calanmai": "Something for Calanmai night",
	&"seamstress": "The manor seamstress", &"painting_room": "Left in the painting room",
	&"stables": "Hanging in the stables", &"story": "It will come to her", &"woven": "Weave it from picked flowers (C)",
}

## entry id -> {"tab": String, "day": int}
var found: Dictionary = {}
## entry ids not yet looked at in the book
var fresh: Dictionary = {}
## "tab:need" of page rewards already granted
var claimed: Dictionary = {}

static var _truth_ids: Array[StringName] = []
static var _rewards: Array[CollectionReward] = []


## Connects to the state objects and quietly records what they already hold
## (starting clothes, a loaded save), so only later finds show as new. The book
## keeps no references to them: their signals already hold the book, so that
## would be a cycle that never frees. It reads them through Gameplay instead.
func watch(inventory: Inventory, journal: ProofJournal, sketchbook: Sketchbook,
		gallery: Gallery, wardrobe: Wardrobe) -> void:
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
	if Gameplay.inventory:
		for container: StringName in [&"satchel", &"forage_pouch", &"keepsakes"]:
			for id: StringName in Gameplay.inventory.contents(container):
				mark(id, &"", false)
	if Gameplay.journal:
		for key: String in Gameplay.journal.entries:
			_on_recipe(String(Gameplay.journal.entries[key].get("name", "")), false)
		for t in Gameplay.journal.truths:
			mark(t, &"truths", false)
	if Gameplay.sketchbook:
		for id: StringName in Gameplay.sketchbook.sketches:
			mark(id, &"sketches", false)
	if Gameplay.gallery:
		for r in Gameplay.gallery.paintings:
			mark(StringName(r.get("id", "")), &"paintings", false)
	if Gameplay.wardrobe:
		for id in Gameplay.wardrobe.owned_pieces():
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
	check_rewards(tab, is_new)
	return true


func is_found(entry_id: StringName) -> bool:
	return found.has(entry_id)


func is_new(entry_id: StringName) -> bool:
	return fresh.has(entry_id)


func new_count(tab: StringName = &"") -> int:
	if tab == &"":
		return fresh.size()
	return fresh.keys().filter(func(id: StringName) -> bool: return String(found[id]["tab"]) == String(tab)).size()


func found_count(tab: StringName) -> int:
	var n := 0
	for v: Dictionary in found.values():
		if v.tab == String(tab):
			n += 1
	return n


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
				out.append(_item_entry(i))
		&"keepsakes":
			for id in ItemCatalog.all_ids():
				var item := ItemCatalog.get_item(id)
				if item is CollectibleData:
					out.append(_item_entry(item))
		&"recipes":
			for d in Chemistry.dishes():
				var e := _entry(d.id, d.display_name, Color(1.0, 0.86, 0.62), d.journal_note)
				e.hint = "%s it, from %d thing%s she has gathered" % [String(d.method).capitalize(), d.required.size(),
					"" if d.required.size() == 1 else "s"]
				out.append(e)
		&"truths":
			for id in truth_ids():
				var e := _entry(id, String(id).capitalize(), Color(0.82, 0.76, 1.0), "")
				e.hint = "Listen to the people around her"
				out.append(e)
		&"sketches":
			if Gameplay.sketchbook:
				for id in Gameplay.sketchbook.order:
					out.append(_entry(id, String(Gameplay.sketchbook.sketches[id].get("title", id)), Color(0.95, 0.93, 0.88), ""))
		&"paintings":
			if Gameplay.gallery:
				for r in Gameplay.gallery.paintings:
					out.append(_entry(StringName(r.id), String(r.title), Color(1.0, 0.9, 0.7), "", String(r.path)))
		&"wardrobe":
			for p in WardrobeCatalog.all_pieces():
				var e := _entry(p.id, p.display_name, p.color, p.description)
				e.hint = SOURCE_HINTS.get(p.source, "Somewhere in the manor")
				out.append(e)
	for e in out:
		e.shape = ItemIcon.shape_for(e.id, tab)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.found and not b.found) if a.found != b.found else String(a.name) < String(b.name))
	return out


## Vector2i(found, total). Total is -1 for open-ended tabs (sketches, paintings).
func progress(tab: StringName) -> Vector2i:
	if tab == &"sketches" or tab == &"paintings":
		return Vector2i(found.values().filter(func(v: Dictionary) -> bool: return v.tab == String(tab)).size(), -1)
	var list := entries(tab)
	return Vector2i(list.filter(func(e: Dictionary) -> bool: return e.found).size(), list.size())


## A page's rewards in the order they are reached.
static func rewards(tab: StringName) -> Array[CollectionReward]:
	if _rewards.is_empty() and DirAccess.dir_exists_absolute(REWARD_DIR):
		for file in ResourceLoader.list_directory(REWARD_DIR):
			if file.ends_with(".tres"):
				var r := load(REWARD_DIR.path_join(file)) as CollectionReward
				if r:
					_rewards.append(r)
		_rewards.sort_custom(func(a: CollectionReward, b: CollectionReward) -> bool: return a.need < b.need)
	return _rewards.filter(func(r: CollectionReward) -> bool: return r.tab == tab)


## The next reward on a page not yet earned, or null.
func next_reward(tab: StringName) -> CollectionReward:
	for r in rewards(tab):
		if not claimed.has(_reward_key(r)):
			return r
	return null


func is_claimed(r: CollectionReward) -> bool:
	return claimed.has(_reward_key(r))


## Grants every reward the page has reached. `announce` false (loading a save,
## starting kit) grants silently.
func check_rewards(tab: StringName, announce: bool = true) -> void:
	var r := next_reward(tab)
	while r != null and found_count(tab) >= r.need:
		claimed[_reward_key(r)] = true
		match r.kind:
			&"wardrobe":
				Gameplay.wardrobe.grant(r.reward_id)
			&"item":
				Gameplay.inventory.add(r.reward_id)
			&"sketch":
				Gameplay.sketchbook.add(r.reward_id, r.label.trim_prefix("Sketch: "))
		if announce:
			reward_earned.emit(r)
			Gameplay.emit(&"collection_reward", [r.reward_id])
		r = next_reward(tab)


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
	return {"found": found.duplicate(true), "fresh": fresh.keys().map(func(k: StringName) -> String: return String(k)),
		"claimed": claimed.keys()}


func load_state(data: Dictionary) -> void:
	found.clear()
	for key: Variant in data.get("found", {}):
		found[StringName(key)] = (data.found[key] as Dictionary).duplicate()
	fresh.clear()
	for key: Variant in data.get("fresh", []):
		fresh[StringName(key)] = true
	claimed.clear()
	for key: Variant in data.get("claimed", []):
		claimed[String(key)] = true
	sync()


func _on_recipe(dish_name: String, is_new: bool = true) -> void:
	for d in Chemistry.dishes():
		if d.display_name == dish_name:
			mark(d.id, &"recipes", is_new)


func _item_entry(item: ItemData) -> Dictionary:
	var e := _entry(item.id, item.display_name, item.color, item.description)
	e.hint = item.hint
	e.rare = item.is_rare()
	e.shiny = item.rarity == &"shiny"
	return e


func _entry(id: StringName, entry_name: String, color: Color, note: String, image: String = "") -> Dictionary:
	return {"id": id, "name": entry_name, "color": color, "found": found.has(id),
		"new": fresh.has(id), "note": note, "image": image, "hint": "", "shape": &"leaf",
		"rare": false, "shiny": false}


static func _reward_key(r: CollectionReward) -> String:
	return "%s:%d" % [r.tab, r.need]
