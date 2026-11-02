## Headless p5 playthrough of Calanmai (L45, ch20-22), extending the Act I
## playtest: same walker, report and exit codes. Dev jump: deeds through
## attor_evaded (and her first painting) are written directly, then she's set
## down on the manor forecourt at dusk. From there it plays by deeds:
##   order        through the front doors at dusk: Tamlin's order, the drums
##   fires        the wayside road to the Hill of the Rite; in among the bonfires
##   stranger     the trench by the cave: the three, the stranger's arm (she
##                steps out of it), she walks away; Lucien carries her home
##   explained    dropped on the hall floor; Lucien's account of the Rite
##   supper       through the service passage to the kitchen; E eats each thing
##   bite         back along the passage: the Hunter; E pushes him off
##   vanity       DEV set-down at her vanity (stairs): E bares the bruise
##   lunch        DEV set-down in the dining hall at noon: bite_endured
##   roses        out and back in at dinner: the white roses
##   gown         a gown from her wardrobe (DEV: equipped directly, no
##                dressing-room UI walk); dinner; the table shrinks; DEV
##                set-down at her easel for the stairs; E gives him the
##                canvas: paintings_shown; it hangs in his bedchamber
##   tools/mq/godot.sh --fixed-fps 60 res://tools/playtest/p5_calanmai_playtest.tscn -- --out=/tmp/p5.json
## Passes when the log has "PLAYTEST exit 0" and every beat in BEATS passes.
## In the chain (P3P4Chain) the dev jump is skipped and attor_evaded must
## already have come out of play.
extends "res://tools/playtest/act1_playtest.gd"

const DEV_DEEDS: Array[String] = ["wolf_killed", "pelt_sold", "beast_claim_accepted", "wall_crossed",
	"first_dinner_eaten", "curtain_trap_set", "bogge_survived", "puca_resisted",
	"tamlin_wound_dressed", "manor_map_drawn", "study_mural_seen", "suriel_bound", "naga_survived",
	"summer_faerie_comforted", "starlight_pool_found", "gallery_opened", "first_painting", "attor_evaded"]
## Beats as they run (prefixed "calanmai:" in the chain).
const BEATS: Array[String] = ["order", "fires", "stranger", "explained", "supper", "bite", "vanity",
	"lunch", "roses", "gown"]
## The manor faces +Z: forecourt, portico, the entrance hall (P3P4Chain).
const FORECOURT := Vector3(0, 0, 14)
const PORTICO := Vector3(0, 0, -18)
## The service passage, entrance hall to kitchens (L28's door-to-door route).
const HALL_TO_KITCHEN := [Vector2(7, -38), Vector2(7, -54), Vector2(9, -50), Vector2(12, -50), Vector2(40, -50),
	Vector2(44, -51), Vector2(52, -51), Vector2(52, -57)]
const GOWN := &"dinner_gown_rose"

var _spaces_seen: Dictionary = {}
## The clip sets this: skip the long road to the hill (a dev set-down).
var ride_to_hill: bool = false


func _run() -> void:
	game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	_load_seconds = Time.get_unix_time_from_system() - _started_at
	_log("game scene loaded in %.1f s (wall)" % _load_seconds)
	EventBus.scene_space_finished.connect(func(id: StringName) -> void: _spaces_seen[id] = true)
	_begin("spawn", "Feyre stands at the cottage, controllable")
	if not await _until(func() -> bool: return game.spawned, 30.0):
		_fail("never spawned")
	else:
		feyre = game.feyre
		_pass()
		if await _dev_jump():
			await _play()
	if not _finished:
		_release_all()
		_note_shutdown_suspects()
		await _settle(settle_limit)
		_finish(0 if beats.all(func(b: Dictionary) -> bool: return b.status == "pass") else 1)


