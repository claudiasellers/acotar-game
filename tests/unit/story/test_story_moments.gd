## Every StoryMoment in data/story/moments plays to its deed, the horror
## failures fail, and the moments chain through phases 2 to 8 in book order.
extends GutTest

const PHASES := preload("res://data/phases/spring_court_phases.tres")
const STEP := 0.1
const BOOK_ORDER := [
	"first_dinner", "curtain_trap", "bogge", "puca",
	"wound_dressing", "hall_mark_1", "hall_mark_2", "hall_mark_3", "hall_mark_4", "hall_mark_5",
	"manor_map", "study_mural", "suriel", "naga", "summer_faerie",
	"starlight_pool", "gallery", "first_painting", "attor",
	"calanmai_fires", "cave_mouth", "bite", "paintings_shown",
	"glamour_lift", "fountain_head", "solstice", "rhysand_visit", "sent_home",
	"nesta_truth", "beddor_fire", "wall_recross",
	"alis_truth", "departure",
]

var root: Node3D
var feyre: Node3D


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	Clock.paused = true
	root = Node3D.new()
	add_child_autofree(root)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	# The director's own global moments would race the ones under test.
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = false


func after_each() -> void:
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = true
	StoryControl.release()
	Clock.paused = false


func _space(moment: StoryMoment) -> MomentSpace:
	Clock.from_dict({"time_of_day": 0.95 if moment.night_only else 0.5, "day": 1})
	var space := MomentSpace.new()
	space.moment = moment
	space.auto_tick = false
	space.position = Vector3(40, 0, 40)
	root.add_child(space)
	feyre.global_position = space.global_position
	return space


## Plays a moment the way a player who does the deed would: stays close,
## presses E, looks where the scene asks (and away from the Bogge), kills
## the naga. Returns false if it never finished.
func _autoplay(space: MomentSpace, avoid_gaze: bool = true) -> bool:
	space.gaze_override = func() -> Array:
		var beat: SceneBeat = space.beats[space.beat_index] if space.running else null
		var from := feyre.global_position + Vector3.UP * 1.6
		if beat is MomentSpace.GazeBeat:
			var target := space.actor((beat as MomentSpace.GazeBeat).target)
			var to := (target.global_position - from).normalized() if target else Vector3.FORWARD
			return [from, -to if (beat as MomentSpace.GazeBeat).avoid and avoid_gaze else to]
		return [from, Vector3.FORWARD]
	if not space.running and not space.start():
		return false
	for _i in 3000:
		if not space.running:
			return true
		var beat: SceneBeat = space.beats[space.beat_index]
		if beat is MomentSpace.StayBeat:
			var near := space.actor((beat as MomentSpace.StayBeat).near)
			feyre.global_position = near.global_position if near else space.global_position
		elif beat is MomentSpace.InteractBeat:
			space.press_interact()
		elif beat.label.begins_with("until "):
			var rest := beat.label.trim_prefix("until ")
			if rest == "1 naga":
				EventBus.creature_killed.emit(&"n1", &"naga", &"arrow_wood", Vector3.ZERO)
			elif not rest.contains(" "):
				WorldState.set_flag(rest)
		space.tick(STEP)
	return not space.running


func _gate_flags(moment: StoryMoment) -> PackedStringArray:
	var flags := PackedStringArray()
	for step in moment.steps:
		if step.get("do") == "raise":
			flags.append(String(step["flag"]))
	return flags


func test_every_moment_plays_to_its_deed() -> void:
	assert_eq(StoryDirector.moments.size(), BOOK_ORDER.size() + 1, "34 moments (rose_thorn is optional)")
	for moment in StoryDirector.moments:
		before_each_moment()
		for flag in moment.require_flags:
			WorldState.set_flag(flag)
		var space := _space(moment)
		assert_true(_autoplay(space), "%s finishes" % moment.id)
		for flag in _gate_flags(moment):
			assert_true(WorldState.has_flag(flag), "%s raises %s" % [moment.id, flag])
		assert_false(space.can_start(), "%s does not replay" % moment.id)
		space.free()


func before_each_moment() -> void:
	WorldState.clear()
	StoryControl.release()


func test_looking_at_the_bogge_fails_the_scene() -> void:
	var moment := StoryDirector.get_moment(&"bogge")
	WorldState.set_flag("first_dinner_eaten")
	var space := _space(moment)
	_autoplay(space, false)
	assert_false(space.running)
	assert_true(WorldState.has_flag("fact.bogge_looked"))
	assert_false(WorldState.has_flag("bogge_survived"))
	assert_true(space.can_start(), "she can try again")


func test_leaving_the_hiding_spot_is_seen_by_the_attor() -> void:
	var moment := StoryDirector.get_moment(&"attor")
	WorldState.set_flag("first_painting")
	var space := _space(moment)
	space.start()
	for _i in 200:
		if not space.running:
			break
		if space.current_beat_label().begins_with("stay"):
			feyre.global_position = space.global_position + Vector3(10, 0, 0)
		space.tick(STEP)
	assert_true(WorldState.has_flag("fact.attor_detected"))
	assert_false(WorldState.has_flag("attor_evaded"))


func test_director_hangs_moments_on_anchors() -> void:
	assert_eq(StoryDirector.anchor_ids().size(), 30)
	var anchor := Marker3D.new()
	anchor.name = "manor_infirmary"
	anchor.add_to_group(&"story_anchor")
	root.add_child(anchor)
	var spaces := StoryDirector.attach_anchor(anchor)
	assert_eq(spaces.size(), 2, "the bandaging and the Summer faerie share the infirmary")
	assert_eq(StoryDirector.attach_anchor(anchor).size(), 2)
	assert_eq(anchor.get_child_count(), 2, "attaching twice adds nothing")


func test_moments_chain_from_the_grounds_to_the_pass() -> void:
	PhaseManager.start(PHASES, &"p2_grounds")
	WorldState.set_flag("wall_crossed")
	for id in BOOK_ORDER:
		var moment := StoryDirector.get_moment(StringName(id))
		var space := _space(moment)
		assert_true(space.can_start(), "%s is open after the moments before it" % id)
		assert_true(_autoplay(space), "%s finishes" % id)
		space.free()
	assert_eq(PhaseManager.current_phase, &"p8_the_pass")
	assert_true(WorldState.has_flag("departed_for_mountain"))
	assert_true(PHASES.get_phase(&"p8_the_pass").exit_condition.evaluate(WorldState.has_flag))
