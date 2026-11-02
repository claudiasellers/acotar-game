## Base for Act II's coded scenes (docs/contracts/act2.md).
##
## A StoryMoment in data/story/moments/ still says where a scene is and what
## opens and closes it; when Act2Spaces lists the moment's id, StoryDirector
## hangs one of these instead of the generic MomentSpace, so the scene can
## have real mechanics (being held at the table, rigging the rope). Staging
## (marks, lines) comes from an Act2Stage .tres. Deeds still only come from
## ActionTriggers through raise() (R2); nobody else sets a phase flag.
class_name Act2Space
extends SceneSpace

## The data moment this scene plays (null for scenes with no moment, such as
## the arrival, which set their flags in _init).
@export var moment: StoryMoment
@export var stage: Act2Stage

## Actor id -> Node3D, for every actor this scene has asked for.
var actors: Dictionary = {}
## With > 0, arriving also needs Feyre within this many metres in height
## (rooms stack: the bedroom is over the gallery).
@export var arrive_height: float = 2.5
## Tests set this: fades and time shifts happen at once (no tweens to wait on).
var instant_fades: bool = false
## E presses while the scene runs (input, or press_interact() in tests).
var _presses: int = 0
## Movement presses while the scene runs (input, or nudge() in tests).
var _nudges: int = 0


func _ready() -> void:
	if moment:
		space_id = moment.id
		require_flags = moment.require_flags
		done_flags = moment.done_flags if not moment.done_flags.is_empty() else moment_deeds()
		night_only = moment.night_only
		auto_start = moment.trigger == &"auto"
		if moment.trigger == &"enter" and arrive_radius <= 0.0 and get_node_or_null(^"Entry") == null:
			arrive_radius = moment.entry_radius
	if stage:
		var gates := PackedStringArray(require_flags)
		for flag in stage.extra_require:
			if not gates.has(flag):
				gates.append(flag)
		require_flags = gates
	super._ready()


## The flags the moment's data raises (its deeds).
func moment_deeds() -> PackedStringArray:
	var flags := PackedStringArray()
	if moment:
		for step in moment.steps:
			if step.get("do") == "raise" and not String(step["flag"]).begins_with("fact."):
				flags.append(String(step["flag"]))
	return flags


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event.is_action_pressed(&"interact"):
		if running:
			_presses += 1
		elif moment and moment.trigger == &"interact" and player_within(moment.entry_radius):
			arrive()
	elif running:
		for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
			if event.is_action_pressed(action):
				_nudges += 1


func _player_here() -> bool:
	if not super._player_here():
		return false
	if player_present or arrive_height <= 0.0:
		return true
	var p := player()
	return p != null and absf(p.global_position.y - (global_transform * arrive_offset).y) <= arrive_height


func press_interact() -> void:
	_presses += 1


func presses() -> int:
	return _presses


## Feyre tries to move (tests; input counts the same way).
func nudge() -> void:
	_nudges += 1


func nudges() -> int:
	return _nudges


func player_within(radius: float, at: Vector3 = global_position) -> bool:
	var p := player()
	return p != null and p.global_position.distance_to(at) <= radius


## A stage mark in world space (the space itself when the mark is missing).
func mark(mark_name: StringName) -> Vector3:
	if stage == null or not stage.has_mark(mark_name):
		return global_position
	return global_transform * stage.mark(mark_name)


## Puts an actor on a mark, facing another mark (or the space).
func cast(actor_id: StringName, at_mark: StringName, face_mark: StringName = &"") -> Node3D:
	var origin := mark(at_mark)
	var face := mark(face_mark) if face_mark != &"" else global_position
	var xform := Transform3D(Basis.IDENTITY, origin)
	if not Vector2(origin.x, origin.z).is_equal_approx(Vector2(face.x, face.z)):
		xform = xform.looking_at(Vector3(face.x, origin.y, face.z), Vector3.UP)
	var who := request_actor(actor_id, xform, func() -> Node3D: return Act2Cast.build(String(actor_id)))
	who.global_transform = xform
	actors[actor_id] = who
	return who


## The actor this scene cast, or null once it has been freed (forgotten too).
func actor(actor_id: StringName) -> Node3D:
	var raw: Variant = actors.get(actor_id)
	if raw == null or not is_instance_valid(raw):
		actors.erase(actor_id)
		return null
	return raw as Node3D


## Removes an actor this scene placed (only its own stand-ins are freed).
func dismiss(actor_id: StringName) -> void:
	var who := actor(actor_id)
	actors.erase(actor_id)
	if who and is_ancestor_of(who):
		who.queue_free()


## Shows a staged line and waits about as long as it takes to read.
func say(line_id: StringName) -> SceneBeat:
	return SayBeat.new(line_id)


