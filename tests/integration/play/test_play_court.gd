# gate: needs:terrain
# gate: when:characters/feyre/feyre.gd,story/act1/act1_game.gd,systems/dialogue/dialogue_director.gd,systems/actor_body/*,systems/mount/*,data/mount/*,ui/map/world_map_hud.gd,ui/map/map_settings.gd,ui/settings_panel.gd,core/save_system.gd,systems/player_assist/player_placement.gd,tests/integration/play/play_harness.gd
## Play test (T097): the Spring Court, through Continue from a save after the
## first dinner (the mare ridden once, so the whistle works), driven by real
## key and pad events (tests/integration/play/README.md). Indoors in the manor,
## then out in the stable yard.
extends GutTest

const PlayHarness := preload("res://tests/integration/play/play_harness.gd")
const SLOT := "gut_play_court"
const SAVED_SLOT := "gut_play_court_saved"
## Her bedroom, upstairs in the manor (as in test_continue_contract.gd).
const BEDROOM := [20.15, 13.7, -63.54]
## Out of the stable yard toward the drive (tools/playtest/mount_ride_clip.gd ROUTE).
const RIDE_TO := Vector3(-60.0, 0.0, 160.0)
const SAVE := {
	"version": 2,
	"clock": {"day": 5, "time_of_day": 0.4},
	"world_state": {"flags": {"wolf_killed": true, "fact.wolf_skinned": true, "fact.wolf_spotted": true,
		"pelt_sold": true, "beast_claim_accepted": true, "wall_crossed": true, "fact.manor_arrived": true,
		"fact.alis_bathed": true, "first_dinner_eaten": true, "fact.mare_ridden": true}},
	"phase": {"phase": "p2_grounds", "phase_set": "res://data/phases/spring_court_phases.tres",
		"unlocked_regions": ["manor_estate", "manor_grounds", "manor_house"]},
	"world_deltas": {},
	"providers": {"player_placement": {"position": BEDROOM, "yaw": 0.0}},
}

var h: PlayHarness
var booted := false


func before_all() -> void:
	h = PlayHarness.new(self)
	booted = await h.boot_from_save(SLOT, SAVE)


func after_all() -> void:
	SaveSystem.delete_save(SLOT)
	SaveSystem.delete_save(SAVED_SLOT)
	await h.shutdown()
	h.dispose()


func before_each() -> void:
	if not booted:
		pending("Continue never gave her control")
	h.release_all()


func after_each() -> void:
	h.release_all()


func _body_of(node: Node) -> ActorBody:
	for c in node.find_children("*", "ActorBody", true, false):
		return c as ActorBody
	return null


func _presence(id: String) -> Node3D:
	for n in get_tree().get_nodes_in_group(DialogueDirector.PRESENCE_GROUP):
		if String(n.name).contains(id):
			return n as Node3D
	return null


## A floor spot `dist` m from `node` on the same storey with nothing solid
## between (world layer), or Vector3.INF.
func _clear_spot_near(node: Node3D, dist: float) -> Vector3:
	var space := node.get_world_3d().direct_space_state
	for i in 16:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 16.0)
		var side := dir.cross(Vector3.UP) * 0.35
		var blocked := false
		# Knee and chest height, her width either side: furniture is low.
		for lift: float in [0.25, 1.0]:
			for off: Vector3 in [Vector3.ZERO, side, -side]:
				var from := node.global_position + Vector3.UP * lift + off + dir * 0.4
				var q := PhysicsRayQueryParameters3D.create(from, from + dir * (dist + 0.4), 1)
				if not space.intersect_ray(q).is_empty():
					blocked = true
		if blocked:
			continue
		var spot := node.global_position + dir * dist
		var y := h.ground_y(spot.x, spot.z, node.global_position.y + 1.5)
		if not is_nan(y) and absf(y - node.global_position.y) < 0.3:
			return Vector3(spot.x, y, spot.z)
	return Vector3.INF


func test_she_wakes_in_her_bedroom_on_the_floor() -> void:
	if not booted:
		return
	assert_lt(PlayHarness.flat_distance(h.feyre.global_position, Vector3(BEDROOM[0], 0, BEDROOM[2])), 0.5)
	assert_true(h.on_solid_ground(), "standing on the bedroom floor")


