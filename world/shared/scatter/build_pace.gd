## Lets a long main-thread build share its frames: a coroutine calls
## `await pace.tick()` between steps, and tick waits for the next frame once
## FrameBudget's time for this one is gone. A build runs at BUDGET_USEC in the
## background, and at HELD_BUDGET_USEC while Feyre is in its region and waiting
## for it. Worker threads are no use here: each RenderingServer read a builder
## makes blocks until the main thread flushes, one frame per read (the house
## took 540 s that way against 3.5 s on the main thread).
class_name BuildPace
extends RefCounted

const HELD_BUDGET_USEC := 50000

var _tree: SceneTree
var _region: StringName
var _since := 0


func _init(tree: SceneTree, region: StringName = &"") -> void:
	_tree = tree
	_region = region
	_since = Time.get_ticks_usec()


func tick() -> void:
	FrameBudget.spend(Time.get_ticks_usec() - _since)
	if not FrameBudget.has_time(_budget()):
		await _tree.process_frame
	_since = Time.get_ticks_usec()


## For waiting on a background load: gives the frame up without spending it.
func next_frame() -> void:
	await _tree.process_frame
	_since = Time.get_ticks_usec()


func _budget() -> int:
	return HELD_BUDGET_USEC if WorldStreamer.in_focus(_region) else FrameBudget.BUDGET_USEC
