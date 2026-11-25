## Stats for one bow. Five exist in the Spring Court build (root design doc §4.3).
## How each one feels is in plans/combat/bow-combat-design.md §7.
class_name BowData
extends Resource

@export var id: StringName
@export var display_name: String
## Seconds from the fire press (left mouse / right trigger) to a full draw.
## Every arrow leaves at full draw: let go sooner and it flies the moment the
## draw completes.
@export var draw_time: float = 0.3
## Arrow launch speed in m/s. Every shot is full power.
@export var max_speed: float = 48.0
## Metres the arrow flies dead straight to the crosshair before it starts to
## drop (gravity eases in after that over BowTuning.gravity_blend_s).
@export var true_range: float = 30.0
## Degrees her aim shakes with this bow when her body is failing her (a
## tired arm, no breath, hunger, cold, dread). Calm and rested it is still.
@export var sway_degrees: float = 1.5
## Noise of a release, 0..1, for creature hearing.
@export var loudness: float = 0.45
## Camera kick on release, degrees of pitch.
@export var kick_degrees: float = 0.35
