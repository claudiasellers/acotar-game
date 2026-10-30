## A roof over part of the house: sits on top of `base_level`'s storey.
class_name ManorRoofDef
extends Resource

@export var rect: Rect2
@export var base_level: int = 1
## hip, gable_x, gable_z, cone, dome, flat (with parapet).
@export var style: StringName = &"hip"
@export var height: float = 6.0
## Lilac-blue slate by default; gold for domes and finials.
@export var color: Color = Color(0.60, 0.52, 0.80)
