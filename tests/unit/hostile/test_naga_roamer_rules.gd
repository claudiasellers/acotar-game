## NagaRoamer pure rules: routine by hour, senses by routine, the scent trail
## and the hush draught, the throat, arrows to kill (docs/contracts/hostiles.md).
extends GutTest

const ROAMER_DATA := preload("res://data/creatures/hostile/naga_roamer.tres")
const CANON_DATA := preload("res://data/creatures/fae/naga.tres")


func test_routine_by_hour() -> void:
	assert_eq(NagaRoamer.routine_for(12.0), &"bask")
	assert_eq(NagaRoamer.routine_for(18.5), &"hunt")
	assert_eq(NagaRoamer.routine_for(2.0), &"nest")
	assert_eq(NagaRoamer.routine_for(8.0), &"nest")
	assert_eq(NagaRoamer.routine_for(16.0), &"nest")


func test_basking_dulls_sight_and_one_keeps_watch() -> void:
	assert_almost_eq(NagaRoamer.sight_mult(&"bask", false), 0.7, 0.001)
	assert_almost_eq(NagaRoamer.sight_mult(&"nest", true), 1.0, 0.001)
	assert_lt(NagaRoamer.sight_mult(&"nest", false), 1.0)
	assert_almost_eq(NagaRoamer.sight_mult(&"hunt", false), 1.0, 0.001)


func test_trail_holds_until_hush() -> void:
	assert_true(NagaRoamer.trail_holds(3.0, 1.0))
	assert_false(NagaRoamer.trail_holds(0.0, 1.0), "not smelled for 6 s")
	assert_false(NagaRoamer.trail_holds(3.0, 0.5), "a hush draught breaks it")


## With the trail broken nothing feeds its awareness; it decays at the senses'
## rate, falls under SEARCH_AT and the ladder gives up. Done-when: <= 20 s.
func test_hush_loses_the_pack_within_twenty_seconds() -> void:
	var l := HostileLadder.new()
	l.step(1.0, 0.1)
	for i in 10:
		l.step(1.0, 0.1)
	assert_eq(l.state, HostileLadder.State.ENGAGED)
	var decay := (autofree(CreatureSenses.new()) as CreatureSenses).decay
	var awareness := 1.0
	var t := 0.0
	var dt := 0.1
	while l.state != HostileLadder.State.LOST and t < 60.0:
		awareness = maxf(awareness - decay * dt, 0.0)
		l.step(awareness, dt)
		t += dt
	assert_eq(l.state, HostileLadder.State.LOST)
	assert_lte(t, 20.0, "lost her in %.1f s" % t)


func test_the_throat_is_the_top_fifth_and_counts_three_times() -> void:
	assert_almost_eq(ROAMER_DATA.weak_zone_height, 0.78, 0.001)
	assert_eq(ROAMER_DATA.weak_zone_name, &"throat")
	assert_almost_eq(ROAMER_DATA.weak_zone_mult, 3.0, 0.001)
	var r := Creature.resolve_hit(ROAMER_DATA, ROAMER_DATA.max_health, &"wood", ROAMER_DATA.weak_zone_mult)
	assert_almost_eq(r.health, ROAMER_DATA.max_health - 24.0, 0.001)


func test_six_body_arrows_kill_and_five_do_not() -> void:
	var hp := ROAMER_DATA.max_health
	for i in 5:
		var r := Creature.resolve_hit(ROAMER_DATA, hp, &"wood")
		assert_false(r.killed, "arrow %d" % (i + 1))
		hp = r.health
	assert_true(Creature.resolve_hit(ROAMER_DATA, hp, &"wood").killed, "the sixth kills")


func test_one_ash_arrow_is_a_mortal_wound_and_any_next_hit_kills() -> void:
	var r := Creature.resolve_hit(ROAMER_DATA, ROAMER_DATA.max_health, &"ash", 1.5)
	assert_false(r.killed)
	assert_true(r.mortal)
	assert_eq(r.ash_taken, 1)
	assert_almost_eq(ROAMER_DATA.lethal_delay, 4.0, 0.001)
	assert_true(Creature.resolve_hit(ROAMER_DATA, r.health, &"wood", 1.0, 1, true).killed)


func test_it_burns() -> void:
	assert_almost_eq(ROAMER_DATA.burn_dps, 6.0, 0.001)


func test_roamer_data_is_its_own_and_canon_naga_untouched() -> void:
	assert_eq(ROAMER_DATA.kind, &"naga", "shares the family's face and voice")
	assert_ne(ROAMER_DATA.resource_path, CANON_DATA.resource_path)
	assert_eq(CANON_DATA.max_health, 16.0, "the canon ambush naga keeps its numbers")
	assert_eq(ROAMER_DATA.max_health, 48.0)
