## Mouth close-ups for the mouth-UV re-export (MOUTHUVGLB-1): Feyre, Tamlin and Lucien at rest,
## mid-line (vis_AA: lips apart onto teeth and tongue), lip_press, and vis_E with a soft smile.
##   godot res://tools/faces/mouth_uv_shot.tscn -- <out_dir>
## Writes mouth_uv.png: one row per character, one column per pose.
extends Node

const TILE := Vector2i(640, 640)
const CAST := [["feyre", "res://characters/feyre/feyre.tscn"],
	["tamlin", "res://characters/tamlin/tamlin_model.tscn"],
	["lucien", "res://characters/lucien/lucien_model.tscn"]]
const POSES := [{}, {"vis_AA": 1.0}, {"lip_press": 1.0}, {"vis_E": 1.0, "smile": 0.5}]

var _cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_environment("SHOTS_OUT")
	if out == "":
		out = "user://mouth_uv_shot"
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(1920, 1080)
	_stage()
	var img := Image.create(TILE.x * POSES.size(), TILE.y * CAST.size(), false, Image.FORMAT_RGB8)
	img.fill(Color(0.98, 0.93, 0.96))
	for row in CAST.size():
		await _row(CAST[row][0] as String, CAST[row][1] as String, img, row)
	img.save_png(out.path_join("mouth_uv.png"))
	print("wrote mouth_uv.png")
	get_tree().quit(0)


func _stage() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	add_child(floor_body)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.86, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.88, 0.95)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.35
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-30, -35, 0)
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(1.0, 0.85, 0.7)
	rim.light_energy = 1.2
	rim.rotation_degrees = Vector3(-20, 150, 0)
	add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 22.0
	add_child(_cam)
	_cam.make_current()


func _row(id: String, path: String, img: Image, row: int) -> void:
	var m := (load(path) as PackedScene).instantiate() as Node3D
	add_child(m)
	for i in 30:
		await get_tree().physics_frame
	# freeze everything that would move the face: the driver, clips and trees
	for n in m.find_children("*", "", true, false):
		if n.has_method(&"express") or n is AnimationPlayer or n is AnimationTree:
			n.process_mode = Node.PROCESS_MODE_DISABLED
	m.process_mode = Node.PROCESS_MODE_DISABLED
	# Feyre brings her own follow camera; take the view back
	for c in m.find_children("*", "Camera3D", true, false):
		(c as Camera3D).current = false
	_cam.make_current()
	var meshes: Array[MeshInstance3D] = []
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh != null and mi.get_blend_shape_count() > 0:
			meshes.append(mi)
	var sk := m.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		sk = m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var xf := sk.global_transform
	var head := xf * sk.get_bone_global_pose(sk.find_bone("Head")).origin
	var eyes := (xf * sk.get_bone_global_pose(sk.find_bone("LeftEye")).origin
		+ xf * sk.get_bone_global_pose(sk.find_bone("RightEye")).origin) * 0.5
	var fwd := eyes - head
	fwd.y = 0.0
	fwd = fwd.normalized()
	var mouth := eyes + Vector3(0.0, -0.065, 0.0) + fwd * 0.01
	var side := fwd.cross(Vector3.UP).normalized()
	_cam.global_position = mouth + fwd * 0.42 + side * 0.10 + Vector3(0.0, 0.015, 0.0)
	_cam.look_at(mouth, Vector3.UP)
	print("%s: %d keyed meshes (%s)" % [id, meshes.size(), ", ".join(meshes.map(func(x: MeshInstance3D) -> String: return String(x.name)))])
	for col in POSES.size():
		var pose: Dictionary = POSES[col]
		for mi in meshes:
			for k in mi.get_blend_shape_count():
				var nm := _shape_name(mi, k)
				mi.set_blend_shape_value(k, float(pose.get(nm, 0.0)))
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGB8)
		var h := shot.get_height()
		shot = shot.get_region(Rect2i((shot.get_width() - h) / 2, 0, h, h))
		shot.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(shot, Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, row * TILE.y))
	m.queue_free()
	await get_tree().process_frame


func _shape_name(mi: MeshInstance3D, k: int) -> String:
	var am := mi.mesh as ArrayMesh
	return String(am.get_blend_shape_name(k)) if am != null else ""
