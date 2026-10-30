## One room (or corridor, stair hall, exterior dressing) of the manor house.
class_name ManorRoomDef
extends Resource

@export var id: StringName
@export var display_name: String
## "C" canon, "C?" canon-verify, "X" invented (lore/00-keeper/README.md).
@export var canon: String = "X"
## -1 cellars, 0 ground, 1 first floor, 2 attic, 3 tower tops.
@export var level: int = 0
## Footprint in world XZ: Rect2(x, z, width, depth).
@export var rect: Rect2
## Clear height floor to ceiling. 0 uses the storey default. Taller than a
## storey makes a double-height room that also fills the level above.
@export var ceiling_height: float = 0.0
## room, corridor, stair_hall, exterior (props only, no walls/floor/ceiling).
@export var kind: StringName = &"room"
## wood, marble, stone, tile, carpet, flagstone.
@export var floor_kind: StringName = &"wood"
## Wallpaper/plaster colour (R3: blush, lilac, mint, butter, pearl...).
@export var wall_color: Color = Color(1.0, 0.88, 0.90)
@export var floor_color: Color = Color(0, 0, 0, 0)
## Windows are cut automatically into this room's exterior walls.
@export var windows: bool = true
@export var props: Array[ManorPropPlacement] = []
@export_multiline var notes: String
