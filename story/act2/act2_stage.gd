## Staging for one Act II scene as data (R8): where people stand, what they
## say, and any extra gate on top of the scene's StoryMoment.
##
## Marks are offsets in the anchor's local frame (metres; the anchor's -Z is
## its forward), so a scene follows its anchor if the manor lane moves it.
## Lines are the book's words where the Keeper confirmed them; anything
## invented is listed in `invented` (canon:"X").
class_name Act2Stage
extends Resource

## Mark name -> anchor-local position.
@export var marks: Dictionary = {}
## Line id -> {"who": "Tamlin", "text": "Sit. Eat."}.
@export var lines: Dictionary = {}
## Flags needed on top of the StoryMoment's require_flags (code-only gates
## that the data-driven moment tests don't know about).
@export var extra_require: PackedStringArray = []
## Line ids that are invented to fill the scene (canon:"X").
@export var invented: PackedStringArray = []
## Chapter and Keeper note, for the cross-check.
@export_multiline var canon: String = ""


func mark(mark_name: StringName) -> Vector3:
	return marks.get(mark_name, marks.get(String(mark_name), Vector3.ZERO))


func has_mark(mark_name: StringName) -> bool:
	return marks.has(mark_name) or marks.has(String(mark_name))


func line(line_id: StringName) -> Dictionary:
	return lines.get(line_id, lines.get(String(line_id), {}))
