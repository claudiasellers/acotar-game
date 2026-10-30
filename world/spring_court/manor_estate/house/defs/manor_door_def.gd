## An opening between two rooms (or a room and outside) on one level.
##
## `at` is the world XZ point on the shared wall line; the builder cuts the
## opening into every room wall that passes through it.
class_name ManorDoorDef
extends Resource

@export var level: int = 0
@export var at: Vector2
@export var width: float = 1.6
@export var height: float = 2.8
## open (archway), door (open doorway with frame), locked (opens when
## requires_flag is set), secret (looks like wall/bookcase/panel; opens when
## fact.manor.secret_<secret_id> is raised), gate (opens with region `region_id`).
@export var kind: StringName = &"door"
@export var requires_flag: String
@export var secret_id: StringName
@export var region_id: StringName
## Look of a secret or locked leaf: wall, bookcase, panel, fireplace, mirror, door.
@export var disguise: StringName = &"door"
@export_multiline var notes: String
