## L25 contract: the Bogge (docs/contracts/act2.md, moment `bogge`).
## Eyes ahead to the end raises bogge_survived once; lingering on it 0.8 s
## makes it real, ends the attempt with fact.bogge_looked and puts her back
## up the path; a glance survives but the fog it raises stays.
extends GutTest

const DT := 0.1

var root: Node3D
var feyre: Node3D
var look_at_bogge := false
var space: BoggeHunt


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	Clock.paused = true
	look_at_bogge = false
	root = Node3D.new()
	add_child_autofree(root)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = false
	space = Act2Spaces.space_for(StoryDirector.get_moment(&"bogge")) as BoggeHunt
	space.auto_tick = false
	space.position = Vector3(-40, 0, 25)
	space.rotation.y = 0.7
	root.add_child(space)
	space.gaze_override = _gaze
	feyre.global_position = space.global_position


func after_each() -> void:
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = true
	StoryControl.release()
	Clock.paused = false


## Feyre stares at the elm, or (look_at_bogge) turns to it.
func _gaze() -> Array:
	var from := feyre.global_position + Vector3.UP * 1.6
	var b := space.bogge()
	var at := (b.global_position + Vector3.UP * 1.2) if look_at_bogge and b else space.mark(&"elm") + Vector3.UP * 3.0
	return [from, (at - from).normalized()]


func _step(seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.001:
		space.tick(DT)
		var b := space.bogge()
		if b:
			b._process(DT)
		t += DT


func _run_until(label: String, limit: float = 30.0) -> bool:
	var t := 0.0
	while space.running and space.current_beat_label() != label and t < limit:
		_step(DT)
		t += DT
	return space.current_beat_label() == label


func _to_the_freeze() -> void:
	assert_true(space.start(), "starts once the first dinner is eaten")
	assert_true(_run_until("reach freeze"))
	feyre.global_position = space.mark(&"freeze")
	assert_true(_run_until("it passes behind her"), "Lucien's warning, then the Bogge comes")


func test_registered_with_its_stage_and_gate() -> void:
	assert_true(Act2Spaces.coded_ids().has("bogge"))
	assert_not_null(space.stage)
	assert_eq(space.require_flags, PackedStringArray(["first_dinner_eaten"]))
	assert_eq(space.done_flags, PackedStringArray(["bogge_survived"]))
	assert_true(space.day_only, "a day hunt: dusk brings the morning to her")
	assert_false(space.can_start())
	for id in space.stage.invented:
		assert_true(space.stage.lines.has(id), "invented line %s exists" % id)


func test_eyes_ahead_survives_it() -> void:
	WorldState.set_flag("first_dinner_eaten")
	_to_the_freeze()
	assert_eq(space.current_beat_label(), "it passes behind her")
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK, "frozen: only her eyes move")
	var b := space.bogge()
	assert_not_null(b, "the real Bogge, not a stand-in")
	var ahead := space.mark(&"elm") - space.mark(&"freeze")
	var worst := 180.0
	var t := 0.0
	while space.current_beat_label() == "it passes behind her" and t < 30.0:
		_step(DT)
		t += DT
		if t > 1.5:
			var off := b.global_position - space.mark(&"freeze")
			worst = minf(worst, rad_to_deg(Vector3(ahead.x, 0, ahead.z).angle_to(Vector3(off.x, 0, off.z))))
	assert_gt(worst, 100.0, "it stays at her back (worst %.0f deg from ahead)" % worst)
	assert_eq(space.acknowledged, 0.0)
	assert_lt(b.reveal, 0.01, "never made real")
	assert_true(_run_until("reach safety"))
	_step(4.0)
	assert_true(space.running, "still at her back until she gets clear")
	feyre.global_position = space.mark(&"safety")
	_step(12.0)
	assert_false(space.running)
	assert_true(WorldState.has_flag("bogge_survived"))
	assert_false(WorldState.has_flag("fact.bogge_looked"))
	assert_not_null(space.get_node_or_null(^"Raise_bogge_survived") as ActionTrigger, "raised by an ActionTrigger")
	var distinct := {}
	for id in space.pleas_shown:
		distinct[id] = true
	assert_gte(distinct.size(), 4, "it begs in her head: %s" % [space.pleas_shown])
	assert_gte(space.thoughts_shown.size(), 2, "the elm brings pleasant thoughts: %s" % [space.thoughts_shown])
	assert_false(space.can_start(), "never replays")


func test_lingering_makes_it_real_and_she_tries_again() -> void:
	WorldState.set_flag("first_dinner_eaten")
	_to_the_freeze()
	_step(2.0)
	var fog_start := space.fog_density()
	look_at_bogge = true
	var looked := 0.0
	while space.watching and looked < 3.0:
		_step(DT)
		looked += DT
	assert_almost_eq(looked, BoggeHunt.MAX_LOOK, 0.11, "it fails at 0.8 s of looking")
	assert_gte(space.fog_density(), fog_start * 3.0, "the fog has thickened (%.3f -> %.3f)" % [fog_start, space.fog_density()])
	assert_eq(space.bogge().reveal, 1.0, "it is real")
	_step(3.0)
	assert_false(space.running, "the attempt is over")
	assert_true(WorldState.has_flag("fact.bogge_looked"))
	assert_false(WorldState.has_flag("bogge_survived"))
	assert_eq(space.fail_count, 1)
	var retry := space.mark(&"retry")
	assert_lt(Vector2(feyre.global_position.x - retry.x, feyre.global_position.z - retry.z).length(), 1.0, "back up the path")
	# Walk back in and keep her eyes ahead this time.
	look_at_bogge = false
	_to_the_freeze()
	_run_until("reach safety", 40.0)
	feyre.global_position = space.mark(&"safety")
	_step(12.0)
	assert_true(WorldState.has_flag("bogge_survived"), "the retry passes")


func test_a_glance_survives_but_the_fog_stays() -> void:
	WorldState.set_flag("first_dinner_eaten")
	_to_the_freeze()
	_step(2.0)
	look_at_bogge = true
	_step(0.3)
	look_at_bogge = false
	var after_glance := space.fog_density()
	assert_gt(space.bogge().reveal, 0.2, "a glance gives it shape")
	_step(4.0)
	assert_true(space.running, "a 0.3 s glance is survivable")
	assert_eq(space.fail_count, 0)
	assert_almost_eq(space.acknowledged, 0.0, 0.001, "it fades from her mind")
	assert_gt(space.scar, 0.25)
	var swell_only := 0.02 + 0.05 * sin(clampf(space.bogge().progress, 0.0, 1.0) * PI)
	assert_gt(space.fog_density(), swell_only + 0.015, "the fog a glance raised hasn't gone")
	assert_gt(after_glance, 0.02)
