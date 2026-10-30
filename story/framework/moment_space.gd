## Plays a StoryMoment: a book scene authored as data.
##
## Step vocabulary ("do"):
##   control  mode (FULL/WALK/LOOK/NONE), focus (actor id, "self" or none), allow ([actions])
##   spawn    actor, at (offset from the space), face (offset to look toward)
##   despawn  actor
##   wait     s
##   cue      actor, cue                 -> EventBus.story_actor_cue
##   mood     mood, i, s, shake          -> EventBus.mood_requested (horror beats)
##   celebrate kind                      -> EventBus.celebration_requested (Spring Court deeds)
##   weather  w, s · grade to, s · grant item, n · journal entry · travel region, anchor
##   raise    flag                       (through an ActionTrigger)
##   until_flag flag
##   until_killed kind, n                (EventBus.creature_killed)
##   stay     s, r, near (actor/"self"), strict, fail_fact
##              time counts only while Feyre is within r; strict fails the scene if she leaves
##   interact n, r                       E presses near the space
##   gaze_avoid actor, s, cone, max, fail_fact
##              survive s seconds without looking at actor for more than max seconds
##   gaze_hold actor, s, cone            look at actor (or "self") for s seconds
##   decision options [{action, fact}], s, default
##
## A failed step (gaze_avoid, strict stay) raises its fail_fact if any and ends
## the scene without its deed, so Feyre can try again.
class_name MomentSpace
extends SceneSpace

signal failed(fact: String)

@export var moment: StoryMoment

## Tests can replace how Feyre's view direction is read.
var gaze_override: Callable
var actors: Dictionary = {}  # actor id -> Node3D
var kills: Dictionary = {}   # kind -> count

var _presses: int = 0


func _ready() -> void:
	if moment:
		space_id = moment.id
		require_flags = moment.require_flags
		done_flags = moment.done_flags if not moment.done_flags.is_empty() else _gate_flags()
		night_only = moment.night_only
		auto_start = moment.trigger == &"auto"
		if moment.trigger == &"enter" and get_node_or_null(^"Entry") == null:
			_add_entry(moment.entry_radius)
	super._ready()
	EventBus.creature_killed.connect(_on_creature_killed)


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event.is_action_pressed(&"interact"):
		if running:
			_presses += 1
		elif moment and moment.trigger == &"interact" and player_within(moment.entry_radius):
			start()


## Counts an interaction (input or tests).
func press_interact() -> void:
	_presses += 1


func presses() -> int:
	return _presses


func player_within(radius: float, target: Node3D = null) -> bool:
	var p := player()
	if p == null:
		return false
	var at := (target if target else self).global_position
	return p.global_position.distance_to(at) <= radius


func actor(actor_id: String) -> Node3D:
	if actor_id == "self" or actor_id == "":
		return self
	var node: Node3D = actors.get(actor_id)
	if node and is_instance_valid(node):
		return node
	return get_tree().get_first_node_in_group(StringName("story_actor_%s" % actor_id)) as Node3D


## Seconds of the current frame that Feyre spends looking at `target`.
func is_looking_at(target: Node3D, cone_deg: float) -> bool:
	if target == null:
		return false
	var dir: Vector3
	var from: Vector3
	if gaze_override.is_valid():
		var g: Array = gaze_override.call()
		from = g[0]
		dir = g[1]
	else:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return false
		from = cam.global_position
		dir = -cam.global_basis.z
	var to := (target.global_position - from).normalized()
	return rad_to_deg(dir.angle_to(to)) <= cone_deg


## Ends the scene without its deed (a failed gaze or a broken hiding).
func abort(fail_fact: String = "") -> void:
	if fail_fact != "":
		raise(fail_fact)
	failed.emit(fail_fact)
	running = false
	StoryControl.release()
	EventBus.mood_requested.emit(&"calm", 0.0, 2.0)
	EventBus.scene_space_finished.emit(space_id)


## The story flags the moment raises; for a moment that only records facts
## (a hall mark, the rose thorn), those facts.
func _gate_flags() -> PackedStringArray:
	var story := PackedStringArray()
	var facts := PackedStringArray()
	for step in moment.steps:
		if step.get("do") == "raise":
			var flag := String(step.get("flag", ""))
			(facts if flag.begins_with("fact.") else story).append(flag)
	return story if not story.is_empty() else facts


func _add_entry(radius: float) -> void:
	var area := Area3D.new()
	area.name = "Entry"
	area.collision_layer = 0
	area.collision_mask = 1 << 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)


func _build_beats() -> Array:
	kills.clear()
	_presses = 0
	var out: Array = []
	for step in moment.steps:
		var beat := _beat_for(step)
		if beat:
			out.append(beat)
	return out


