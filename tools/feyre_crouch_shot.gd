## Poses Feyre in her crouch clips on a lit floor and saves frames, for judging the
## crouch by eye:
##   godot --path . res://tools/feyre_crouch_shot.tscn -- <out_dir> [clip=crouch_idle] [times=0,1.2]
## Each time writes <clip>_<i>_side.png and <clip>_<i>_front.png (1280x720).
## Needs a renderer (Mac GPU, or xvfb-run + Mesa lavapipe in the cloud).
extends Node3D

const MODEL := "res://characters/feyre/model/feyre_model.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://crouch"
	var clip := args[1] if args.size() > 1 else "crouch_idle"
	var times: Array[float] = []
	for s in (args[2] if args.size() > 2 else "0,1.2").split(","):
		times.append(float(s))
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	var stage := _stage()
	add_child(stage)
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	stage.add_child(model)
	await get_tree().process_frame
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim.has_animation_library(&"moves"):
		anim.add_animation_library(&"moves", FeyreAnimator.load_library())
	var cam := Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.current = true
	for i in times.size():
		anim.play(&"moves/" + clip)
		anim.seek(times[i], true)
		anim.pause()
		for view in [["side", Vector3(2.6, 0.7, 0.0)], ["front", Vector3(-1.3, 0.8, -2.3)]]:
			cam.global_position = view[1]
			cam.look_at(Vector3(0.0, 0.55, 0.0))
			for _f in 3:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			var path := out.path_join("%s_%d_%s.png" % [clip, i, view[0]])
			img.save_png(path)
			print("saved ", path)
	get_tree().quit(0)


func _stage() -> Node3D:
	var stage := Node3D.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.93, 0.86, 0.92)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1.0, 0.95, 0.97)
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.88, 0.8)
	plane.material = mat
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)
	return stage
