## Every WeaponData row in data/combat/weapons/, by id.
class_name WeaponTable
extends RefCounted

const DIR := "res://data/combat/weapons/"

static var _rows: Dictionary = {}
static var _loaded: bool = false


static func get_weapon(weapon_id: StringName) -> WeaponData:
	_load()
	return _rows.get(weapon_id) as WeaponData


static func has(weapon_id: StringName) -> bool:
	_load()
	return _rows.has(weapon_id)


static func ids() -> Array[StringName]:
	_load()
	var out: Array[StringName] = []
	for k: StringName in _rows:
		out.append(k)
	out.sort()
	return out


static func of_family(family: StringName) -> Array[WeaponData]:
	_load()
	var out: Array[WeaponData] = []
	for w: WeaponData in _rows.values():
		if w.family == family:
			out.append(w)
	return out


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for file in ResourceLoader.list_directory(DIR):
		if not file.ends_with(".tres"):
			continue
		var row := load(DIR + file) as WeaponData
		if row and row.id != &"":
			_rows[row.id] = row