func _dev_jump() -> bool:
	_begin("dev_jump_p5", "DEV JUMP: deeds through attor_evaded; set down on the manor forecourt at dusk")
	_beat["dev_jump"] = true
	for i in range(1, 6):
		WorldState.set_flag("fact.hall_x_%d" % i)
		WorldState.set_flag("fact.hall_mark_%d" % i)
	WorldState.set_flag("fact.hall_map_set_down")
	WorldState.set_flag("fact.gallery_seen")
	# Act II's first evening, which the real path has long since played.
	WorldState.set_flag("fact.manor_arrived")
	WorldState.set_flag("fact.alis_bathed")
	# The Summer faerie (p3) is long buried: no body on the hall table.
	for fact in ["fact.summer_faerie_died_alone", "fact.summer_faerie_buried", "fact.summer_faerie_farewell"]:
		WorldState.set_flag(fact)
	for flag in DEV_DEEDS:
		WorldState.raise_deed(flag)
	Clock.from_dict({"time_of_day": 18.75 / 24.0, "day": int(Clock.get(&"day"))})
	feyre.set_physics_process(false)
	feyre.global_position = Vector3(FORECOURT.x, WorldHeight.height_at(FORECOURT.x, FORECOURT.z) + 1.0, FORECOURT.z)
	WorldStreamer.update_for(feyre.global_position)
	feyre.set_physics_process(true)
	if not await _until_wall(func() -> bool: return _anchor(&"manor_window_hide") != null, 600.0):
		_fail("the house never streamed in (region %s)" % _region())
		return false
	_note("phase %s, %s" % [PhaseManager.current_phase, _clock()])
	_pass()
	return true


func _play() -> void:
	for step: Callable in [_order, _fires, _stranger, _explained, _supper, _bite, _vanity, _lunch, _roses, _gown]:
		if not await step.call():
			return
		if stop_after != "" and _beat.get("id", "") == stop_after:
			return


# --- ch20 -------------------------------------------------------------------

func _order() -> bool:
	_begin("order", "through the front doors at dusk: Tamlin orders her to stay inside, and goes")
	var a := _anchor(&"manor_window_hide")
	if not WorldState.has_flag("attor_evaded"):
		return _no("attor_evaded isn't earned (the chain needs the Attor before Calanmai)")
	await _walk_to(FORECOURT, 4.0)
	await _walk_to(PORTICO, 2.0)
	await _walk_to(a.global_position, 3.0)
	var order := a.get_node_or_null(^"FireNightOrder") as SceneSpace
	if order == null:
		return _no("no FireNightOrder on manor_window_hide")
	if not await _until(func() -> bool: return order.running or WorldState.has_flag("fact.calanmai_ordered_inside"), 20.0):
		return _no("Tamlin never gave the order (can_start %s, %s, %.1f m off)" % [order.can_start(), _clock(), _flat(a.global_position)])
	if not await _until(func() -> bool: return not order.running, 120.0):
		return _no("the order never ended (at %s)" % order.current_beat_label())
	if not WorldState.has_flag("fact.calanmai_ordered_inside"):
		return _no("no fact.calanmai_ordered_inside")
	_note("%s; drums %s" % [_clock(), get_tree().root.get_node_or_null(^"CalanmaiFarDrums") != null])
	_pass()
	return true


func _fires() -> bool:
	_begin("fires", "out by the front doors, the wayside road to the Hill of the Rite; in among the bonfires: calanmai_attended")
	await _walk_to(PORTICO, 2.0)
	await _walk_to(FORECOURT, 4.0)
	if ride_to_hill:
		# The clip's time budget: a dev set-down at the last wayside spot
		# instead of the 1.2 km road (the playtest walks it).
		var last: Vector3 = _wayside()[-1]
		feyre.global_position = Vector3(last.x, WorldHeight.height_at(last.x, last.z) + 1.0, last.z)
		feyre.velocity = Vector3.ZERO
		WorldStreamer.update_for(feyre.global_position)
		_beat["dev_jump"] = true
		_note("DEV: set down at the last wayside spot %s" % _v(feyre.global_position))
	else:
		for p: Vector3 in _wayside():
			await _walk_to(p, 6.0)
	var a: Node3D = null
	if await _until_wall(func() -> bool: return _anchor(&"calanmai_bonfires") != null, 120.0):
		a = _anchor(&"calanmai_bonfires")
	if a == null:
		return _no("no calanmai_bonfires anchor (loaded %s)" % [WorldStreamer.loaded_ids()])
	var night := a.get_node_or_null(^"CalanmaiNight")
	_note("CalanmaiNight %s, %s" % [night != null, _clock()])
	await _walk_to(a.global_position, 10.0, func() -> bool: return WorldState.has_flag("calanmai_attended"))
	if not await _until(func() -> bool: return WorldState.has_flag("calanmai_attended"), 60.0):
		var fires := a.get_node_or_null(^"Moment_calanmai_fires") as SceneSpace
		return _no("calanmai_attended never rose (%s, can_start %s, %.1f m off)" % [
			_clock(), fires.can_start() if fires else false, _flat(a.global_position)])
	_pass()
	return true


