## Base for the Calanmai chapter's scenes (ch20-22, L45): an Act2Space whose
## gate is its own (require / done facts set in code, no data moment needed),
## with an optional hour window (dusk, lunch, dinner) that, like night_only,
## brings the hour to her with a soft fade when she arrives at the wrong time.
## Lines go to the caption and to the speaker's face (L36's Faces API).
class_name CalanmaiSpace
extends Act2Space

## Speaker names in the stage -> story actor ids, for faces and lip movement.
const SPEAKERS := {"Tamlin": &"tamlin", "Lucien": &"lucien", "The stranger": &"rhysand", "Feyre": &"feyre",
	"A faerie": &"high_fae_male"}

## Hour window in Clock hours (0..24); both < 0 means any hour (or night_only/day_only).
var hour_from: float = -1.0
var hour_to: float = -1.0
## Where the fade brings the Clock when she arrives outside the window (hours).
var shift_hour: float = -1.0
## Scenes in a room another scene just used (the dining hall: lunch, then dinner)
## wait until she has walked out and come back in, so one meal doesn't fade
## straight into the next.
var fresh_entry: bool = false
var _armed: bool = false


func _physics_process(delta: float) -> void:
	if fresh_entry and not _armed and not running and not _player_here() and _required_met():
		_armed = true
	super._physics_process(delta)


func _required_met() -> bool:
	for flag in require_flags:
		if not WorldState.has_flag(flag):
			return false
	return true


func arrive() -> bool:
	if fresh_entry and not _armed:
		return false
	return super.arrive()


## Opens a window: [from, to) hours, faded to `shift` when she arrives outside it.
func window(from: float, to: float, shift: float) -> void:
	hour_from = from
	hour_to = to
	shift_hour = shift


func _hour_ok() -> bool:
	if hour_from < 0.0:
		return super._hour_ok()
	var h := Clock.hour()
	return h >= hour_from and h < hour_to


func waits_only_for_time() -> bool:
	if hour_from < 0.0:
		return super.waits_only_for_time()
	if running:
		return false
	var a := hour_from
	hour_from = -1.0
	var ok := can_start()
	hour_from = a
	return ok and not _hour_ok()


func shift_time() -> void:
	if hour_from < 0.0:
		super.shift_time()
		return
	shifting_time = true
	TimeShift.fade_to(self, shift_hour / 24.0, func() -> void:
		shifting_time = false
		if not start():
			StoryControl.release())


## A spoken line: the caption, plus the speaker's face and mouth when they have one.
func speak(line_id: StringName, emotion: StringName = &"") -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			var spoken: Dictionary = stage.line(line_id) if stage else {}
			var actor_id: StringName = SPEAKERS.get(String(spoken.get("who", "")), &"")
			if actor_id == &"" or not is_inside_tree():
				return
			var text := String(spoken.get("text", ""))
			var secs := Act2Caption.reading_time(text)
			if emotion != &"":
				EventBus.face_requested.emit(actor_id, emotion, 0.8, secs)
			EventBus.line_spoken.emit(actor_id, text, emotion, secs), "voice %s" % line_id),
		say(line_id),
	]


## An actor turns to face a point (flat).
static func face_toward(who: Node3D, at: Vector3) -> void:
	if who == null or not who.is_inside_tree():
		return
	var p := who.global_position
	var d := Vector3(at.x - p.x, 0.0, at.z - p.z)
	if d.length() > 0.05:
		who.look_at(p + d, Vector3.UP)


## Slides an actor toward a point at `speed`, playing its walk when it has one.
## Returns true on arrival.
static func step_toward(who: Node3D, at: Vector3, speed: float, delta: float) -> bool:
	if who == null:
		return true
	var p := who.global_position
	var to := Vector3(at.x - p.x, 0.0, at.z - p.z)
	var step := speed * delta
	var arrived := to.length() <= step
	who.global_position = Vector3(at.x, at.y, at.z) if arrived else Vector3(p.x, at.y, p.z) + to.normalized() * step
	if not arrived:
		face_toward(who, at)
	if who.has_method(&"play_locomotion"):
		who.call(&"play_locomotion", 0.0 if arrived else speed, true, delta)
	return arrived


## An actor walks a route of marks (world points when given Vector3s) at `speed`.
func walk(actor_id: StringName, route: Array, speed: float = 1.6) -> SceneBeat:
	return WalkBeat.new(actor_id, route, speed)


## Runs `fn(delta)` every tick until it returns true (a scene's own little loop).
func each_tick(fn: Callable, label_text: String) -> SceneBeat:
	return TickBeat.new(fn, label_text)


class WalkBeat:
	extends SceneBeat
	var actor_id: StringName
	var route: Array
	var speed: float
	var index: int = 0

	func consumes_time() -> bool:
		return true

	func _init(id: StringName, r: Array, s: float) -> void:
		actor_id = id
		route = r
		speed = s
		label = "walk %s" % id

	func enter(_space: SceneSpace) -> void:
		index = 0

	func tick(space: SceneSpace, delta: float) -> bool:
		var s := space as Act2Space
		var who := s.actor(actor_id)
		if who == null or index >= route.size():
			return true
		var target: Vector3 = route[index] if route[index] is Vector3 else s.mark(StringName(route[index]))
		target.y = who.global_position.y
		if CalanmaiSpace.step_toward(who, target, speed, delta):
			index += 1
		if index >= route.size() and who.has_method(&"play_locomotion"):
			who.call(&"play_locomotion", 0.0, true, delta)
		return index >= route.size()


class TickBeat:
	extends SceneBeat
	var fn: Callable

	func consumes_time() -> bool:
		return true

	func _init(f: Callable, l: String) -> void:
		fn = f
		label = l

	func tick(_space: SceneSpace, delta: float) -> bool:
		return bool(fn.call(delta))
