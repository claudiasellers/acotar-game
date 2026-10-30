## P0's gate: the food tally scratched on the cottage beam (lore:
## archeron-cottage.md [X]). The systems lane counts the family's food and
## announces it; one notch per day of food shows on the beam. When the
## larder holds `secure_days`, Feyre looks at the tally and food_secured rises.
class_name FoodTally
extends DeedMoment

@export var secure_days: float = 7.0
@export var max_notches: int = 14

var days_of_food: float = 0.0
var _notches: Node3D


func _init() -> void:
	space_id = &"food_tally"
	deed_flag = "food_secured"
	done_flags = PackedStringArray(["food_secured"])
	look_seconds = 2.0


func _ready() -> void:
	super._ready()
	EventBus.food_stock_changed.connect(_on_food_stock_changed)
	_notches = Node3D.new()
	_notches.name = "Notches"
	add_child(_notches)


func notch_count() -> int:
	return clampi(floori(days_of_food), 0, max_notches)


func _on_food_stock_changed(days: float) -> void:
	days_of_food = days
	_draw_notches()
	if days_of_food >= secure_days:
		trigger()


func _draw_notches() -> void:
	for child in _notches.get_children():
		child.queue_free()
	for i in notch_count():
		var notch := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.015, 0.12, 0.01)
		notch.mesh = box
		notch.position = Vector3(-0.2 + i * 0.03, 0.0, 0.0)
		_notches.add_child(notch)