## The wayside road, manor to hill (data/wayside/manor_hill_of_the_rite.tres).
func _wayside() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var route := load("res://data/wayside/manor_hill_of_the_rite.tres")
	for item: Variant in (route.get(&"spots") if route and route.get(&"spots") != null else []):
		var p: Variant = (item as Resource).get(&"position") if item is Resource else null
		if p is Vector3:
			out.append(p)
	if out.is_empty():
		out = [Vector3(93, 0, -137), Vector3(170, 0, -279), Vector3(284, 0, -392), Vector3(352, 0, -518),
			Vector3(475, 0, -640), Vector3(546, 0, -783)]
	return out


func _stranger() -> bool:
	_begin("stranger", "to the trench by the cave: the three pin her; the stranger; she steps out of his arm, walks away: stranger_met; Lucien carries her home")
	var a := _anchor(&"calanmai_cave_mouth")
	if a == null:
		return _no("no calanmai_cave_mouth anchor")
	var cave := a.get_node_or_null(^"Moment_cave_mouth") as Act2Space
	await _walk_to(a.global_position, 6.0, func() -> bool: return cave != null and cave.running)
	if cave == null or not await _until(func() -> bool: return cave.running, 20.0):
		return _no("the three never came (%s, %.1f m off)" % [_clock(), _flat(a.global_position)])
	if not await _until(func() -> bool: return cave.current_beat_label() == "she steps out of his arm", 120.0):
		return _no("the stranger never held her (at %s)" % cave.current_beat_label())
	var him := cave.actor(&"rhysand")
	_note("the stranger: %s" % (him.scene_file_path if him else "missing"))
	await _press(&"interact")
	if not await _until(func() -> bool: return cave.current_beat_label() == "she walks away", 40.0):
		return _no("she couldn't step out of his arm (at %s)" % cave.current_beat_label())
	var away := feyre.global_position + (feyre.global_position - him.global_position).normalized() * 16.0
	await _walk_to(away, 2.0, func() -> bool: return WorldState.has_flag("stranger_met"))
	if not WorldState.has_flag("stranger_met"):
		return _no("stranger_met never rose (%.1f m from him)" % _flat(him.global_position))
	if not await _until(func() -> bool: return WorldState.has_flag("fact.calanmai_carried"), 90.0):
		return _no("Lucien never found her (at %s)" % cave.current_beat_label())
	_pass()
	return true


# --- ch21 -------------------------------------------------------------------

func _explained() -> bool:
	_begin("explained", "carried home: dropped on the entrance-hall floor; Lucien explains the Rite and goes")
	if not await _until_wall(func() -> bool: return _anchor(&"manor_window_hide") != null, 300.0):
		return _no("the house never streamed back in")
	var a := _anchor(&"manor_window_hide")
	if not await _until(func() -> bool: return WorldState.has_flag("fact.calanmai_rite_explained"), 120.0):
		return _no("Lucien never explained (%.1f m from the hall, %s)" % [_flat(a.global_position), _clock()])
	_note("in the hall at %s, %s" % [_v(feyre.global_position), _clock()])
	_pass()
	return true


func _supper() -> bool:
	_begin("supper", "through the service passage to the empty kitchen; E at the table eats bread, an apple, a lemon tart")
	var a := _anchor(&"manor_alis_hiding")
	var supper := a.get_node_or_null(^"KitchenSupper") as Act2Space if a else null
	if supper == null:
		return _no("no KitchenSupper on manor_alis_hiding")
	for p: Vector2 in HALL_TO_KITCHEN:
		await _walk_to(Vector3(p.x, feyre.global_position.y, p.y), 1.0)
	var table := supper.mark(&"table")
	await _walk_to(table, 1.2)
	if not await _until(func() -> bool: return supper.running, 10.0):
		return _no("supper didn't start (can_start %s, %.1f m from the table)" % [supper.can_start(), _flat(table)])
	for i in 40:
		if WorldState.has_flag("fact.calanmai_supper_eaten"):
			break
		_turn_camera_to(table + Vector3.UP * 0.9)
		await _press(&"interact")
		await _wait(0.6)
	if not WorldState.has_flag("fact.calanmai_supper_eaten"):
		return _no("she couldn't eat (at %s, %.1f m from the table)" % [supper.current_beat_label(), _flat(table)])
	_pass()
	return true


