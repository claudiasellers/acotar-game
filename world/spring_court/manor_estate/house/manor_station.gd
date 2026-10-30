## A usable station (kitchen range, stillroom bench, easel, bath, bed, mirror...).
##
## Contract with the gameplay lane: group "station", `station_id`, `use(user)`.
## Gameplay UIs subscribe to `used` by group; use() itself stays light.
class_name ManorStation
extends Node3D

signal used(station_id: StringName)

const GROUP := &"station"

@export var station_id: StringName
@export var display_name: String


func _ready() -> void:
	add_to_group(GROUP)


func use(_user: Node = null) -> void:
	used.emit(station_id)
