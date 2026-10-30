## The four quick slots at the bottom of the screen. Each holds a satchel entry
## id (an arrow type, something edible, or a cooked dish). The first time
## Feyre picks up something usable it drops into the first empty slot; once
## the player moves or clears it, it's theirs to place.
##
## One bar per Inventory: QuickBar.current() follows Gameplay.inventory, so a
## new game (Gameplay.reset) starts with an empty bar.
class_name QuickBar
extends RefCounted

signal changed
signal used(slot: int, id: StringName)
signal pinned(slot: int, id: StringName)

const SLOTS := 4
const SAVE_KEY := "quick_bar"

static var _current: QuickBar = null

var inventory: Inventory
var slots: Array[StringName] = []
## Ids that have been auto-placed once (never auto-placed again).
var _seen: Dictionary = {}


## The bar for the current game's inventory (rebinds after Gameplay.reset).
static func current() -> QuickBar:
	if _current == null:
		_current = QuickBar.new(Gameplay.inventory)
	elif _current.inventory != Gameplay.inventory:
		_current.bind(Gameplay.inventory)
	return _current


func _init(inv: Inventory = null) -> void:
	bind(inv if inv else Inventory.new())


func bind(inv: Inventory) -> void:
	if inventory and inventory.item_added.is_connected(_on_added):
		inventory.item_added.disconnect(_on_added)
		inventory.changed.disconnect(_on_changed)
	inventory = inv
	slots.clear()
	slots.resize(SLOTS)
	slots.fill(&"")
	_seen.clear()
	inventory.item_added.connect(_on_added)
	inventory.changed.connect(_on_changed)
	_fill_from_contents()
	changed.emit()


## Puts an entry in a slot (moving it if it was pinned elsewhere). False when
## it can't be used from the bar.
func pin(slot: int, id: StringName) -> bool:
	if slot < 0 or slot >= SLOTS or not SatchelUse.can_pin(id):
		return false
	var was := slots.find(id)
	if was >= 0:
		slots[was] = slots[slot] if was != slot else id
	slots[slot] = id
	_seen[id] = true
	changed.emit()
	pinned.emit(slot, id)
	return true


func clear(slot: int) -> void:
	if slot >= 0 and slot < SLOTS and slots[slot] != &"":
		slots[slot] = &""
		changed.emit()


## The slot `id` sits in, or -1.
func slot_of(id: StringName) -> int:
	return slots.find(id)


func entry(slot: int) -> StringName:
	return slots[slot] if slot >= 0 and slot < SLOTS else &""


func count(slot: int) -> int:
	var id := entry(slot)
	return SatchelEntries.count(inventory, id) if id != &"" else 0


## Next slot for "pin" on a pad: the slot after where it sits now, else the
## first empty one, else the first.
func next_slot_for(id: StringName) -> int:
	var at := slot_of(id)
	if at >= 0:
		return (at + 1) % SLOTS
	var empty := slots.find(&"")
	return empty if empty >= 0 else 0


## Uses the entry in a slot on `who` (Feyre). Empty slots keep their pin.
func use(slot: int, who: Object) -> bool:
	var id := entry(slot)
	if id == &"" or not SatchelUse.use(inventory, id, who):
		return false
	used.emit(slot, id)
	return true


func save_state() -> Dictionary:
	var seen: Array[String] = []
	for id: StringName in _seen:
		seen.append(String(id))
	return {"slots": slots.map(func(s: StringName) -> String: return String(s)), "seen": seen}


func load_state(data: Dictionary) -> void:
	slots.fill(&"")
	var saved: Array = data.get("slots", [])
	for i in mini(saved.size(), SLOTS):
		slots[i] = StringName(saved[i])
	_seen.clear()
	for id in data.get("seen", []):
		_seen[StringName(id)] = true
	changed.emit()


func _auto_place(id: StringName) -> void:
	if _seen.has(id) or not SatchelUse.can_pin(id) or slots.has(id):
		return
	_seen[id] = true
	var empty := slots.find(&"")
	if empty < 0:
		return
	slots[empty] = id
	changed.emit()
	pinned.emit(empty, id)


## A bar that starts on an inventory already carrying things (a fresh game's
## kit) fills from it: arrows, then dishes, then food.
func _fill_from_contents() -> void:
	for id: StringName in inventory.contents(Inventory.QUIVER):
		_auto_place(id)
	for dish in inventory.dishes:
		_auto_place(SatchelEntries.dish_id(dish))
	for pocket: StringName in [Inventory.POUCH, Inventory.SATCHEL]:
		for id: StringName in inventory.contents(pocket):
			_auto_place(id)


func _on_added(id: StringName, _count: int, _container: StringName) -> void:
	_auto_place(id)


## Dishes arrive through Inventory.add_dish, which only emits `changed`.
func _on_changed() -> void:
	for dish in inventory.dishes:
		_auto_place(SatchelEntries.dish_id(dish))
	changed.emit()
