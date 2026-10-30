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


## Whether an item's window (ItemData.bound) is open at this hour (0-24) and
## weather (&"rain", &"snow" or &"clear"). Region lanes gate rare spawns with it.
static func in_window(item: ItemData, hour: float, weather: StringName = &"clear") -> bool:
	if item == null:
		return true
	var bound := item.bound
	if item is IngredientData and (item as IngredientData).night_only:
		bound = &"night"
	match bound:
		&"dawn":
			return hour >= 4.5 and hour < 7.5
		&"dusk":
			return hour >= 18.0 and hour < 21.0
		&"night":
			return hour >= 20.5 or hour < 5.5
		&"mist":
			return hour >= 4.0 and hour < 9.0
		&"rain":
			return weather == &"rain"
		&"snow":
			return weather == &"snow"
	return true


## The current hour and weather, for in_window.
static func current_conditions(tree: SceneTree) -> Dictionary:
	var clock := Gameplay.autoload(&"Clock")
	var hour := float(clock.call(&"hour")) if clock and clock.has_method(&"hour") else 12.0
	var weather := &"clear"
	var w := Weather.find(tree) if tree else null
	if w and w.precipitation > 0.2:
		weather = w.precipitation_kind
	return {"hour": hour, "weather": weather}


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
