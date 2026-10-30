## The baked world map (tools/generators/world_map.gd): the painted image and
## the landmark table from scatter and the court's content, in one resource
## so it loads in exports with no import step.
class_name MapBake
extends Resource

@export var image: Image
## {id, label, x, z, height?} each.
@export var landmarks: Array[Dictionary] = []
@export var metres_per_pixel: float = 4.0