func _bite() -> bool:
	_begin("bite", "back along the moonlit passage: the Hunter pins her; E pushes him off; she wakes late in her room")
	var a := _anchor(&"manor_kitchen_hall")
	var bite := a.get_node_or_null(^"Moment_bite") as Act2Space if a else null
	if bite == null:
		return _no("no bite space on manor_kitchen_hall")
	await _walk_to(Vector3(52, feyre.global_position.y, -51), 1.0)
	await _walk_to(a.global_position, 1.5, func() -> bool: return bite.running)
	if not await _until(func() -> bool: return bite.running, 15.0):
		return _no("no one in the moonlight (can_start %s, %s)" % [bite.can_start(), _clock()])
	if not await _until(func() -> bool: return bite.current_beat_label().begins_with("decision"), 90.0):
		return _no("never pinned (at %s)" % bite.current_beat_label())
	await _wait(1.0)
	await _press(&"interact")
	if not await _until(func() -> bool: return WorldState.has_flag("fact.bite_held_off") and not bite.running, 90.0):
		return _no("the hallway never ended (at %s)" % bite.current_beat_label())
	_note("pushed %s; woke at %s, %s; bruise %s" % [WorldState.has_flag("fact.bite.pushed"), _v(feyre.global_position),
		_clock(), feyre.find_child("CalanmaiBruise", true, false) != null])
	if not WorldState.has_flag("fact.bite.pushed"):
		return _no("E didn't push him off")
	_pass()
	return true


# --- ch22 -------------------------------------------------------------------

func _vanity() -> bool:
	_begin("vanity", "DEV: set down at her vanity (the walker can't take stairs); E bares the bruise")
	var a := _anchor(&"feyre_bedroom_window")
	var vanity := a.get_node_or_null(^"BruiseVanity") as Act2Space if a else null
	if vanity == null:
		return _no("no BruiseVanity on feyre_bedroom_window")
	if not await _set_down(vanity.global_transform * vanity.arrive_offset, a.global_position.y):
		return false
	if not await _until(func() -> bool: return vanity.current_beat_label() == "she opens her collar (E)", 40.0):
		return _no("no mirror (can_start %s, %s, at %s)" % [vanity.can_start(), _clock(), vanity.current_beat_label()])
	await _press(&"interact")
	if not await _until(func() -> bool: return WorldState.has_flag("fact.bruise_shown"), 30.0):
		return _no("E didn't open her collar")
	_pass()
	return true


func _lunch() -> bool:
	_begin("lunch", "DEV: set down in the dining hall; lunch with the bruise bared: bite_endured")
	var a := _anchor(&"manor_dining_table")
	var lunch := a.get_node_or_null(^"BruiseLunch") as Act2Space if a else null
	if lunch == null:
		return _no("no BruiseLunch on manor_dining_table")
	await _until(func() -> bool: return not (_anchor(&"feyre_bedroom_window").get_node(^"BruiseVanity") as SceneSpace).running, 20.0)
	if not await _set_down(a.global_position + Vector3(0, 0, -2.0), a.global_position.y):
		return false
	if not await _until(func() -> bool: return WorldState.has_flag("bite_endured"), 90.0):
		return _no("bite_endured never rose (can_start %s, %s, at %s)" % [lunch.can_start(), _clock(), lunch.current_beat_label()])
	_pass()
	return true


func _roses() -> bool:
	_begin("roses", "out of the dining hall and back at dinner: the white roses; they stand in her painting room")
	var a := _anchor(&"manor_dining_table")
	var roses := a.get_node_or_null(^"RoseDinner") as Act2Space
	await _until(func() -> bool: return not (a.get_node(^"BruiseLunch") as SceneSpace).running, 20.0)
	if not await _out_and_back(a, roses):
		return false
	if not await _until(func() -> bool: return WorldState.has_flag("fact.white_roses_given"), 90.0):
		return _no("no roses (can_start %s, %s, at %s)" % [roses.can_start(), _clock(), roses.current_beat_label()])
	await _until(func() -> bool: return not roses.running, 20.0)
	var vase := _anchor(&"painting_room_easel").get_node_or_null(^"WhiteRosesVase")
	_note("vase in the painting room: %s" % (vase != null and vase.get_child_count() > 0))
	_pass()
	return true


