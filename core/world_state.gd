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
	var value: Variant = _flags.get(String(flag), false)
	return value != null and bool(value)


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
