## L25 contract: the puca (docs/contracts/act2.md, moment `puca`).
## At night after the Bogge, her silent father limps ahead of her to the open
## gate, never within reach; Tamlin stops her; it changes shape only while
## she looks, in the book's order; then it darts and puca_resisted is raised.
## Walking away from it lets her go without the deed.
extends GutTest

const DT := 0.1

var root: Node3D
var feyre: Node3D
var looking := true
var space: PucaLure


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	Clock.paused = true
	looking = true
	root = Node3D.new()
	add_child_autofree(root)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = false
	space = Act2Spaces.space_for(StoryDirector.get_moment(&"puca")) as PucaLure
	space.auto_tick = false
	space.position = Vector3(12, 0, -30)
	space.rotation.y = -0.4
	root.add_child(space)
	space.gaze_override = _gaze
	feyre.global_position = space.mark(&"house")


func after_each() -> void:
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = true
	StoryControl.release()
	Clock.paused = false


func _night() -> void:
	WorldState.set_flag("bogge_survived")
	Clock.from_dict({"time_of_day": 0.95, "day": 3})


func _gaze() -> Array:
	var from := feyre.global_position + Vector3.UP * 1.6
	var p := space.puca()
	var at := p.global_position + Vector3.UP * 1.2 if looking and p else from - (space.mark(&"gate") - from)
	return [from, (at - from).normalized()]


func _step(seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.001:
		space.tick(DT)
		var p := space.puca()
		if p:
			p._process(DT)
		t += DT


func _run_until(label: String, limit: float = 30.0) -> bool:
	var t := 0.0
	while space.running and space.current_beat_label() != label and t < limit:
		_step(DT)
		t += DT
	return space.current_beat_label() == label


## Walks her after her father at a brisk pace; returns the closest she got.
func _follow_to_gate() -> float:
	var closest := 999.0
	var t := 0.0
	while space.current_beat_label() == "follow him to the gate" and t < 150.0:
		var to := space.puca().global_position - feyre.global_position
		to.y = 0.0
		if to.length() > 0.05:
			feyre.global_position += to.normalized() * minf(1.6 * DT, to.length())
		_step(DT)
		t += DT
		var p := space.puca()
		if p and t > 3.0:
			closest = minf(closest, Vector2(p.global_position.x - feyre.global_position.x, p.global_position.z - feyre.global_position.z).length())
	return closest


func test_registered_night_only_after_the_bogge() -> void:
	assert_true(Act2Spaces.coded_ids().has("puca"))
	assert_true(space.night_only)
	assert_eq(space.require_flags, PackedStringArray(["bogge_survived"]))
	assert_eq(space.done_flags, PackedStringArray(["puca_resisted"]))
	WorldState.set_flag("bogge_survived")
	Clock.from_dict({"time_of_day": 0.5, "day": 3})
	assert_false(space.can_start(), "not by day")
	assert_true(space._player_here(), "she is in the garden under her window")


func test_father_leads_her_to_the_gate_and_she_looks_again() -> void:
	_night()
	assert_true(space.start())
	var p := space.puca()
	assert_not_null(p, "the real puca")
	assert_eq(p.showing, &"father", "first her father")
	assert_eq(StoryControl.mode, StoryControl.Mode.WALK)
	var closest := _follow_to_gate()
	assert_gt(closest, 5.0, "always just out of reach (closest %.1f m)" % closest)
	assert_eq(space.current_beat_label(), "say tamlin_going", "Tamlin catches her at the gate")
	assert_not_null(space.actor(&"tamlin"))
	assert_lt(space.actor(&"tamlin").global_position.distance_to(feyre.global_position), 1.5, "at her side")
	assert_true(_run_until("look again"))
	# Looking away, nothing happens: seeing it is her deed.
	looking = false
	_step(5.0)
	assert_eq(space.shifts_seen.size(), 0, "no shift while she looks away")
	looking = true
	var t := 0.0
	while space.current_beat_label() == "look again" and t < 20.0:
		_step(DT)
		t += DT
	assert_lt(t, 4 * PucaLure.LOOK_PER_SHIFT + 1.0, "four shifts while she holds her look")
	_step(0.3)
	assert_eq(space.puca().showing, &"father", "a flawless rendering, before it goes")
	assert_eq(space.shifts_seen, [&"bow", &"supplies", &"sisters", &"father"] as Array[StringName])
	_step(10.0)
	assert_false(space.running)
	assert_true(WorldState.has_flag("puca_resisted"))
	assert_not_null(space.get_node_or_null(^"Raise_puca_resisted") as ActionTrigger, "raised by an ActionTrigger")
	assert_false(space.can_start(), "never replays")


func test_walking_away_lets_her_go_without_the_deed() -> void:
	_night()
	assert_true(space.start())
	_step(1.0)
	feyre.global_position = space.mark(&"house") + (space.mark(&"house") - space.mark(&"gate")).normalized() * 50.0
	_step(0.5)
	assert_false(space.running)
	assert_eq(space.lost_count, 1)
	assert_false(WorldState.has_flag("puca_resisted"))
	assert_true(space.can_start(), "it will come again")
