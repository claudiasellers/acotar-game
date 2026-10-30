## The proof journal: every distinct combination Feyre has made, recorded once,
## and which tags she has learned for each ingredient by using it (discovery,
## not a tooltip).
class_name ProofJournal
extends RefCounted

signal discovered(entry: Dictionary)

## key -> entry
var entries: Dictionary = {}
## ingredient id -> Array of learned tag names
var learned_tags: Dictionary = {}
var order: Array[String] = []


## Records a successful result. Returns true the first time it is made.
func record(result: Dictionary, ingredients: Array[IngredientData] = []) -> bool:
	if not result.get("ok", false):
		return false
	for i in ingredients:
		var known: Array = learned_tags.get(String(i.id), [])
		for tag in i.tags:
			if not known.has(String(tag)):
				known.append(String(tag))
		learned_tags[String(i.id)] = known
	var key := String(result.key)
	if entries.has(key):
		entries[key]["times"] = int(entries[key]["times"]) + 1
		return false
	var clock := Gameplay.autoload(&"Clock")
	var entry := {
		"key": key, "name": result.name, "method": String(result.method),
		"ingredients": (result.ingredients as Array).map(func(id: Variant) -> String: return String(id)),
		"effects": result.effects, "kind": String(result.kind),
		"day": int(clock.get(&"day")) if clock else 0, "times": 1,
	}
	entries[key] = entry
	order.append(key)
	discovered.emit(entry)
	Gameplay.emit(&"recipe_discovered", [key])
	return true


func has(key: String) -> bool:
	return entries.has(key)


func count() -> int:
	return entries.size()


func known_tags(ingredient_id: StringName) -> Array:
	return learned_tags.get(String(ingredient_id), [])


func save_state() -> Dictionary:
	return {"entries": entries.duplicate(true), "learned_tags": learned_tags.duplicate(true), "order": order.duplicate()}


func load_state(data: Dictionary) -> void:
	entries = (data.get("entries", {}) as Dictionary).duplicate(true)
	learned_tags = (data.get("learned_tags", {}) as Dictionary).duplicate(true)
	order.clear()
	for key in data.get("order", []):
		order.append(String(key))
