## The short freeze that gives a hit its weight (health-interactions §3.5 #6):
## her arrow, knife or bow bash landing on a creature, and a creature's blow
## landing on her. It holds TimeScale at SCALE under &"hit_stop" for a few
## frames of real time, counted on the unscaled clock so the freeze can't
## stretch itself, then lets go so time returns to whatever else asked
## (Focus, the quiver wheel). Reduced Effects halves it. A blow she can't see
## coming gets none: the HUD edge speaks for that one.
class_name HitStop
extends Node

const ID := &"hit_stop"
const SCALE := 0.05
## Frames at 60 a second, by how hard the hit is.
const FRAMES := {&"light": 4, &"medium": 6, &"heavy": 9}
const WEAK_SPOT_FRAMES := 3
const KILL_FRAMES := 10
const FRAME_USEC := 1000000.0 / 60.0
## Strike kinds (StrikeController.struck) that land harder than a plain stab.
const STRIKE_REACTIONS := {&"bash": &"medium", &"sneak": &"heavy", &"finisher": &"heavy"}

var player: Node3D
var vitals: VitalsState
var strike: StrikeController
## Real time (Time.get_ticks_usec) the freeze ends at; 0 when there is none.
var _until_usec: int = 0
## The frame her last hit landed on: a kill freezes only as the blow lands,
## never when a mortal wound runs out later.
var _hit_frame: int = -1


func _init() -> void:
	name = "HitStop"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	Gameplay.listen(&"creature_hit", _on_creature_hit)
	Gameplay.listen(&"creature_killed", _on_creature_killed)
	if vitals:
		vitals.hit_taken.connect(_on_hit_taken)
	if strike:
		strike.struck.connect(_on_struck)


func _exit_tree() -> void:
	end()


## Frames a hit of `reaction` holds for (0 for &"none").
static func frames(reaction: StringName, weak_spot: bool = false, killed: bool = false) -> int:
	if killed:
		return KILL_FRAMES
	var n := int(FRAMES.get(reaction, 0))
	return n + WEAK_SPOT_FRAMES if n > 0 and weak_spot else n


## Freezes for a hit of `reaction`. A longer freeze already running is kept.
func hit(reaction: StringName, weak_spot: bool = false, killed: bool = false) -> void:
	hold(HitStop.frames(reaction, weak_spot, killed))


func hold(frame_count: int) -> void:
	if GameSettings.reduced_effects:
		frame_count = frame_count / 2
	if frame_count <= 0:
		return
	_until_usec = maxi(_until_usec, Time.get_ticks_usec() + int(frame_count * FRAME_USEC))
	TimeScale.request(ID, SCALE)


func active() -> bool:
	return _until_usec > 0


## Real seconds the freeze has left.
func left() -> float:
	return maxf(_until_usec - Time.get_ticks_usec(), 0.0) / 1000000.0 if _until_usec > 0 else 0.0


func end() -> void:
	_until_usec = 0
	TimeScale.release(ID)


func _process(_delta: float) -> void:
	if _until_usec > 0 and Time.get_ticks_usec() >= _until_usec:
		end()


## Whether a hit with this cause is one of hers (not fire, a fall, another beast).
static func is_hers(cause: StringName) -> bool:
	return cause == &"knife" or cause == &"bow_bash" or String(cause).begins_with("arrow_")


func _on_creature_hit(_id: StringName, _kind: StringName, cause: StringName, part: StringName) -> void:
	if HitStop.is_hers(cause):
		_hit_frame = Engine.get_process_frames()
		hit(&"medium" if cause == &"bow_bash" else &"light", part != &"body")


func _on_creature_killed(_id: StringName, _kind: StringName, cause: StringName, _at: Vector3) -> void:
	if HitStop.is_hers(cause) and _hit_frame == Engine.get_process_frames():
		hit(&"light", false, true)


func _on_struck(kind: StringName, target: Node) -> void:
	if target is Creature and STRIKE_REACTIONS.has(kind):
		hit(STRIKE_REACTIONS[kind])


## A blow landed on her. One from outside the view gets no freeze.
func _on_hit_taken(origin: Vector3, _damage: float, reaction: StringName) -> void:
	if _in_view(origin):
		hit(reaction)


func _in_view(origin: Vector3) -> bool:
	if not origin.is_finite() or not is_inside_tree():
		return true
	var camera := get_viewport().get_camera_3d()
	return camera == null or camera.is_position_in_frustum(origin)
