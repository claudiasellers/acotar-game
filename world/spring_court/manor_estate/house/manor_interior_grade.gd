## The grade inside the house: GI and a softer tone that only a closed room
## needs (T043). It sits ahead of the grounds' RegionGrade and covers the rooms
## by height too, so the lawn over a cellar stays outdoors.
class_name ManorInteriorGrade
extends RegionGrade

## Past a room's edge this far still counts, so walking through a wall's
## thickness or a stair's floor slab doesn't blend out and back.
const REACH := 0.7
const CHEST := Vector3.UP * 1.0


func _init() -> void:
	name = "ManorInteriorGrade"
	grade = &"manor_interior"
	blend_seconds = 1.0
	leave_seconds = 1.0


func contains(world_pos: Vector3) -> bool:
	for at in [world_pos, world_pos + CHEST]:
		for offset in [Vector3.ZERO, Vector3.RIGHT * REACH, Vector3.LEFT * REACH, Vector3.FORWARD * REACH, Vector3.BACK * REACH]:
			if not is_nan(ManorIndoors.ceiling_over(get_tree(), at + offset)):
				return true
	return false
