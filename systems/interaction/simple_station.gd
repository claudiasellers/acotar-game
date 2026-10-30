## A usable thing with no logic of its own (a wardrobe, a mirror, a bed):
## Feyre's Interactor routes by station_id. Shared station shape.
class_name SimpleStation
extends StaticBody3D

signal used(station_id: StringName)

@export var station_id: StringName


func _ready() -> void:
	add_to_group(&"station")


func use(_user: Node) -> void:
	used.emit(station_id)
