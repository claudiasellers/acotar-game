## Every AttackData row in data/combat/attacks/, looked up by id or by family.
## An unknown id warns once and resolves to the hazard row generic_hit.
class_name AttackTable
extends RefCounted

const DIR := "res://data/combat/attacks/"
const GENERIC := &"generic_hit"

static var _rows: Dictionary = {}
static var _defaults: Dictionary = {}
static var _loaded: bool = false
static var _warned: Dictionary = {}


static func resolve(attack_id: StringName) -> AttackData:
	_load()
	if _rows.has(attack_id):
		return _rows[attack_id]
	if _defaults.has(attack_id):
		return _defaults[attack_id]
	if not _warned.has(attack_id):
		_warned[attack_id] = true
		push_warning("AttackTable: unknown attack '%s', using %s" % [attack_id, GENERIC])
	return _rows.get(GENERIC) as AttackData


static func has(attack_id: StringName) -> bool:
	_load()
	return _rows.has(attack_id) or _defaults.has(attack_id)


static func count() -> int:
	_load()
	return _rows.size()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for file in ResourceLoader.list_directory(DIR):
		if not file.ends_with(".tres"):
			continue
		var row := load(DIR + file) as AttackData
		if row == null or row.id == &"":
			continue
		_rows[row.id] = row
		if row.is_default and row.family != &"":
			_defaults[row.family] = row
