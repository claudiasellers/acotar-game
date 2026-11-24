## Stats for one bow. Five exist in the Spring Court build (root design doc §4.3).
## How each one feels is in plans/combat/bow-combat-design.md §7.
class_name BowData
extends Resource

@export var id: StringName
@export var display_name: String
## Seconds of holding fire (left mouse / right trigger) to draw the string to
## full. Releasing at full draw looses a full-power arrow; releasing earlier
## lets the string down and looses nothing. There are no weak shots.
@export var draw_time: float = 0.3
## Arrow launch speed in m/s. Every shot is full power.
@export var max_speed: float = 48.0
## Degrees of aim sway at full draw before settle, stance, breath and body state.
@export var sway_degrees: float = 1.5
## Noise of a release, 0..1, for creature hearing.
@export var loudness: float = 0.45
## Camera kick on release, degrees of pitch.
@export var kick_degrees: float = 0.35
