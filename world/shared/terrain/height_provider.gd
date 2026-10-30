## One lane's say over the terrain height inside a rectangle of the map.
## `height_script` must define, in world coordinates:
##   static func height_at(x: float, z: float) -> float
## and may define, for painting the ground:
##   static func texture_at(x: float, z: float) -> Vector3i  # (base, overlay, blend 0-255)
## Inside `bounds` the provider's height wins; over the outer `fade` metres it
## blends back to MacroHeight, so edges always meet the neighbours.
class_name HeightProvider
extends Resource

@export var id: StringName
## XZ rectangle in world coordinates (position = min x, min z).
@export var bounds: Rect2
@export var fade: float = 64.0
@export var height_script: Script
## Higher priority providers are applied later, so they win overlaps.
@export var priority: int = 0


func weight_at(x: float, z: float) -> float:
	if not bounds.has_point(Vector2(x, z)):
		return 0.0
	if fade <= 0.0:
		return 1.0
	var edge := minf(minf(x - bounds.position.x, bounds.end.x - x), minf(z - bounds.position.y, bounds.end.y - z))
	return smoothstep(0.0, fade, edge)


func height_at(x: float, z: float) -> float:
	return float(height_script.call(&"height_at", x, z))


func has_texture_rule() -> bool:
	return height_script != null and height_script.has_method(&"texture_at")


func texture_at(x: float, z: float) -> Vector3i:
	return height_script.call(&"texture_at", x, z)
