## Slice 2(d) (hostile plan §8.4, §3.3): settling brings the court's fliers
## back within 20 s, with one chime and a sparkle. Butterflies by day,
## faelights by night; a site that loads settled keeps its swarm at full.
extends GutTest

const SITE_SCRIPT := preload("res://creatures/hostile/hostile_site.gd")
const LIMIT_S := 20.0
const DT := 0.2

var celebrations: Array = []
var _time: float


func before_each() -> void:
	celebrations.clear()
	_time = Clock.time_of_day
	Clock.time_of_day = 12.0 / 24.0
	EventBus.celebration_requested.connect(_on_celebration)


func after_each() -> void:
	if EventBus.celebration_requested.is_connected(_on_celebration):
		EventBus.celebration_requested.disconnect(_on_celebration)
	Clock.time_of_day = _time
	WorldState.clear()


func _on_celebration(kind: StringName, at: Vector3) -> void:
	celebrations.append([kind, at])


func _site(id: StringName = &"naga_stream_glen") -> HostileSite:
	var site := SITE_SCRIPT.new() as HostileSite
	site.data = load("res://data/creatures/hostile_sites/%s.tres" % id) as HostileSiteData
	site.snap_to_core = false
	site.height_func = func(_x: float, _z: float) -> float: return 0.0
	add_child_autofree(site)
	for m in site.members:
		m.set_physics_process(false)
	return site


func _kill_all(site: HostileSite) -> void:
	for m in site.members:
		m.die(&"arrow_ash")
	# The members' DreadFields go at the end of the frame.
	await wait_process_frames(2)


func test_no_swell_while_the_camp_stands() -> void:
	var site := _site()
	assert_null(site.swell)
	assert_eq(site.get_node_or_null("SettleSwell"), null)


func test_settling_brings_the_fliers_back_within_20s() -> void:
	var site := _site()
	await _kill_all(site)
	assert_true(site.is_settled)
	assert_not_null(site.swell, "a settled site grows its swell")
	if site.swell == null:
		return
	var swarm := site.swell.swarm
	assert_not_null(swarm)
	assert_true(swarm.global_position.distance_to(site.global_position) < 0.01, "at the core")
	assert_lt(swarm.multimesh.visible_instance_count, swarm.count, "it starts thin, it doesn't pop in")
	var t := 0.0
	var half_at := -1.0
	while t < LIMIT_S and swarm.multimesh.visible_instance_count < swarm.count:
		swarm._process(DT)
		site.swell.step(DT)
		t += DT
		if half_at < 0.0 and swarm.multimesh.visible_instance_count * 2 >= swarm.count:
			half_at = t
	assert_eq(swarm.multimesh.visible_instance_count, swarm.count, "every flier is back by %ss" % LIMIT_S)
	assert_lte(t, LIMIT_S)
	assert_gt(half_at, 2.0, "it swells back, it doesn't snap back")


func test_one_chime_and_a_sparkle() -> void:
	var site := _site()
	await _kill_all(site)
	assert_eq(celebrations.size(), 1, "one chime")
	if celebrations.size() == 1:
		assert_eq(celebrations[0][0], &"site_settled")
	var bank := load(SoundDirector.BANK_PATH) as SoundBank
	assert_not_null(bank.cue(&"ui_celebrate"), "the celebration's chime is in the bank")
	if site.swell == null:
		return
	assert_not_null(site.swell.sparkle, "a sparkle at the core")
	assert_not_null(site.swell.petals, "petals while it fills")
	if site.swell.petals:
		assert_true(site.swell.petals.emitting)
	for i in int(ceil((SettleSwell.PETAL_SECONDS + 0.1) / DT)):
		site.swell.step(DT)
	if site.swell.petals:
		assert_false(site.swell.petals.emitting, "the petals stop when the swell is done")
	assert_null(site.swell.sparkle, "the spent sparkle is dropped")


func test_faelights_at_night() -> void:
	Clock.time_of_day = 23.0 / 24.0
	var site := _site()
	await _kill_all(site)
	assert_not_null(site.swell)
	if site.swell:
		assert_true(site.swell.swarm.round_glow, "night brings the faelights back")


func test_butterflies_by_day() -> void:
	var site := _site()
	await _kill_all(site)
	assert_not_null(site.swell)
	if site.swell:
		assert_false(site.swell.swarm.round_glow, "day brings the butterflies back")


func test_a_site_that_loads_settled_keeps_its_swarm_at_full() -> void:
	WorldState.set_flag(HostileSite.settle_flag(&"naga_weir"), Clock.day)
	var site := _site(&"naga_weir")
	assert_true(site.is_settled)
	assert_not_null(site.swell)
	if site.swell == null:
		return
	assert_almost_eq(site.swell.swarm.withdrawn, 0.0, 0.001, "no swell on load: it's already alive")
	assert_null(site.swell.petals)
	assert_null(site.swell.sparkle)
	assert_eq(celebrations.size(), 0, "and no chime on load")


func test_the_swell_fits_the_plan() -> void:
	assert_lte(SettleSwell.SWELL_SECONDS, LIMIT_S)
	assert_lte(SettleSwell.PETAL_SECONDS, LIMIT_S)
