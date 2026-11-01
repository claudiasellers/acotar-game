## Headless p3 playthrough of the house beats (L28), extending the Act I
## playtest: same walker, presses only, same report and exit codes. Starts
## from the dev jump (story/act3/dev/p3_house_jump.tscn) in the entrance hall
## at dusk and plays the canon way (ch12-13): mark the five places on her map
## while walking the halls, set the map down on the foyer table at night,
## watch the beast come in and follow Tamlin to the infirmary, dress his hand,
## then study the mural in his study.
##   tools/mq/godot.sh --fixed-fps 60 res://tools/playtest/p3_house_playtest.tscn -- --out=/tmp/p3h.json
## Passes when the log has "PLAYTEST exit 0" and these beats pass: spawn,
## hall_marks, map_drawn, the_beast, to_the_infirmary, wound_dressed, mural.
## final_phase stays p3_house_and_woods with tamlin_wound_dressed,
## manor_map_drawn and study_mural_seen.
extends "res://tools/playtest/act1_playtest.gd"

const JUMP_SCENE := "res://story/act3/dev/p3_house_jump.tscn"
## Door-to-door walks in house space (x, z), ground floor.
const TO_MARK_2 := [Vector2(7, -38)]
const TO_MARK_3 := [Vector2(7, -55)]
const SALOON := [Vector2(-1, -59), Vector2(-1.8, -62.5), Vector2(-1.8, -67.5), Vector2(-1.8, -62.5), Vector2(-1, -59), Vector2(7, -55)]
const TO_GALLERY := [Vector2(8, -54), Vector2(9, -50), Vector2(12, -50), Vector2(26, -50), Vector2(26, -55), Vector2(26, -50)]
const TO_DINING := [Vector2(21, -50), Vector2(21, -44), Vector2(21, -50)]
const TO_MARK_4 := [Vector2(40, -50), Vector2(44, -51), Vector2(52, -51)]
const KITCHEN := [Vector2(52, -57), Vector2(52, -51)]
const TO_MARK_5 := [Vector2(62, -51)]
const SERVICE_ROOMS := [Vector2(49, -51), Vector2(49, -47), Vector2(54.8, -46.5), Vector2(54.8, -38), Vector2(60, -37.5),
		Vector2(66, -37.5), Vector2(60, -37.5), Vector2(54.8, -38), Vector2(54.8, -46.5), Vector2(49, -47), Vector2(49, -51)]
const BACK_TO_FOYER := [Vector2(44, -51), Vector2(40, -50), Vector2(12, -50), Vector2(9, -50), Vector2(7, -54),
		Vector2(-7.5, -54.5), Vector2(-8, -48.5)]
const TO_STUDY := [Vector2(60, -37.5), Vector2(54.8, -38), Vector2(54.8, -46.5), Vector2(49, -47), Vector2(49, -51), Vector2(40, -50), Vector2(12, -50), Vector2(9, -50),
		Vector2(7, -55), Vector2(-1, -59), Vector2(-1.8, -62.5), Vector2(-1.8, -67.5), Vector2(-9, -67.5), Vector2(-9, -66), Vector2(-12, -66), Vector2(-12.8, -61.5)]

var jump: Node
var house: Node3D
var map: HallMap
var wound: WoundDressing
var mural: StudyMural


func _run() -> void:
	jump = (load(JUMP_SCENE) as PackedScene).instantiate()
	add_child(jump)
	game = jump.get(&"game")
	_load_seconds = Time.get_unix_time_from_system() - _started_at
	_log("p3 house jump loaded in %.1f s (wall)" % _load_seconds)
	await _play()
	if not _finished:
		_release_all()
		_note_shutdown_suspects()
		await _settle(settle_limit)
		_finish(0 if beats.all(func(b: Dictionary) -> bool: return b.status == "pass") else 1)


func _h(p: Vector2) -> Vector3:
	return house.to_global(Vector3(p.x, ManorHouseBuilder.floor_y(0) + 0.2, p.y))


func _walk_route(route: Array, radius: float = 1.0) -> bool:
	for p: Vector2 in route:
		if not await _walk_to(_h(p), radius):
			return false
	return true


func _mark(n: int, route: Array) -> bool:
	if not await _walk_route(route):
		return false
	var a := _anchor(StringName("hall_mark_%d" % n))
	await _walk_to(a.global_position, 1.2)
	await _press(&"interact")
	return await _until(func() -> bool: return WorldState.has_flag("fact.hall_mark_%d" % n), 6.0)


