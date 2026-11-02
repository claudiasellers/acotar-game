## Proof clip for how she moves (SteerFrame and Feyre._ground_or_air): she
## breaks straight into a run, the camera is swung round her for her (as the
## follow-behind does) and she keeps her line, the mouse turns only the camera
## (or her too, with "Turning the camera steers her while moving"), a quarter
## turn keeps her speed and faces her path, she stops short, and a jump lands
## quickly. Writes frame_####.jpg (and prints her speed and heading every
## 0.25 s) for ffmpeg:
##   godot --fixed-fps 30 res://tools/steer_clip.tscn -- <out_dir>
extends Node3D

const FEYRE := "res://characters/feyre/feyre.tscn"
const FPS := 30.0
## [seconds, auto camera turn (deg), mouse turn (deg), keys held, caption]
const SCRIPT := [
	[0.8, 0.0, 0.0, [&"move_forward", &"sprint"], "Shift + forward: straight into a run"],
	[2.4, 0.0, 0.0, [&"move_forward", &"move_left", &"sprint"], "forward + left: she runs the diagonal, no circling"],
	[1.0, 0.0, 0.0, [&"move_forward"], "forward only: straight on"],
	[1.2, 0.0, -60.0, [&"move_forward"], "mouse turns the camera: she keeps her line (default)"],
	[0.5, 0.0, 0.0, [], "let go"],
	[0.8, 0.0, 0.0, [&"move_forward"], "forward again: the way the camera now faces"],
	[1.2, 0.0, 60.0, [&"move_forward"], "setting on, \"Turning the camera steers her\": she turns with it"],
	[1.0, 0.0, 0.0, [&"move_right"], "right: a quarter turn, same speed"],
	[0.8, 0.0, 0.0, [], "let go: she stops short"],
	[0.5, 0.0, 0.0, [&"move_forward"], "forward"],
	[0.45, 0.0, 0.0, [&"move_forward", &"jump"], "jump"],
	[1.2, 0.0, 0.0, [], "let go in the air: she doesn't drift on"],
]
const KEYS: Array[StringName] = [&"move_forward", &"move_left", &"move_right", &"sprint", &"jump"]

var _feyre: Feyre
var _label: Label
var _out := "user://steer_clip"
var _frame := 0


func _ready() -> void:
	_build_stage()
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_feyre.camera.make_current()
	for i in int(FPS * 0.8):
		await get_tree().process_frame
	var t_all := 0.0
	var next_note := 0.0
	for step: Array in SCRIPT:
		_label.text = step[4]
		for k in KEYS:
			if (step[3] as Array).has(k):
				if k != &"jump" or not Input.is_action_pressed(k):
					Input.action_press(k)
			else:
				Input.action_release(k)
		var frames := int(float(step[0]) * FPS)
		var auto := deg_to_rad(float(step[1])) / frames
		var mouse := deg_to_rad(float(step[2])) / frames
		GameSettings.set_value(&"mouse_steers", String(step[4]).begins_with("setting on"))
		for f in frames:
			if auto != 0.0:
				_feyre.nudge_camera(auto, 0.0)
			if mouse != 0.0:
				_feyre._look(-mouse if not GameSettings.invert_x else mouse, 0.0)
			await get_tree().process_frame
			t_all += 1.0 / FPS
			if t_all >= next_note:
				next_note += 0.25
				var v := Vector2(_feyre.velocity.x, _feyre.velocity.z)
				print("t %.2f  speed %5.2f  heading %4.0f  facing %4.0f  camera %4.0f  y %.2f  [%s]" % [t_all, v.length(),
						rad_to_deg(atan2(-v.x, -v.y)) if v.length() > 0.1 else 0.0, rad_to_deg(_feyre.model.rotation.y),
						rad_to_deg(_feyre.camera_yaw()), _feyre.global_position.y, step[4]])
			if _frame % 2 == 0:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_jpg("%s/frame_%04d.jpg" % [_out, _frame / 2], 0.9)
			_frame += 1
	for k in KEYS:
		Input.action_release(k)
	GameSettings.set_value(&"mouse_steers", false)
	get_tree().quit()


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.72, 0.78, 0.84)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.45, 0.5)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _grid()
	mat.uv1_scale = Vector3(200.0, 200.0, 1.0)
	mesh.material_override = mat
	floor_body.add_child(mesh)
	add_child(floor_body)
	# The line she should keep to: straight ahead (-z) from where she starts.
	var line := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(0.25, 0.02, 120.0)
	line.mesh = strip
	line.position = Vector3(0.0, 0.01, -60.0)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.75, 0.2)
	line.material_override = gold
	add_child(line)
	_feyre = (load(FEYRE) as PackedScene).instantiate() as Feyre
	add_child(_feyre)
	_feyre.global_position = Vector3(0.0, 0.05, 0.0)
	var ui := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(24, 20)
	_label.add_theme_font_size_override(&"font_size", 30)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 8)
	ui.add_child(_label)
	add_child(ui)


func _grid() -> ImageTexture:
	var img := Image.create(64, 64, true, Image.FORMAT_RGB8)
	img.fill(Color(0.24, 0.3, 0.2))
	for i in 64:
		for j in 2:
			img.set_pixel(i, j, Color(0.1, 0.12, 0.08))
			img.set_pixel(j, i, Color(0.1, 0.12, 0.08))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
