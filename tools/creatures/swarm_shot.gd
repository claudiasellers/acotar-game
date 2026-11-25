## A lampwing swarm on a plain stage, for judging the moth and its poses by eye
## before it goes into the game (lane L83). Renders in the cloud under xvfb:
##   xvfb-run -a godot --path . res://tools/creatures/swarm_shot.tscn -- <out_dir>
## lampwing_poses.png: flutter (two beats), feed, roost, bite and fall, by day,
## with no light. lampwing_face.png: the bite up close. lampwing_night.png:
## sixty of them as one MultiMesh, lit, at night.
extends Node

const SIZE := Vector2i(1920, 1080)
const MODEL := preload("res://creatures/swarm/lampwing.gltf")
const MATERIAL := preload("res://creatures/materials/lampwing.tres")
## [name, fold, rate, mouth, light, turn (degrees), pitch]
const POSES: Array[Array] = [["flutter", 0.0, 1.0, 0.0, 0.0, 200.0, 20.0], ["flutter", 0.0, 1.0, 0.0, 0.0, 160.0, -15.0],
		["feed", 0.0, 0.12, 0.0, 0.0, 215.0, 35.0], ["roost", 1.0, 0.0, 0.0, 0.0, 240.0, 0.0],
		["bite", 0.0, 1.8, 1.0, 0.0, 150.0, 5.0], ["fall", 0.6, 0.0, 0.0, 0.0, 200.0, 70.0]]

var _cam: Camera3D
var _env: Environment
var _sun: DirectionalLight3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://swarm_shot"
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = SIZE
	_stage()
	var mesh := (MODEL.instantiate().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	print("lampwing: %d triangles" % (mesh.surface_get_array_index_len(0) / 3))
	var row := Node3D.new()
	add_child(row)
	var moths: Array[MeshInstance3D] = []
	for i in POSES.size():
		var p := POSES[i]
		var m := MeshInstance3D.new()
		m.mesh = mesh
		var mat := MATERIAL.duplicate() as ShaderMaterial
		for k in 4:
			mat.set_shader_parameter([&"fold", &"rate", &"mouth", &"light"][k], p[k + 1])
		m.material_override = mat
		m.position = Vector3((i % 3 - 1) * 0.2, 1.0 + (0.09 if i < 3 else -0.09), 0.0)
		m.rotation = Vector3(deg_to_rad(p[6]), deg_to_rad(p[5]), 0.0)
		row.add_child(m)
		moths.append(m)
	_look(Vector3(0.0, 1.03, -0.62), Vector3(0.0, 1.0, 0.0), 30.0)
	await _settle(0.5)
	(await _grab()).save_png(out + "/lampwing_poses.png")
	# the bite, from in front
	var bite := moths[4]
	var at := bite.global_position
	var ahead := -bite.global_transform.basis.z
	_look(at + ahead * 0.2 + Vector3(0.03, 0.03, 0.0), at + ahead * 0.02, 30.0)
	(await _grab()).save_png(out + "/lampwing_face.png")
	row.queue_free()
	# night: sixty as one MultiMesh, each posed through its custom data
	_env.ambient_light_energy = 0.12
	_env.background_energy_multiplier = 0.05
	_env.glow_enabled = true
	_env.glow_intensity = 0.9
	_env.glow_bloom = 0.15
	_sun.light_energy = 0.12
	_sun.light_color = Color(0.6, 0.7, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = 60
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	for i in mm.instance_count:
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3)))
		var r := sqrt(rng.randf()) * 0.9
		var a := rng.randf_range(0.0, TAU)
		mm.set_instance_transform(i, Transform3D(b, Vector3(cos(a) * r, 1.0 + rng.randf_range(-0.45, 0.45), sin(a) * r * 0.6)))
		mm.set_instance_color(i, Color(1.0, rng.randf_range(0.82, 1.0), rng.randf_range(0.86, 1.0)))
		mm.set_instance_custom_data(i, Color(0.0, rng.randf_range(0.9, 1.8), 0.0, 1.0))
	var swarm := MultiMeshInstance3D.new()
	swarm.multimesh = mm
	var mat := MATERIAL.duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"per_instance", true)
	swarm.material_override = mat
	add_child(swarm)
	_look(Vector3(0.0, 1.05, -2.3), Vector3(0.0, 1.0, 0.0), 34.0)
	await _settle(0.5)
	(await _grab()).save_png(out + "/lampwing_night.png")
	get_tree().quit()


func _look(from: Vector3, at: Vector3, fov: float) -> void:
	_cam.global_position = from
	_cam.look_at(at)
	_cam.fov = fov


func _grab() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _settle(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame


func _stage() -> void:
	_env = Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.35, 0.5, 0.72)
	mat.sky_horizon_color = Color(0.72, 0.78, 0.8)
	mat.ground_bottom_color = Color(0.12, 0.14, 0.1)
	mat.ground_horizon_color = Color(0.5, 0.55, 0.5)
	sky.sky_material = mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.7
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(1.0, 0.93, 0.82)
	_sun.light_energy = 1.5
	add_child(_sun)
	_sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(205.0), 0.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.26, 0.16)
	plane.material = gm
	ground.mesh = plane
	add_child(ground)
	_cam = Camera3D.new()
	_cam.near = 0.01
	add_child(_cam)
	_cam.make_current()
