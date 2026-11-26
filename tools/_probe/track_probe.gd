## L86-41: the ride north on the new direct track to the Wall. Shots when rendered.
##   res://tools/_probe/track_probe.tscn -- <out_dir>
extends Node

var out_dir := "user://track"
var game: Node
var feyre: Node3D
var ride: RideNorth


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


func _state() -> String:
	var s := "feyre %s" % _v(feyre.global_position)
	if ride:
		s += " | ride running %s beat '%s' step %s" % [ride.running, ride.current_beat_label() if ride.running else "", ride.step]
		if ride.horse and is_instance_valid(ride.horse):
			var d := ride.horse.global_position - feyre.global_position
			d.y = 0.0
			s += " mare %s (%.1f m) verb '%s' station %s" % [_v(ride.horse.global_position), d.length(),
					ride.horse.use_verb, ride.horse.is_in_group(&"station")]
	var up := UsePrompt.of(get_tree())
	s += " | prompt %s" % (str(up.offered()) if up else "none")
	return s


func _shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img and img.get_width() > 8:
			img.save_png("%s/%s.png" % [out_dir, name])
	print("SHOT %s | %s" % [name, _state()])


func _key(action: StringName, down: bool) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k := (e as InputEventKey).duplicate() as InputEventKey
			k.pressed = down
			Input.parse_input_event(k)
			return
	var a := InputEventAction.new()
	a.action = action
	a.pressed = down
	Input.parse_input_event(a)


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
			"beast_claim_accepted"]:
		WorldState.raise_deed(flag)
	w = 0.0
	while w < 30.0:
		ride = Act1Anchors.find_ride(get_tree())
		if ride and ride.running and ride.horse:
			break
		await _wait(0.25)
		w += 0.25
	print("PROBE ride | %s" % _state())
	if ride == null or ride.horse == null:
		print("PROBE no mare")
		get_tree().quit(1)
		return
	await _wait(2.0)
	# Beside her near side, facing her, as a player walks up.
	var m := ride.horse.global_transform
	var at := m.origin - m.basis.x.normalized() * 1.4
	at.y = feyre.global_position.y if absf(feyre.global_position.y - at.y) < 2.0 else at.y + 0.2
	if feyre is CharacterBody3D:
		(feyre as CharacterBody3D).velocity = Vector3.ZERO
	feyre.global_position = at
	feyre.look_at(Vector3(m.origin.x, at.y, m.origin.z), Vector3.UP, true)
	await _wait(1.5)
	await _shot("0a_at_the_mare")
	_key(&"interact", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_key(&"interact", false)
	await _wait(0.4)
	await _shot("0b_getting_up")
	await _wait(3.0)
	var bridge := ride.locate(Vector3(-75.0, 0.0, 1935.0)).x
	print("PROBE bridge at %.0f m, seam %.0f m" % [bridge, ride.seam_at()])
	ride.autopilot = func() -> Array:
		var to := ride.heading() - ride.horse.global_position
		to.y = 0.0
		return [to.normalized() if to.length() > 0.1 else Vector3.ZERO, ride.progress < ride.beast_at - 6.0]
	var stops := [[120.0, "1_on_the_track"], [bridge - 25.0, "2_to_the_bridge"], [bridge + 2.0, "3_on_the_bridge"],
			[ride.seam_at() - 140.0, "4_to_the_wall"], [ride.seam_at() - 25.0, "5_at_the_gap"]]
	var t0 := Time.get_ticks_msec()
	for stop: Array in stops:
		var w2 := 0.0
		while ride.progress < float(stop[0]) and w2 < 120.0:
			await _wait(0.1)
			w2 += 0.1
		await _shot(stop[1])
		print("PROBE %s at %.0f m after %.0f s" % [stop[1], ride.progress, (Time.get_ticks_msec() - t0) / 1000.0])
	print("PROBE result: %s" % ("THROUGH" if WorldState.has_flag("wall_crossed") or ride.progress > ride.seam_at() - 40.0 else "SHORT"))
	get_tree().quit(0)
