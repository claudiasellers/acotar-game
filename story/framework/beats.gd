## The beat vocabulary for scene spaces. Build a scene as a list:
##
##   return [
##       Beats.control(StoryControl.Mode.LOOK, doe),
##       Beats.wait(2.0),
##       Beats.until_flag("wolf_killed"),
##       Beats.raise("pelt_sold"),
##   ]
class_name Beats
extends RefCounted


static func wait(seconds: float) -> SceneBeat:
	return WaitBeat.new(seconds)


## Limits Feyre's control and points the camera at `focus` (null for none).
static func control(mode: StoryControl.Mode, focus: Node3D = null,
		allowed: PackedStringArray = PackedStringArray()) -> SceneBeat:
	return ControlBeat.new(mode, focus, allowed)


static func until_flag(flag: String) -> SceneBeat:
	return UntilBeat.new(func() -> bool: return WorldState.has_flag(flag), "until %s" % flag)


static func until(condition: Callable, label: String = "until") -> SceneBeat:
	return UntilBeat.new(condition, label)


## Raises a flag through the space's ActionTrigger for it.
static func raise(flag: String) -> SceneBeat:
	return DoBeat.new(func(space: SceneSpace) -> void: space.raise(flag), "raise %s" % flag)


static func cue(actor: StringName, cue_name: StringName) -> SceneBeat:
	return DoBeat.new(func(_space: SceneSpace) -> void: EventBus.story_actor_cue.emit(actor, cue_name),
			"cue %s %s" % [actor, cue_name])


## Sets the scene mood (lighting, sound) and camera shake. Horror is staged
## with dread, never toned down.
static func mood(mood_name: StringName, intensity: float, seconds: float = 1.5, shake: float = 0.0) -> SceneBeat:
	return DoBeat.new(func(space: SceneSpace) -> void:
		space.note_mood()
		StoryControl.shake = shake
		EventBus.mood_requested.emit(mood_name, intensity, seconds), "mood %s" % mood_name)


## Runs a function once. It receives the SceneSpace.
static func run(fn: Callable, label: String = "run") -> SceneBeat:
	return DoBeat.new(fn, label)


## A decision window: the first listed action Feyre performs within
## `seconds` is the choice; otherwise `default_fact`. Each option is
## {"action": &"interact", "fact": "fact.beast_door.raised_knife"}.
## The chosen fact is raised; the scene continues either way.
static func decision(options: Array, seconds: float, default_fact: String) -> SceneBeat:
	return DecisionBeat.new(options, seconds, default_fact)


class WaitBeat:
	extends SceneBeat

	func consumes_time() -> bool:
		return true

	var seconds: float
	var _left: float

	func _init(s: float) -> void:
		seconds = s
		label = "wait %.1f" % s

	func enter(_space: SceneSpace) -> void:
		_left = seconds

	func tick(_space: SceneSpace, delta: float) -> bool:
		_left -= delta
		return _left <= 0.0


class ControlBeat:
	extends SceneBeat
	var mode: StoryControl.Mode
	var focus: Node3D
	var allowed: PackedStringArray

	func _init(m: StoryControl.Mode, f: Node3D, a: PackedStringArray) -> void:
		mode = m
		focus = f
		allowed = a
		label = "control %s" % StoryControl.Mode.keys()[m]

	func enter(_space: SceneSpace) -> void:
		StoryControl.set_mode(mode, allowed)
		StoryControl.set_focus(focus)


class UntilBeat:
	extends SceneBeat
	var condition: Callable

	func _init(c: Callable, l: String) -> void:
		condition = c
		label = l

	func tick(_space: SceneSpace, _delta: float) -> bool:
		return bool(condition.call())


class DoBeat:
	extends SceneBeat
	var fn: Callable

	func _init(f: Callable, l: String) -> void:
		fn = f
		label = l

	func enter(space: SceneSpace) -> void:
		fn.call(space)


class DecisionBeat:
	extends SceneBeat

	func consumes_time() -> bool:
		return true

	var options: Array
	var seconds: float
	var default_fact: String
	var chosen_fact: String = ""
	var _left: float

	func _init(o: Array, s: float, d: String) -> void:
		options = o
		seconds = s
		default_fact = d
		label = "decision %.1f s" % s

	func enter(space: SceneSpace) -> void:
		_left = seconds
		chosen_fact = ""
		space.clear_choice()

	func tick(space: SceneSpace, delta: float) -> bool:
		var action := space.last_choice()
		if action != &"":
			for option: Dictionary in options:
				if option.get("action") == action:
					chosen_fact = String(option.get("fact", ""))
					return true
		_left -= delta
		if _left <= 0.0:
			chosen_fact = default_fact
			return true
		return false

	func exit(space: SceneSpace) -> void:
		space.decision_made.emit(chosen_fact)
		if chosen_fact != "":
			space.raise(chosen_fact)
