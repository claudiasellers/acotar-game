## Layout check for the saddle (L47): the white horse with Feyre's model on it
## in the ride pose, three views, no world. Cloud:
##   xvfb-run godot --rendering-method gl_compatibility res://tools/mount/ride_pose_shot.tscn -- <out_dir>
extends Node

const HORSE := preload("res://creatures/fae/white_horse.tscn")
const FEYRE := preload("res://characters/feyre/model/feyre_model.tscn")


class Rider:
	extends Node3D
	var model: Node3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://ride_pose"
	DirAccess.make_dir_recursive_absolute(out)
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.78, 0.8, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	root.add_child(sun)
	var horse := HORSE.instantiate() as WhiteHorse
	root.add_child(horse)
	var rider := Rider.new()
	root.add_child(rider)
	rider.model = FEYRE.instantiate() as Node3D
	WardrobeApplier.dress(rider.model)   # her Act I clothes, as in play (L41-4)
	rider.add_child(rider.model)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 40.0
	for i in 6:
		await get_tree().process_frame
	Saddle.seat(rider)
	for i in 4:
		Saddle.place(rider, horse)
		await get_tree().process_frame
	var at := horse.seat_point()
	var drop: float = rider.get_meta(Saddle.HIP_DROP)
	print("seat %s drop %.2f rider %s" % [at, drop, rider.global_position])
	for view: Array in [["side", Vector3(5.5, 1.6, 0.0)], ["front", Vector3(2.8, 2.2, -4.5)], ["back", Vector3(-2.5, 2.6, 4.5)]]:
		cam.look_at_from_position(view[1], Vector3(0, 1.3, 0))
		for i in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, view[0]])
	get_tree().quit()
