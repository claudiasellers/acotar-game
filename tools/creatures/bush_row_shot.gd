## A row of the court's rose bushes with a briarling sitting among them in its
## bush form, under the court's own foliage material, with Feyre for scale
## (lane L83). The briarling is the third from the camera's left.
##   xvfb-run -a godot --path . res://tools/creatures/bush_row_shot.tscn -- <out_dir> [name]
## Writes <name>.png (default bush_row).
extends Node

const SIZE := Vector2i(1920, 1080)
const BUSH := "res://world/spring_court/wider/assets/flora/flora_bush_rose.gltf"
const BRIARLING := "res://creatures/models/fae/briarling.gltf"
const FEYRE := "res://characters/feyre/model/feyre_model.tscn"
## x, z, turn (degrees), scale for each real bush
const BUSHES: Array[Array] = [[-2.6, 0.2, 40.0, 1.0], [-1.3, -0.3, 150.0, 1.08], [1.3, 0.1, 260.0, 0.95], [2.6, -0.2, 95.0, 1.05], [0.6, 1.3, 200.0, 1.1], [-0.9, 1.5, 310.0, 1.0]]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://bush_row"
	var shot := args[1] if args.size() > 1 else "bush_row"
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = SIZE
	var cam := _stage()
	RenderingServer.global_shader_parameter_set(&"snow_cover", 0.0)   # spring: the project default is a winter value
	var mat := CourtAssets.material_for(&"flora_bush_rose")
	for b in BUSHES:
		var n := (load(BUSH) as PackedScene).instantiate() as Node3D
		add_child(n)
		n.position = Vector3(b[0], 0.0, b[1])
		n.rotation.y = deg_to_rad(b[2])
		n.scale = Vector3.ONE * b[3]
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			mi.visible = not String(mi.name).ends_with("_LOD1")
			mi.material_override = mat
	var br := (load(BRIARLING) as PackedScene).instantiate() as Node3D
	add_child(br)
	br.rotation.y = deg_to_rad(20.0)
	for mi: MeshInstance3D in br.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
		mi.set_instance_shader_parameter(&"wind_amount", 0.0)
	var anim := br.find_child("AnimationPlayer", true, false) as AnimationPlayer
	anim.play(&"bush")
	anim.seek(0.0, true)
	anim.pause()
	var feyre := (load(FEYRE) as PackedScene).instantiate() as Node3D
	add_child(feyre)
	feyre.position = Vector3(3.9, 0.0, 0.3)
	cam.global_position = Vector3(0.6, 1.5, -6.2)
	cam.look_at(Vector3(0.5, 0.45, 0.3))
	cam.fov = 40.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [out, shot])
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
