## Feyre running and sprinting on a flat gridded floor, for judging her fast gaits
## by eye (T025). Needs a GPU (Mac shots, docs/SHOTS.md):
##   godot res://tools/feyre_gait_shot.tscn -- <out_dir>
## Writes run_0..7.png and sprint_0..7.png (side camera, one gait cycle each),
## sprint_play.png (her own camera at full sprint) and prints her speed, clip rate
## and camera FOV for each.
extends Node3D

const FEYRE := "res://characters/feyre/feyre.tscn"
const SHOTS := 8

var _feyre: Feyre
var _side: Camera3D


func _ready() -> void:
	_build_stage()
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _feyre and _side:
		var p := _feyre.global_position
		_side.global_position = p + Vector3(5.5, 1.1, 0.0)
		_side.look_at(p + Vector3(0.0, 0.95, 0.0))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://gait"
	DirAccess.make_dir_recursive_absolute(out)
	await _settle(1.0)
	Input.action_press(&"move_forward")
	await _settle(2.5)
	await _cycle("run", out)
	Input.action_press(&"sprint")
	_feyre.camera.make_current()
	await _settle(2.0)
	_report("sprint_play")
	await _save(out + "/sprint_play.png")
	await _cycle("sprint", out)
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	get_tree().quit()


## One gait cycle of the clip at its current rate, SHOTS frames evenly spaced.
func _cycle(gait: String, out: String) -> void:
	_side.make_current()
	var animator := _feyre.model.find_child("FeyreAnimator", true, false) as FeyreAnimator
	var speed := Vector2(_feyre.velocity.x, _feyre.velocity.z).length()
	var rate := animator.loco_blend(speed).y
	var cycle: float = animator.clip_lengths.get(StringName(gait), 0.8) / rate
	_report(gait)
	print("  cycle %.3f s real time (%.2f steps/s)" % [cycle, 2.0 / cycle])
	for i in SHOTS:
		await _settle(cycle / SHOTS)
		await _save("%s/%s_%d.png" % [out, gait, i])


func _report(label: String) -> void:
	var animator := _feyre.model.find_child("FeyreAnimator", true, false) as FeyreAnimator
	var speed := Vector2(_feyre.velocity.x, _feyre.velocity.z).length()
	print("%s: speed %.2f m/s, clip rate x%.2f, camera fov %.1f" % [label, speed,
			animator.loco_blend(speed).y, _feyre.camera.fov])


func _settle(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.72, 0.78, 0.84)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.45, 0.5)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 1.0, 4000.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, -1900.0)
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 4000.0)
	mesh.mesh = plane
	mesh.position = Vector3(0.0, 0.0, -1900.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _grid()
	mat.uv1_scale = Vector3(400.0, 4000.0, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mesh.material_override = mat
	floor_body.add_child(mesh)
	add_child(floor_body)
	_feyre = (load(FEYRE) as PackedScene).instantiate() as Feyre
	add_child(_feyre)
	_side = Camera3D.new()
	_side.fov = 50.0
	add_child(_side)


## One-metre tiles with dark edges, so a sliding foot is easy to see.
func _grid() -> ImageTexture:
	var img := Image.create(64, 64, true, Image.FORMAT_RGB8)
	img.fill(Color(0.24, 0.3, 0.2))
	for i in 64:
		for j in 2:
			img.set_pixel(i, j, Color(0.1, 0.12, 0.08))
			img.set_pixel(j, i, Color(0.1, 0.12, 0.08))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
