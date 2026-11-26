## The end of the ride north and the arrival at the manor (L86-28): prompts,
## the beast, the mare and the light, with shots when rendered.
##   res://tools/_probe/arrival_probe.tscn -- <out_dir>
extends Node

var out_dir := "user://arrival"
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


func _lum() -> float:
	if DisplayServer.get_name() == "headless":
		return -1.0
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return -1.0
	var small := img.duplicate() as Image
	small.resize(64, 36)
	var sum := 0.0
	for y in 36:
		for x in 64:
			sum += small.get_pixel(x, y).get_luminance()
	return sum / 2304.0


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT %s | %s" % [name, _state()])
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img and img.get_width() > 8:
		img.save_png("%s/%s.png" % [out_dir, name])
	print("SHOT %s lum %.3f | %s" % [name, _lum(), _state()])


func _find_all(n: Node, cls: Variant, out: Array) -> void:
	if is_instance_of(n, cls):
		out.append(n)
	for c in n.get_children():
		_find_all(c, cls, out)


func _arrival() -> ManorArrival:
	var a: Array = []
	_find_all(get_tree().root, ManorArrival, a)
	return a[0] if a.size() > 0 else null


func _state() -> String:
	var mares: Array = []
	_find_all(get_tree().root, MareMount, mares)
	var ms := []
	for m in mares:
		var mm := m as MareMount
		ms.append("%s %s st%d" % [mm.get_path().get_name(mm.get_path().get_name_count() - 1), _v(mm.global_position), mm.state])
	var beasts := get_tree().get_nodes_in_group(&"story_actor_tamlin_beast")
	var bs := []
	for b in beasts:
		var nm := NavMover.on(b as Node3D)
		var dest: Vector3 = b.get(&"_destination")
		var pth := NavigationServer3D.map_get_path(nm.get_navigation_map(), (b as Node3D).global_position, dest, true) if nm.has_mesh_at((b as Node3D).global_position) else PackedVector3Array()
		bs.append("%s %s st%s dest %s mesh %s stalls %s pathend %s" % [(b as Node).name, _v((b as Node3D).global_position), b.get(&"stage"), _v(dest),
				nm.has_mesh_at((b as Node3D).global_position), nm.stalls_short_of(dest), _v(pth[pth.size() - 1]) if pth.size() > 0 else "none"])
	var arr := _arrival()
	var env := get_viewport().get_camera_3d().get_world_3d().environment if get_viewport().get_camera_3d() else null
	return "caption '%s' t%.1f clock %.2f feyre %s step %d prompt '%s' arrival %s '%s' beasts %s mares %s mode %s exp %s" % [
		LinePresenter.of(get_tree()).showing, Time.get_ticks_msec() / 1000.0, Clock.hour(), _v(feyre.global_position), ride.step if ride else -1,
		UsePrompt.of(get_tree()).text(), arr.running if arr else false, arr.current_beat_label() if arr and arr.running else "",
		bs, ms, StoryControl.mode, ("%.2f" % env.tonemap_exposure) if env else "?"]


func _v(p: Vector3) -> String:
	return "(%.0f, %.0f, %.0f)" % [p.x, p.y, p.z]


func _run() -> void:
	game = (load("res://story/act1/act1_game.tscn") as PackedScene).instantiate()
	add_child(game)
	var w := 0.0
	while not game.get(&"spawned") and w < 90.0:
		await _wait(0.5)
		w += 0.5
	feyre = game.get(&"feyre")
	await _wait(4.0)
	for flag in ["wolf_killed", "pelt_sold", CottageEvening.SUPPER, CottageEvening.SLEPT, "fact.cottage_door_broken"]:
		WorldState.raise_deed(flag)
	Clock.from_dict({"time_of_day": 0.92, "day": 1})
	WorldState.set_flag("beast_claim_accepted")
	w = 0.0
	while w < 20.0:
		ride = get_tree().get_first_node_in_group(RideNorth.GROUP) as RideNorth
		if ride and ride.running and ride.horse:
			break
		await _wait(0.25)
		w += 0.25
	print("PROBE ride running %s" % (ride.running if ride else false))
	feyre.global_position = ride.horse.global_position + Vector3(1.0, 0.3, 0.0)
	await _wait(0.5)
	ride.mount(feyre)
	ride.autopilot = func() -> Array:
		var to := ride.heading() - ride.horse.global_position
		to.y = 0.0
		return [to.normalized() if to.length() > 0.1 else Vector3.ZERO, ride.progress < ride.beast_at - 6.0]
	await _wait(2.0)
	# Through the Wall and up the estate road in two jumps (long moves are
	# teleports to the Wall's guard), then ride the last stretch.
	for at in [ride.seam_at() + 30.0, ride.path_length() - 160.0]:
		for k in 3:
			ride.horse.global_transform = ride.pose_at(at)
			ride.beast_at = at + RideNorth.LEAD
			ride.beast.global_transform = ride.pose_at(ride.beast_at)
			await get_tree().physics_frame
		await _wait(3.0)
	print("PROBE jumped to %.0f | %s" % [ride.progress, _state()])
	w = 0.0
	while ride.step != RideNorth.Step.AT_STEPS and w < 120.0:
		await _wait(1.0)
		w += 1.0
		if int(w) % 5 == 0:
			print("PROBE riding %.0f/%.0f | %s" % [ride.progress, ride.path_length(), _state()])
	await _wait(1.0)
	await _shot("1_at_steps")
	await _wait(6.0)
	await _shot("2_waiting_to_get_down")
	await _wait(5.0)
	await _shot("2b_he_waits")
	ride.get_down()
	w = 0.0
	while ride.running and w < 10.0:
		await _wait(0.25)
		w += 0.25
	await _wait(1.0)
	await _shot("3_dismounted")
	for i in 40:
		await _wait(1.0)
		var arr := _arrival()
		var b := arr.actor(&"tamlin_beast") if arr and arr.running else null
		if b:
			var to := b.global_position - feyre.global_position
			to.y = 0.0
			if to.length() > 3.5:
				feyre.global_position += to.normalized() * minf(2.5, to.length() - 3.0)
		if i % 2 == 0:
			print("PROBE follow %d | %s" % [i, _state()])
		if i == 6:
			await _shot("4_following_in")
		if i == 14:
			await _shot("5_hall")
		if i == 26:
			await _shot("6_dining")
	get_tree().quit(0)
