## What Feyre owns and wears: outfit pieces by slot, hairstyle and makeup.
## Purely aesthetic (owner, L64): what she wears never changes a stat.
## Contract: docs/WARDROBE_CONTRACT.md.
class_name Wardrobe
extends RefCounted

signal changed
signal piece_granted(piece_id: StringName)

const STARTING_PIECES: Array[StringName] = [&"hunter_tunic", &"hunter_trousers", &"hunter_cloak", &"hunter_boots"]
## Clothes are looks only: she is always dressed for the weather at what the
## old hunter kit gave (0.2 + 0.1 + 0.4 + 0.1), so cold play is the same in a
## ball gown as in her patched cloak.
const DRESSED_WARMTH := 0.8

## slot -> piece id
var _equipped: Dictionary = {}
var _owned: Array[StringName] = []
## Pieces granted that she hasn't seen in a wardrobe yet (the "New" ribbon).
var _unseen: Array[StringName] = []
## True while WardrobeStock restocks: those grants arrive together, so the
## wardrobe celebrates them once instead of one card and sparkle each.
var granting_quietly: bool = false
var hair: StringName = &"braid"
## channel -> {"id", "color", "amount", "sheen"}
var _makeup: Dictionary = {}


func _init() -> void:
	for id in STARTING_PIECES:
		_owned.append(id)
		var p := WardrobeCatalog.piece(id)
		if p:
			for slot in p.slots:
				_equipped[slot] = id
	# The rest of the cottage chest is hers from the start, folded away.
	for p in WardrobeCatalog.all_pieces():
		if p.source == WardrobeStock.COTTAGE and not _owned.has(p.id):
			_owned.append(p.id)


## Gives her a piece. `quiet` (a restock of many at once) still files it in the
## collection book and marks it New, but leaves the celebration to the caller.
func grant(piece_id: StringName, quiet: bool = false) -> bool:
	if _owned.has(piece_id) or WardrobeCatalog.piece(piece_id) == null:
		return false
	_owned.append(piece_id)
	_unseen.append(piece_id)
	var was_quiet := granting_quietly
	granting_quietly = quiet or was_quiet
	if granting_quietly and self == Gameplay.wardrobe:
		Gameplay.collection.mark(piece_id, &"wardrobe", false)
		Gameplay.collection.fresh[piece_id] = true
	piece_granted.emit(piece_id)
	granting_quietly = was_quiet
	Gameplay.emit(&"item_acquired", [piece_id, 1])
	return true


## Granted but not yet seen in a wardrobe.
func unseen() -> Array[StringName]:
	return _unseen.duplicate()


func is_unseen(piece_id: StringName) -> bool:
	return _unseen.has(piece_id)


func mark_seen(ids: Array[StringName] = []) -> void:
	if ids.is_empty():
		_unseen.clear()
	else:
		for id in ids:
			_unseen.erase(id)


func owns(piece_id: StringName) -> bool:
	return _owned.has(piece_id)


func owned_pieces() -> Array[StringName]:
	return _owned.duplicate()


## Equips an owned piece, clearing whatever shares any of its slots (a gown
## takes off both the tunic and the trousers).
func equip(piece_id: StringName) -> bool:
	var p := WardrobeCatalog.piece(piece_id)
	if p == null or not owns(piece_id):
		return false
	for slot in p.slots:
		var current: StringName = _equipped.get(slot, &"")
		if current != &"":
			unequip_slot(slot, false)
	for slot in p.slots:
		_equipped[slot] = piece_id
	changed.emit()
	return true


func unequip_slot(slot: StringName, notify: bool = true) -> void:
	var current: StringName = _equipped.get(slot, &"")
	if current == &"":
		return
	var p := WardrobeCatalog.piece(current)
	for s in (p.slots if p else [slot]):
		if _equipped.get(s) == current:
			_equipped.erase(s)
	if notify:
		changed.emit()


func equipped() -> Dictionary:
	return _equipped.duplicate()


func equipped_in(slot: StringName) -> StringName:
	return _equipped.get(slot, &"")


func set_hair(hair_id: StringName) -> bool:
	var h := WardrobeCatalog.hair(hair_id)
	if h == null or not h.unlocked():
		return false
	hair = hair_id
	changed.emit()
	return true


func apply_makeup(makeup_id: StringName) -> bool:
	var m := WardrobeCatalog.makeup(makeup_id)
	if m == null:
		return false
	_makeup[m.channel] = {"id": m.id, "color": m.color, "amount": m.amount, "sheen": m.sheen}
	changed.emit()
	return true


func clear_makeup(channel: StringName = &"") -> void:
	if channel == &"":
		_makeup.clear()
	else:
		_makeup.erase(channel)
	changed.emit()


func makeup() -> Dictionary:
	return _makeup.duplicate(true)


## Distinct pieces worn (a gown counts once).
func worn_pieces() -> Array[WardrobePiece]:
	var out: Array[WardrobePiece] = []
	for id: StringName in _equipped.values():
		var p := WardrobeCatalog.piece(id)
		if p and not out.has(p):
			out.append(p)
	return out


## Kept for callers (feyre.gd's cold insulation and run speed): constant in
## every outfit, because clothes are purely aesthetic.
func warmth() -> float:
	return DRESSED_WARMTH


func stealth() -> float:
	return 0.0


func swift() -> float:
	return 0.0


func save_state() -> Dictionary:
	var mk := {}
	for ch: StringName in _makeup:
		mk[String(ch)] = String(_makeup[ch]["id"])
	var eq := {}
	for slot: StringName in _equipped:
		eq[String(slot)] = String(_equipped[slot])
	return {"owned": _owned.map(func(s: StringName) -> String: return String(s)), "equipped": eq,
		"hair": String(hair), "makeup": mk,
		"unseen": _unseen.map(func(s: StringName) -> String: return String(s))}


func load_state(data: Dictionary) -> void:
	_owned.clear()
	for id in data.get("owned", []):
		_owned.append(StringName(id))
	_equipped.clear()
	var eq: Dictionary = data.get("equipped", {})
	for slot in eq:
		_equipped[StringName(slot)] = StringName(eq[slot])
	_unseen.clear()
	for id in data.get("unseen", []):
		_unseen.append(StringName(id))
	hair = StringName(data.get("hair", "braid"))
	_makeup.clear()
	var mk: Dictionary = data.get("makeup", {})
	for ch in mk:
		apply_makeup(StringName(mk[ch]))
	changed.emit()
