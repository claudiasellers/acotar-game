## Stats for one bow. Five exist in the Spring Court build (root design doc §4.3).
class_name BowData
extends Resource

@export var id: StringName
@export var display_name: String
## Seconds to reach a full draw.
@export var draw_time: float = 0.8
## Arrow launch speed in m/s at a minimal and at a full draw.
@export var min_speed: float = 15.0
@export var max_speed: float = 48.0
## Degrees of aim sway at full draw before body state modifies it.
@export var sway_degrees: float = 1.5
