## Headless P6 playthrough, "The blight tightens" (ch 23-27, lane L46),
## extending the Act I playtest: same walker, report and exit codes.
## Dev jump: every deed through paintings_shown (P5) is written, as a save
## would hold it. From there it plays by deeds:
##   invite        out of the front doors to Tamlin on the steps, E: the ride
##   picnic        E at the blanket beside him -> L33's "Eyes Open" -> glamour_lifted
##   wonders       look at the willow and the brook, stand by Tamlin; home
##   alis          stare at Alis at the breakfast tray (her bark bleaches)
##   fountain      the next morning, up the walk to the heron; look at the head
##   dressing      Solstice: E at the gown Alis holds out
##   solstice      the plateau: faerie wine, Tamlin at the bower, follow him,
##                 the dance in the wisps, dawn -> solstice_danced
##   lunch         the next noon, E at her place -> L33's "The Night Court" -> rhysand_faced
##   farewell      night in her room: his hand, dawn, the travel dress, her paintings
##   carriage      Lucien storms off; give Tamlin the paintings; board -> sent_home
## The walker can't take stairs: like L30's painting run, she is set down in
## upstairs rooms (bedroom) and between days (logged as "set down"); every
## deed is still earned by walking, looking and pressing E.
##   tools/mq/godot.sh --fixed-fps 60 res://tools/playtest/p6_blight_playtest.tscn -- --out=/tmp/p6.json
## Passes when the log has "PLAYTEST exit 0" and every beat passes.
extends "res://tools/playtest/act1_playtest.gd"

const DEV_DEEDS: Array[String] = ["wolf_killed", "pelt_sold", "beast_claim_accepted", "wall_crossed",
	"first_dinner_eaten", "curtain_trap_set", "bogge_survived", "puca_resisted",
	"tamlin_wound_dressed", "manor_map_drawn", "study_mural_seen", "suriel_bound", "naga_survived",
	"summer_faerie_comforted", "starlight_pool_found", "gallery_opened", "first_painting", "attor_evaded",
	"calanmai_attended", "stranger_met", "bite_endured", "paintings_shown"]
const BEATS: Array[String] = ["spawn", "dev_jump_p6", "invite", "picnic", "wonders", "alis",
	"fountain", "dressing", "solstice", "lunch", "farewell", "carriage"]
const FORECOURT := Vector3(0, 0, 14)
const PORTICO := Vector3(0, 0, -18)


func _run() -> void:
	game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	_load_seconds = Time.get_unix_time_from_system() - _started_at
	_log("game scene loaded in %.1f s (wall)" % _load_seconds)
	await _play()
	if not _finished:
		_release_all()
		_note_shutdown_suspects()
		await _settle(settle_limit)
		var ok := beats.size() == BEATS.size() and beats.all(func(b: Dictionary) -> bool: return b.status == "pass")
		_finish(0 if ok else 1)


func _play() -> void:
	_begin("spawn", "Feyre stands in the world, controllable")
	if not await _until(func() -> bool: return game.spawned, 30.0):
		return _fail("never spawned")
	feyre = game.feyre
	_pass()

	_begin("dev_jump_p6", "DEV JUMP: deeds through paintings_shown; the manor's forecourt, morning")
	_beat["dev_jump"] = true
	for i in range(1, 6):
		WorldState.set_flag("fact.hall_x_%d" % i)
		WorldState.set_flag("fact.hall_mark_%d" % i)
	WorldState.set_flag("fact.hall_map_set_down")
	for flag in DEV_DEEDS:
		WorldState.raise_deed(flag)
	TimeShift.advance_to(TimeShift.MORNING + 0.01)
	var s := ManorSitePlan.SPAWN
	feyre.global_position = Vector3(s.x, WorldHeight.height_at(s.x, s.z) + 1.0, s.z)
	WorldStreamer.update_for(feyre.global_position)
	if not await _until_wall(func() -> bool: return _anchor(&"hall_mark_1") != null, 600.0):
		return _fail("the house never streamed in (region %s)" % _region())
	_note("phase %s" % PhaseManager.current_phase)
	_pass()

	for step: Callable in [_invite, _picnic, _wonders, _alis, _fountain, _dressing, _solstice, _lunch, _farewell, _carriage]:
		if not await step.call():
			return
		if stop_after != "" and beats.any(func(b: Dictionary) -> bool: return b.id == stop_after):
			return


# --- helpers ------------------------------------------------------------------

func _failed(why: String) -> bool:
	_fail(why)
	return false


func _space(anchor_id: StringName, node_name: String) -> Act6Space:
	var a := _anchor(anchor_id)
	return a.get_node_or_null(node_name) as Act6Space if a else null