func _beat_for(step: Dictionary) -> SceneBeat:
	var s := float(step.get("s", 0.0))
	match String(step.get("do", "")):
		"control":
			var mode: StoryControl.Mode = StoryControl.Mode[String(step.get("mode", "FULL"))]
			var focus_id := String(step.get("focus", ""))
			var allow := PackedStringArray(step.get("allow", []))
			return Beats.run(func(_sp: SceneSpace) -> void:
				StoryControl.set_mode(mode, allow)
				StoryControl.set_focus(actor(focus_id) if focus_id != "" else null), "control %s" % step.get("mode"))
		"spawn":
			return Beats.run(func(_sp: SceneSpace) -> void: _spawn(step), "spawn %s" % step.get("actor"))
		"despawn":
			return Beats.run(func(_sp: SceneSpace) -> void:
				var node := actor(String(step.get("actor")))
				if node and node != self and actors.has(String(step.get("actor"))):
					node.queue_free()
				actors.erase(String(step.get("actor"))), "despawn")
		"wait":
			return Beats.wait(s)
		"cue":
			return Beats.cue(StringName(step.get("actor", "")), StringName(step.get("cue", "")))
		"mood":
			return Beats.mood(StringName(step.get("mood", "dread")), float(step.get("i", 1.0)),
					float(step.get("s", 1.5)), float(step.get("shake", 0.0)))
		"celebrate":
			return Beats.run(func(_sp: SceneSpace) -> void:
				EventBus.celebration_requested.emit(StringName(step.get("kind", "deed")), global_position), "celebrate")
		"weather":
			return Beats.run(func(_sp: SceneSpace) -> void:
				EventBus.weather_requested.emit(StringName(step.get("w", "clear")), s), "weather")
		"grade":
			return Beats.run(func(_sp: SceneSpace) -> void:
				EventBus.grade_swap_requested.emit(StringName(step.get("to", "spring")), s if s > 0.0 else 2.0), "grade")
		"grant":
			return Beats.run(func(_sp: SceneSpace) -> void:
				EventBus.story_item_granted.emit(StringName(step.get("item", "")), int(step.get("n", 1))), "grant")
		"journal":
			return Beats.run(func(_sp: SceneSpace) -> void:
				EventBus.journal_entry_added.emit(StringName(step.get("entry", ""))), "journal")
		"travel":
			return Beats.run(func(_sp: SceneSpace) -> void:
				EventBus.travel_requested.emit(StringName(step.get("region", "")), StringName(step.get("anchor", ""))), "travel")
		"raise":
			return Beats.raise(String(step.get("flag", "")))
		"until_flag":
			return Beats.until_flag(String(step.get("flag", "")))
		"until_killed":
			var kind := String(step.get("kind", ""))
			var n := int(step.get("n", 1))
			return Beats.until(func() -> bool: return int(kills.get(kind, 0)) >= n, "until %d %s" % [n, kind])
		"interact":
			var n := int(step.get("n", 1))
			return InteractBeat.new(n, float(step.get("r", 4.0)))
		"stay":
			return StayBeat.new(s, float(step.get("r", 4.0)), String(step.get("near", "self")),
					bool(step.get("strict", false)), String(step.get("fail_fact", "")))
		"gaze_avoid":
			return GazeBeat.new(String(step.get("actor", "")), s, float(step.get("cone", 35.0)),
					float(step.get("max", 1.0)), String(step.get("fail_fact", "")), true)
		"gaze_hold":
			return GazeBeat.new(String(step.get("actor", "self")), s, float(step.get("cone", 25.0)),
					0.0, "", false)
		"decision":
			return Beats.decision(step.get("options", []), s, String(step.get("default", "")))
	push_error("MomentSpace %s: unknown step %s" % [space_id, step])
	return null


func _spawn(step: Dictionary) -> void:
	var actor_id := String(step.get("actor", ""))
	var origin: Vector3 = global_transform * (step.get("at", Vector3.ZERO) as Vector3)
	var face: Vector3 = global_transform * (step.get("face", Vector3.ZERO) as Vector3)
	var xform := Transform3D(Basis.IDENTITY, origin)
	if not origin.is_equal_approx(face):
		xform = xform.looking_at(Vector3(face.x, origin.y, face.z), Vector3.UP)
	actors[actor_id] = request_actor(StringName(actor_id), xform, func() -> Node3D: return StandIns.figure(actor_id))


func _on_creature_killed(_id: StringName, kind: StringName, _cause: StringName, _at: Vector3) -> void:
	if running:
		kills[String(kind)] = int(kills.get(String(kind), 0)) + 1


class InteractBeat:
	extends SceneBeat
	var needed: int
	var radius: float
	var _start: int

	func _init(n: int, r: float) -> void:
		needed = n
		radius = r
		label = "interact x%d" % n

	func enter(space: SceneSpace) -> void:
		_start = (space as MomentSpace).presses()

	func tick(space: SceneSpace, _delta: float) -> bool:
		return (space as MomentSpace).presses() - _start >= needed


class StayBeat:
	extends SceneBeat
	var seconds: float
	var radius: float
	var near: String
	var strict: bool
	var fail_fact: String
	var _held: float = 0.0

	func _init(s: float, r: float, n: String, st: bool, f: String) -> void:
		seconds = s
		radius = r
		near = n
		strict = st
		fail_fact = f
		label = "stay %.0f s" % s

	func consumes_time() -> bool:
		return true

	func enter(_space: SceneSpace) -> void:
		_held = 0.0

	func tick(space: SceneSpace, delta: float) -> bool:
		var ms := space as MomentSpace
		if ms.player_within(radius, ms.actor(near)):
			_held += delta
		elif strict:
			ms.abort(fail_fact)
			return false
		return _held >= seconds


class GazeBeat:
	extends SceneBeat
	var target: String
	var seconds: float
	var cone: float
	var max_look: float
	var fail_fact: String
	var avoid: bool
	var _elapsed: float = 0.0
	var _looked: float = 0.0

	func _init(t: String, s: float, c: float, m: float, f: String, a: bool) -> void:
		target = t
		seconds = s
		cone = c
		max_look = m
		fail_fact = f
		avoid = a
		label = ("don't look at %s" if a else "look at %s") % t

	func consumes_time() -> bool:
		return true

	func enter(_space: SceneSpace) -> void:
		_elapsed = 0.0
		_looked = 0.0

	func tick(space: SceneSpace, delta: float) -> bool:
		var ms := space as MomentSpace
		var looking := ms.is_looking_at(ms.actor(target), cone)
		if avoid:
			_elapsed += delta
			if looking:
				_looked += delta
				if _looked > max_look:
					ms.abort(fail_fact)
					return false
			return _elapsed >= seconds
		if looking:
			_looked += delta
		return _looked >= seconds
