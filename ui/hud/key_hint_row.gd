## One key hint (KeyHints): which keys it names and what each does. Rows live
## in data/key_hints/, one file per feature, so a lane adding a hint touches
## only its own file.
class_name KeyHintRow
extends Resource

## The hint's name: what `hold`, `nudge` and `learn` are called with, and its
## key under [prompts] in the settings file.
@export var id: StringName
## Lower shows first when several rows are wanted. No two rows in the game
## share one; leave gaps so a row can be put between two others.
@export var priority: int
## The action of each pair, in order. &"" is words alone; "move" and "look"
## name the keys or sticks (KeyHints.cap).
@export var keys: Array[StringName] = []
## What each pair's key does, one per entry of `keys`.
@export var says: PackedStringArray = []
## Never learnt and never off: a choice she has to see for as long as it waits.
@export var always: bool = false


## The row as [[action, words], ...].
func pairs() -> Array:
	var out: Array = []
	for i in keys.size():
		out.append([keys[i], says[i]])
	return out
