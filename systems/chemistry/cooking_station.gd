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

## Steep strongest tag -> steeped arrow item (docs/GAMEPLAY_M2.md item 2).
const STEEP_ARROWS := {
	&"quiet": &"arrow_sleep", &"warm": &"arrow_fire", &"cool": &"arrow_frost", &"bright": &"arrow_light",
}
const LURE_ARROW := &"arrow_lure"
## Wood arrows one steep can coat.
const ARROWS_PER_STEEP := 5

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


## Why the station can't be used right now, or "" when it can.
func unavailable_reason() -> String:
	if station == null:
		return "nothing here"
	if station.night_only:
		var clock := Gameplay.autoload(&"Clock")
		if clock and not clock.call(&"is_night"):
			return "it only answers at night"
	if station.required_flag != "":
		var state := Gameplay.autoload(&"WorldState")
		if state and not state.call(&"has_flag", station.required_flag):
			return "not yet"
	return ""


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
	var blocked := unavailable_reason()
	if blocked != "":
		return {"ok": false, "reason": blocked}
	var result := Chemistry.combine(ingredients, station, method)
	if not result.ok:
		return result
	if method == &"steep":
		return _steep_arrows(result, ingredients, needed)
	for id: StringName in needed:
		Gameplay.inventory.remove(id, int(needed[id]))
	var first := Gameplay.journal.record(result, ingredients)
	result["first_time"] = first
	if result.kind == &"pigment":
		# One cake of paint per pigment ingredient used.
		for i in ingredients:
			if i.pigment != &"":
				Gameplay.inventory.add(StringName("pig_%s" % i.pigment))
	else:
		Gameplay.inventory.add_dish(result)
	Juice.burst(self, &"unlock" if first else &"craft")
	cooked.emit(result)
	return result


## The steeped arrow type a steep result makes.
static func steeped_arrow_for(result: Dictionary) -> StringName:
	var effects: Dictionary = result.get("effects", {})
	var best := &""
	var best_v := 0.0
	for tag: StringName in STEEP_ARROWS:
		var v := float(effects.get(tag, 0.0))
		if v > best_v:
			best_v = v
			best = tag
	if best != &"":
		return STEEP_ARROWS[best]
	if float(result.get("fae_toll", 0.0)) > 0.0 or float(result.get("heal", 0.0)) > 0.0:
		return LURE_ARROW
	return &""


func _steep_arrows(result: Dictionary, ingredients: Array[IngredientData], needed: Dictionary) -> Dictionary:
	var arrow := steeped_arrow_for(result)
	if arrow == &"":
		return {"ok": false, "reason": "the steep has nothing in it to carry"}
	var count := mini(Gameplay.inventory.arrow_count(&"arrow_wood"), ARROWS_PER_STEEP)
	if count == 0:
		return {"ok": false, "reason": "no wood arrows to steep"}
	for id: StringName in needed:
		Gameplay.inventory.remove(id, int(needed[id]))
	Gameplay.inventory.remove(&"arrow_wood", count)
	Gameplay.inventory.add(arrow, count)
	var first := Gameplay.journal.record(result, ingredients)
	result["first_time"] = first
	result["arrows"] = {"item_id": arrow, "count": count}
	result["name"] = "%s (%d)" % [ItemCatalog.get_item(arrow).display_name, count]
	Juice.burst(self, &"unlock" if first else &"craft")
	cooked.emit(result)
	return result
