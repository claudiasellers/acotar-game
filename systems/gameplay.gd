## Holds the player's gameplay state (inventory, journal, sketchbook, food
## tally, wardrobe) without an extra autoload, and connects it to the story
## lane's SaveSystem and EventBus when those interfaces exist.
##
## Systems never reference each other's nodes; they share state here and talk
## to the story through EventBus signals.
class_name Gameplay
extends RefCounted

static var inventory: Inventory = Inventory.new()
static var journal: ProofJournal = ProofJournal.new()
static var sketchbook: Sketchbook = Sketchbook.new()
static var food_tally: FamilyLarder = FamilyLarder.new()
static var wardrobe: Wardrobe = Wardrobe.new()
static var forage: ForageRegistry = ForageRegistry.new()

static var _registered: bool = false


## Fresh state (new game, tests).
static func reset() -> void:
	inventory = Inventory.new()
	journal = ProofJournal.new()
	sketchbook = Sketchbook.new()
	food_tally = FamilyLarder.new()
	wardrobe = Wardrobe.new()
	forage = ForageRegistry.new()
	_registered = false
	register_save_providers()


## Registers each state object with SaveSystem.register_provider (story lane
## interface). Safe to call repeatedly and before that interface exists.
static func register_save_providers() -> void:
	if _registered:
		return
	var save := _autoload(&"SaveSystem")
	if save == null or not save.has_method(&"register_provider"):
		return
	save.register_provider("inventory", inventory)
	save.register_provider("proof_journal", journal)
	save.register_provider("sketchbook", sketchbook)
	save.register_provider("food_tally", food_tally)
	save.register_provider("wardrobe", wardrobe)
	save.register_provider("forage", forage)
	_registered = true


## Emits an EventBus signal only if it is declared (story lane adds them).
static func emit(signal_name: StringName, args: Array = []) -> void:
	var bus := _autoload(&"EventBus")
	if bus == null or not bus.has_signal(signal_name):
		return
	bus.callv(&"emit_signal", [signal_name] + args)


## Connects to an EventBus signal if it is declared.
static func listen(signal_name: StringName, callable: Callable) -> void:
	var bus := _autoload(&"EventBus")
	if bus and bus.has_signal(signal_name) and not bus.is_connected(signal_name, callable):
		bus.connect(signal_name, callable)


## An autoload by name, or null (keeps this file free of hard references to
## autoloads other lanes are still adding).
static func autoload(autoload_name: StringName) -> Node:
	return _autoload(autoload_name)


static func _autoload(autoload_name: StringName) -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null(NodePath(String(autoload_name)))
