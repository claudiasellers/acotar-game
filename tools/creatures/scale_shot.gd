## The monsters in a row beside Feyre (1.7 m), so their sizes can be judged
## (lane L83). Renders in the cloud under xvfb:
##   xvfb-run -a godot --path . res://tools/creatures/scale_shot.tscn -- <out_dir>
## Writes monster_scale.png.
extends Node

const SIZE := Vector2i(1920, 1080)
const FEYRE := "res://characters/feyre/model/feyre_model.tscn"
const FAE := "res://creatures/models/fae/"
## [model, x, height off the ground, clip to stand in]
const ROW: Array[Array] = [["suriel", -3.9, 0.0, &"idle"], ["naga", -2.0, 0.0, &"idle"], ["briarling", 1.7, 0.0, &"idle"],
		["hollow_crow", 3.1, 0.0, &"idle"], ["bogge_jaw", 4.3, 1.5, &""], ["bogge_claws", 4.3, 0.9, &""], ["bogge_eye", 4.3, 2.0, &""]]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://scale_shot"
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = SIZE
	var cam := _stage()
	var feyre := (load(FEYRE) as PackedScene).instantiate() as Node3D
	add_child(feyre)
	for row in ROW:
		var path: String = FAE + row[0] + ".gltf"
		if not ResourceLoader.exists(path):
			continue
		var m := (load(path) as PackedScene).instantiate() as Node3D
		add_child(m)
		m.position = Vector3(row[1], row[2], 0.0)
		var anim := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim != null and anim.has_animation(row[3]):
			anim.play(row[3])
			anim.seek(0.0, true)
			anim.pause()
	# a few lampwings at her shoulder
	var moth_path := FAE + "lampwing.gltf"
	if ResourceLoader.exists(moth_path):
		for i in 5:
			var moth := (load(moth_path) as PackedScene).instantiate() as Node3D
			add_child(moth)
			moth.position = Vector3(0.55 + 0.16 * (i % 3), 1.25 + 0.14 * (i / 3) + 0.05 * (i % 2), -0.1)
			moth.rotation = Vector3(0.5, 0.5 * i, 0.0)
	cam.global_position = Vector3(0.2, 1.25, -9.6)
	cam.look_at(Vector3(0.2, 1.05, 0.0))
	cam.fov = 33.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out + "/monster_scale.png")
	get_tree().quit()


func _stage() -> Camera3D:
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.35, 0.5, 0.72)
	mat.sky_horizon_color = Color(0.72, 0.78, 0.8)
	mat.ground_bottom_color = Color(0.12, 0.14, 0.1)
	mat.ground_horizon_color = Color(0.5, 0.55, 0.5)
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(205.0), 0.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.26, 0.16)
	plane.material = gm
	ground.mesh = plane
	add_child(ground)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	return cam
