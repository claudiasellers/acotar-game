## The sketchbook: Feyre's first-person narration as images (root doc §4.7).
class_name Sketchbook
extends RefCounted

signal sketch_added(sketch_id: StringName, title: String)

## id -> {"title", "day", "time_of_day"}
var sketches: Dictionary = {}
var order: Array[StringName] = []


func add(sketch_id: StringName, title: String) -> bool:
	if sketches.has(sketch_id):
		return false
	var clock := Gameplay.autoload(&"Clock")
	sketches[sketch_id] = {
		"title": title,
		"day": int(clock.get(&"day")) if clock else 0,
		"time_of_day": float(clock.get(&"time_of_day")) if clock else 0.0,
	}
	order.append(sketch_id)
	sketch_added.emit(sketch_id, title)
	Gameplay.emit(&"sketch_added", [sketch_id])
	return true


func has(sketch_id: StringName) -> bool:
	return sketches.has(sketch_id)


func count() -> int:
	return sketches.size()


func save_state() -> Dictionary:
	return {"sketches": sketches.duplicate(true), "order": order.map(func(s: StringName) -> String: return String(s))}


func load_state(data: Dictionary) -> void:
	sketches.clear()
	var saved: Dictionary = data.get("sketches", {})
	for key in saved:
		sketches[StringName(key)] = saved[key]
	order.clear()
	for id in data.get("order", []):
		order.append(StringName(id))
