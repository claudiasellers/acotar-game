## HostileLadder contract (docs/contracts/hostiles.md): every state reachable,
## the startle window, the wary spell. Pure: no nodes.
extends GutTest

const S := HostileLadder.State


func _run(ladder: HostileLadder, awareness: float, seconds: float, dt: float = 0.1) -> HostileLadder.State:
	var t := 0.0
	while t < seconds - 0.0001:
		ladder.step(awareness, dt)
		t += dt
	return ladder.state


func test_every_state_is_reachable_in_order() -> void:
	var l := HostileLadder.new()
	var seen := {}
	seen[l.step(0.0, 0.1)] = true
	assert_eq(l.state, S.ROUTINE)
	seen[l.step(0.2, 0.1)] = true
	assert_eq(l.state, S.CURIOUS)
	seen[l.step(0.5, 0.1)] = true
	assert_eq(l.state, S.SEARCHING)
	seen[l.step(0.8, 0.1)] = true
	assert_eq(l.state, S.STARTLE)
	seen[_run(l, 0.8, 1.0)] = true
	assert_eq(l.state, S.ENGAGED)
	seen[_run(l, 0.1, 6.5)] = true
	assert_eq(l.state, S.LOST)
	assert_eq(seen.size(), 6, "all six states were visited")


func test_breaking_sight_in_the_startle_window_drops_it_to_searching() -> void:
	var l := HostileLadder.new()
	l.step(0.9, 0.1)
	assert_eq(l.state, S.STARTLE)
	assert_true(l.is_hostile())
	_run(l, 0.5, 1.0)
	assert_eq(l.state, S.SEARCHING, "she broke sight before it committed")


func test_engaged_holds_while_awareness_stays_above_search() -> void:
	var l := HostileLadder.new()
	l.step(0.9, 0.1)
	_run(l, 0.9, 1.0)
	assert_eq(l.state, S.ENGAGED)
	assert_eq(_run(l, 0.45, 20.0), S.ENGAGED)


func test_lost_is_wary_then_routine() -> void:
	var l := HostileLadder.new()
	l.step(0.9, 0.1)
	_run(l, 0.9, 1.0)
	_run(l, 0.0, 6.5)
	assert_eq(l.state, S.LOST)
	assert_true(l.is_wary())
	assert_almost_eq(l.sensitivity(), 1.3, 0.001)
	_run(l, 0.0, 91.0, 1.0)
	assert_eq(l.state, S.ROUTINE)
	assert_false(l.is_wary())
	assert_almost_eq(l.sensitivity(), 1.0, 0.001)


func test_give_up_sends_it_lost() -> void:
	var l := HostileLadder.new()
	l.step(0.9, 0.1)
	l.give_up()
	assert_eq(l.state, S.LOST)
	assert_false(l.is_hostile())


func test_state_names() -> void:
	assert_eq(HostileLadder.state_name(S.ENGAGED), &"engaged")
	assert_eq(HostileLadder.state_name(S.ROUTINE), &"routine")
