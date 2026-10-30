## A named patch of ground inside a wider-court region (lakeshore, birch copse,
## bonfire terraces...). Forage and decor entries list the habitats they grow in.
## The highest-priority habitat containing a point wins; otherwise the region's
## default habitat applies.
class_name CourtHabitat
extends Resource

enum Shape { CIRCLE, RING, RECT, RIVER_BAND }

@export var tag: StringName
@export var shape: Shape = Shape.CIRCLE
## CIRCLE / RING centre in world XZ.
@export var center: Vector2
@export var radius: float = 50.0
## RING only: points closer than this are outside.
@export var inner_radius: float = 0.0
## RECT only, world XZ.
@export var rect: Rect2
## RIVER_BAND only: distance from the Thornwater centreline.
@export var band_min: float = 0.0
@export var band_max: float = 30.0
@export var priority: int = 0
## No forage or decor at all except entries that name this habitat (water).
@export var exclusive: bool = false


func contains(p: Vector2) -> bool:
	match shape:
		Shape.CIRCLE:
			return p.distance_to(center) <= radius
		Shape.RING:
			var d := p.distance_to(center)
			return d <= radius and d >= inner_radius
		Shape.RECT:
			return rect.has_point(p)
		Shape.RIVER_BAND:
			var d := MacroHeight.distance_to_river(p.x, p.y)
			return d >= band_min and d <= band_max
	return false
