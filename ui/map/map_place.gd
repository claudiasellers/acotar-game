## A named place on the world map (data/map/map_places.tres). Its name is
## written on the map once Feyre first walks inside `rect`.
class_name MapPlace
extends Resource

@export var id: StringName
@export var label: String
## World XZ bounds (position = min x, min z), from docs/contracts/world.md.
@export var rect: Rect2
## Where the name sits on the map, world XZ.
@export var label_at: Vector2
## "C" canon, "X" invented for the game (R7).
@export var canon: String = "X"
