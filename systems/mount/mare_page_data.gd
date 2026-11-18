## Her page's words (lane L47-8): what she does now at each bond step, and a
## MareBondNote per milestone. Data: data/mount/mare_page.tres.
class_name MarePageData
extends Resource

## What she does now, by MareBond.tier() (0..4), in landmarks, not metres.
@export var now: PackedStringArray = []
@export var notes: Array[MareBondNote] = []


func note(id: StringName) -> MareBondNote:
	for n in notes:
		if n.id == id:
			return n
	return null
