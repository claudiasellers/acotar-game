## Shots of the real yard after the beast scene (L86-25): plays BeastDoor from
## her slept night to its end (she freezes at the window), then the ride's
## start, and saves what her own camera sees inside, at the door and outside.
##   res://tools/creatures/cottage_exit_shot.tscn -- <out_dir>
extends Node

var out_dir := "user://cottage_exit"
var game: Node
var feyre: Node3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _find(n: Node, cls: Variant) -> Node:
	if is_instance_of(n, cls):
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	img.save_png("%s/%s.png" % [out_dir, name])
	var small := img.duplicate() as Image
	small.resize(64, 36)
	var sum := 0.0
	for y in 36:
		for x in 64:
			sum += small.get_pixel(x, y).get_luminance()
	print("SHOT %s mean luminance %.3f caption '%s'" % [name, sum / 2304.0, LinePresenter.of(get_tree()).showing])


func _run() -> void:
	game = (load("res://story/act1/act1_game.tscn") as PackedScene).instantiate()
	add_child(game)
	var w := 0.0
	while not game.get(&"spawned") and w < 90.0:
		await _wait(0.5)
		w += 0.5
	feyre = game.get(&"feyre")
	await _wait(6.0)
	LinePresenter.of(get_tree()).clear()
	for flag in ["wolf_killed", "pelt_sold", CottageEvening.SUPPER, CottageEvening.SLEPT]:
		WorldState.raise_deed(flag)
	Clock.from_dict({"time_of_day": 0.92, "day": 1})
	var door := _find(get_tree().root, BeastDoor) as BeastDoor
	if door == null:
		print("SHOT no BeastDoor")
		get_tree().quit(1)
		return
	var interior: Node3D = null
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == &"act1_cottage_door":
			interior = a
	feyre.global_position = interior.global_position - interior.global_basis.z * 2.5 + Vector3.UP * 0.3
	await _wait(1.0)
	door.set_player_inside(true)
	if not door.running:
		door.start()
	print("SHOT beast door running %s" % door.running)
	w = 0.0
	while door.running and w < 240.0:
		await _wait(0.5)
		w += 0.5
	print("SHOT beast door done after %.0f s (%s)" % [w, door.chosen_fact])
	var ride := get_tree().get_first_node_in_group(RideNorth.GROUP) as RideNorth
	w = 0.0
	while (ride == null or ride.horse == null) and w < 20.0:
		await _wait(0.25)
		w += 0.25
		ride = get_tree().get_first_node_in_group(RideNorth.GROUP) as RideNorth
	await _wait(2.0)
	await _shot("1_inside_after_goodbye")
	await _wait(3.0)
	await _shot("2_inside_thoughts")
	# Out of the broken door, as she'd walk.
	var out := interior.global_basis.z
	out.y = 0.0
	out = out.normalized()
	feyre.global_position = interior.global_position + out * 1.6 + Vector3.UP * 0.3
	feyre.look_at(feyre.global_position + out, Vector3.UP)
	await _wait(2.5)
	await _shot("3_at_the_door")
	await _wait(3.0)
	await _shot("4_his_order")
	print("SHOT mare %s beast %s feyre %s" % [ride.horse.global_position if ride else Vector3.ZERO,
			ride.beast.global_position if ride and ride.beast else Vector3.ZERO, feyre.global_position])
	print("SHOT said %s" % [ride.said if ride else []])
	await _wait(14.0)
	await _shot("5_lingering")
	get_tree().quit(0)
