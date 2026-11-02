## When the sketchbook's hints unlock (L54). Pure logic, no nodes.
##
## Hint k (0-based) unlocks after STUCK[k] seconds of play on that step, or
## after ATTEMPTS[k] failed tries, whichever comes first. Unlocked is not
## shown: a hint is revealed only when she asks ("Think on it"), one at a time.
## Time counts only while the game runs (not paused, not in a menu).
class_name HintLadder
extends RefCounted

const STUCK: Array[float] = [60.0, 180.0, 360.0]
const ATTEMPTS: Array[int] = [1, 2, 4]

## entry id -> {"t": seconds, "fails": int, "shown": int}
var state: Dictionary = {}


func _slot(id: StringName) -> Dictionary:
	if not state.has(id):
		state[id] = {"t": 0.0, "fails": 0, "shown": 0}
	return state[id]


func tick(id: StringName, delta: float) -> void:
	if id != &"":
		_slot(id).t += delta


func note_fail(id: StringName) -> void:
	if id != &"":
		_slot(id).fails += 1


## How many of `count` hints have unlocked for this step.
func unlocked(id: StringName, count: int) -> int:
	var s := _slot(id)
	var n := 0
	for k in mini(count, STUCK.size()):
		var limit: float = STUCK[k]
		var tries: int = ATTEMPTS[k]
		if float(s.t) >= limit or int(s.fails) >= tries:
			n = k + 1
		else:
			break
	# Past the table, any further hints ride on the last threshold.
	if count > STUCK.size() and n == STUCK.size():
		n = count
	return n


func shown(id: StringName) -> int:
	return int(_slot(id).shown)


func can_reveal(id: StringName, count: int) -> bool:
	return shown(id) < unlocked(id, count)


## Reveals the next unlocked hint. Returns its index, or -1.
func reveal(id: StringName, count: int) -> int:
	if not can_reveal(id, count):
		return -1
	var s := _slot(id)
	s.shown = int(s.shown) + 1
	return int(s.shown) - 1


## Seconds until the next hint unlocks by time alone (INF when none left).
func seconds_to_next(id: StringName, count: int) -> float:
	var n := unlocked(id, count)
	if n >= mini(count, STUCK.size()):
		return INF
	return maxf(0.0, STUCK[n] - float(_slot(id).t))


func to_dict() -> Dictionary:
	var out := {}
	for k in state:
		out[String(k)] = (state[k] as Dictionary).duplicate()
	return out


func from_dict(data: Dictionary) -> void:
	state.clear()
	for k in data:
		var d: Dictionary = data[k]
		state[StringName(k)] = {"t": float(d.get("t", 0.0)), "fails": int(d.get("fails", 0)), "shown": int(d.get("shown", 0))}