func test_the_bedroom_wall_stops_her() -> void:
	if not booted:
		return
	await h.place_on_ground(BEDROOM[0], BEDROOM[2], 0.3, 600, BEDROOM[1] + 1.5)
	var start := h.feyre.global_position
	# West: the bedroom wall is about 3.9 m off (a ray from her chest).
	var space := h.feyre.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(start + Vector3.UP, start + Vector3.UP + Vector3.LEFT * 12.0, 1)
	q.exclude = [h.feyre.get_rid()]
	var hit := space.intersect_ray(q)
	assert_false(hit.is_empty(), "a wall to the west of her")
	if hit.is_empty():
		return
	var wall_at := start.distance_to((hit.position as Vector3) - Vector3.UP)
	var start_of_end := start
	for i in 150:
		h.stick_toward(start + Vector3.LEFT * 12.0)
		await wait_physics_frames(1)
		if i == 119:
			start_of_end = h.feyre.global_position
	h.stick(Vector2.ZERO)
	var went := PlayHarness.flat_distance(start, h.feyre.global_position)
	assert_gt(went, 1.0, "she ran toward the wall (%.2f m)" % went)
	assert_lt(PlayHarness.flat_distance(start_of_end, h.feyre.global_position), 0.2,
			"and was stopped, pushing, for the last half second")
	assert_lt(went, wall_at, "never past the wall (%.2f of %.2f m)" % [went, wall_at])


func test_talking_to_alis_shows_a_line_and_leaves_her_free() -> void:
	if not booted:
		return
	var alis := _presence("alis")
	assert_not_null(alis, "Alis is in the house")
	if alis == null:
		return
	var spot := _clear_spot_near(alis, 6.0)
	assert_ne(spot, Vector3.INF, "room to stand 6 m from Alis")
	if spot == Vector3.INF:
		return
	await h.place_on_ground(spot.x, spot.z, 0.3, 600, spot.y + 1.5)
	var dd := h.child_of(DialogueDirector) as DialogueDirector
	var heard: Array[StringName] = []
	var on_line := func(_id: StringName, speaker: StringName, _t: String, _at: Vector3, _inner: bool) -> void:
		heard.append(speaker)
	dd.line_spoken.connect(on_line)
	await h.look_toward(alis.global_position)
	await h.walk_to(alis.global_position, 2.5, 300, false, 0.4)
	var spoke := await h.wait_until(func() -> bool: return heard.has(&"alis"), 60 * 15)
	dd.line_spoken.disconnect(on_line)
	assert_true(spoke, "Alis says something when Feyre walks up (heard %s)" % [heard])
	assert_true(h.has_control(), "a line never takes the controls")
	var caption := get_tree().get_first_node_in_group(Act2Caption.GROUP) as Act2Caption
	if caption:
		assert_true(await h.wait_until(func() -> bool: return caption.showing == "", 60 * 20),
				"the caption goes away by itself")


func test_a_person_blocks_her_then_lets_her_squeeze_past() -> void:
	if not booted:
		return
	var alis := _presence("alis")
	if alis == null:
		pending("no Alis in the house")
		return
	var spot := _clear_spot_near(alis, 3.0)
	if spot == Vector3.INF:
		pending("no clear line to Alis")
		return
	await h.place_on_ground(spot.x, spot.z, 0.3, 600, spot.y + 1.5)
	var through := alis.global_position + (alis.global_position - spot).normalized() * 2.0
	through.y = alis.global_position.y
	var body := _body_of(alis)
	assert_not_null(body, "Alis has a body (ActorBody, T092)")
	if body == null:
		return
	var blocked_frames := 0
	var closest := INF
	var squeezed_at := -1
	var passed := false
	var tick := Engine.get_physics_frames()
	for i in 300:
		h.stick_toward(through, 0.6)
		await wait_physics_frames(1)
		# A busy machine runs two physics ticks in one frame: count ticks.
		var ticks := Engine.get_physics_frames() - tick
		tick = Engine.get_physics_frames()
		var d := PlayHarness.flat_distance(h.feyre.global_position, alis.global_position)
		if squeezed_at < 0 and body.squeezing:
			squeezed_at = i
		if squeezed_at < 0:
			# Solid: she never gets inside Alis before the squeeze.
			closest = minf(closest, d)
			if d < ActorBody.RADIUS + ActorBody.FEYRE_RADIUS + 0.2:
				blocked_frames += ticks
		if PlayHarness.flat_distance(h.feyre.global_position, through) < 0.6:
			passed = true
			break
	h.stick(Vector2.ZERO)
	assert_gt(closest, ActorBody.RADIUS + ActorBody.FEYRE_RADIUS - 0.1,
			"Alis is solid: Feyre stops against her (closest %.2f m before the squeeze)" % closest)
	assert_gt(blocked_frames, int(ActorBody.SQUEEZE_TIME * 60.0 * 0.8),
			"she is held up about SQUEEZE_TIME against Alis (%d physics ticks)" % blocked_frames)
	assert_true(squeezed_at >= 0 and passed,
			"then Alis lets her squeeze past (squeeze at frame %d, ended %.2f m short)" % [
			squeezed_at, PlayHarness.flat_distance(h.feyre.global_position, through)])


