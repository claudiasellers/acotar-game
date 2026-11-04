## Act II beats for the headless playthrough (L24, extending L08's
## tools/playtest/act1_playtest.gd). Same rules: input actions only, flags
## are only read, never written (R2). Each beat is one scene of the first
## evening at the manor:
##   10. act2_arrival   the doors open, she follows the beast to the table,
##                      he becomes Tamlin; fact.manor_arrived
##   11. act2_bath      Alis's bath (E at the tub), the tunic; fact.alis_bathed
##   12. act2_dinner    to her chair, try to rise (one shove), E until the
##                      plate is clear and the torte vanishes; first_dinner_eaten
##   13. curtain_trap   Return Home (pause menu) to her window, E at night,
##                      E at each window's curtains, rig the rope at the door; curtain_trap_set, then
##                      Alis trips at dawn (fact.alis_tripped)
## `t` is the running playtest (its walker, presses and report).
class_name Act2PlaytestBeats
extends RefCounted

var t: Node


func play(playtest: Node) -> bool:
	t = playtest
	for beat: Callable in [_arrival, _bath, _dinner, _curtain_trap]:
		if not await beat.call():
			return false
		if t._beat.id == t.stop_after:
			return false
	return true


func _space(node_name: String) -> Act2Space:
	return t._find_named(StringName(node_name)) as Act2Space


func _label(space: Act2Space) -> String:
	return space.current_beat_label() if space and space.running else ""


func _fail(why: String) -> bool:
	t._fail(why)
	return false


func _arrival() -> bool:
	t._begin("act2_arrival", "walk up to the front door; follow the beast to the table; he becomes Tamlin; fact.manor_arrived")
	var arrival := _space("ManorArrival") as ManorArrival
	if arrival == null:
		# The ride can now land before the house has streamed in (F16): stand
		# on the drive and wait for it, as a player would, and log the wait.
		var t0: float = Time.get_unix_time_from_system()
		await t._until_wall(func() -> bool: return _space("ManorArrival") != null, 300.0)
		arrival = _space("ManorArrival") as ManorArrival
		if arrival:
			t._note("waited %.0f s (wall) on the drive for the house to stream in" % [Time.get_unix_time_from_system() - t0])
	if arrival == null:
		return _fail("no ManorArrival under manor_dining_table (is manor_house loaded? region %s)" % t._region())
	var door := arrival.mark(&"front_door")
	await t._walk_to(door + Vector3(0, 0, 4), 2.0, func() -> bool: return arrival.running, 600.0)
	if not await t._until(func() -> bool: return arrival.running, 5.0):
		return _fail("at %s, %.0f m from the front door, and the doors never opened" % [t._v(t.feyre.global_position), t._flat(door)])
	t._note("the doors open at %s" % t._v(t.feyre.global_position))
	await t._until(func() -> bool: return _label(arrival).begins_with("lead"), 10.0)
	var guard := 0
	while _label(arrival).begins_with("lead") and guard < 40:
		guard += 1
		var beast := arrival.actor(&"tamlin_beast")
		if beast:
			await t._walk_to(beast.global_position, 3.0, Callable(), 4.0)
		else:
			await t._wait(0.5)
	await t._walk_to(arrival.mark(&"dining_inside"), 2.5, Callable(), 30.0)
	if not await t._until(func() -> bool: return arrival.actor(&"tamlin") != null, 15.0):
		return _fail("never became Tamlin (beat '%s', %.0f m from the head chair)" % [_label(arrival), t._flat(arrival.mark(&"tamlin_seat"))])
	t._note("Tamlin at the head chair; beat '%s'" % _label(arrival))
	if not await t._until(func() -> bool: return WorldState.has_flag("fact.manor_arrived") and not arrival.running, 90.0):
		return _fail("the arrival stalled at '%s'" % _label(arrival))
	t._pass()
	return true


func _bath() -> bool:
	t._begin("act2_bath", "Alis's bath (E at the tub), trousers and tunic, down to dinner; fact.alis_bathed")
	var welcome := _space("AlisWelcome") as AlisWelcome
	if welcome == null:
		return _fail("no AlisWelcome under feyre_bedroom_window")
	if not await t._until(func() -> bool: return _label(welcome) == "reach bath", 30.0):
		return _fail("Alis's scene never reached the bath (running %s, beat '%s', at %s)" % [welcome.running, _label(welcome), t._v(t.feyre.global_position)])
	# Round the bedroom wall to the bathing-chamber door, then to the tub.
	await t._walk_to(welcome.mark(&"bath") + Vector3(-3.0, 0, 1.4), 1.0, Callable(), 20.0)
	await t._walk_to(welcome.mark(&"bath"), 1.6, Callable(), 20.0)
	if not await t._until(func() -> bool: return _label(welcome) == "until she steps in", 5.0):
		return _fail("not at the bath: %.1f m off, beat '%s'" % [t._flat(welcome.mark(&"bath")), _label(welcome)])
	await t._press(&"interact")
	if not await t._until(func() -> bool: return WorldState.has_flag("fact.alis_bathed") and not welcome.running, 90.0):
		return _fail("the bath stalled at '%s'" % _label(welcome))
	if not Gameplay.wardrobe.equipped().values().has(AlisWelcome.TUNIC):
		return _fail("not in the tunic after the bath: %s" % Gameplay.wardrobe.equipped())
	t._note("in the tunic; at %s" % t._v(t.feyre.global_position))
	t._pass()
	return true


