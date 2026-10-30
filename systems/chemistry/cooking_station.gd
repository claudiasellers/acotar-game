## A hearth or campfire: a chemistry station, a heat source, and a light.
##
## Follows the shared station shape (group "station", station_id, use(user)).
class_name CookingStation
extends Node3D

signal used(station_id: StringName)
signal cooked(result: Dictionary)

const PANEL := preload("res://ui/hearth_panel.gd")

@export var station: StationData = preload("res://data/stations/hearth.tres")
## Warmth reaches this far, fading with distance.
@export var heat_radius: float = 5.0
@export var lit: bool = true

var station_id: StringName:
	get:
		return station.id if station else &""


func _ready() -> void:
	add_to_group(&"station")
	add_to_group(ElementState.HEAT_GROUP)


func heat_at(world_pos: Vector3) -> float:
	if not lit:
		return 0.0
	var d := global_position.distance_to(world_pos)
	return clampf(1.0 - d / heat_radius, 0.0, 1.0)


func use(user: Node) -> void:
	used.emit(station_id)
	if user is Feyre:
		PANEL.open(user as Feyre, self)


## Cooks from Gameplay.inventory. On success the ingredients are used up, the
## journal records it and the dish goes in the satchel.
func cook(ids: Array[StringName], method: StringName) -> Dictionary:
	var ingredients: Array[IngredientData] = []
	var needed := {}
	for id in ids:
		needed[id] = int(needed.get(id, 0)) + 1
		var item := ItemCatalog.get_item(id) as IngredientData
		if item == null:
			return {"ok": false, "reason": "%s can't be cooked" % id}
		ingredients.append(item)
	for id: StringName in needed:
		if Gameplay.inventory.count(id) < int(needed[id]):
			return {"ok": false, "reason": "not enough %s" % id}
	var result := Chemistry.combine(ingredients, station, method)
	if not result.ok:
		return result
	for id: StringName in needed:
		Gameplay.inventory.remove(id, int(needed[id]))
	var first := Gameplay.journal.record(result, ingredients)
	result["first_time"] = first
	Gameplay.inventory.add_dish(result)
	Juice.burst(self, &"unlock" if first else &"craft")
	cooked.emit(result)
	return result