## Waits until Feyre is within `radius` of a mark (on foot, any height).
func reach(mark_name: StringName, radius: float) -> SceneBeat:
	return Beats.until(func() -> bool:
		var p := player()
		if p == null:
			return false
		var at := mark(mark_name)
		return Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() <= radius,
		"reach %s" % mark_name)


## Sparkles, chime and bounce (R3: every reward gets its burst).
func delight(kind: StringName, at_mark: StringName = &"", target: Node3D = null) -> void:
	if not is_inside_tree():
		return
	Juice.burst(target, kind, mark(at_mark) if target == null else Vector3.ZERO)


## A line that doesn't hold the scene up (thoughts while she acts).
func aside(line_id: StringName) -> void:
	var spoken: Dictionary = stage.line(line_id) if stage else {}
	if spoken.is_empty() or not is_inside_tree():
		return
	Act2Caption.find_or_make(self).say(String(spoken.get("who", "")), String(spoken.get("text", "")))


## Beats: fade to dark, move the Clock to `to` (fraction of the day), run
## `then` in the dark (move Feyre, change her clothes), fade back, go on.
func fade_time(to: float, then: Callable = Callable(), label: String = "fade") -> Array:
	var done := [false]
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			done[0] = false
			var finish := func() -> void:
				if then.is_valid():
					then.call()
				done[0] = true
			if instant_fades or not is_inside_tree():
				TimeShift.advance_to(to)
				finish.call()
			else:
				TimeShift.fade_to(self, to, finish), label),
		Beats.until(func() -> bool: return done[0], "until %s ends" % label),
	]


## Moves Feyre to a world point (on her feet, stopped).
func place_feyre(at: Vector3) -> void:
	var p := player()
	if p == null:
		return
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
	p.global_position = at + Vector3.UP * 0.1


## The first story anchor with this id in the tree (another room's scene).
func find_anchor(anchor_id: StringName) -> Node3D:
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group(&"story_anchor"):
		if node is Node3D and StringName(node.get_meta(&"anchor_id", node.name)) == anchor_id:
			return node
	return null


## An actor walks a list of marks; with `wait_for` > 0 it waits at each mark
## until Feyre is that close (she follows it). Uses the actor's own lead()
## when it has one (BeastActor), otherwise slides it at `speed`.
func lead_along(actor_id: StringName, route: Array, wait_for: float = 0.0, speed: float = 2.2) -> SceneBeat:
	return LeadBeat.new(actor_id, route, wait_for, speed)


class LeadBeat:
	extends SceneBeat
	var actor_id: StringName
	var route: Array
	var wait_for: float
	var speed: float
	var index: int = 0
	var _asked: int = -1

	func consumes_time() -> bool:
		return true

	func _init(id: StringName, r: Array, w: float, s: float) -> void:
		actor_id = id
		route = r
		wait_for = w
		speed = s
		label = "lead %s" % id

	func enter(_space: SceneSpace) -> void:
		index = 0
		_asked = -1

	func tick(space: SceneSpace, delta: float) -> bool:
		var s := space as Act2Space
		var who := s.actor(actor_id)
		if who == null or index >= route.size():
			return true
		var target := s.mark(StringName(route[index]))
		target.y = who.global_position.y
		if who.has_method(&"lead"):
			if _asked != index:
				who.call(&"lead", target)
				_asked = index
		else:
			var to := target - who.global_position
			if to.length() > 0.05:
				who.global_position += to.limit_length(speed * delta)
				var flat := Vector3(target.x, who.global_position.y, target.z)
				if not flat.is_equal_approx(who.global_position):
					who.look_at(flat, Vector3.UP)
		if who.global_position.distance_to(target) > 0.6:
			return false
		if wait_for > 0.0 and not s.player_within(wait_for, who.global_position):
			return false
		index += 1
		return index >= route.size()


class SayBeat:
	extends SceneBeat
	var line_id: StringName
	var _left: float

	func consumes_time() -> bool:
		return true

	func _init(id: StringName) -> void:
		line_id = id
		label = "say %s" % id

	func enter(space: SceneSpace) -> void:
		var s := space as Act2Space
		var spoken: Dictionary = s.stage.line(line_id) if s.stage else {}
		var text := String(spoken.get("text", ""))
		if text == "":
			push_warning("Act2Space %s: no line '%s'" % [space.space_id, line_id])
			_left = 0.0
			return
		_left = Act2Caption.reading_time(text)
		if space.is_inside_tree():
			Act2Caption.find_or_make(space).say(String(spoken.get("who", "")), text, _left)

	func tick(_space: SceneSpace, delta: float) -> bool:
		_left -= delta
		return _left <= 0.0
