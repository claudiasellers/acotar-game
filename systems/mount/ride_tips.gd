## The riding key hints (lane L47, docs/contracts/mount.md): while she rides,
## the first riding key she hasn't used yet is held on KeyHints (the game's one
## table of key hints, R18), one at a time in the order a rider needs them:
## steer, gallop, leap, get down. Each is learnt the moment she uses its key,
## and learnt keys stay learnt (KeyHints saves them), so the first ride teaches
## them and later rides don't repeat them. A hint says what a key does, never
## what to do next (R2).
##
## Any ride uses it: MountDirector while Feyre is in the saddle, and the ride
## north (RideNorth, with `get_down` false until she may dismount).
##   var tips := RideTips.attach(self)   # she's up
##   tips.get_down = true                # she may get down now
##   tips.queue_free()                   # she's down (the hold lets go)
class_name RideTips
extends Node

## The KeyHints rows, in teaching order.
const ORDER: Array[StringName] = [&"ride_steer", &"ride_gallop", &"ride_leap", &"ride_off"]
## Stick or key push that counts as steering.
const STEER_MIN := 0.3

## Whether she may get down on this ride (the get-down hint waits for it).
var get_down: bool = true

var _hints: KeyHints
var _showing: StringName = &""


## Adds the tips under `parent` (they last as long as the node does).
static func attach(parent: Node, can_get_down: bool = true) -> RideTips:
	var t := RideTips.new()
	t.name = "RideTips"
	t.get_down = can_get_down
	parent.add_child(t)
	return t


func _ready() -> void:
	_hints = KeyHints.of(get_tree())


## The row to hold now: the first riding key she hasn't used.
func next_row() -> StringName:
	if _hints == null:
		return &""
	for id in ORDER:
		if id == &"ride_off" and not get_down:
			continue
		if _hints.teaches(id):
			return id
	return &""


func _process(_delta: float) -> void:
	if _hints == null:
		return
	var steer := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back").length()
	if steer >= STEER_MIN:
		_hints.learn(&"ride_steer")
		if Input.is_action_pressed(&"sprint"):
			_hints.learn(&"ride_gallop")
	var id := next_row()
	if id != _showing:
		_showing = id
		_hints.hold(self, id)


## _input, not _unhandled_input: the ride itself takes jump and E as handled.
func _input(event: InputEvent) -> void:
	if _hints == null or event.is_echo():
		return
	if event.is_action_pressed(&"jump"):
		_hints.learn(&"ride_leap")
	elif event.is_action_pressed(&"interact") and get_down:
		_hints.learn(&"ride_off")


func _exit_tree() -> void:
	if _hints and is_instance_valid(_hints):
		_hints.hold(self, &"")
