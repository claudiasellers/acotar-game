## L86-31: the manor arrival to the first dinner, with shots when rendered.
##   res://tools/_probe/dinner_probe.tscn -- <out_dir>
extends Node

var out_dir := "user://dinner"
var game: Node
var feyre: Node3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT %s | %s" % [name, _state()])
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img and img.get_width() > 8:
		img.save_png("%s/%s.png" % [out_dir, name])
	print("SHOT %s | %s" % [name, _state()])


func _space(cls: Variant) -> Act2Space:
	var a := get_tree().root.find_children("*", "Node", true, false)
	for n in a:
		if is_instance_of(n, cls):
			return n as Act2Space
	return null


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


func _state() -> String:
	var arr := _space(ManorArrival) as ManorArrival
	var wel := _space(AlisWelcome) as AlisWelcome
	var din := _space(FirstDinner) as FirstDinner
	var chair := SpringMagic.foot_chair(self)
	var s := "caption '%s' feyre %s" % [LinePresenter.of(get_tree()).showing, _v(feyre.global_position)]
	for sp: Act2Space in [arr, wel, din]:
		if sp and sp.running:
			s += " | %s '%s'" % [sp.space_id, sp.current_beat_label()]
			for id: StringName in [&"tamlin_beast", &"tamlin", &"alis", &"lucien"]:
				var a := sp.actor(id)
				if a:
					s += " %s %s" % [id, _v(a.global_position)]
	s += " | chair %s" % (_v(chair.global_position) if chair else "none")
	if arr and arr.running:
		var b := arr.actor(&"tamlin_beast")
		if b:
			var dest: Variant = b.get(&"_destination")
			var nm := NavMover.on(b)
			s += " | beast %s cls %s stage %s dest %s mesh %s next %s fin %s" % [b.name, b.get_class(), b.get(&"stage"),
					_v(dest) if dest is Vector3 else "-", nm.has_mesh_at(b.global_position),
					_v(nm.steer(dest)) if dest is Vector3 else "-", nm.is_navigation_finished()]
			s += " ws %s burst %s proc %s paused %s ride %s" % [b.get(&"walk_speed"), b.get(&"_bursting"), b.is_processing(), get_tree().paused,
					str(get_tree().get_first_node_in_group(RideNorth.GROUP).get(&"running")) if get_tree().get_first_node_in_group(RideNorth.GROUP) else "none"]
	return s


func _ground(x: float, z: float) -> float:
	var space := get_viewport().world_3d.direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -20, z), 1))
	return (hit["position"] as Vector3).y if not hit.is_empty() else NAN


func _put(at: Vector3) -> void:
	if feyre is CharacterBody3D:
		(feyre as CharacterBody3D).velocity = Vector3.ZERO
	feyre.global_position = at


