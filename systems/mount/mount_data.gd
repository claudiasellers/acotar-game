## Tuning for a rideable mount (lane L47, docs/contracts/mount.md).
## One file per mount in data/mount/; the white mare is data/mount/white_mare.tres.
class_name MountData
extends Resource

@export var id: StringName = &"white_mare"
## Where she waits when she is home (the stable yard), and which way she faces.
@export var home: Vector3 = Vector3(-130.0, 0.0, -16.0)
@export var home_yaw: float = 0.0
## Ground speeds (m/s): stick held lightly, held fully, and with sprint.
@export var walk_speed: float = 2.2
@export var canter_speed: float = 10.0
## Capped at 15 by the director (L40 streaming: ~20 s of look-ahead); the
## speed is sold with FOV, hoof cadence and wind, not raw speed.
@export var gallop_speed: float = 15.0
## Acceleration and braking (m/s²).
@export var acceleration: float = 7.0
@export var braking: float = 11.0
## Turn rate (rad/s) at a walk and at a full gallop; between, it eases.
@export var turn_slow: float = 3.0
@export var turn_fast: float = 1.5
## A leap over a fence or a brook (jump): vertical speed and the least ground speed it needs.
@export var leap_speed: float = 5.6
@export var leap_min_speed: float = 3.0
## Steepest ground she climbs (degrees).
@export var max_slope: float = 42.0
## The whistle: how far away she starts when she isn't in sight, and how close she stops.
@export var call_distance: float = 70.0
@export var call_stop: float = 3.2
## Left with nobody this far away, she goes home to the stables.
@export var stray_distance: float = 320.0
## How far ahead she looks for dread (the Bogge, the Suriel glade, the naga reeds).
@export var balk_probe: float = 7.0
## Region ids she will not enter at all (horror: the Suriel glade and its naga reeds).
@export var no_ride_regions: PackedStringArray = ["suriel_glade"]
## Saddle seat above the spine bone's origin, in the model's space (metres).
@export var seat_offset: Vector3 = Vector3(0.0, 0.34, 0.0)
@export var canon: String = "C"
@export var source: String = "ch 9: she rides a white mare from the painted stables with Lucien; ch 5: the beast's white horse"
