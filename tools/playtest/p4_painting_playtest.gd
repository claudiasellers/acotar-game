## Headless p4 playthrough of painting (L30), extending the Act I playtest:
## same walker, report and exit codes. Dev jump: Acts I-III deeds are written
## directly up to starlight_pool_found, then she's set down at the painting-room
## easel (the walker can't take stairs). From there it plays by deeds:
## E at the easel opens the studio; her first stroke asks for paint and opens
## the gallery; she mixes in a well, finishes, and the canvas leans against
## the wall (first_painting); then she walks into the gallery (its moment).
##   tools/mq/godot.sh --fixed-fps 60 res://tools/playtest/p4_painting_playtest.tscn -- --out=/tmp/p4.json
## Passes when the log has "PLAYTEST exit 0" and these beats pass:
## spawn, dev_jump_p4, studio_open, gallery_opened, first_painting, gallery_seen.
extends "res://tools/playtest/act1_playtest.gd"

const DEV_DEEDS: Array[String] = ["wolf_killed", "pelt_sold", "beast_claim_accepted", "wall_crossed",
	"first_dinner_eaten", "curtain_trap_set", "bogge_survived", "puca_resisted",
	"tamlin_wound_dressed", "manor_map_drawn", "study_mural_seen", "suriel_bound", "naga_survived",
	"summer_faerie_comforted", "starlight_pool_found"]

var easel: Node3D


func _ready() -> void:
	# The studio pauses the game; the playtest keeps running through it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()


func _run() -> void:
	game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	_load_seconds = Time.get_unix_time_from_system() - _started_at
	_log("game scene loaded in %.1f s (wall)" % _load_seconds)
	await _play()
	if not _finished:
		_release_all()
		if StudioUi.is_open():
			StudioUi.close()
		_note_shutdown_suspects()
		await _settle(settle_limit)
		_finish(0 if beats.all(func(b: Dictionary) -> bool: return b.status == "pass") else 1)