func test_n_hides_and_shows_the_minimap() -> void:
	if not booted:
		return
	var hud := h.child_of(WorldMapHud) as WorldMapHud
	await h.wait_until(func() -> bool: return hud.minimap.visible, 30)
	var was := hud.minimap.visible
	assert_true(was, "the minimap is on")
	await h.press(&"map_minimap")
	await wait_process_frames(2)
	assert_ne(hud.minimap.visible, was, "N flips it")
	await h.press(&"map_minimap")
	await wait_process_frames(2)
	assert_eq(hud.minimap.visible, was, "N again puts it back")


func _to_the_stable_yard() -> bool:
	var md := h.child_of(MountDirector) as MountDirector
	var home := md.data.home
	return await h.place_on_ground(home.x + 4.0, home.z + 7.0)


func test_walk_run_sprint_move_her_and_letting_go_stops_her() -> void:
	if not booted:
		return
	assert_true(await _to_the_stable_yard(), "out in the stable yard")
	var out := h.feyre.global_position
	var speeds := {}
	for mode: Array in [[&"walk", 0.4, false], [&"run", 1.0, false], [&"sprint", 1.0, true]]:
		await h.place_on_ground(out.x, out.z, 1.0, 600, out.y + 1.5)
		var from := h.feyre.global_position
		if mode[2]:
			h.hold(&"sprint")
		h.stick(Vector2(0.0, 1.0) * mode[1])
		await wait_physics_frames(45)
		speeds[mode[0]] = h.flat_speed()
		h.stick(Vector2.ZERO)
		h.release(&"sprint")
		assert_gt(PlayHarness.flat_distance(from, h.feyre.global_position), 0.5, "%s moves her" % mode[0])
		assert_true(await h.wait_still(45), "%s: she stops within 45 frames of letting go (speed %.2f)" % [mode[0], h.flat_speed()])
	assert_lt(speeds.walk, speeds.run, "a light stick walks, slower than a full run (%s)" % [speeds])
	assert_lt(speeds.run, speeds.sprint, "sprint is faster than a run (%s)" % [speeds])