func _play() -> void:
	_begin("spawn", "Feyre in the manor's entrance hall in p3, the house beats hung")
	if game == null or not await _until_wall(func() -> bool: return game.spawned, 900.0):
		return _fail("never spawned")
	feyre = game.feyre
	var first := _anchor(&"hall_mark_1")
	var infirmary := _anchor(&"manor_infirmary")
	var study := _anchor(&"manor_study_mural")
	if first == null or infirmary == null or study == null:
		return _fail("house anchors missing")
	house = first.get_parent() as Node3D
	map = first.get_node_or_null(^"HallMap") as HallMap
	wound = infirmary.get_node_or_null(^"WoundDressing") as WoundDressing
	mural = study.get_node_or_null(^"StudyMural") as StudyMural
	if map == null or wound == null or mural == null:
		return _fail("Act3Anchors didn't hang HallMap/WoundDressing/StudyMural")
	if PhaseManager.current_phase != &"p3_house_and_woods":
		return _fail("not in p3")
	_note("at %s, phase %s" % [_v(feyre.global_position), PhaseManager.current_phase])
	_pass()

	_begin("hall_marks", "walk the halls: five Xs and circles, and >= %d rooms on her page" % map.plan.min_rooms)
	await _press(&"interact")  # she starts on mark 1, by the front doors
	if not await _until(func() -> bool: return WorldState.has_flag("fact.hall_mark_1"), 6.0):
		return _fail("mark 1 (front doors) not made")
	if not await _mark(2, TO_MARK_2) or not await _mark(3, TO_MARK_3):
		return _fail("marks 2-3")
	await _walk_route(SALOON)
	await _walk_route(TO_GALLERY)
	await _walk_route(TO_DINING)
	if not await _mark(4, TO_MARK_4):
		return _fail("mark 4 (kitchen door)")
	await _walk_route(KITCHEN)
	if not await _mark(5, TO_MARK_5):
		return _fail("mark 5 (servants' stair)")
	if map.sketched_count() < map.plan.min_rooms:
		await _walk_route(SERVICE_ROOMS)
	var here := house.to_local(feyre.global_position)
	_note("%d rooms on her page; she is at house %s, level %d, room '%s', anchor 1 at house %s, mapping %s" % [
		map.sketched_count(), _v(here), HallMap.level_at(here.y), HallMap.room_at(map.rooms, here).get("id", ""),
		_v(first.position), map.mapping()])
	if not WorldState.has_flag(HallMap.ENOUGH_FACT):
		return _fail("only %d rooms sketched" % map.sketched_count())
	_pass()

	_begin("map_drawn", "back to the foyer table; at night she sets the map down: manor_map_drawn")
	if not await _walk_route(BACK_TO_FOYER):
		return _fail("couldn't get back to the foyer")
	await _walk_to(wound.mark(&"foyer_table"), 1.4)
	if not await _until(func() -> bool: return wound.running, 40.0):
		return _fail("the night never started at the table (can_start %s, night %s)" % [wound.can_start(), Clock.is_night()])
	await _walk_to(wound.mark(&"foyer_map"), 1.0)
	await _press(&"interact")
	if not await _until(func() -> bool: return WorldState.has_flag("manor_map_drawn"), 8.0):
		return _fail("manor_map_drawn never raised (set down %s)" % WorldState.has_flag("fact.hall_map_set_down"))
	_pass()

	_begin("the_beast", "the beast limps in from the garden doors, the flash, Tamlin; he knows she can't write")
	if not await _until(func() -> bool: return WorldState.has_flag("fact.tamlin_knows_she_cannot_read"), 90.0):
		return _fail("stuck at '%s'" % wound.current_beat_label())
	_note("%d blood stains on the marble" % wound.stains.size())
	_pass()

	_begin("to_the_infirmary", "follow him through the service wing to the small infirmary")
	var t0 := _sim_seconds()
	while _sim_seconds() - t0 < 180.0 and not wound.current_beat_label().begins_with("until the supplies"):
		var t := wound.actor(&"tamlin")
		if t and _flat(t.global_position) > 2.5:
			await _walk_to(t.global_position, 2.0, Callable(), 8.0)
		else:
			await _wait(0.3)
	if not wound.current_beat_label().begins_with("until the supplies"):
		return _fail("stuck at '%s'" % wound.current_beat_label())
	_pass()

	_begin("wound_dressed", "supplies, water, clean, bind, empty the bowl: tamlin_wound_dressed")
	t0 = _sim_seconds()
	while _sim_seconds() - t0 < 150.0 and not WorldState.has_flag("tamlin_wound_dressed"):
		if wound.glint.visible:
			var g := wound.glint.global_position
			await _walk_to(Vector3(g.x, feyre.global_position.y, g.z), 1.1, Callable(), 10.0)
			await _press(&"interact")
		await _wait(0.4)
	_note("collected %d, cleaned %d, bound %d, emptied %s" % [wound.collected.size(), wound.cleaned, wound.bound, wound.bowl_emptied])
	if not WorldState.has_flag("tamlin_wound_dressed"):
		return _fail("stuck at '%s'" % wound.current_beat_label())
	_pass()

	_begin("mural", "to his study: look at the crocuses, the lambs, the roses; study_mural_seen")
	await _until(func() -> bool: return not wound.running, 30.0)
	if not await _walk_route(TO_STUDY):
		return _fail("couldn't reach the study")
	if not await _until(func() -> bool: return mural.running, 10.0):
		return _fail("the mural beat never started (can_start %s)" % mural.can_start())
	for id: StringName in [&"crocuses", &"lambs", &"roses"]:
		for i in 90:
			_turn_camera_to(mural.spot_world(id))
			await get_tree().physics_frame
	if not await _until(func() -> bool: return WorldState.has_flag("study_mural_seen"), 30.0):
		return _fail("noticed %s; study_mural_seen never raised" % [mural.noticed])
	_pass()


func _until_wall(cond: Callable, wall_seconds: float) -> bool:
	var end := Time.get_unix_time_from_system() + wall_seconds
	while Time.get_unix_time_from_system() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())