func _play() -> void:
	_begin("spawn", "Feyre stands at the cottage, controllable")
	if not await _until(func() -> bool: return game.spawned, 30.0):
		return _fail("never spawned")
	feyre = game.feyre
	_pass()

	_begin("dev_jump_p4", "DEV JUMP: deeds through starlight_pool_found; set down at the painting-room easel")
	_beat["dev_jump"] = true
	# The p3 house facts that the real path writes before manor_map_drawn;
	# without them the five hall-mark moments start (auto) once the house
	# streams in, and the run would be testing a p3 state no player has.
	for i in range(1, 6):
		WorldState.set_flag("fact.hall_x_%d" % i)
		WorldState.set_flag("fact.hall_mark_%d" % i)
	WorldState.set_flag("fact.hall_map_set_down")
	for flag in DEV_DEEDS:
		WorldState.raise_deed(flag)
	_note("phase %s" % PhaseManager.current_phase)
	var s := ManorSitePlan.SPAWN
	feyre.set_physics_process(false)
	feyre.global_position = Vector3(s.x, WorldHeight.height_at(s.x, s.z) + 1.0, s.z)
	WorldStreamer.update_for(feyre.global_position)
	if not await _until_wall(func() -> bool: return _anchor(&"painting_room_easel") != null, 600.0):
		return _fail("the house never streamed in (no painting_room_easel anchor; region %s)" % _region())
	var stand := _anchor(&"painting_room_easel")
	easel = _studio_easel(stand.global_position)
	if easel == null:
		return _fail("no easel station within 3 m of painting_room_easel")
	# The house builds its floors over a few frames after it streams in (fast
	# on the Mac): set her down until she stays on the upstairs floor by the
	# easel for 1.5 s, instead of falling through to the ground floor.
	var settled := false
	var tries := 0
	var end := Time.get_unix_time_from_system() + 60.0
	while not settled and Time.get_unix_time_from_system() < end:
		tries += 1
		feyre.global_position = stand.global_position + Vector3.UP * 0.2
		feyre.velocity = Vector3.ZERO
		feyre.set_physics_process(true)
		await _wait(0.3)
		settled = await _until(func() -> bool: return not _by_easel(), 1.5) == false
		if not settled:
			await _wait(1.0)
	if not settled:
		return _fail("never stayed on the painting-room floor (%d tries, at %s, %.1f m from the easel)" % [
			tries, _v(feyre.global_position), feyre.global_position.distance_to(easel.global_position)])
	if tries > 1:
		_note("set down %d times before the floor held" % tries)
	_note("at the easel %.1f m away, phase %s" % [feyre.global_position.distance_to(easel.global_position), PhaseManager.current_phase])
	_pass()

	_begin("studio_open", "E at the easel opens the studio, paused, with charcoal at least")
	for i in 45:
		_turn_camera_to(easel.global_position + Vector3.UP)
		await get_tree().physics_frame
	if easel.get_node_or_null(StudioNook.NAME) == null:
		return _fail("the easel has no painting nook around it")
	await _look_around_nook()
	await _press(&"interact")
	if not await _until_wall(func() -> bool: return StudioUi.is_open(), 3.0):
		return _fail("E didn't open the studio (%.1f m from the easel, on floor %s, reach %.1f, control %s)" % [
			feyre.global_position.distance_to(easel.global_position), feyre.is_on_floor(), Interactor.REACH,
			StoryControl.Mode.keys()[StoryControl.mode]])
	var session := StudioUi.session()
	_note("%d paints, stocked %s, paused %s" % [session.supply.paints().size(), StudioSupply.stocked(), get_tree().paused])
	if StudioSupply.stocked():
		return _fail("the room was stocked before she asked for paint")
	_pass()

	_begin("gallery_opened", "her first stroke asks for paint: gallery_opened, the gallery door unlocks, the room is stocked")
	session.select_paint(StudioSupply.CHARCOAL)
	session.canvas.brush = StudioCanvas.brushes()[0]
	session.canvas.size_index = 0
	var why: String = await _stroke(session, _curve(Vector2(60, 470), Vector2(964, 430), -50.0))
	if why != "":
		return _fail("the stroke didn't land: %s" % why)
	if not WorldState.has_flag("gallery_opened"):
		return _fail("no gallery_opened after the first stroke")
	var door := _find_named(StudioDeeds.GALLERY_DOOR) as ManorDoorLeaf
	if door == null or not door.is_open():
		return _fail("the gallery door didn't open (%s)" % ("missing" if door == null else "still shut"))
	_note("door open; %d paints now" % session.supply.paints().size())
	_pass()

	_begin("first_painting", "mix in a well, paint, finish: first_painting, the canvas leans by the wall, the easel shows a fresh canvas")
	var found_before := StudioPalette.found_names().size()
	await _paint_picture(session)
	_note("colours found %d -> %d; strokes %d" % [found_before, StudioPalette.found_names().size(), session.canvas.strokes])
	var finish := _button(StudioUi._open, "Finish and set it aside")
	if finish == null:
		return _fail("no Finish button in the studio")
	finish.pressed.emit()
	if not await _until_wall(func() -> bool: return not StudioUi.is_open() and not get_tree().paused, 3.0):
		return _fail("the studio didn't close after Finish")
	if not WorldState.has_flag("first_painting"):
		return _fail("no first_painting after finishing")
	var spots := easel.get_parent().get_node_or_null(StudioRoom.SPOTS_NAME)
	var leaning := 0
	if spots:
		for spot in spots.get_children():
			leaning += spot.get_child_count()
	if leaning != 1:
		return _fail("expected one canvas leaning by the wall, found %d" % leaning)
	if easel.get_node_or_null(StudioRoom.VIEW_NAME) == null:
		return _fail("no canvas showing on the easel")
	_note("%d paintings in the gallery record" % Gameplay.gallery.count())
	# Look at it leaning by the wall, as a player would.
	var canvas_obj: Node3D = null
	for spot in spots.get_children():
		if spot.get_child_count() > 0:
			canvas_obj = spot.get_child(0)
	for i in 120:
		_turn_camera_to(canvas_obj.global_position)
		await get_tree().physics_frame
	_pass()

	_begin("gallery_seen", "DEV: set down outside the gallery door; walk in; the gallery moment plays")
	var inside := _anchor(&"manor_gallery")
	if inside == null:
		return _fail("no manor_gallery anchor")
	var into := (inside.global_position - door.global_position)
	into.y = 0.0
	var outside := door.global_position - into.normalized() * 2.0
	feyre.global_position = Vector3(outside.x, inside.global_position.y + 0.2, outside.z)
	feyre.velocity = Vector3.ZERO
	await _wait(0.5)
	var played := [false]
	EventBus.scene_space_finished.connect(func(id: StringName) -> void:
		if id == &"gallery":
			played[0] = true)
	await _walk_to(door.global_position + into.normalized() * 1.5, 1.0, Callable(), 20.0)
	await _walk_to(inside.global_position, 2.0, func() -> bool: return played[0], 40.0)
	_release_all()
	if not await _until(func() -> bool: return played[0], 20.0):
		return _fail("the gallery moment never finished (at %s, %.1f m from the anchor)" % [_v(feyre.global_position), _flat(inside.global_position)])
	_pass()


