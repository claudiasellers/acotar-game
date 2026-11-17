## One pair of whorl stones (data/fast_travel/<id>.tres, written by
## tools/fast_travel/place_whorl_stones.gd). The form is canon (ch 31: "the
## mossy stones placed across from each other, a faint whorl carved into them
## both. A gate."); a pair in every Spring region is canon:"X".
class_name WhorlStoneDef
extends Resource

@export var id: StringName
## The RegionDef id the stones stand in; they load and unload with it.
@export var region_id: StringName
## The MapPlace id (data/map/map_places.tres) whose name the travel card shows.
@export var place_id: StringName
## World XZ of the middle of the way between the two stones.
@export var position: Vector2
## Yaw of the pair, degrees: at 0 the stones stand east and west and the way
## between them runs north-south.
@export var yaw_degrees: float = 0.0
## The blighted pair: cold bare stone, no moss (R3: horror is never pastel).
@export var blight: bool = false
## "C" canon, "X" invented for the game (R7).
@export var canon: String = "X"
@export_multiline var notes: String
