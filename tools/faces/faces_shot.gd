## In-game close-ups of the cast's canon expressions (lane L36), for the Mac look shots:
##   godot res://tools/faces/faces_shot.tscn -- <out_dir> [numbers]
## faces_tamlin_lucien.png and faces_alis_father.png: one row per character,
## its rest face then each preset, driven through Faces.express() exactly as
## story code asks (EventBus), so the sheet proves the whole path. `numbers`
## prints each preset's strongest shape weight instead of rendering.
extends Node

const TILE := Vector2i(480, 480)
const SHEETS := {"faces_tamlin_lucien": [&"tamlin", &"lucien"], "faces_alis_father": [&"alis", &"father"]}
const COLS := 8

var _out := "user://faces_shot"
var _numbers := false
var _cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else _out
	_numbers = args.has("numbers")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1920, 1080)
	_stage()
	for sheet_name: String in SHEETS:
		var ids: Array = SHEETS[sheet_name]
		var img := Image.create(TILE.x * COLS, TILE.y * ids.size(), false, Image.FORMAT_RGB8)
		img.fill(Color(0.98, 0.93, 0.96))
		for row in ids.size():
			await _row(ids[row] as StringName, img, row)
		if not _numbers:
			img.save_png(_out + "/" + sheet_name + ".png")
			print("wrote ", sheet_name)
	get_tree().quit(0)


func _stage() -> void:
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
	_cam.fov = 18.0
	add_child(_cam)
	_cam.make_current()


func _row(id: StringName, img: Image, row: int) -> void:
	var m := (load("res://characters/%s/%s_model.tscn" % [id, id]) as PackedScene).instantiate() as Node3D
	add_child(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var d := m.get(&"face") as FaceDriver
	var notice: Variant = m.get(&"notice")
	if notice is NoticePlayer:
		(notice as NoticePlayer).enabled = false
	var anim := m.get(&"anim") as AnimationPlayer
	if anim:
		anim.pause()
	d.profile.blink_min = 999.0      # no blink mid-shot
	d.profile.blink_max = 1000.0
	d.profile.tics = []
	var sk := m.get(&"skeleton") as Skeleton3D
	var head := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"Head"))
	var face_pt := head.origin + Vector3(0, 0.06, 0)
	# the model faces -Z after its 180-degree turn: stand in front, a little to its left
	_cam.global_position = face_pt + Vector3(0.28, 0.02, -0.95)
	_cam.look_at(face_pt + Vector3(0, -0.015, 0))
	var order: Array = [d.profile.rest]
	for p: String in d.profile.presets:
		if StringName(p) != d.profile.rest:
			order.append(StringName(p))
	for col in mini(order.size(), COLS):
		var preset := order[col] as StringName
		if col == 0:
			Faces.clear(id)
		else:
			Faces.express(id, preset)
		for i in 30:
			await get_tree().process_frame
		var strongest := 0.0
		for k: String in d.profile.mix_of(preset):
			strongest = maxf(strongest, d.weight_of(k))
		print("%s %-14s strongest shape %.2f, meshes %d" % [id, preset, strongest, d.meshes.size()])
		if _numbers:
			continue
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGB8)
		var side := shot.get_height()
		shot = shot.get_region(Rect2i((shot.get_width() - side) / 2, 0, side, side))
		shot.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(shot, Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, row * TILE.y))
	m.queue_free()
	await get_tree().process_frame
