## Proof clip for "turning the camera doesn't steer her" (SteerFrame): she walks
## a straight gold line holding only the forward key while the camera swings
## round her and back; then the key is let go and pressed again, and she sets
## off where the camera now looks. Writes frame_####.jpg (and prints her heading
## each half second) for ffmpeg:
##   godot --fixed-fps 30 res://tools/steer_clip.tscn -- <out_dir>
extends Node3D

const FEYRE := "res://characters/feyre/feyre.tscn"
const FPS := 30.0
## [seconds, camera turn over the step (degrees), forward held, caption]
const SCRIPT := [
	[1.2, 0.0, true, "holding forward only"],
	[1.6, 110.0, true, "camera swings right: she keeps to the line"],
	[0.8, 0.0, true, "holding forward only"],
	[2.0, -200.0, true, "camera swings back left: still the line"],
	[0.8, 0.0, true, "holding forward only"],
	[0.6, 0.0, false, "let go"],
	[2.0, 0.0, true, "press forward again: she goes where the camera looks"],
]

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
		_label.text = step[3]
		if step[2]:
			Input.action_press(&"move_forward")
		else:
			Input.action_release(&"move_forward")
		var frames := int(float(step[0]) * FPS)
		var per := deg_to_rad(float(step[1])) / frames
		for f in frames:
			if per != 0.0:
				_feyre.nudge_camera(per, 0.0)
				_feyre.look_input_this_frame = true
			await get_tree().process_frame
			t_all += 1.0 / FPS
			if t_all >= next_note:
				next_note += 0.5
				var v := Vector2(_feyre.velocity.x, _feyre.velocity.z)
				print("t %.1f  camera yaw %4.0f deg  heading %4.0f deg  speed %.1f  x %.2f  [%s]" % [t_all,
						rad_to_deg(_feyre.camera_yaw()), rad_to_deg(atan2(-v.x, -v.y)) if v.length() > 0.1 else 0.0,
						v.length(), _feyre.global_position.x, step[3]])
			if _frame % 2 == 0:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_jpg("%s/frame_%04d.jpg" % [_out, _frame / 2], 0.9)
			_frame += 1
	Input.action_release(&"move_forward")
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
	strip.size = Vector3(0.25, 0.02, 80.0)
	line.mesh = strip
	line.position = Vector3(0.0, 0.01, -40.0)
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
