## The single source of truth for story facts.
##
## Flags are plain string keys such as "wolf_killed" or "fact.test.reached_summit".
## Gameplay only writes flags (through ActionTrigger); PhaseManager reads them.
extends Node

var _flags: Dictionary = {}


func set_flag(flag: String, value: Variant = true) -> void:
	var key := String(flag)
	if _flags.has(key) and _flags[key] == value:
		return
	_flags[key] = value
	EventBus.flag_changed.emit(key, value)


## Records a deed: sets the flag and announces it as something Feyre did.
func raise_deed(flag: String) -> void:
	set_flag(flag, true)
	EventBus.deed_performed.emit(String(flag))


func get_flag(flag: String, default: Variant = null) -> Variant:
	return _flags.get(String(flag), default)


## True when the flag is set to a truthy value.
func has_flag(flag: String) -> bool:
	return truthy(_flags.get(String(flag), false))


## Truthiness for any flag value (facts can hold a quality, a count or an id):
## null, false, 0, 0.0 and an empty String/StringName are false; a bool, number
## or non-empty String/StringName is true by its value; anything else is true.
static func truthy(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return bool(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return not String(value).is_empty()
	return true


func all_flags() -> Dictionary:
	return _flags.duplicate(true)


func clear() -> void:
	_flags.clear()


func to_dict() -> Dictionary:
	return {"flags": _flags.duplicate(true)}


## Replaces every flag without emitting change signals (used by loading).
func from_dict(data: Dictionary) -> void:
	_flags.clear()
	var flags: Dictionary = data.get("flags", {})
	for key in flags:
		_flags[String(key)] = flags[key]
