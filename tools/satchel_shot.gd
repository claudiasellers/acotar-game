## Milestone screenshots for the satchel lane (needs a GPU or lavapipe):
##   xvfb-run godot --rendering-driver vulkan res://tools/satchel_shot.tscn -- <page|bar|worn> [out.png]
extends Node

const GREYBOX := "res://story/act1/greybox/act1_greybox.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "page"
	var out := args[1] if args.size() > 1 else "user://satchel_%s.png" % id
	Gameplay.reset()
	var inv := Gameplay.inventory
	inv.coin = 7
	for pair in [[&"arrow_wood", 12], [&"arrow_ash", 1], [&"ing_bilberry", 6], [&"ing_snowdrop", 3],
			[&"ing_pine_resin", 4], [&"ing_venison", 2], [&"col_odd_stone", 1], [&"mat_shaft", 5],
			[&"obj_wolf_pelt", 1]]:
		inv.add(pair[0], pair[1])
	inv.add_dish({"key": "rabbit_stew", "name": "Rabbit stew", "hunger_relief": 0.3, "heal": 0.1})
	var scene := (load(GREYBOX) as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	var hud := SatchelHud.new()
	scene.add_child(hud)
	for i in 90:
		await get_tree().process_frame
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if id == "page":
		hud.menu.open()
		for i in 30:
			await get_tree().process_frame
	elif id == "bar" or id == "chord":
		# Wake the bar (it dims when idle); "chord" shows it with LB held.
		if id == "chord":
			hud.call(&"_set_chord", true)
		for i in 40:
			hud.set(&"_idle", 0.0)
			await get_tree().process_frame
	elif id == "worn" and feyre:
		var cam := Camera3D.new()
		feyre.add_child(cam)
		var model := (feyre as Feyre).model
		var left := model.global_basis.x
		var fwd := -model.global_basis.z
		cam.global_position = feyre.global_position + Vector3.UP * 1.05 + (left * 1.0 + fwd * 1.15)
		cam.look_at(feyre.global_position + Vector3.UP * 0.95)
		cam.fov = 40.0
		cam.current = true
		hud.visible = false
		for i in 20:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	get_tree().quit()
