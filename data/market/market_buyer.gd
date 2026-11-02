## Someone at the human village market who pays coin for Feyre's things
## (lane L53; Keeper, ch 3). Prices are the item's base_price times
## price_factor, never below one copper. Coin only: nobody here barters.
class_name MarketBuyer
extends Resource

@export var id: StringName
## As Feyre would name them ("the cobbler").
@export var display_name: String
## "C" canon, "A" adapted, "X" invented (R7).
@export var canon: String = "X"
## Exact item ids this buyer takes.
@export var buys: PackedStringArray = []
## Also takes any ingredient carrying one of these craft tags.
@export var buys_tags: PackedStringArray = []
## Never takes these, whatever the tags say.
@export var refuses: PackedStringArray = []
@export var price_factor: float = 1.0
## Said when Feyre steps up, when she sells, and when she has nothing they want.
@export var greeting: String = ""
@export var thanks: String = ""
@export var nothing: String = ""


func takes(item_id: StringName) -> bool:
	var id := String(ItemCatalog.canonical(item_id))
	if refuses.has(id):
		return false
	if buys.has(id):
		return true
	if buys_tags.is_empty():
		return false
	var item := ItemCatalog.get_item(StringName(id))
	if item == null or item.base_price <= 0 or not item is IngredientData:
		return false
	for t: StringName in (item as IngredientData).tags:
		if buys_tags.has(String(t)):
			return true
	return false


## Coppers paid for one.
func price(item_id: StringName) -> int:
	var item := ItemCatalog.get_item(ItemCatalog.canonical(item_id))
	if item == null or item.base_price <= 0:
		return 0
	return maxi(1, roundi(item.base_price * price_factor))


## What Feyre carries that this buyer would take: [{id, count, price}], by name.
func offers(inv: Inventory) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for e: Dictionary in SatchelEntries.list(inv):
		var id: StringName = e.id
		if seen.has(id) or SatchelEntries.is_dish(id) or not takes(id) or price(id) <= 0:
			continue
		seen[id] = true
		out.append({"id": id, "name": e.name, "count": inv.count(id), "price": price(id), "entry": e})
	return out
