## Every painting that can hang in the manor, and which rooms suit which
## themes (L39). Built by tools/art/manor_paintings/build.py; never hand-edited.
class_name ManorArtCatalog
extends Resource

const PATH := "res://data/manor_art/manor_art_catalog.tres"

@export var works: Array[ManorArtWork] = []
## "room_id" or "room_id@level" -> themes, best first.
@export var room_themes: Dictionary = {}
## For rooms not listed: [substring of the room id, themes...], first match
## wins; an empty substring matches every room.
@export var room_patterns: Array[PackedStringArray] = []


static func load_default() -> ManorArtCatalog:
	return load(PATH) as ManorArtCatalog


## The themes a room hangs, best first.
func themes_for(room_id: StringName, level: int) -> PackedStringArray:
	var key := "%s@%d" % [room_id, level]
	if room_themes.has(key):
		return room_themes[key]
	if room_themes.has(String(room_id)):
		return room_themes[String(room_id)]
	for pat in room_patterns:
		if pat.size() > 1 and (pat[0] == "" or String(room_id).contains(pat[0])):
			return pat.slice(1)
	return PackedStringArray(["hall"])


func by_id(id: StringName) -> ManorArtWork:
	for w in works:
		if w.id == id:
			return w
	return null
