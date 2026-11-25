## A MultiMesh of one ingredient (or keepsake) whose instances can be picked.
##
## World lanes can use this directly, or set meta "ingredient_id" on their own
## MultiMeshInstance3D and call ForageScatter.pick_from() on it. Picked
## instances shrink to nothing until they respawn on the clock.
class_name ForageScatter
extends MultiMeshInstance3D

const GROUP := &"forage_field"

@export var item_id: StringName
## Region the scatter belongs to, for picked-state bookkeeping.
@export var region_id: StringName = &"test"


func _ready() -> void:
	add_to_group(GROUP)
	set_meta(&"ingredient_id", item_id)
	refresh()
	var bus := Gameplay.autoload(&"EventBus")
	if bus and bus.has_signal(&"day_started"):
		bus.connect(&"day_started", func(_d: int) -> void: refresh())
	var item := ItemCatalog.get_item(item_id)
	if item and (item.bound != &"" or (item is IngredientData and (item as IngredientData).night_only)):
		# Rare, windowed finds only show while their window is open.
		var timer := Timer.new()
		timer.wait_time = 4.0
		timer.autostart = true
		timer.timeout.connect(_update_window.bind(item))
		add_child(timer)
		_update_window(item)


func _update_window(item: ItemData) -> void:
	var now := ForageRegistry.current_conditions(get_tree())
	visible = ForageRegistry.in_window(item, now.hour, now.weather)


## Picks the nearest unpicked instance within `radius` and returns its item id
## (empty when nothing is in reach). Same signature as the world lanes' fields.
func pick_nearest(world_pos: Vector3, radius: float) -> StringName:
	return ForageScatter.pick_from(self, world_pos, radius)


## Shows instances whose respawn time has passed and hides picked ones.
func refresh() -> void:
	ForageScatter.refresh_field(self)


static func respawn_days_for(id: StringName) -> float:
	var item := ItemCatalog.get_item(id)
	if item is IngredientData:
		return (item as IngredientData).respawn_days
	if item is CollectibleData:
		return (item as CollectibleData).respawn_days
	return 2.0


## Works on any MultiMeshInstance3D with meta "ingredient_id": finds and
## takes the nearest unpicked instance in one go.
static func pick_from(field: MultiMeshInstance3D, world_pos: Vector3, radius: float) -> StringName:
	var index := nearest_unpicked(field, world_pos, radius)
	return take(field, index) if index >= 0 else &""


## The nearest instance within `radius` that is unpicked and in its window
## (-1 when none). Changes nothing, so the caller can check her bags first.
static func nearest_unpicked(field: MultiMeshInstance3D, world_pos: Vector3, radius: float) -> int:
	var mm := field.multimesh
	if mm == null:
		return -1
	var id := StringName(field.get_meta(&"ingredient_id", &""))
	if id == &"":
		return -1
	var region := _region(field)
	var local := field.global_transform.affine_inverse() * world_pos
	var best := -1
	var best_d := radius
	for i in mm.instance_count:
		if Gameplay.forage.is_picked(region, "%s:%d" % [field.name, i]):
			continue
		var d := mm.get_instance_transform(i).origin.distance_to(local)
		if d <= best_d:
			best_d = d
			best = i
	if best < 0:
		return -1
	var item := ItemCatalog.get_item(id)
	var now := ForageRegistry.current_conditions(field.get_tree())
	if not ForageRegistry.in_window(item, now.hour, now.weather):
		return -1
	return best


## Marks instance `index` picked, hides it and returns its item id.
static func take(field: MultiMeshInstance3D, index: int) -> StringName:
	var id := StringName(field.get_meta(&"ingredient_id", &""))
	Gameplay.forage.mark_picked(_region(field), "%s:%d" % [field.name, index], respawn_days_for(id))
	_hide(field, index)
	return id


static func _region(field: Node) -> StringName:
	return StringName(field.get(&"region_id")) if &"region_id" in field else &"world"


static func refresh_field(field: MultiMeshInstance3D) -> void:
	var mm := field.multimesh
	if mm == null:
		return
	var region := _region(field)
	var originals: Dictionary = field.get_meta(&"_forage_original", {})
	for i in mm.instance_count:
		var picked := Gameplay.forage.is_picked(region, "%s:%d" % [field.name, i])
		if picked and not originals.has(i):
			_hide(field, i)
		elif not picked and originals.has(i):
			mm.set_instance_transform(i, originals[i])
			originals.erase(i)
	field.set_meta(&"_forage_original", originals)


static func _hide(field: MultiMeshInstance3D, i: int) -> void:
	var originals: Dictionary = field.get_meta(&"_forage_original", {})
	var t := field.multimesh.get_instance_transform(i)
	if not originals.has(i):
		originals[i] = t
	field.set_meta(&"_forage_original", originals)
	field.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), t.origin))
