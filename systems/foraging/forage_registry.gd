## Picked-forage bookkeeping with respawn on the in-game clock.
##
## Uses the story lane's WorldDeltas autoload when it exists (so picked state
## lives with the other region deltas); otherwise keeps its own record.
class_name ForageRegistry
extends RefCounted

## key "<region>|<instance_key>" -> absolute game day when it grows back.
var _picked: Dictionary = {}


static func now_days() -> float:
	var clock := Gameplay.autoload(&"Clock")
	if clock == null:
		return 0.0
	return float(clock.get(&"day")) + float(clock.get(&"time_of_day"))


func mark_picked(region_id: StringName, instance_key: String, respawn_days: float) -> void:
	var deltas := Gameplay.autoload(&"WorldDeltas")
	if deltas and deltas.has_method(&"mark_picked"):
		deltas.mark_picked(region_id, instance_key, respawn_days)
		return
	_picked["%s|%s" % [region_id, instance_key]] = now_days() + maxf(respawn_days, 0.0) \
			if respawn_days > 0.0 else INF


func is_picked(region_id: StringName, instance_key: String) -> bool:
	var deltas := Gameplay.autoload(&"WorldDeltas")
	if deltas and deltas.has_method(&"is_picked"):
		return deltas.is_picked(region_id, instance_key)
	var key := "%s|%s" % [region_id, instance_key]
	if not _picked.has(key):
		return false
	if now_days() >= float(_picked[key]):
		_picked.erase(key)
		return false
	return true


func save_state() -> Dictionary:
	var out := {}
	for key: String in _picked:
		out[key] = -1.0 if is_inf(float(_picked[key])) else _picked[key]
	return {"picked": out}


func load_state(data: Dictionary) -> void:
	_picked.clear()
	var saved: Dictionary = data.get("picked", {})
	for key in saved:
		var v := float(saved[key])
		_picked[String(key)] = INF if v < 0.0 else v