func _gown() -> bool:
	_begin("gown", "a gown for dinner; the table shrinks; up to her painting room (DEV set-down); E gives him the canvas: paintings_shown")
	var a := _anchor(&"manor_dining_table")
	var gown := a.get_node_or_null(^"Moment_paintings_shown") as Act2Space
	if gown == null:
		return _no("no paintings_shown space on manor_dining_table")
	# A dev assist, not a workaround (nothing in the game is broken): the
	# dressing-room walk upstairs is L12's playtest; here she just puts it on.
	_beat["dev_jump"] = true
	Gameplay.wardrobe.grant(GOWN)
	Gameplay.wardrobe.equip(GOWN)
	_note("DEV: dressed in %s from her wardrobe (gown %s)" % [GOWN, CalanmaiKit.wearing_gown()])
	if not await _out_and_back(a, gown):
		return false
	if not await _until(func() -> bool: return gown.current_beat_label() == "she leads him up to her painting room", 90.0):
		return _no("no dinner (can_start %s, gown %s, %s, at %s)" % [gown.can_start(), CalanmaiKit.wearing_gown(), _clock(),
			gown.current_beat_label()])
	var easel := _anchor(&"painting_room_easel")
	if not await _set_down(easel.global_position + Vector3(-1.0, 0, -1.5), easel.global_position.y):
		return false
	if not await _until(func() -> bool: return gown.current_beat_label() == "she gives it to him (E)", 60.0):
		return _no("he never stopped at a canvas (at %s)" % gown.current_beat_label())
	await _press(&"interact")
	if not await _until(func() -> bool: return WorldState.has_flag("paintings_shown"), 30.0):
		return _no("paintings_shown never rose")
	await _until(func() -> bool: return not gown.running, 30.0)
	await _wait(0.5)
	var kept := _anchor(&"manor_tamlin_room").get_node_or_null(^"KeptCanvas")
	_note("kept %s; on his wall %s; phase %s" % [WorldState.get_flag(CalanmaiKit.KEPT_ID_FACT, ""),
		kept != null and kept.get_child_count() > 0, PhaseManager.current_phase])
	if kept == null or kept.get_child_count() == 0:
		return _no("the canvas isn't on his bedchamber wall")
	_pass()
	return true


# --- plumbing ---------------------------------------------------------------

## Out of the dining hall into the entrance hall and back in to the table, as
## she would come down to the next meal. A stuck-hop can lift her onto the
## upper floor; then she is set down in the entrance hall (noted).
func _out_and_back(dining: Node3D, space: SceneSpace) -> bool:
	var hall := _anchor(&"manor_window_hide")
	await _walk_to(Vector3(hall.global_position.x, feyre.global_position.y, hall.global_position.z - 5.5), 1.5)
	if absf(feyre.global_position.y - hall.global_position.y) > 1.5:
		_note("a hop lifted her to %s; set down in the entrance hall" % _v(feyre.global_position))
		if not await _set_down(hall.global_position + Vector3(0, 0, -5.5), hall.global_position.y):
			return false
	await _wait(1.0)
	await _walk_to(dining.global_position + Vector3(0, 0, -2.0), 1.5, func() -> bool: return space.running)
	if not space.running and absf(feyre.global_position.y - dining.global_position.y) > 1.5:
		_note("a hop lifted her to %s; set down in the dining hall" % _v(feyre.global_position))
		if not await _set_down(dining.global_position + Vector3(0, 0, -2.0), dining.global_position.y):
			return false
	return true


## Sets her down at `at` on the floor at `floor_y` until she stays there (the
## house builds its floors over a few frames). The beat is marked dev_jump.
func _set_down(at: Vector3, floor_y: float) -> bool:
	_beat["dev_jump"] = true
	for tries in 6:
		feyre.teleport(Vector3(at.x, floor_y + 0.2, at.z))
		await _wait(1.0)
		if absf(feyre.global_position.y - floor_y) < 1.0:
			return true
	_fail("never stayed on the floor at %s (at %s)" % [_v(at), _v(feyre.global_position)])
	return false


## Fails the beat; false, for the step to return.
func _no(why: String) -> bool:
	_fail(why)
	return false


func _clock() -> String:
	return "day %d %05.2f h" % [int(Clock.get(&"day")), Clock.hour()]
