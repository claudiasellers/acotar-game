## Stats for one bow. Five exist in the Spring Court build (root design doc §4.3).
class_name BowData
extends Resource

@export var id: StringName
@export var display_name: String
## Seconds from raising the bow until it is nocked (T101). After that every
## shot is full power; upgrades can shorten this.
@export var nock_time: float = 0.3
## Arrow launch speed in m/s. Every shot is full power.
@export var max_speed: float = 48.0
## Degrees of aim sway at full draw before body state modifies it.
@export var sway_degrees: float = 1.5
## Noise of a release, 0..1, for creature hearing.
@export var loudness: float = 0.45
