## L82 contract (UX review G1, G6, G9): E never takes what her bags can't
## hold, and never silently does nothing at a station. Every manor station the
## house generators place either opens a screen, brews, or has a StationUse
## row; the rows do what they say (the bed calls VitalsState.rest()).
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")
const MANOR_GENERATORS := ["res://tools/manor_estate/gen_ground.gd", "res://tools/manor_estate/gen_service.gd",
	"res://tools/manor_estate/gen_upper.gd"]
## Waits out SleepFade (fade, hold, fade back) with a margin.
const FADE_WAIT := SleepFade.FADE * 2.4 + SleepFade.HOLD + 0.6

var hill: Node3D
var feyre: Feyre


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	feyre.set_physics_process(false)
	EventBus.mood_changed.emit(&"calm", 0.0, 0.0)
	await wait_physics_frames(5)


## Somewhere on the hill with nothing else in reach.
func _alone() -> void:
	feyre.global_position = Vector3(400.0, 80.0, 400.0)


func _fill_with(id: StringName) -> void:
	while Gameplay.inventory.add(id, 1) > 0:
		pass


func _station(id: StringName) -> ManorStation:
	var s := ManorStation.new()
	s.station_id = id
	hill.add_child(s)
	s.global_position = feyre.global_position + Vector3(1.0, 0, 0)
	return s


# --- G1: full bags -----------------------------------------------------------

func test_room_for_and_fits_add_nothing() -> void:
	var inv := Gameplay.inventory
	assert_eq(inv.room_for(&"ing_snowdrop", 3), 3)
	_fill_with(&"ing_snowdrop")
	var held := inv.count(&"ing_snowdrop")
	assert_eq(inv.room_for(&"ing_snowdrop"), 0)
	assert_false(inv.fits([{"item_id": &"ing_snowdrop", "qty": 1}]))
	assert_eq(inv.count(&"ing_snowdrop"), held, "asking takes nothing")
	assert_true(inv.fits([]))


func test_full_bags_leave_the_flower_growing_and_say_so() -> void:
	var field := hill.get_node("GameplaySandbox/Forage_ing_snowdrop") as ForageScatter
	feyre.global_position = field.global_transform * field.multimesh.get_instance_transform(0).origin
	_fill_with(&"ing_snowdrop")
	var held := Gameplay.inventory.count(&"ing_snowdrop")
	watch_signals(Gameplay.inventory)
	assert_true(feyre.interactor.interact(), "E answers")
	assert_eq(Gameplay.inventory.count(&"ing_snowdrop"), held, "nothing lost, nothing gained")
	for i in field.multimesh.instance_count:
		assert_false(Gameplay.forage.is_picked(&"test_hill", "%s:%d" % [field.name, i]), "the flower still grows")
	assert_signal_emitted(Gameplay.inventory, "refused", "the satchel glyph is told")
	var pickup_log := PickupLog.of(get_tree())
	assert_true(" ".join(pickup_log.lines()).contains("No room") or pickup_log.waiting() > 0, "she says so in the log")
	Gameplay.inventory.remove(&"ing_snowdrop", 1)
	assert_true(feyre.interactor.interact())
	assert_eq(Gameplay.inventory.count(&"ing_snowdrop"), held, "with room again, E picks it")


func test_full_bags_leave_the_carcass_unskinned() -> void:
	_alone()
	var carcass := Harvestable.new()
	carcass.setup(&"hare", &"animal", [{"item_id": &"ing_snowdrop", "qty": 1}] as Array[Dictionary])
	hill.add_child(carcass)
	carcass.global_position = feyre.global_position + Vector3(1, 0, 0)
	_fill_with(&"ing_snowdrop")
	assert_eq(String(feyre.interactor.target().verb), "skin the hare")
	assert_true(feyre.interactor.interact())
	assert_false(carcass.is_harvested, "the kill waits for room")


func test_full_quiver_leaves_the_arrow_and_falls_through() -> void:
	_alone()
	_fill_with(&"arrow_wood")
	var arrow := Arrow.create(null)
	hill.add_child(arrow)
	arrow.global_position = feyre.global_position + Vector3(1, 0.2, 0)
	arrow.add_to_group(Arrow.STUCK_GROUP)
	var piano := _station(&"pianoforte")
	assert_eq(feyre.interactor.target().kind, &"station", "a target that doesn't fit gives way")
	assert_true(feyre.interactor.interact())
	assert_true(arrow.is_in_group(Arrow.STUCK_GROUP), "the arrow stays where it is")
	piano.queue_free()
	await wait_process_frames(1)
	assert_true(feyre.interactor.interact(), "alone, the arrow gets the no-room answer")
	assert_true(is_instance_valid(arrow) and arrow.is_in_group(Arrow.STUCK_GROUP))


