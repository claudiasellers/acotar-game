## Where one member of the cast stands in free roam, and when (lane L34).
## Keyed to phase and place only: a spot reads WorldState, never writes it.
class_name PresenceSpot
extends Resource

@export var id: StringName
## Speaker key the lines use (tamlin, nesta, fae_moth...).
@export var speaker: StringName
## Scene spawned: a CourtNpc or FamilyMember scene, or a cast model.
@export_file("*.tscn") var scene: String
@export var region: StringName
## World x/z, or with `room`, x/z in house space.
@export var at: Vector2
## Manor-house room id: `at` is then house space on that room's storey.
@export var room: StringName = &""
@export var yaw_deg: float = 0.0
## Anchor whose position the spot is relative to (act1_cottage_interior), if any.
@export var anchor: StringName = &""
@export var phases: PackedStringArray = []
@export var require_flags: PackedStringArray = []
@export var forbid_flags: PackedStringArray = []
@export var hour_from: float = -1.0
@export var hour_to: float = -1.0
## Metres a CourtNpc wanders from the spot.
@export var wander: float = 0.0
@export var canon: String = "X"
@export var notes: String = ""


func fits_hour(hour: float) -> bool:
	if hour_from < 0.0 or hour_to < 0.0:
		return true
	if hour_from <= hour_to:
		return hour >= hour_from and hour < hour_to
	return hour >= hour_from or hour < hour_to
