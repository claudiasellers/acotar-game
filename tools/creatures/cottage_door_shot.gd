## Shots of the cottage doorway (L86-27): the front wall by day with the door
## broken open, close on the opening, and from inside looking out, to check no
## timber crosses the doorway.  res://tools/creatures/cottage_door_shot.tscn -- <out_dir>
extends Node

var out_dir := "user://cottage_door"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [out_dir, name])
		print("SHOT %s" % name)


func _run() -> void:
	var game := (load("res://story/act1/act1_game.tscn") as PackedScene).instantiate()
	add_child(game)
	var w := 0.0
	while not game.get(&"spawned") and w < 90.0:
		await _wait(0.5)
		w += 0.5
	var feyre := game.get(&"feyre") as Node3D
	Clock.from_dict({"time_of_day": 0.45, "day": 1})
	var door: Node3D = null
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == &"act1_cottage_door":
			door = a
	var out := door.global_basis.z
	out.y = 0.0
	out = out.normalized()
	var side := out.cross(Vector3.UP)
	feyre.global_position = door.global_position + out * 12.0 - side * 10.0 + Vector3.UP * 0.5
	await _wait(4.0)
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.make_current()
	var base := door.global_position
	for state in ["intact", "broken"]:
		if state == "broken":
			WorldState.raise_deed("fact.cottage_door_broken")
			await _wait(1.5)
		cam.global_position = base + out * 6.0 + side * 1.5 + Vector3.UP * 1.6
		cam.look_at(base + Vector3.UP * 1.1, Vector3.UP)
		await _wait(1.0)
		await _shot("%s_1_front" % state)
		cam.global_position = base + out * 2.2 + Vector3.UP * 1.3
		cam.look_at(base + Vector3.UP * 1.1, Vector3.UP)
		await _wait(0.5)
		await _shot("%s_2_doorway" % state)
	cam.global_position = base - out * 2.5 + Vector3.UP * 1.4
	cam.look_at(base + out * 3.0 + Vector3.UP * 1.1, Vector3.UP)
	await _wait(0.5)
	await _shot("broken_3_inside_out")
	get_tree().quit(0)
