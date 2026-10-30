## A usable station: kitchen range, stillroom bench, easel, bath, bed, mirror...
class_name ManorStationDef
extends Resource

@export var station_id: StringName
@export var display_name: String
@export var level: int = 0
## World XZ position; y is above the level's floor.
@export var position: Vector3
@export var yaw_deg: float = 0.0
## PropLib id for its look.
@export var prop_id: StringName
@export var canon: String = "X"