func test_whistle_brings_the_mare_and_she_mounts_rides_and_gets_down() -> void:
	if not booted:
		return
	assert_true(await _to_the_stable_yard(), "out in the stable yard")
	var md := h.child_of(MountDirector) as MountDirector
	var answers: Array[bool] = []
	var on_whistle := func(ok: bool) -> void: answers.append(ok)
	md.whistled.connect(on_whistle)
	await h.press(&"call_mount")
	await wait_process_frames(2)
	md.whistled.disconnect(on_whistle)
	assert_eq(answers, [true] as Array[bool], "H whistles and she answers (blocked: %s)" % md.last_block)
	if answers != ([true] as Array[bool]):
		return
	var came := await h.wait_until(func() -> bool:
		return md.mare != null and is_instance_valid(md.mare) and md.mare.state == MareMount.State.STANDING \
				and md.mare.global_position.distance_to(h.feyre.global_position) < 5.0, 60 * 30)
	assert_true(came, "the mare comes up beside her and stands")
	if not came:
		return
	await h.look_toward(md.mare.global_position)
	await h.walk_to(md.mare.global_position, 1.6, 240, false, 0.4)
	await h.press(&"interact")
	var up := await h.wait_until(func() -> bool: return md.riding, 30)
	assert_true(up, "E by the mare puts her in the saddle")
	if not up:
		return
	# Ride out of the yard toward the drive (open ground, the mount clip's
	# route): the stick canters, sprint gallops.
	var from := md.mare.global_position
	var canter := 0.0
	var gallop := 0.0
	for i in 240:
		if i == 120:
			canter = md.mare.speed
			h.hold(&"sprint")
		h.stick_toward(RIDE_TO)
		await wait_physics_frames(1)
	gallop = md.mare.speed
	h.release(&"sprint")
	h.stick(Vector2.ZERO)
	assert_gt(PlayHarness.flat_distance(from, md.mare.global_position), 5.0, "the stick rides her forward")
	assert_gt(gallop, canter, "sprint gallops faster than the canter (%.1f vs %.1f m/s)" % [gallop, canter])
	assert_lt(h.feyre.global_position.distance_to(md.seat_point()), 1.5, "Feyre rides along in the saddle")
	await h.wait_until(func() -> bool: return md.mare.speed < 0.3, 60 * 6)
	# A tap of E with nothing in reach gets her down.
	await h.press(&"interact")
	var down := await h.wait_until(func() -> bool: return not md.riding, 30)
	assert_true(down, "E with nothing in reach gets her down")
	assert_true(await h.wait_until(func() -> bool: return h.has_control(), 60), "and she has her legs back")
	assert_true(await h.wait_still(120) and h.on_solid_ground(), "standing on the ground beside the mare")
	var before := h.feyre.global_position
	await h.hold_for(&"move_back", 30)
	assert_gt(PlayHarness.flat_distance(before, h.feyre.global_position), 0.5, "and she walks")


func test_pause_saves_and_continue_puts_her_back() -> void:
	if not booted:
		return
	assert_true(await _to_the_stable_yard(), "out in the stable yard")
	await h.hold_for(&"move_right", 20)
	await h.wait_still()
	var panel := h.child_of(SettingsPanel) as SettingsPanel
	await h.press(&"pause")
	assert_true(panel.is_open(), "Esc opens the pause menu")
	# The menu's Save buttons save then leave for the title, which would end
	# this run, so the save is the button's own call; the load is real Continue.
	assert_eq(SaveSystem.save_game(SAVED_SLOT), OK, "saved")
	await h.press(&"pause")
	assert_false(panel.is_open(), "Esc closes it")
	var at := h.feyre.global_position
	var yaw := h.feyre.model.rotation.y
	var flags := WorldState.all_flags().duplicate()
	var phase := PhaseManager.current_phase
	await h.shutdown()
	booted = await h.boot_slot(SAVED_SLOT)
	assert_true(booted, "Continue gives her control")
	# F3 (T097, fixed by T110): the freed-lambda error no longer fires here.
	if not booted:
		return
	assert_lt(PlayHarness.flat_distance(at, h.feyre.global_position), 0.5,
			"she is where she saved (%s, saved at %s)" % [h.feyre.global_position, at])
	assert_almost_eq(h.feyre.model.rotation.y, yaw, 0.05, "facing the same way")
	assert_eq(PhaseManager.current_phase, phase, "same phase")
	var now_flags := WorldState.all_flags()
	var lost := flags.keys().filter(func(k: String) -> bool: return not now_flags.has(k))
	var gained := now_flags.keys().filter(func(k: String) -> bool: return not flags.has(k))
	assert_eq(lost, [], "no deed lost in the load")
	# Lines heard since she landed (dlg.*) are new, honestly; nothing else is.
	assert_eq(gained.filter(func(k: String) -> bool: return not k.begins_with("dlg.")), [],
			"no deed gained by loading (gained %s)" % [gained])
	assert_true(await h.wait_still(120) and h.on_solid_ground(), "standing on the ground")
	var before := h.feyre.global_position
	await h.hold_for(&"move_back", 20)
	assert_gt(PlayHarness.flat_distance(before, h.feyre.global_position), 0.5, "and she walks")
