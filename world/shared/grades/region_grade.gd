## Put one in a region scene to give it its own grade (the per-region LUT
## slot). GradeDirector blends to `grade` while Feyre is inside `bounds`, unless
## a story swap is holding a grade.
class_name RegionGrade
extends Node

const GROUP := &"region_grade"

@export var grade: StringName = &"spring"
## XZ rectangle in world coordinates.
@export var bounds: Rect2
## The exact XZ rectangles the region owns, when its shape isn't one box (the
## Blighted Reaches is an L whose bounding box swallows the solstice plateau
## and the hill). Empty = use `bounds`.
@export var rects: Array[Rect2] = []
## Rectangles inside `rects` that belong to someone else.
@export var holes: Array[Rect2] = []
@export var blend_seconds := 4.0
## How long the blend takes on the way out of here; 0 uses the next area's.
@export var leave_seconds := 0.0


func _ready() -> void:
	add_to_group(GROUP)


func contains(world_pos: Vector3) -> bool:
	var p := Vector2(world_pos.x, world_pos.z)
	if rects.is_empty():
		return bounds.has_point(p)
	for h in holes:
		if h.has_point(p):
			return false
	for r in rects:
		if r.has_point(p):
			return true
	return false
