## Where the studio's paint comes from (L30). Canon (Keeper, ch16/19): the
## painting room is stocked once the gallery is opened, "so, so many paints".
## Before that Feyre has charcoal from the hearth and the pigment cakes she
## made from forage [X]; each cake gives STROKES_PER_CAKE strokes.
class_name StudioSupply
extends RefCounted

const STROKES_PER_CAKE := 40
const CHARCOAL := &"studio_charcoal"
const MANOR_PREFIX := "manor:"
const STOCK_FLAG := "gallery_opened"
const MANOR_PAINTS: StudioPaintSet = preload("res://data/studio/manor_paints.tres")

## pigment item id -> strokes left in the cake already opened (this session)
static var charges: Dictionary = {}

var _inventory: Inventory


func _init(inventory: Inventory) -> void:
	_inventory = inventory


static func stocked() -> bool:
	return WorldState.has_flag(STOCK_FLAG)


## Every paint she can use now: {id, name, color, kind, left} (left -1 = plenty).
func paints() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"id": CHARCOAL, "name": "Charcoal", "color": Color(0.17, 0.15, 0.18),
			"kind": &"charcoal", "left": -1}]
	if stocked():
		for i in MANOR_PAINTS.size():
			out.append({"id": StringName(MANOR_PREFIX + str(i)), "name": MANOR_PAINTS.names[i],
					"color": MANOR_PAINTS.colors[i], "kind": &"manor", "left": -1})
	var seen := {}
	for id in _inventory.ids_with_craft_tag(&"pigment"):
		seen[id] = true
		out.append(_forage(id))
	for id: StringName in charges:
		if not seen.has(id) and int(charges[id]) > 0:
			out.append(_forage(id))
	return out


func left(id: StringName) -> int:
	if id == CHARCOAL or String(id).begins_with(MANOR_PREFIX):
		return -1 if (id == CHARCOAL or stocked()) else 0
	return int(charges.get(id, 0)) + _inventory.count(id) * STROKES_PER_CAKE


func color_of(id: StringName) -> Color:
	if id == CHARCOAL:
		return Color(0.17, 0.15, 0.18)
	if String(id).begins_with(MANOR_PREFIX):
		return MANOR_PAINTS.colors[int(String(id).trim_prefix(MANOR_PREFIX))]
	var item := ItemCatalog.get_item(id)
	return item.color if item else Color.BLACK


## Spends one stroke of a paint. False when there's none left.
func spend(id: StringName) -> bool:
	var l := left(id)
	if l < 0:
		return true
	if l == 0:
		return false
	if int(charges.get(id, 0)) <= 0:
		if _inventory.remove(id, 1) == 0:
			return false
		charges[id] = int(charges.get(id, 0)) + STROKES_PER_CAKE
	charges[id] = int(charges[id]) - 1
	return true


func _forage(id: StringName) -> Dictionary:
	var item := ItemCatalog.get_item(id)
	return {"id": id, "name": item.display_name if item else String(id), "color": color_of(id),
			"kind": &"forage", "left": left(id)}
