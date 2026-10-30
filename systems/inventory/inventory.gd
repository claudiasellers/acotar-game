## Feyre's weight-class inventory (root doc §4.6): quiver, satchel, forage
## pouch, keepsakes and sketchbook, plus coin.
##
## Items are routed by kind and weight class: arrows to the quiver, keepsakes
## (col_*) to the keepsakes pouch, tiny and small ingredients to the forage
## pouch (spilling into the satchel when it is full), everything else to the
## satchel. Cooked dishes live in the satchel as their own entries.
class_name Inventory
extends RefCounted

signal changed
signal item_added(item_id: StringName, count: int, container: StringName)

const QUIVER := &"quiver"
const SATCHEL := &"satchel"
const POUCH := &"forage_pouch"
const KEEPSAKES := &"keepsakes"

## Weight units each container holds (quiver counts arrows, keepsakes count items).
const CAPACITY := {QUIVER: 30.0, SATCHEL: 40.0, POUCH: 12.0, KEEPSAKES: 60.0}
## Total carried weight units before Feyre slows down, and the floor.
const ENCUMBRANCE_START := 30.0
const ENCUMBRANCE_FULL := 60.0
const MIN_SPEED_MULTIPLIER := 0.7

var coin: int = 0
## container -> {item_id: count}
var _contents: Dictionary = {QUIVER: {}, SATCHEL: {}, POUCH: {}, KEEPSAKES: {}}
## Cooked results: Array of Dictionary (see Chemistry.combine).
var dishes: Array[Dictionary] = []


## Adds up to `count` of an item and returns how many fit.
func add(item_id: StringName, count: int = 1) -> int:
	item_id = ItemCatalog.canonical(item_id)
	var item := ItemCatalog.get_item(item_id)
	var added := 0
	for i in count:
		var container := _route(item_id, item)
		if container == &"":
			break
		var bucket: Dictionary = _contents[container]
		bucket[item_id] = int(bucket.get(item_id, 0)) + 1
		added += 1
	if added > 0:
		item_added.emit(item_id, added, container_of(item_id))
		Gameplay.emit(&"item_acquired", [item_id, added])
		changed.emit()
	return added


## Removes up to `count` (from the pouch first, then the satchel) and returns
## how many were removed.
func remove(item_id: StringName, count: int = 1) -> int:
	item_id = ItemCatalog.canonical(item_id)
	var removed := 0
	for container: StringName in [QUIVER, POUCH, SATCHEL, KEEPSAKES]:
		var bucket: Dictionary = _contents[container]
		while removed < count and int(bucket.get(item_id, 0)) > 0:
			bucket[item_id] = int(bucket[item_id]) - 1
			if bucket[item_id] == 0:
				bucket.erase(item_id)
			removed += 1
	if removed > 0:
		changed.emit()
	return removed


func count(item_id: StringName) -> int:
	item_id = ItemCatalog.canonical(item_id)
	var total := 0
	for container: StringName in _contents:
		total += int(_contents[container].get(item_id, 0))
	return total


func has(item_id: StringName, amount: int = 1) -> bool:
	return count(item_id) >= amount