## Waits (wall clock) for a P6 scene to exist and start.
func _started(anchor_id: StringName, node_name: String, wall: float = 120.0) -> Act6Space:
	var ok := await _until_wall(func() -> bool:
		var sp := _space(anchor_id, node_name)
		return sp != null and sp.running, wall)
	return _space(anchor_id, node_name) if ok else null


func _label_is(sp: Act6Space, label: String, seconds: float = 60.0) -> bool:
	return await _until(func() -> bool: return sp.current_beat_label() == label, seconds)


## Turns her view onto a point until it is within a few degrees, then holds it.
func _look(point: Callable, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		_turn_camera_to(point.call() as Vector3)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


## Sets her down on an anchor's frame point (upstairs rooms, between days),
## until the floor holds her there for a second.
func _set_down(anchor_id: StringName, local: Vector3, why: String) -> bool:
	if not await _until_wall(func() -> bool: return _anchor(anchor_id) != null, 30.0):
		var region := &"manor_estate"
		EventBus.travel_requested.emit(region, anchor_id)
		if not await _until_wall(func() -> bool: return _anchor(anchor_id) != null, 600.0):
			_fail("no %s anchor to set her down on" % anchor_id)
			return false
	var a := _anchor(anchor_id)
	var at := a.global_transform * local
	for i in 6:
		feyre.global_position = at + Vector3.UP * 0.2
		feyre.velocity = Vector3.ZERO
		await _wait(1.0)
		if absf(feyre.global_position.y - at.y) < 1.0:
			_note("set down at %s (%s)" % [anchor_id, why])
			return true
	_fail("never stayed on the floor at %s (%s)" % [anchor_id, _v(feyre.global_position)])
	return false


## The next morning: the clock runs on (a sleep in a real game).
func _next_day(hour: float) -> void:
	TimeShift.advance_to(hour / 24.0)
	_note("the clock runs on to day %d, %.1f h" % [Clock.day, Clock.hour()])


# --- beats --------------------------------------------------------------------

func _invite() -> bool:
	_begin("invite", "out of the front doors to Tamlin on the steps; E: the ride to the glen")
	await _walk_to(FORECOURT, 4.0)
	await _walk_to(PORTICO, 3.0)
	var sp := await _started(&"hall_mark_1", "GlenInvite")
	if sp == null:
		return _failed("GlenInvite never started (%s)" % _v(feyre.global_position))
	await _walk_to(sp.ground_mark(&"tamlin_steps"), 2.5)
	if not await _label_is(sp, "E: go with him"):
		return _failed("stuck at '%s'" % sp.current_beat_label())
	await _press(&"interact")
	if not await _until_wall(func() -> bool: return WorldState.has_flag("fact.glen_ride_taken"), 10.0):
		return _failed("E by Tamlin didn't take the ride")
	if not await _until_wall(func() -> bool: return _anchor(&"glamour_lift_glade") != null \
			and _flat(_anchor(&"glamour_lift_glade").global_position) < 8.0, 600.0):
		return _failed("never reached the glen (%s, region %s)" % [_v(feyre.global_position), _region()])
	_pass()
	return true


func _picnic() -> bool:
	_begin("picnic", "E at the blanket beside him; the film raises glamour_lifted")
	var sp := await _started(&"glamour_lift_glade", "GlenPicnic")
	if sp == null:
		return _failed("GlenPicnic never started")
	var picnic := sp as GlenPicnic
	await _walk_to(picnic._blanket(), 1.5)
	if not await _label_is(sp, "E: sit beside him"):
		return _failed("stuck at '%s'" % sp.current_beat_label())
	await _press(&"interact")
	if not await _until_wall(func() -> bool: return WorldState.has_flag("fact.glen_picnic_shared"), 5.0):
		return _failed("E at the blanket didn't seat her")
	if not await _until_wall(func() -> bool: return WorldState.has_flag("glamour_lifted") \
			and WorldState.has_flag("fact.film_eyes_open_seen"), 240.0):
		return _failed("glamour_lifted never rose (film moment)")
	_pass()
	return true


func _wonders() -> bool:
	_begin("wonders", "the willow sings, the brook's rainbow, his scent; then home to her room, next morning")
	var sp := (await _started(&"glamour_lift_glade", "EyesOpenWonders", 30.0)) as EyesOpenWonders
	if sp == null:
		return _failed("EyesOpenWonders never started")
	await _walk_to(sp.local(EyesOpenWonders.BROOK_MID) + Vector3(0, 0, 4), 2.0)
	await _look(func() -> Vector3: return sp.local(EyesOpenWonders.WILLOW_TOP), 2.5)
	await _look(func() -> Vector3: return sp.local(EyesOpenWonders.BROOK_MID), 2.5)
	var t := sp.actor(&"tamlin")
	if t:
		await _walk_to(t.global_position, 1.5)
	_note("wonders found: %s" % sp.found.keys())
	if not await _until_wall(func() -> bool: return WorldState.has_flag("fact.eyes_open_wonders"), 200.0):
		return _failed("never went home (at '%s')" % sp.current_beat_label())
	if sp.found.size() < 3:
		return _failed("only %d wonders" % sp.found.size())
	_pass()
	return true


func _alis() -> bool:
	_begin("alis", "in her room the next morning: Alis as she truly is; stare and her bark pales")
	if _anchor(&"feyre_bedroom_window") == null or _flat(_anchor(&"feyre_bedroom_window").global_position) > 20.0:
		if not await _set_down(&"feyre_bedroom_window", Vector3(0, 0, 12), "home from the glen"):
			return false
	var sp := (await _started(&"feyre_bedroom_window", "AlisTrueMorning", 60.0)) as AlisTrueMorning
	if sp == null:
		return _failed("AlisTrueMorning never started (%s, %.1f h)" % [_v(feyre.global_position), Clock.hour()])
	await _label_is(sp, "she stares at Alis", 30.0)
	await _look(func() -> Vector3: return sp._alis_face(), 2.5)
	var tf := sp._true_form()
	_note("Alis true form %s, fright %.2f" % [tf != null and tf.lifted, tf.fright if tf else -1.0])
	if not await _until_wall(func() -> bool: return WorldState.has_flag("fact.alis_true_seen"), 60.0):
		return _failed("stuck at '%s'" % sp.current_beat_label())
	if tf == null or not tf.lifted:
		return _failed("Alis wasn't in her true form")
	_pass()
	return true


func _fountain() -> bool:
	_begin("fountain", "the next morning: up the rose garden walk to the heron; look at what's on its bill")
	_next_day(8.5)
	if not await _set_down(&"manor_fountain", Vector3(0, 0, 14), "out to paint the irises"):
		return false
	var sp := (await _started(&"manor_fountain", "FountainHead", 30.0)) as FountainHead
	if sp == null:
		return _failed("FountainHead never started")
	await _walk_to(sp.center() + Vector3(0, 0, 7.0), 0.8)
	await _look(func() -> Vector3: return sp.head_point(), 4.0)
	if not await _until_wall(func() -> bool: return WorldState.has_flag("fountain_head_found"), 120.0):
		return _failed("stuck at '%s'" % sp.current_beat_label())
	_pass()
	return true


func _dressing() -> bool:
	_begin("dressing", "Solstice: Alis dresses her (E at the gown); to the plateau at sunset")
	_next_day(9.0)
	if not await _set_down(&"feyre_bedroom_window", Vector3(0, 0, 12), "Solstice morning in her room"):
		return false
	var sp := await _started(&"feyre_bedroom_window", "SolsticeDressing", 60.0)
	if sp == null:
		return _failed("SolsticeDressing never started")
	if not await _label_is(sp, "E: the blue gown", 120.0):
		return _failed("stuck at '%s'" % sp.current_beat_label())
	await _walk_to(sp.mark(&"gown"), 1.2)
	await _press(&"interact")
	if not await _until_wall(func() -> bool: return WorldState.has_flag("fact.solstice_dressed"), 30.0):
		return _failed("E at the gown didn't dress her")
	_note("wearing %s, hair %s" % [Gameplay.wardrobe.equipped_in(&"top"), Gameplay.wardrobe.hair])
	if not await _until_wall(func() -> bool: return _anchor(&"solstice_dance_floor") != null \
			and _flat(_anchor(&"solstice_dance_floor").global_position) < 20.0, 600.0):
		return _failed("never reached the plateau (%s)" % _region())
	_pass()
	return true


func _solstice() -> bool:
	_begin("solstice", "faerie wine, Tamlin's fiddle, follow him to the wisps, dance until dawn")
	var sp := (await _started(&"solstice_dance_floor", "SolsticeNight", 60.0)) as SolsticeNight
	if sp == null:
		return _failed("SolsticeNight never started")
	if not await _label_is(sp, "the party", 60.0):
		return _failed("stuck at '%s'" % sp.current_beat_label())
	await _walk_to(sp.ground_mark(&"wine_table"), 2.0)
	await _press(&"interact")
	_note("crowd %d, wine %s" % [sp.crowd.size(), sp.drank])
	await _walk_to(sp.ground_mark(&"bower"), 4.0)
	if not await _until(func() -> bool: return sp.current_beat_label().begins_with("lead"), 90.0):
		return _failed("Tamlin never left the band (at '%s')" % sp.current_beat_label())
	if not await _until_wall(func() -> bool:
		var t := sp.actor(&"tamlin")
		if t and _flat(t.global_position) > 3.0:
			_walk_step(t.global_position)
		return sp.current_beat_label() == "the dance", 400.0):
		return _failed("never reached the wisps (at '%s')" % sp.current_beat_label())
	if not await _until_wall(func() -> bool:
		var t := sp.actor(&"tamlin")
		if t:
			_walk_step(t.global_position, 1.0)
		return sp.danced >= SolsticeNight.DANCE, 120.0):
		return _failed("the dance never finished (%.1f s together)" % sp.danced)
	_release_all()
	if not await _until_wall(func() -> bool: return WorldState.has_flag("solstice_danced"), 90.0):
		return _failed("no solstice_danced (at '%s')" % sp.current_beat_label())
	_pass()
	return true


## One frame of walking toward a point (follows a moving actor).
func _walk_step(target: Vector3, radius: float = 2.0) -> void:
	if _flat(target) <= radius:
		Input.action_release(&"move_forward")
		return
	var to := target - feyre.global_position
	feyre.nudge_camera(wrapf(atan2(-to.x, -to.z) - feyre.camera_yaw(), -PI, PI), 0.0)
	Input.action_press(&"move_forward")


func _lunch() -> bool:
	_begin("lunch", "the next noon, E at her place at the table; the film raises rhysand_faced")
	_next_day(11.5)
	if not await _set_down(&"manor_dining_table", Vector3(0, 0, -2), "in to lunch"):
		return false
	var sp := await _started(&"manor_dining_table", "LunchTable", 60.0)
	if sp == null:
		return _failed("LunchTable never started")
	if not await _label_is(sp, "E: sit down to lunch", 60.0):
		return _failed("stuck at '%s'" % sp.current_beat_label())
	await _walk_to(sp.mark(&"feyre_chair"), 1.2)
	await _press(&"interact")
	if not await _until_wall(func() -> bool: return WorldState.has_flag("fact.lunch_sat_down"), 10.0):
		return _failed("E at her chair didn't seat her")
	if not await _until_wall(func() -> bool: return WorldState.has_flag("rhysand_faced") \
			and WorldState.has_flag("fact.film_night_court_seen"), 300.0):
		return _failed("rhysand_faced never rose (film moment)")
	_pass()
	return true


func _farewell() -> bool:
	_begin("farewell", "night in her room: his hand; dawn; the travel dress; her paintings")
	if not await _set_down(&"feyre_bedroom_window", Vector3(0, 0, 12), "up to her room that night"):
		return false
	var sp := await _started(&"feyre_bedroom_window", "FarewellNight", 120.0)
	if sp == null:
		return _failed("FarewellNight never started (%.1f h)" % Clock.hour())
	for step: Array in [["E: take his hand", func() -> Vector3: return sp.actor(&"tamlin").global_position],
			["E: the travel dress", func() -> Vector3: return sp.actor(&"alis").global_position],
			["E: her paintings", func() -> Vector3: return sp.mark(&"desk")]]:
		if not await _label_is(sp, step[0], 120.0):
			return _failed("stuck at '%s' before '%s'" % [sp.current_beat_label(), step[0]])
		await _walk_to((step[1] as Callable).call(), 1.4)
		await _press(&"interact")
	if not await _until_wall(func() -> bool: return WorldState.has_flag("fact.travel_dressed"), 30.0):
		return _failed("stuck at '%s'" % sp.current_beat_label())
	_note("wearing %s; carrying %d bundle" % [Gameplay.wardrobe.equipped_in(&"top"), get_tree().get_nodes_in_group(&"p6_carried_paintings").size()])
	_pass()
	return true


func _carriage() -> bool:
	_begin("carriage", "Lucien storms off; give Tamlin the paintings; board; sent_home")
	if not await _set_down(&"hall_mark_1", Vector3(0, 0, 1), "downstairs to the hall"):
		return false
	var sp := (await _started(&"hall_mark_1", "CarriageFarewell", 60.0)) as CarriageFarewell
	if sp == null:
		return _failed("CarriageFarewell never started")
	if not await _label_is(sp, "she walks out to him", 60.0):
		return _failed("stuck at '%s'" % sp.current_beat_label())
	await _walk_to(PORTICO, 3.0)
	await _walk_to(sp.ground_mark(&"tamlin_carriage"), 1.6)
	if not await _label_is(sp, "E: give him the paintings", 20.0):
		return _failed("stuck at '%s'" % sp.current_beat_label())
	await _press(&"interact")
	if not await _label_is(sp, "E: get in", 30.0):
		return _failed("stuck at '%s' (given %s)" % [sp.current_beat_label(), sp.given])
	await _walk_to(sp.ground_mark(&"carriage_door"), 1.4)
	await _press(&"interact")
	if not await _until_wall(func() -> bool: return WorldState.has_flag("sent_home"), 60.0):
		return _failed("no sent_home (at '%s')" % sp.current_beat_label())
	_note("horses %d; phase %s" % [sp.horses.size(), PhaseManager.current_phase])
	_pass()
	return true
