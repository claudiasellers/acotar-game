## Something Feyre can't stop looking at (root doc §4.7): a snowdrop in the
## snow, her sister's hands, a wilting rose. Place one in the world; the
## NoticeDirector on Feyre does the rest.
class_name NoticePoint
extends Node3D

const GROUP := &"notice_point"

@export var sketch_id: StringName
@export var title: String
## Metres within which the camera may drift toward it.
@export var radius: float = 14.0
## Seconds of holding the look before the sketch is made.
@export var look_seconds: float = 2.0
## Half-angle in degrees of the cone in which it can catch her eye.
@export var cone_degrees: float = 40.0


func _ready() -> void:
	add_to_group(GROUP)
