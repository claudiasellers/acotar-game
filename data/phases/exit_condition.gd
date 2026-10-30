## The flags that end a phase. ALL needs every flag (and child condition);
## ANY needs one. Children allow "wolf_killed AND (crossed_on_horse OR crossed_on_foot)".
class_name ExitCondition
extends Resource

enum Mode { ALL, ANY }

@export var mode: Mode = Mode.ALL
@export var flags: PackedStringArray = []
## Nested ExitCondition resources.
@export var children: Array[Resource] = []


## `has_flag` is a Callable taking a flag name and returning bool
## (normally WorldState.has_flag). An empty condition is never met.
func evaluate(has_flag: Callable) -> bool:
	var results: Array[bool] = []
	for flag in flags:
		results.append(bool(has_flag.call(flag)))
	for child in children:
		if child is ExitCondition:
			results.append((child as ExitCondition).evaluate(has_flag))
	if results.is_empty():
		return false
	if mode == Mode.ALL:
		return not results.has(false)
	return results.has(true)
