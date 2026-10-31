## A book scene as a place (root design doc §3.3, §12 tier 1).
##
## A scene space is entered through play (walking into its Entry area, or a
## deed making it eligible), narrows Feyre's control for short anchored
## moments, raises its deeds through ActionTriggers, and leaves the world
## visibly changed (StateVisibility nodes keyed on those flags).
##
## Subclasses override _build_beats(). Everything is ticked from
## _physics_process, so tests can drive a scene with tick().
class_name SceneSpace
extends Node3D

signal started
signal finished
signal decision_made(fact: String)

@export var space_id: StringName
## Every flag here must be set before the space can start.
@export var require_flags: PackedStringArray = []
## The space never starts once any of these is set (usually the deed it raises).
@export var done_flags: PackedStringArray = []
## Start as soon as the requirements are met (otherwise: on Entry, or start()).
@export var auto_start: bool = false
## Only at night by the Clock (the beast comes at night).
@export var night_only: bool = false
## Only by day (the hunt is in daylight, in falling snow).
@export var day_only: bool = false
## When Feyre arrives and only the hour is wrong, the hour comes to her: a soft
## fade, the Clock moves on to the scene's time, and the scene starts. A scene
## always starts when she walks into it, whatever time she gets there.
@export var shift_time_on_arrival: bool = true
## Also counts as arriving: Feyre within this many metres on the ground (flat
## distance, any height) of `arrive_offset`. 0 = only the Entry area.
@export var arrive_radius: float = 0.0
@export var arrive_offset: Vector3 = Vector3.ZERO
## Tick from _physics_process. Tests turn this off and call tick() directly.
@export var auto_tick: bool = true

var running: bool = false
var beats: Array = []
var beat_index: int = -1

var _choice: StringName = &""
var _triggers: Dictionary = {}
var _mood_set: bool = false
## Feyre is inside the Entry area (or the arrive radius) right now.
var player_present: bool = false
## A time shift is fading in; the scene starts when it ends.
var shifting_time: bool = false
## After the scene ends or fails she has to step out before it can start again.
var _must_leave: bool = false


## Called by mood beats so the scene restores calm when it ends.
func note_mood() -> void:
	_mood_set = true


func _ready() -> void:
	var entry := get_node_or_null(^"Entry") as Area3D
	if entry:
		entry.body_entered.connect(_on_entry_body_entered)
		entry.body_exited.connect(_on_entry_body_exited)


func _physics_process(delta: float) -> void:
	if not auto_tick:
		return
	if running:
		tick(delta)
		return
	if shifting_time:
		return
	var here := _player_here()
	if not here:
		_must_leave = false
	if auto_start and can_start():
		start()
	elif here and not _must_leave:
		arrive()


## Feyre has arrived: start now, or bring the scene's hour to her and then
## start. Returns true when the scene started or the hour is on its way.
func arrive() -> bool:
	if running or shifting_time:
		return running or shifting_time
	if can_start():
		return start()
	if shift_time_on_arrival and waits_only_for_time():
		shift_time()
		return true
	return false


## Everything is ready but the hour (a night scene by day, a day scene by night).
func waits_only_for_time() -> bool:
	if not (night_only or day_only) or running:
		return false
	var was_night := night_only
	var was_day := day_only
	night_only = false
	day_only = false
	var ok := can_start()
	night_only = was_night
	day_only = was_day
	return ok and not _hour_ok()


func _hour_ok() -> bool:
	if night_only and not Clock.is_night():
		return false
	if day_only and Clock.is_night():
		return false
	return true


## Fades out, moves the Clock to the scene's hour, fades in and starts.
func shift_time() -> void:
	shifting_time = true
	var to := TimeShift.NIGHT if night_only else TimeShift.MORNING
	TimeShift.fade_to(self, to, func() -> void:
		shifting_time = false
		if not start():
			StoryControl.release())


func _player_here() -> bool:
	if player_present:
		return true
	if arrive_radius <= 0.0:
		return false
	var p := player()
	if p == null:
		return false
	var at := global_transform * arrive_offset
	return Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() <= arrive_radius


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	for action: StringName in [&"interact", &"fire", &"aim", &"jump"]:
		if event.is_action_pressed(action):
			_choice = action


func can_start() -> bool:
	if running:
		return false
	for flag in require_flags:
		if not WorldState.has_flag(flag):
			return false
	for flag in done_flags:
		if WorldState.has_flag(flag):
			return false
	if not _hour_ok():
		return false
	return true


func start() -> bool:
	if not can_start():
		return false
	running = true
	beats = _build_beats()
	beat_index = -1
	EventBus.scene_space_started.emit(space_id)
	started.emit()
	_advance()
	tick(0.0)  # run the leading instant beats now
	return true


## Runs the current beat for `delta` seconds, moving on as beats finish.
## Several instant beats can complete in one tick.
func tick(delta: float) -> void:
	var guard := beats.size() + 1
	while running and guard > 0:
		guard -= 1
		var beat: SceneBeat = beats[beat_index]
		if not beat.tick(self, delta):
			return
		if beat.consumes_time():
			delta = 0.0
		beat.exit(self)
		_advance()


## Raises a flag through this space's ActionTrigger for it (story flags only
## ever come from ActionTriggers).
func raise(flag: String) -> void:
	if not _triggers.has(flag):
		var trigger := ActionTrigger.new()
		trigger.name = "Raise_%s" % flag.validate_node_name()
		trigger.flag = flag
		trigger.fire_on_body_enter = false
		trigger.monitoring = false
		trigger.monitorable = false
		add_child(trigger)
		_triggers[flag] = trigger
	(_triggers[flag] as ActionTrigger).fire()


## Choose an option in an open decision window (input or tests).
func choose(action: StringName) -> void:
	_choice = action


func last_choice() -> StringName:
	return _choice


func clear_choice() -> void:
	_choice = &""


func current_beat_label() -> String:
	if beat_index < 0 or beat_index >= beats.size():
		return ""
	return (beats[beat_index] as SceneBeat).label


## The player node (Feyre), if one is in the tree.
func player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


## Asks the owning lane to place an actor; if nobody answers (no node joins
## group "story_actor_<id>"), builds the placeholder from `fallback`.
func request_actor(actor_id: StringName, where: Transform3D, fallback: Callable) -> Node3D:
	EventBus.story_spawn_requested.emit(actor_id, where)
	var group := StringName("story_actor_%s" % actor_id)
	var answered := get_tree().get_first_node_in_group(group) as Node3D
	if answered:
		return answered
	var stand_in := fallback.call() as Node3D
	stand_in.add_to_group(group)
	add_child(stand_in)
	stand_in.global_transform = where
	return stand_in


func _build_beats() -> Array:
	return []


func _finish() -> void:
	running = false
	_must_leave = true
	if _mood_set:
		EventBus.mood_requested.emit(&"calm", 0.0, 3.0)
	StoryControl.release()
	EventBus.scene_space_finished.emit(space_id)
	finished.emit()


func _advance() -> void:
	beat_index += 1
	if beat_index >= beats.size():
		_finish()
		return
	(beats[beat_index] as SceneBeat).enter(self)


func _on_entry_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		player_present = true
		_must_leave = false
		arrive()


func _on_entry_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		player_present = false