## Item ids carrying a craft tag ("fletching"), most plentiful first.
func ids_with_craft_tag(tag: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for container: StringName in _contents:
		for id: StringName in _contents[container]:
			var item := ItemCatalog.get_item(id)
			if item and item.has_craft_tag(tag) and not out.has(id):
				out.append(id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return count(a) > count(b))
	return out


func contents(container: StringName) -> Dictionary:
	return (_contents[container] as Dictionary).duplicate()


func container_of(item_id: StringName) -> StringName:
	for container: StringName in _contents:
		if _contents[container].has(item_id):
			return container
	return &""


func used(container: StringName) -> float:
	var total := 0.0
	for id: StringName in _contents[container]:
		total += _units(id, container) * int(_contents[container][id])
	return total


func free_space(container: StringName) -> float:
	return float(CAPACITY[container]) - used(container)


## Everything carried, in weight units (quiver and keepsakes are light).
func total_weight() -> float:
	var total := 0.0
	for container: StringName in [SATCHEL, POUCH]:
		total += used(container)
	return total + dishes.size() * 1.0


## 1.0 when lightly loaded, falling to MIN_SPEED_MULTIPLIER when overloaded.
func speed_multiplier() -> float:
	var t := clampf((total_weight() - ENCUMBRANCE_START) / (ENCUMBRANCE_FULL - ENCUMBRANCE_START), 0.0, 1.0)
	return lerpf(1.0, MIN_SPEED_MULTIPLIER, t)


# --- Arrows -----------------------------------------------------------------

func arrow_count(arrow_item_id: StringName = &"") -> int:
	if arrow_item_id != &"":
		return int(_contents[QUIVER].get(arrow_item_id, 0))
	var total := 0
	for id: StringName in _contents[QUIVER]:
		total += int(_contents[QUIVER][id])
	return total


# --- Dishes -----------------------------------------------------------------

func add_dish(result: Dictionary) -> bool:
	if free_space(SATCHEL) < 1.0:
		return false
	dishes.append(result.duplicate(true))
	changed.emit()
	return true


func take_dish(index: int) -> Dictionary:
	if index < 0 or index >= dishes.size():
		return {}
	var dish: Dictionary = dishes.pop_at(index)
	changed.emit()
	return dish


# --- Market -----------------------------------------------------------------

## Sells `count` at the item's base price times `price_factor`. Returns coin earned.
func sell(item_id: StringName, amount: int = 1, price_factor: float = 1.0) -> int:
	item_id = ItemCatalog.canonical(item_id)
	var item := ItemCatalog.get_item(item_id)
	var price := roundi((item.base_price if item else 0) * price_factor)
	if price <= 0:
		return 0
	var removed := remove(item_id, amount)
	var earned := removed * price
	if removed > 0:
		coin += earned
		Gameplay.emit(&"item_sold", [item_id, earned])
		changed.emit()
	return earned


## Buys if Feyre has the coin and the room. Returns true on success.
func buy(item_id: StringName, price: int) -> bool:
	if coin < price:
		return false
	if add(item_id, 1) == 0:
		return false
	coin -= price
	changed.emit()
	return true


# --- Save -------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"coin": coin, "contents": _contents.duplicate(true), "dishes": dishes.duplicate(true)}


func load_state(data: Dictionary) -> void:
	coin = int(data.get("coin", 0))
	_contents = {QUIVER: {}, SATCHEL: {}, POUCH: {}, KEEPSAKES: {}}
	var saved: Dictionary = data.get("contents", {})
	for container in saved:
		var key := StringName(container)
		if not _contents.has(key):
			continue
		for id in saved[container]:
			_contents[key][StringName(id)] = int(saved[container][id])
	dishes.clear()
	for dish in data.get("dishes", []):
		dishes.append(dish)
	changed.emit()


# --- Routing ----------------------------------------------------------------

func _route(item_id: StringName, item: ItemData) -> StringName:
	var preferred := _preferred(item_id, item)
	if free_space(preferred) >= _units(item_id, preferred):
		return preferred
	if preferred == POUCH and free_space(SATCHEL) >= _units(item_id, SATCHEL):
		return SATCHEL
	return &""


func _preferred(item_id: StringName, item: ItemData) -> StringName:
	var id := String(item_id)
	if id.begins_with("arrow_"):
		return QUIVER
	if id.begins_with("col_"):
		return KEEPSAKES
	if item is IngredientData and item.weight_class <= ItemData.WeightClass.SMALL:
		return POUCH
	return SATCHEL


func _units(item_id: StringName, container: StringName) -> float:
	if container == QUIVER or container == KEEPSAKES:
		return 1.0
	var item := ItemCatalog.get_item(item_id)
	return item.weight_units() if item else 1.0
