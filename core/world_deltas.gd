## Everything about the world that differs from how the regions were authored:
## picked forage, container contents and per-region values (a broken door, a
## moved chair). Saved by SaveSystem.
##
## Respawn times are absolute in-game days (Clock.day - 1 + time_of_day).
extends Node

var _picked: Dictionary = {}      # region_id -> {instance_key: respawn_at_day}
var _containers: Dictionary = {}  # container_id -> Dictionary
var _region_values: Dictionary = {}  # region_id -> {key: value}


static func now_days() -> float:
	return float(Clock.day - 1) + Clock.time_of_day


## Marks a scatter instance as picked. respawn_days <= 0 means never respawns.
func mark_picked(region_id: StringName, instance_key: String, respawn_days: float) -> void:
	var region := String(region_id)
	if not _picked.has(region):
		_picked[region] = {}
	_picked[region][instance_key] = now_days() + respawn_days if respawn_days > 0.0 else -1.0


func is_picked(region_id: StringName, instance_key: String) -> bool:
	var region: Dictionary = _picked.get(String(region_id), {})
	if not region.has(instance_key):
		return false
	var respawn_at := float(region[instance_key])
	if respawn_at >= 0.0 and now_days() >= respawn_at:
		region.erase(instance_key)
		return false
	return true


func picked_in(region_id: StringName) -> PackedStringArray:
	var keys := PackedStringArray()
	for key in _picked.get(String(region_id), {}).keys():
		if is_picked(region_id, key):
			keys.append(key)
	return keys


func set_container(container_id: String, contents: Dictionary) -> void:
	_containers[container_id] = contents.duplicate(true)


func get_container(container_id: String, default: Dictionary = {}) -> Dictionary:
	return _containers.get(container_id, default).duplicate(true)


func has_container(container_id: String) -> bool:
	return _containers.has(container_id)


func set_region_value(region_id: StringName, key: String, value: Variant) -> void:
	var region := String(region_id)
	if not _region_values.has(region):
		_region_values[region] = {}
	_region_values[region][key] = value


func get_region_value(region_id: StringName, key: String, default: Variant = null) -> Variant:
	return _region_values.get(String(region_id), {}).get(key, default)


func clear() -> void:
	_picked.clear()
	_containers.clear()
	_region_values.clear()


func to_dict() -> Dictionary:
	return {
		"picked": _picked.duplicate(true),
		"containers": _containers.duplicate(true),
		"region_values": _region_values.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	clear()
	_picked = (data.get("picked", {}) as Dictionary).duplicate(true)
	_containers = (data.get("containers", {}) as Dictionary).duplicate(true)
	_region_values = (data.get("region_values", {}) as Dictionary).duplicate(true)
