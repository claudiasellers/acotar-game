## Look shots of the Archeron cottage interior (L38-2; needs a GPU, Mac shots,
## docs/SHOTS.md):  godot res://tools/cottage_room_shot.tscn -- <out_dir>
## Free camera at eye height in the cottage frame: the main room from the front
## door and from the hearth, the sisters' room through its door and from the
## bed's foot. Fire and candle light only, with a low dawn ambient through the
## shutters' cracks.
extends Node3D

const COTTAGE := "res://world/human_realm/cottage/cottage.tscn"
## [name, eye (cottage frame), look-at (cottage frame)]
const VIEWS := [
	["main_from_door", Vector3(-1.9, 1.6, -2.3), Vector3(2.6, 0.8, 1.2)],
	["main_from_hearth", Vector3(2.9, 1.55, -1.6), Vector3(-1.4, 0.8, 0.8)],
	["sisters_room_door", Vector3(-2.2, 1.6, -1.9), Vector3(-2.9, 0.5, 1.6)],
	["sisters_room_inside", Vector3(-1.5, 1.5, 0.3), Vector3(-3.6, 0.7, 0.9)],
	["hearth_and_cot", Vector3(0.6, 1.4, 0.4), Vector3(3.2, 0.5, 1.6)],
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://cottage_rooms"
	DirAccess.make_dir_recursive_absolute(out)
	Clock.paused = true
	Clock.time_of_day = 0.3
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.56, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.31, 0.34)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var cottage := (load(COTTAGE) as PackedScene).instantiate() as Node3D
	add_child(cottage)
	var cot := cottage.find_child("ArcheronCottage", true, false) as Node3D
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	add_child(cam)
	cam.make_current()
	await get_tree().create_timer(1.0).timeout
	for v: Array in VIEWS:
		cam.global_position = cot.global_transform * (v[1] as Vector3)
		cam.look_at(cot.global_transform * (v[2] as Vector3), Vector3.UP)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var path := out.path_join("cottage_%s.png" % v[0])
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	get_tree().quit()
