## The two small labels Feyre writes beside a thing when she draws it on the
## satchel page ("black vane", "split quill"): what she sees, never what it
## does. One file per thing in data/satchel/notes/, named for its id (R8).
## Written from tools/satchel/item_notes.tsv by build_item_notes.py.
class_name ItemNotes
extends Resource

const FOLDER := "res://data/satchel/notes/"

## The item's id, or "dish:<key>" for a cooked dish.
@export var id: StringName
@export var labels: PackedStringArray = []
## Lore canon status (R7): "C", "C?" or "X" for invented.
@export var canon: String = "X"

static var _cache: Dictionary = {}


## The notes for an item or dish id, or null when nobody has written any.
static func of(item_id: StringName) -> ItemNotes:
	if not _cache.has(item_id):
		var path := path_for(item_id)
		_cache[item_id] = load(path) as ItemNotes if ResourceLoader.exists(path) else null
	return _cache[item_id]


static func path_for(item_id: StringName) -> String:
	return FOLDER + String(item_id).replace(":", "_") + ".tres"
