## One painting that can hang in the manor house (L39). Built with the rest of
## the catalogue by tools/art/manor_paintings/build.py; never hand-edited.
class_name ManorArtWork
extends Resource

@export var id: StringName
@export var title: String
## landscape, still, portrait, animal, plate, botanical, map, cauldron, interior.
@export var genre: StringName
## Canvas format: land, port, square, round, oval_p, oval_l, arch_p.
@export var fmt: StringName
## Painted large, for the 2.6 m frames (or a full-length portrait).
@export var major: bool = false
## "C" book, "C?" map lore, "X" invented (lore/00-keeper/README.md).
@export var canon: String = "X"
## What in the story it shows or refers to (vetted by the Keeper).
@export_multiline var story_ref: String
## Room themes it suits, best first (ManorArtCatalog.room_themes).
@export var themes: PackedStringArray = PackedStringArray()
## Where it must hang, or empty: room ids separated by "|", first that has a
## slot wins; "room@x,z" picks that room's slot nearest the room-local x, z.
@export var pin: StringName
## Listed but not hung (not yet up to the bar); never counts toward a slot.
@export var reserve: bool = false
## The texture array holding the canvas (empty when held back), the canvas's
## layer in it, and its rect in that layer (0..1).
@export var sheet: String
@export var layer: int = -1
@export var uv: Rect2
@export var pixels: Vector2i
## Where the image comes from and on what terms (director's condition 1).
@export var source: String
@export var licence: String


## Canvas width over height.
func aspect() -> float:
	return float(pixels.x) / maxf(1.0, float(pixels.y))


## The frame shape: the format, except that big portraits are full-length.
func shape() -> StringName:
	if fmt == &"port" and major:
		return &"full"
	return fmt
