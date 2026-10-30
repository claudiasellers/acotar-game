## Put one in a region scene to give it its own grade (the per-region LUT
## slot). GradeDirector blends to `grade` while Feyre is inside `bounds`, unless
## a story swap is holding a grade.
class_name RegionGrade
extends Node

const GROUP := &"region_grade"

@export var grade: StringName = &"spring"
## XZ rectangle in world coordinates.
@export var bounds: Rect2
@export var blend_seconds := 4.0


func _ready() -> void:
	add_to_group(GROUP)


func contains(world_pos: Vector3) -> bool:
	return bounds.has_point(Vector2(world_pos.x, world_pos.z))
