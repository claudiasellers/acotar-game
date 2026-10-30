## A flight of stairs from one level to the next.
##
## The flight fills `rect` and climbs toward `rise_toward`; the level above
## gets a hole cut in its floor over the rect. Arrive into a room on the upper
## level that contains the top edge.
class_name ManorStairDef
extends Resource

@export var id: StringName
@export var level_from: int = 0
@export var rect: Rect2
## north (-Z), south (+Z), east (+X), west (-X).
@export var rise_toward: StringName = &"north"
@export var style: StringName = &"grand"   # grand, service, spiral_tower, cellar
