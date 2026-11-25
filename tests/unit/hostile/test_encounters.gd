## How fights with hostiles end (design reconciliation §3 item 2): each
## encounter ends once on EventBus.hostile_encounter_ended, and every outcome
## but a knockdown adds one to fact.plain_fights, the count the village's
## opening reads (progression §8a.1b).
extends GutTest

const SITE_SCRIPT := preload("res://creatures/hostile/hostile_site.gd")
const PUCA := preload("res://creatures/hostile/puca_roamer.tscn")

var ended: Array = []


func before_each() -> void:
	ended.clear()
	WorldState.clear()
	EventBus.hostile_encounter_ended.connect(_on_ended)


func after_each() -> void:
	if EventBus.hostile_encounter_ended.is_connected(_on_ended):
		EventBus.hostile_encounter_ended.disconnect(_on_ended)
	WorldState.clear()


func _on_ended(source: StringName, family: StringName, outcome: StringName) -> void:
	ended.append([source, family, outcome])


func _site() -> HostileSite:
	var site := SITE_SCRIPT.new() as HostileSite
	site.data = load("res://data/creatures/hostile_sites/naga_stream_glen.tres") as HostileSiteData
	site.snap_to_core = false
	site.height_func = func(_x: float, _z: float) -> float: return 0.0
	add_child_autofree(site)
	site.set_physics_process(false)
	for m in site.members:
		m.set_physics_process(false)
	return site


func test_the_count_is_a_fact() -> void:
	assert_true(HostileEncounters.PLAIN_FIGHTS.begins_with("fact."), "a deed fact, never a phase flag (R2)")
	assert_eq(HostileEncounters.plain_fights(), 0)


func test_clearing_a_camp_counts() -> void:
	var site := _site()
	for m in site.members:
		m.die(&"arrow_ash")
	assert_eq(ended, [[&"naga_stream_glen", &"naga", HostileEncounters.KILLED]])
	assert_eq(HostileEncounters.plain_fights(), 1)


func test_slipping_away_counts() -> void:
	var site := _site()
	site.report(site.members[0], Vector3.ZERO)
	assert_true(site.engaged)
	for i in int(HostileSite.ENCOUNTER_CALM_S / 0.5) - 1:
		site._step_encounter(0.5)
	assert_eq(ended.size(), 0, "not over while it might still find her")
	site._step_encounter(1.0)
	assert_eq(ended, [[&"naga_stream_glen", &"naga", HostileEncounters.SLIPPED]])
	assert_false(site.engaged)
	assert_eq(HostileEncounters.plain_fights(), 1)


func test_a_hunting_member_keeps_the_fight_on() -> void:
	var site := _site()
	site.report(site.members[0], Vector3.ZERO)
	var n := site.members[0] as NagaRoamer
	n.ladder.step(1.0, 0.1)
	assert_true(n.ladder.is_hostile())
	for i in 40:
		site._step_encounter(0.5)
	assert_eq(ended.size(), 0)


func test_a_knockdown_ends_it_and_doesnt_count() -> void:
	var site := _site()
	site.report(site.members[0], Vector3.ZERO)
	EventBus.player_knocked_down.emit(site.members[1].creature_id, &"naga_claw", Vector3.ZERO)
	assert_eq(ended, [[&"naga_stream_glen", &"naga", HostileEncounters.KNOCKDOWN]])
	assert_eq(HostileEncounters.plain_fights(), 0)
	for m in site.members:
		m.die(&"arrow_ash")
	assert_eq(HostileEncounters.plain_fights(), 1, "coming back and clearing it does count")


func test_someone_elses_knockdown_is_not_this_camps() -> void:
	var site := _site()
	site.report(site.members[0], Vector3.ZERO)
	EventBus.player_knocked_down.emit(&"wolf_3", &"wolf_bite", Vector3.ZERO)
	assert_eq(ended.size(), 0)
	assert_true(site.engaged)


func _puca() -> PucaRoamer:
	var p := PUCA.instantiate() as PucaRoamer
	p.creature_id = &"puca_enc"
	p.hour_func = func() -> float: return 22.0
	p.day_func = func() -> int: return 5
	var her := Node3D.new()
	add_child_autofree(her)
	her.global_position = Vector3(0, 0, 10)
	p.player_func = func() -> Node3D: return her
	add_child_autofree(p)
	p.set_physics_process(false)
	p._think(1.0 / 30.0)
	return p


func test_driving_off_the_puca_counts_once() -> void:
	var p := _puca()
	p.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", p.global_position)
	p.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", p.global_position)
	for i in 60:
		p._think(1.0 / 30.0)
	assert_eq(ended, [[&"puca_enc", &"puca", HostileEncounters.DRIVEN_OFF]], "once, though it vanishes after")
	assert_eq(HostileEncounters.plain_fights(), 1)


func test_killing_the_puca_counts() -> void:
	var p := _puca()
	p.apply_hit(&"arrow_ash", &"ash", 1.0, &"body", p.global_position)
	assert_eq(ended, [[&"puca_enc", &"puca", HostileEncounters.KILLED]])
	assert_eq(HostileEncounters.plain_fights(), 1)


func test_three_fights_open_the_way() -> void:
	for i in 3:
		HostileEncounters.ended(StringName("s%d" % i), &"naga", HostileEncounters.SLIPPED)
	HostileEncounters.ended(&"s9", &"naga", HostileEncounters.KNOCKDOWN)
	assert_eq(HostileEncounters.plain_fights(), 3)
	assert_eq(WorldState.get_flag(HostileEncounters.PLAIN_FIGHTS), 3)