func _run() -> void:
	game = (load("res://story/act1/act1_game.tscn") as PackedScene).instantiate()
	add_child(game)
	var w := 0.0
	while not game.get(&"spawned") and w < 90.0:
		await _wait(0.5)
		w += 0.5
	feyre = game.get(&"feyre")
	await _wait(3.0)
	for flag in ["wolf_killed", "pelt_sold", CottageEvening.SUPPER, CottageEvening.SLEPT, "fact.cottage_door_broken",
			"beast_claim_accepted", "fact.ride_north_done"]:
		WorldState.raise_deed(flag)
	WorldState.set_flag("wall_crossed")
	Clock.from_dict({"time_of_day": 0.45, "day": 2})
	# Out on the drive, south of the front door: the manor streams in.
	_put(Vector3(0, 20, -20))
	WorldStreamer.hold(&"manor_estate")
	w = 0.0
	while w < 60.0:
		var y := _ground(0.0, -24.0)
		if not is_nan(y) and _space(ManorArrival):
			_put(Vector3(0, y + 0.2, -24.0))
			break
		await _wait(0.5)
		w += 0.5
	print("PROBE at the doors | %s" % _state())
	var arr: ManorArrival = null
	w = 0.0
	while w < 20.0:
		arr = _space(ManorArrival) as ManorArrival
		if arr and arr.running:
			break
		await _wait(0.25)
		w += 0.25
	print("PROBE arrival running %s" % (arr.running if arr else false))
	await _wait(2.5)
	await _shot("1_follow_him_in")
	# Follow on his trail, a couple of seconds behind, until he calls her in.
	var trail: Array[Vector3] = []
	for i in 160:
		await _wait(0.25)
		var b := arr.actor(&"tamlin_beast")
		if b:
			if trail.is_empty() or trail.back().distance_to(b.global_position) > 0.3:
				trail.append(b.global_position)
			if trail.size() > 6:
				var at: Vector3 = trail[trail.size() - 7]
				_put(at + Vector3.UP * 0.1)
			elif b.global_position.distance_to(feyre.global_position) > 2.5:
				var to := b.global_position - feyre.global_position
				to.y = 0.0
				_put(feyre.global_position + to.normalized() * 0.6)
		if i % 8 == 0:
			print("PROBE follow %d | %s" % [i, _state()])
		if i == 12 and b:
			var p0 := b.global_position
			b.call(&"_process", 0.1)
			var p1 := b.global_position
			await get_tree().process_frame
			var p2 := b.global_position
			await get_tree().physics_frame
			var nm := NavMover.on(b)
			for k in 6:
				await get_tree().process_frame
				print("PROBE frame %d at %s steer %s idx %d path %s" % [k, _v(b.global_position), _v(nm.steer(b.get(&"_destination"))),
						nm.get_current_navigation_path_index(), nm.get_current_navigation_path()])
			print("PROBE manual step %s -> %s -> frame %s -> physics %s" % [_v(p0), _v(p1), _v(p2), _v(b.global_position)])
		if i == 20:
			await _shot("1b_down_the_hall")
		if arr.current_beat_label() == "say call_in":
			await _shot("2_in_here")
			break
	# Step back into the hall, out of the room.
	_put(arr.mark(&"hall_east") + Vector3(0, 0.1, 0))
	# She hangs back in the hall: he goes on to the chair and waits.
	await _wait(6.0)
	print("PROBE hanging back | %s" % _state())
	await _shot("3_waits_at_the_chair")
	# Through the doors.
	_put(arr.mark(&"dining_door") + Vector3(1.0, 0.1, 0.6))
	await _wait(0.4)
	await _shot("4_the_change")
	print("PROBE in the room | %s" % _state())
	w = 0.0
	while arr.running and arr.current_beat_label() != "say chair" and w < 30.0:
		await _wait(0.25)
		w += 0.25
	await _wait(0.6)
	await _shot("5_chair_slides_out")
	while arr.running and arr.current_beat_label() != "say eat" and w < 60.0:
		await _wait(0.25)
		w += 0.25
	await _shot("6_eat")
	while arr.running and w < 120.0:
		await _wait(0.5)
		w += 0.5
	print("PROBE arrival done | %s" % _state())
	# Her room: Alis shows her the bath.
	var wel: AlisWelcome = null
	w = 0.0
	while w < 20.0:
		wel = _space(AlisWelcome) as AlisWelcome
		if wel and wel.running:
			break
		await _wait(0.25)
		w += 0.25
	print("PROBE welcome running %s | %s" % [wel.running if wel else false, _state()])
	w = 0.0
	while wel.running and wel.current_beat_label() != "say alis_this_way" and w < 30.0:
		await _wait(0.25)
		w += 0.25
	await _wait(0.8)
	await _shot("7_this_way")
	_put(wel.mark(&"bath") + Vector3(-1.2, 0.1, 0))
	await _wait(1.5)
	await _shot("8_at_the_bath")
	wel.press_interact()
	while wel.running and w < 120.0:
		await _wait(0.5)
		w += 0.5
	print("PROBE welcome done | %s" % _state())
	# The first dinner.
	var din: FirstDinner = null
	w = 0.0
	while w < 30.0:
		din = _space(FirstDinner) as FirstDinner
		if din and din.running:
			break
		await _wait(0.25)
		w += 0.25
	print("PROBE dinner running %s | %s" % [din.running if din else false, _state()])
	while din.running and not din.current_beat_label().begins_with("reach feyre_chair") and w < 60.0:
		await _wait(0.25)
		w += 0.25
	await _wait(1.0)
	await _shot("9_dinner_chair_out")
	_put(din.mark(&"feyre_chair") + Vector3(0, 0.1, 0))
	while din.running and din.current_beat_label() != "say no_slaves" and w < 120.0:
		await _wait(0.25)
		w += 0.25
	await _shot("10_no_slaves")
	while din.running and din.current_beat_label() != "until she rises" and w < 160.0:
		await _wait(0.25)
		w += 0.25
	din.nudge()
	await _wait(0.1)
	await _shot("11_she_rises")
	await _wait(FirstDinner.RISEN_SECONDS + 0.05)
	await _shot("12_green_hands")
	await _wait(0.3)
	await _shot("12b_green_hands")
	await _wait(4.0)
	print("PROBE held | %s" % _state())
	get_tree().quit(0)
