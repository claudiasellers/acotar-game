## Drives Act I end to end through the signals other lanes will emit: food
## tally -> wolf -> skinning -> pelt sale -> beast at the door -> ride and
## wall crossing, and checks the ladder lands in p2_grounds.
extends GutTest

const PHASES := preload("res://data/phases/spring_court_phases.tres")
const STEP := 1.0 / 30.0

var root: Node3D
var feyre: Node3D
var tally: FoodTally
var wolf: WolfKill
var skinning: WolfSkinning
var sale: PeltSale
var beast: BeastDoor
var ride: RideNorth
var grade_requests: Array = []
var cues: Array = []


func _space(space: SceneSpace, at: Vector3) -> SceneSpace:
	space.auto_tick = false
	space.position = at
	root.add_child(space)
	return space


func _run(space: SceneSpace, seconds: float) -> void:
	var t := 0.0
	while t < seconds and space.running:
		space.tick(STEP)
		t += STEP


func before_each() -> void:
	WorldState.clear()
	WorldDeltas.clear()
	StoryControl.release()
	Clock.paused = true
	Clock.from_dict({"time_of_day": 0.45, "day": 1})
	PhaseManager.start(PHASES)
	grade_requests.clear()
	EventBus.grade_swap_requested.connect(_on_grade)
	cues.clear()
	EventBus.story_actor_cue.connect(_on_cue)
	root = Node3D.new()
	add_child_autofree(root)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	tally = _space(FoodTally.new(), Vector3.ZERO)
	wolf = _space(WolfKill.new(), Vector3(0, 0, -200))
	skinning = _space(WolfSkinning.new(), Vector3(0, 0, -200))
	sale = _space(PeltSale.new(), Vector3(150, 0, 0))
	beast = _space(BeastDoor.new(), Vector3.ZERO)
	ride = _space(RideNorth.new(), Vector3.ZERO)
	var path := Path3D.new()
	path.name = "RidePath"
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3.ZERO)
	path.curve.add_point(Vector3(0, 0, -120))
	ride.add_child(path)


func after_each() -> void:
	EventBus.grade_swap_requested.disconnect(_on_grade)
	EventBus.story_actor_cue.disconnect(_on_cue)
	StoryControl.release()
	Clock.paused = false


func _on_cue(actor: StringName, cue: StringName) -> void:
	cues.append([actor, cue])


func _on_grade(to_grade: StringName, seconds: float) -> void:
	grade_requests.append([to_grade, seconds])


func test_act_one_plays_through_to_the_grounds() -> void:
	assert_eq(PhaseManager.current_phase, &"p0_winter")

	# P0: the systems lane reports food; not enough, then enough.
	EventBus.food_stock_changed.emit(3.0)
	assert_false(tally.running)
	assert_eq(tally.notch_count(), 3)
	EventBus.food_stock_changed.emit(7.5)
	assert_true(tally.running)
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK)
	_run(tally, 5.0)
	assert_eq(PhaseManager.current_phase, &"p1_wolf_and_crossing")
	assert_true(PhaseManager.is_region_unlocked(&"border_woods"))

	# The wolf: the ash arrow is granted, a wood arrow does not kill him.
	watch_signals(EventBus)
	assert_true(wolf.start())
	assert_signal_emitted_with_parameters(EventBus, "story_item_granted", [&"arrow_ash", 1])
	_run(wolf, 6.0)
	assert_not_null(wolf.wolf, "a wolf (stand-in) is in the clearing")
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL, "free to take the shot")
	EventBus.creature_killed.emit(&"andras", &"great_wolf", &"arrow_wood", Vector3.ZERO)
	_run(wolf, 1.0)
	assert_false(WorldState.has_flag("wolf_killed"), "wood does not kill a High Fae")
	EventBus.creature_killed.emit(&"andras", &"great_wolf", &"arrow_ash", Vector3.ZERO)
	_run(wolf, 5.0)
	assert_true(WorldState.has_flag("wolf_killed"))
	assert_false(wolf.running)

	# Skinning and the sale.
	EventBus.creature_harvested.emit(&"andras", &"great_wolf", PackedStringArray(["obj_wolf_pelt"]))
	_run(skinning, 5.0)
	assert_true(WorldState.has_flag("fact.wolf_skinned"))
	EventBus.item_sold.emit(&"ing_wolf_pelt", 4)
	assert_false(sale.running, "an ordinary pelt is not Andras's")
	EventBus.item_sold.emit(&"obj_wolf_pelt", 40)
	_run(sale, 5.0)
	assert_true(WorldState.has_flag("pelt_sold"))

	# The beast: only at night, only with Feyre home.
	beast.set_player_inside(true)
	assert_false(beast.can_start(), "daytime")
	Clock.from_dict({"time_of_day": 0.92, "day": 2})
	assert_true(beast.start())
	_run(beast, 5.0)
	assert_true(WorldState.has_flag("fact.cottage_door_broken"))
	assert_eq(WorldDeltas.get_region_value(&"cottage", "door"), "broken")
	assert_true(cues.has([&"family", &"gather"]))
	assert_true(cues.has([&"tamlin_beast", &"enter"]))
	assert_true(beast.current_beat_label().begins_with("decision"))
	beast.choose(&"interact")
	_run(beast, 10.0)
	assert_eq(beast.chosen_fact, "fact.beast_door.raised_knife")
	assert_true(WorldState.has_flag("beast_claim_accepted"))

	# The ride and the wall.
	assert_true(ride.start())
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK)
	_run(ride, 60.0)
	assert_eq(grade_requests, [[&"spring", 2.0]])
	assert_true(WorldState.has_flag("wall_crossed"))
	assert_false(ride.running)
	assert_almost_eq(feyre.global_position.z, -120.0, 0.5, "she rode to the end of the line")
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL)

	assert_eq(PhaseManager.current_phase, &"p2_grounds")
