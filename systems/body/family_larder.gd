## The family's food, counted in days (the larder behind the cottage's tally). The
## story lane listens to food_stock_changed and raises food_secured through an
## ActionTrigger once it is high enough.
class_name FamilyLarder
extends RefCounted

signal stock_changed(days_of_food: float)

## Family-days eaten per in-game day.
const DAILY_NEED := 1.0

var days_of_food: float = 1.5


func add_days(days: float) -> void:
	if days <= 0.0:
		return
	days_of_food += days
	_announce()


## Gives an item from the inventory to the family. Returns days added.
func give_item(item_id: StringName, inventory: Inventory, amount: int = 1) -> float:
	var item := ItemCatalog.get_item(item_id) as IngredientData
	if item == null or item.food_days <= 0.0:
		return 0.0
	var removed := inventory.remove(item_id, amount)
	var days := item.food_days * removed
	add_days(days)
	return days


## Gives a cooked dish (Chemistry.combine result). Returns days added.
func give_dish(result: Dictionary) -> float:
	var days := float(result.get("food_days", 0.0))
	add_days(days)
	return days


## One day passes: the family eats.
func consume_day() -> void:
	days_of_food = maxf(days_of_food - DAILY_NEED, 0.0)
	_announce()


func _announce() -> void:
	stock_changed.emit(days_of_food)
	Gameplay.emit(&"food_stock_changed", [days_of_food])


func save_state() -> Dictionary:
	return {"days_of_food": days_of_food}


func load_state(data: Dictionary) -> void:
	days_of_food = float(data.get("days_of_food", 1.5))
