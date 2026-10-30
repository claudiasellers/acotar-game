## What using a quick-bar or satchel entry does. Arrows nock that arrow type,
## edible ingredients and cooked dishes are eaten; anything else can't be
## pinned or used from the bar.
class_name SatchelUse
extends RefCounted

const ARROW := &"arrow"
const FOOD := &"food"
const DISH := &"dish"


## &"arrow", &"food", &"dish", or &"" when the entry can't be used.
static func kind(id: StringName) -> StringName:
	if SatchelEntries.is_dish(id):
		return DISH
	var s := String(id)
	if s.begins_with("arrow_"):
		return ARROW
	var item := ItemCatalog.get_item(id)
	if item is IngredientData and (item as IngredientData).edible and (item as IngredientData).nutrition > 0.0:
		return FOOD
	return &""


static func can_pin(id: StringName) -> bool:
	return kind(id) != &""


## The verb the page and bar show for an entry.
static func verb(id: StringName) -> String:
	match kind(id):
		ARROW:
			return "Nock"
		FOOD, DISH:
			return "Eat"
	return ""


## Uses one. `who` is Feyre (or any node with body_state / bow_controller).
## Returns true when something happened.
static func use(inv: Inventory, id: StringName, who: Object) -> bool:
	if SatchelEntries.count(inv, id) <= 0:
		return false
	var body: BodyState = who.get(&"body_state") as BodyState if who else null
	match kind(id):
		ARROW:
			var bow: BowController = who.get(&"bow_controller") as BowController if who else null
			if bow == null:
				return false
			bow.selected = id
			bow.arrow_type_changed.emit(id)
			return true
		FOOD:
			if inv.remove(id, 1) == 0:
				return false
			if body:
				body.eat_raw(ItemCatalog.get_item(id) as IngredientData)
			return true
		DISH:
			var dish := inv.take_dish(SatchelEntries.dish_indices(inv, id)[0])
			if body:
				body.eat(dish)
			return true
	return false
