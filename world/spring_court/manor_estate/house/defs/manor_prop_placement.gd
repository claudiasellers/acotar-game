## One prop in a room: a PropLib id placed relative to the room.
class_name ManorPropPlacement
extends Resource

@export var prop_id: StringName
## Room-local metres: x and z from the room rect's min corner, y above the floor.
@export var position: Vector3
@export var yaw_deg: float = 0.0
@export var scale: float = 1.0
