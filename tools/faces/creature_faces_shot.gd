## In-game close-ups of the creatures' threat displays (lane L36-3), for the Mac look shots:
##   godot res://tools/faces/creature_faces_shot.tscn -- <out_dir> [numbers]
## creature_faces.png: one row per creature, its rest face then each preset,
## driven through Faces.express() (EventBus) exactly as story code asks.
extends Node

const TILE := Vector2i(480, 480)
const COLS := 8
## scene, face point in the model's own space (null: the head bone), camera offset in the
## model's space (it faces -Z), looking slightly down.
const ROWS := [
	["res://creatures/wolves/great_wolf.tscn", null, Vector3(1.5, 0.35, -1.6)],
	["res://creatures/wolves/wolf.tscn", null, Vector3(0.95, 0.22, -1.0)],
	["res://creatures/fae/suriel.tscn", Vector3(0, 1.93, -0.70), Vector3(0.18, 0.04, -0.75)],
	["res://creatures/fae/naga.tscn", Vector3(0, 1.64, -0.36), Vector3(0.35, 0.06, -0.8)],
	["res://creatures/fae/attor.tscn", Vector3(0, 1.45, -0.6), Vector3(0.75, 0.0, -0.5)],
]

var _out := "user://creature_faces_shot"
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
	WorldState.raise_deed("glamour_lifted")   # the Attor's true form
	var img := Image.create(TILE.x * COLS, TILE.y * ROWS.size(), false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.12, 0.14))
	for row in ROWS.size():
		await _row(ROWS[row] as Array, img, row)
	if not _numbers:
		img.save_png(_out + "/creature_faces.png")
		print("wrote creature_faces")
	get_tree().quit(0)


func _stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.17, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.72, 0.7)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.5
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.85, 0.85, 0.95)
	rim.light_energy = 1.0
	rim.rotation_degrees = Vector3(-15, 150, 0)
	add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	add_child(_cam)
	_cam.make_current()


func _row(spec: Array, img: Image, row: int) -> void:
	var n := (load(spec[0] as String) as PackedScene).instantiate() as Node3D
	if &"scripted" in n:
		n.set(&"scripted", true)
	add_child(n)
	# hold it still: no falling (there is no floor), no wandering, no idle sway
	n.set_physics_process(false)
	n.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var f := n.get(&"face") as CreatureFace
	f.profile = f.profile.duplicate(true) as FaceProfile
	f.profile.states = {}       # the rest face, not what its brain happens to be doing
	f.profile.tics = []
	var model := n.get(&"model") as Node3D
	var pt: Vector3
	if spec[1] == null:
		var sk := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		pt = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"head"))).origin
	else:
		pt = model.global_transform * (spec[1] as Vector3)
	_cam.global_position = pt + model.global_basis * (spec[2] as Vector3)
	_cam.look_at(pt)
	var order: Array = [f.profile.rest]
	for p: String in f.profile.presets:
		if StringName(p) != f.profile.rest:
			order.append(StringName(p))
	for col in mini(order.size(), COLS):
		var preset := order[col] as StringName
		if col == 0:
			Faces.clear(f.character_id)
		else:
			Faces.express(f.character_id, preset)
		for i in 30:
			await get_tree().process_frame
		var strongest := 0.0
		for k: String in f.profile.mix_of(preset):
			strongest = maxf(strongest, f.weight_of(k))
		print("%s %-10s strongest %.2f meshes %d snarl %s" % [f.character_id, preset, strongest, f.meshes.size(), f.snarl != null])
		if _numbers:
			continue
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGB8)
		var side := shot.get_height()
		shot = shot.get_region(Rect2i((shot.get_width() - side) / 2, 0, side, side))
		shot.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(shot, Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, row * TILE.y))
	n.queue_free()
	await get_tree().process_frame
