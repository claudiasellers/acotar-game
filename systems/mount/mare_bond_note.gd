## One line of her page (MarePage, lane L47-8): a bond milestone as Feyre
## knows it. What she means to try, hints from gentle to plain (only the last
## may name a key), and the memory kept once it's done. Data:
## data/mount/mare_page.tres.
class_name MareBondNote
extends Resource

## The MareBond milestone (MareBond.MILESTONES).
@export var id: StringName
## Shown only once these flags are up (e.g. Calanmai's reunion waits for it).
@export var require_flags: PackedStringArray = []
## What Feyre means to try, in her voice. `{places}` is how many places she's
## been on her back.
@export_multiline var after: String
@export var hints: PackedStringArray = []
## Past tense, kept on the page once done.
@export_multiline var memory: String
## V/A/X (all X: the book has no such deeds).
@export var canon: String = "X"


func ready() -> bool:
	for f in require_flags:
		if not WorldState.has_flag(f):
			return false
	return true