## The clip looks around the painting nook here; the playtest doesn't.
func _look_around_nook() -> void:
	pass


## A small spring landscape: a periwinkle-to-blush sky in washes, spring-green
## hills mixed in a well, rose blossoms mixed with white, and a little gold.
func _paint_picture(session: StudioSession) -> void:
	var c := session.canvas
	var b := StudioCanvas.brushes()
	c.brush = b[3]  # wash
	c.size_index = 3
	session.select_paint(&"manor:14")  # periwinkle
	for i in 4:
		await _stroke(session, _curve(Vector2(-20, 60 + i * 55), Vector2(1044, 80 + i * 55), 12.0))
	session.select_paint(&"manor:12")  # blush
	for i in 3:
		await _stroke(session, _curve(Vector2(-20, 300 + i * 50), Vector2(1044, 290 + i * 50), -10.0))
	# Spring green: sap green and butter in a well.
	session.select_paint(&"manor:6")
	session.tap_well(0)
	session.select_paint(&"manor:16")
	session.tap_well(0)
	c.brush = b[2]  # bristle
	c.size_index = 3
	for i in 5:
		await _stroke(session, _curve(Vector2(-20, 500 + i * 55), Vector2(1044, 470 + i * 60), -60.0 + i * 10))
	# Rose: rose madder and lead white, twice the madder.
	session.select_paint(&"manor:5")
	session.tap_well(1)
	session.select_paint(&"manor:3")
	session.tap_well(1)
	session.select_paint(&"manor:5")
	session.tap_well(1)
	c.brush = b[0]  # round
	c.size_index = 1
	for i in 9:
		var at := Vector2(140 + i * 90, 560 + (i % 3) * 40)
		await _stroke(session, _curve(at, at + Vector2(14, -10), 6.0))
	c.brush = b[4]  # sparkle
	c.size_index = 2
	session.select_paint(&"manor:18")  # gold leaf
	await _stroke(session, _curve(Vector2(120, 140), Vector2(900, 120), 60.0))


## One stroke. The clip overrides this to paint it over several frames.
func _stroke(session: StudioSession, points: Array[Vector2]) -> String:
	var why := session.paint_line(points)
	await get_tree().process_frame
	return why


## A gently bowed stroke from a to b, the way a hand paints.
func _curve(a: Vector2, b: Vector2, bow: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := (b - a).normalized().orthogonal()
	for i in 25:
		var t := i / 24.0
		out.append(a.lerp(b, t) + n * sin(t * PI) * bow)
	return out


func _by_easel() -> bool:
	return feyre.is_on_floor() and feyre.global_position.distance_to(easel.global_position) < Interactor.REACH - 0.1


func _studio_easel(near: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := 3.0
	for st in get_tree().get_nodes_in_group(&"station"):
		if st is Node3D and StringName(st.get(&"station_id")) == &"easel":
			var d := (st as Node3D).global_position.distance_to(near)
			if d < best_d:
				best_d = d
				best = st
	return best


func _button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null
