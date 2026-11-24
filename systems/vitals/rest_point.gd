## Where Feyre comes round after a knockdown: a bed, the infirmary cot, a hearth,
## a marked whorl stone. The nearest one in the group wins (plan §5.2).
class_name RestPoint
extends Marker3D

const GROUP := &"rest_point"

@export var rest_id: StringName = &""


func _ready() -> void:
	add_to_group(GROUP)