func _dinner() -> bool:
	t._begin("act2_dinner", "to her chair; one shove when she rises; E until the plate is clear and the torte vanishes; first_dinner_eaten")
	var dinner := _space("Moment_first_dinner") as FirstDinner
	if dinner == null:
		return _fail("no FirstDinner (Moment_first_dinner) under manor_dining_table")
	if not await t._until(func() -> bool: return _label(dinner).begins_with("reach feyre_chair"), 30.0):
		return _fail("dinner never began (running %s, beat '%s', at %s)" % [dinner.running, _label(dinner), t._v(t.feyre.global_position)])
	await t._walk_to(dinner.mark(&"feyre_chair"), 1.0, Callable(), 30.0)
	if not await t._until(func() -> bool: return _label(dinner) == "until she rises", 40.0):
		return _fail("not seated: %.1f m from her chair, beat '%s'" % [t._flat(dinner.mark(&"feyre_chair")), _label(dinner)])
	await t._press(&"move_forward")
	if not await t._until(func() -> bool: return _label(dinner) == "until her first bite", 40.0):
		return _fail("the hold never came (shoves %d, beat '%s')" % [dinner.shoves, _label(dinner)])
	t._note("held after %d shove(s); %.1f m from the chair" % [dinner.shoves, t._flat(dinner.mark(&"feyre_chair"))])
	for _i in 6:
		if dinner.torte_gone:
			break
		await t._press(&"interact")
		await t._wait(0.4)
	if not await t._until(func() -> bool: return WorldState.has_flag("first_dinner_eaten"), 30.0):
		return _fail("ate %d bite(s), torte gone %s, beat '%s'" % [dinner.bites, dinner.torte_gone, _label(dinner)])
	await t._until(func() -> bool: return StoryControl.can_move(), 30.0)
	var arrival := _space("ManorArrival")
	await t._walk_to(arrival.mark(&"dining_door") if arrival else dinner.mark(&"table") + Vector3(-10, 0, 0), 1.5, Callable(), 30.0)
	if not await t._until(func() -> bool: return not dinner.running, 20.0):
		return _fail("still at the table after the meal (beat '%s')" % _label(dinner))
	t._pass()
	return true


func _curtain_trap() -> bool:
	t._begin("curtain_trap", "Return Home to her window; E at night; rig the rope at the door; curtain_trap_set; Alis trips at dawn")
	var trap := _space("Moment_curtain_trap") as CurtainTrap
	if trap == null:
		return _fail("no CurtainTrap (Moment_curtain_trap) under feyre_bedroom_window")
	ReturnHome.go(t.feyre, t.feyre.global_position)
	await t._wait(1.0)
	await t._press(&"interact")
	if not await t._until(func() -> bool: return trap.running, 20.0):
		return _fail("E at the window didn't start it (%.1f m from the window, night %s)" % [t._flat(trap.global_position), Clock.is_night()])
	# Every window's trimmings, E at each (T077).
	var spots: Array[Vector3] = trap.spots()
	for i in spots.size():
		if trap.stripped.has(i):
			continue
		await t._walk_to(spots[i] + Vector3(0, 0, 1.0), 1.2, Callable(), 30.0)
		await t._press(&"interact")
		if not await t._until(func() -> bool: return trap.stripped.has(i), 3.0):
			return _fail("E at window %d didn't take its trimmings (%.1f m off)" % [i, t._flat(spots[i])])
	if not await t._until(func() -> bool: return _label(trap) == "reach door_inside", 20.0):
		return _fail("no rope (beat '%s')" % _label(trap))
	await t._walk_to(trap.mark(&"door_inside"), 1.4, Callable(), 30.0)
	if not await t._until(func() -> bool: return _label(trap) == "until she rigs it", 5.0):
		return _fail("not at the door: %.1f m off" % t._flat(trap.mark(&"door_inside")))
	await t._press(&"interact")
	if not await t._until(func() -> bool: return WorldState.has_flag("curtain_trap_set"), 10.0):
		return _fail("rigging didn't raise curtain_trap_set (beat '%s')" % _label(trap))
	if not await t._until(func() -> bool: return WorldState.has_flag("fact.alis_tripped") and not trap.running, 150.0):
		return _fail("dawn stalled at '%s'" % _label(trap))
	t._note("phase %s; flags: first_dinner_eaten, curtain_trap_set" % PhaseManager.current_phase)
	t._pass()
	return true
