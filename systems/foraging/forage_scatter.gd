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


## Works on any MultiMeshInstance3D with meta "ingredient_id".
static func pick_from(field: MultiMeshInstance3D, world_pos: Vector3, radius: float) -> StringName:
	var mm := field.multimesh
	if mm == null:
		return &""
	var id := StringName(field.get_meta(&"ingredient_id", &""))
	if id == &"":
		return &""
	var region := StringName(field.get(&"region_id")) if &"region_id" in field else &"world"
	var local := field.global_transform.affine_inverse() * world_pos
	var best := -1
	var best_d := radius
	for i in mm.instance_count:
		var key := "%s:%d" % [field.name, i]
		if Gameplay.forage.is_picked(region, key):
			continue
		var d := mm.get_instance_transform(i).origin.distance_to(local)
		if d <= best_d:
			best_d = d
			best = i
	if best < 0:
		return &""
	var item := ItemCatalog.get_item(id)
	if item is IngredientData and (item as IngredientData).night_only:
		var clock := Gameplay.autoload(&"Clock")
		if clock and not clock.call(&"is_night"):
			return &""
	Gameplay.forage.mark_picked(region, "%s:%d" % [field.name, best], respawn_days_for(id))
	_hide(field, best)
	return id


static func refresh_field(field: MultiMeshInstance3D) -> void:
	var mm := field.multimesh
	if mm == null:
		return
	var region := StringName(field.get(&"region_id")) if &"region_id" in field else &"world"
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