# --- G6: no dead stations ----------------------------------------------------

func test_every_manor_station_does_something() -> void:
	var re := RegEx.new()
	re.compile("dsl\\.station\\(&\"(\\w+)\"")
	var ids := {}
	for path: String in MANOR_GENERATORS:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			ids[StringName(m.get_string(1))] = true
	assert_gt(ids.size(), 10, "found the manor's stations")
	for id: StringName in ids:
		var probe := ManorStation.new()
		probe.station_id = id
		var opens := Interactor.DRESSING_STATIONS.has(id) or id == &"easel" \
				or ChemistryStations.data_for(probe, id) != null or StationUses.of(id) != null
		assert_true(opens, "%s does something on E" % id)
		probe.free()


func test_rows_are_complete() -> void:
	for id: StringName in [&"pianoforte", &"harp", &"library_desk", &"armory_rack", &"infirmary", &"bed", &"bath"]:
		var row := StationUses.of(id)
		assert_not_null(row, "%s has a row" % id)
		if row:
			assert_ne(row.verb, "", "%s has a verb" % id)
			assert_false(row.lines.is_empty(), "%s has her thoughts" % id)


func test_a_station_with_no_use_is_not_a_target() -> void:
	_alone()
	_station(&"nothing_here")
	assert_true(feyre.interactor.target().is_empty())
	assert_false(feyre.interactor.interact(), "E is not swallowed")


func test_the_prompt_names_the_use() -> void:
	_alone()
	_station(&"pianoforte")
	await wait_seconds(Interactor.PROMPT_REFRESH * 2.0 + 0.05)
	var offer := UsePrompt.of(get_tree()).offered()
	assert_eq(String(offer[0][0]) if not offer.is_empty() else "", "play a few notes")


func test_letters_wait_for_p3_and_count_once_a_day() -> void:
	_alone()
	_station(&"library_desk")
	assert_true(feyre.interactor.target().is_empty(), "shut before p3 (Keeper: ch 13)")
	PhaseManager.current_phase = &"p3_house_and_woods"
	assert_true(feyre.interactor.interact())
	assert_eq(int(WorldState.get_flag(StationUses.FACT_LETTERS, 0)), 1)
	assert_true(feyre.interactor.interact())
	assert_eq(int(WorldState.get_flag(StationUses.FACT_LETTERS, 0)), 1, "once a day")


func test_the_rack_fills_her_quiver_to_ten_once_a_day() -> void:
	_alone()
	Gameplay.inventory.remove(&"arrow_wood", 999)
	Gameplay.inventory.add(&"arrow_wood", 3)
	_station(&"armory_rack")
	assert_true(feyre.interactor.interact())
	assert_eq(Gameplay.inventory.count(&"arrow_wood"), 10)
	Gameplay.inventory.remove(&"arrow_wood", 5)
	assert_true(feyre.interactor.interact())
	assert_eq(Gameplay.inventory.count(&"arrow_wood"), 5, "the rack is for once a day")


func test_the_infirmary_mends_her() -> void:
	_alone()
	var vitals := Vitals.of(feyre)
	vitals.health = 40.0
	_station(&"infirmary")
	assert_true(feyre.interactor.interact())
	await wait_seconds(0.5)
	assert_gt(vitals.health, 40.0)


func test_a_night_in_her_bed_rests_her_until_morning() -> void:
	_alone()
	var vitals := Vitals.of(feyre)
	vitals.health = 30.0
	Clock.time_of_day = 22.0 / 24.0
	var day := Clock.day
	_station(&"bed")
	assert_eq(String(feyre.interactor.target().verb), "sleep")
	assert_true(feyre.interactor.interact())
	await wait_seconds(FADE_WAIT)
	assert_eq(vitals.health, VitalsState.MAX_HEALTH, "VitalsState.rest() ran")
	assert_eq(Clock.day, day + 1)
	assert_almost_eq(Clock.hour(), StationUses.MORNING, 0.2)
	assert_gt(vitals.well_rested_left, 0.0, "every night in her bed leaves her Well rested (the user, 2026-11-24)")
	assert_true(StoryControl.holders().is_empty(), "her hands are hers again")


func test_a_bath_warms_her() -> void:
	_alone()
	feyre.body_state.cold = 0.8
	_station(&"bath")
	assert_true(feyre.interactor.interact())
	await wait_seconds(FADE_WAIT)
	assert_lt(feyre.body_state.cold, 0.5)
	assert_gt(feyre.body_state.effect(&"warm"), 0.0)
