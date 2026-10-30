## What Feyre owns and wears: outfit pieces by slot, hairstyle and makeup.
## Contract: docs/WARDROBE_CONTRACT.md.
class_name Wardrobe
extends RefCounted

signal changed
signal piece_granted(piece_id: StringName)

const STARTING_PIECES: Array[StringName] = [&"hunter_tunic", &"hunter_trousers", &"hunter_cloak", &"hunter_boots"]

## slot -> piece id
var _equipped: Dictionary = {}
var _owned: Array[StringName] = []
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


func grant(piece_id: StringName) -> bool:
	if _owned.has(piece_id) or WardrobeCatalog.piece(piece_id) == null:
		return false
	_owned.append(piece_id)
	piece_granted.emit(piece_id)
	Gameplay.emit(&"item_acquired", [piece_id, 1])
	return true


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
	if WardrobeCatalog.hair(hair_id) == null:
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


func warmth() -> float:
	return worn_pieces().reduce(func(acc: float, p: WardrobePiece) -> float: return acc + p.warmth, 0.0)


func stealth() -> float:
	return worn_pieces().reduce(func(acc: float, p: WardrobePiece) -> float: return acc + p.stealth, 0.0)


func swift() -> float:
	return worn_pieces().reduce(func(acc: float, p: WardrobePiece) -> float: return acc + p.swift, 0.0)


func save_state() -> Dictionary:
	var mk := {}
	for ch: StringName in _makeup:
		mk[String(ch)] = String(_makeup[ch]["id"])
	var eq := {}
	for slot: StringName in _equipped:
		eq[String(slot)] = String(_equipped[slot])
	return {"owned": _owned.map(func(s: StringName) -> String: return String(s)), "equipped": eq,
		"hair": String(hair), "makeup": mk}


func load_state(data: Dictionary) -> void:
	_owned.clear()
	for id in data.get("owned", []):
		_owned.append(StringName(id))
	_equipped.clear()
	var eq: Dictionary = data.get("equipped", {})
	for slot in eq:
		_equipped[StringName(slot)] = StringName(eq[slot])
	hair = StringName(data.get("hair", "braid"))
	_makeup.clear()
	var mk: Dictionary = data.get("makeup", {})
	for ch in mk:
		apply_makeup(StringName(mk[ch]))
	changed.emit()
