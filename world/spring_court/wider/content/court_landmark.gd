## A named landmark, station or set piece: something to steer by without markers.
class_name CourtLandmark
extends Resource

@export var id: StringName
@export var display_name: String
## World XZ.
@export var position: Vector2
@export var yaw_degrees: float = 0.0
## Models placed here (from world/spring_court/wider/assets/props or flora).
@export var asset_ids: PackedStringArray = []
## Offsets of each asset from `position` (x, z), same length as asset_ids or empty.
@export var offsets: PackedVector2Array = []
## Height of the tallest part above ground, metres.
@export var height_m: float = 10.0
## Distance it can be recognised from (R1 wants >= 200 m).
@export var visible_from_m: float = 250.0
## landmark, station, climbable, readable, overlook
@export var kind: StringName = &"landmark"
@export var canon: String = "X"
@export_multiline var notes: String
