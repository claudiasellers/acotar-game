## The white mare's wardrobe (lane L47-7, docs/contracts/mare_bond.md): which
## dress-up pieces Feyre has made for her, which she wears, and making one from
## what Feyre found. Kept with the world in WorldDeltas region `mount` (never a
## story flag). The look itself is MareLook's.
class_name MareTack
extends RefCounted

const DIR := "res://data/mount/decor"
const DELTAS := &"mount"
const OWNED_KEY := "decor_owned"
const WORN_KEY := "decor_worn"
## Every slot, in the order the tending screen shows them.
const SLOTS: Array[StringName] = [&"cloth", &"mane", &"brow", &"garland", &"bows", &"tail", &"tack", &"hooves"]
## Slots she can go without (a worn piece); the rest always show something.
const OPTIONAL: Array[StringName] = [&"garland", &"bows", &"tail"]
## Slot -> the tab name on the tending screen.
const SLOT_NAMES := {&"cloth": "Saddle cloth", &"mane": "Mane", &"brow": "Brow blooms", &"garland": "Garland",
	&"bows": "Mane bows", &"tail": "Tail bow", &"tack": "Tack", &"hooves": "Hooves"}

static var _all: Dictionary = {}


static func _load() -> void:
	if not _all.is_empty():
		return
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		var file := f.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var p := load("%s/%s" % [DIR, file]) as MareDecor
			if p:
				_all[p.id] = p


static func piece(id: StringName) -> MareDecor:
	_load()
	return _all.get(id) as MareDecor


static func all_pieces() -> Array[MareDecor]:
	_load()
	var out: Array[MareDecor] = []
	for p: MareDecor in _all.values():
		out.append(p)
	out.sort_custom(func(a: MareDecor, b: MareDecor) -> bool: return String(a.id) < String(b.id))
	return out


## The slot's pieces, the one she starts with first.
static func in_slot(slot: StringName) -> Array[MareDecor]:
	var out: Array[MareDecor] = []
	for p in all_pieces():
		if p.slot == slot:
			out.append(p)
	out.sort_custom(func(a: MareDecor, b: MareDecor) -> bool:
		if a.inputs.is_empty() != b.inputs.is_empty():
			return a.inputs.is_empty()
		return String(a.id) < String(b.id))
	return out


static func is_starter(p: MareDecor) -> bool:
	return p != null and p.inputs.is_empty()


static func owned(id: StringName) -> bool:
	var p := piece(id)
	if p == null:
		return false
	return is_starter(p) or (WorldDeltas.get_region_value(DELTAS, OWNED_KEY, []) as Array).has(String(id))


static func owned_count() -> int:
	var n := 0
	for p in all_pieces():
		if owned(p.id):
			n += 1
	return n


## What she wears: slot -> piece id. A slot left out wears its starter (or nothing).
static func worn() -> Dictionary:
	var w: Dictionary = WorldDeltas.get_region_value(DELTAS, WORN_KEY, {})
	return w.duplicate()


static func worn_in(slot: StringName) -> MareDecor:
	var id := StringName(String(worn().get(String(slot), "")))
	if id != &"" and owned(id):
		return piece(id)
	if slot in OPTIONAL:
		return null
	for p in in_slot(slot):
		if is_starter(p):
			return p
	return null


## Every piece showing now, by slot.
static func outfit() -> Dictionary:
	var out := {}
	for s in SLOTS:
		var p := worn_in(s)
		if p:
			out[s] = p
	return out


static func can_make(p: MareDecor, inventory: Inventory) -> bool:
	return p != null and not owned(p.id) and inventory != null and not _plan(p, inventory).is_empty()


## Makes `p` from Feyre's things and keeps it. False (nothing used) if she lacks any.
static func make(p: MareDecor, inventory: Inventory) -> bool:
	if not can_make(p, inventory):
		return false
	var plan := _plan(p, inventory)
	for id: StringName in plan:
		inventory.remove(id, int(plan[id]))
	var have: Array = (WorldDeltas.get_region_value(DELTAS, OWNED_KEY, []) as Array).duplicate()
	have.append(String(p.id))
	WorldDeltas.set_region_value(DELTAS, OWNED_KEY, have)
	return true


## Puts `p` on her (its slot's old piece comes off). False if she hasn't got it.
static func wear(p: MareDecor) -> bool:
	if p == null or not owned(p.id):
		return false
	var w := worn()
	w[String(p.slot)] = String(p.id)
	WorldDeltas.set_region_value(DELTAS, WORN_KEY, w)
	return true


## Takes the piece in `slot` off (only the optional slots go bare).
static func take_off(slot: StringName) -> void:
	var w := worn()
	if slot in OPTIONAL:
		w[String(slot)] = ""
	else:
		w.erase(String(slot))
	WorldDeltas.set_region_value(DELTAS, WORN_KEY, w)


## What each input resolves to in this inventory ({} if anything is missing),
## with the same "tag:" rules as the knife's recipes (Crafting.resolve).
static func _plan(p: MareDecor, inventory: Inventory) -> Dictionary:
	var r := CraftRecipe.new()
	r.inputs = p.inputs
	return Crafting.resolve(r, inventory)


## "3 lilac blooms, 1 cordage" style needs, with what she has: [[label, have, need]].
static func needs(p: MareDecor, inventory: Inventory) -> Array:
	var out := []
	for key: String in p.inputs:
		var need := int(p.inputs[key])
		var have := 0
		var label := key
		if key.begins_with("tag:"):
			var tag := StringName(key.substr(4))
			if inventory:
				for id in inventory.ids_with_craft_tag(tag):
					have += inventory.count(id)
			label = TAG_NAMES.get(tag, String(tag).replace("_", " "))
		else:
			have = inventory.count(StringName(key)) if inventory else 0
			label = _item_name(StringName(key))
		out.append([label, have, need])
	return out


const TAG_NAMES := {&"bloom_rose": "rose-pink blooms", &"bloom_lilac": "lilac blooms", &"bloom_butter": "buttercup blooms",
	&"bloom_pearl": "white blooms", &"bloom_sky": "sky-blue blooms", &"bloom": "any blooms", &"cordage": "cord or twine"}


static func _item_name(id: StringName) -> String:
	var item := ItemCatalog.get_item(id)
	if item and String(item.display_name) != "":
		return item.display_name
	return String(id).trim_prefix("ing_").replace("_", " ")
