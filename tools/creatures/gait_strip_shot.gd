## A film strip of a body walking, for judging by eye that its feet plant.
##   godot res://tools/creatures/gait_strip_shot.tscn -- <out_dir> [great_wolf:1.4 great_wolf:4.5:trot lucien:1.6 ...]
## Each argument is <body>:<speed m/s>[:<label>]; a creature name spawns the
## creature, anything else the cast model of that id, moved by its position as
## the story moves it. One PNG per argument: eight frames, left to right, top
## row then bottom, spread over about two strides, side-on, the camera
## travelling with the body. Where a foot lands a dark stone is dropped on the
## snow and stays: a planted foot sits on its stone until it lifts; a sliding
## one leaves it behind. Needs a window (xvfb + lavapipe in the cloud, or the
## Mac shot queue, docs/SHOTS.md). The numbers are tools/creatures/gait_plant_probe.tscn.
extends Node3D

const TILE := Vector2i(960, 540)
const FRAMES := 8
const CREATURES := {
	&"great_wolf": "res://creatures/wolves/great_wolf.tscn",
	&"wolf": "res://creatures/wolves/wolf.tscn",
	&"deer": "res://creatures/prey/deer.tscn",
	&"hare": "res://creatures/prey/hare.tscn",
}
const PAWS: Array[String] = ["paw_fl_l", "paw_fl_r", "paw_hl_l", "paw_hl_r"]
const FEET: Array[String] = ["LeftFoot", "RightFoot"]

var _cam: Camera3D
var _stones: Node3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://gait_strip"
	var runs := args.slice(1) if args.size() > 1 else PackedStringArray(["great_wolf:1.0:stalk", "great_wolf:1.4", "great_wolf:4.5", "lucien:1.6"])
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = TILE
	get_window().content_scale_size = TILE
	_stage()
	for run in runs:
		var parts := run.split(":")
		await _film(StringName(parts[0]), parts[1].to_float() if parts.size() > 1 else 1.4,
				StringName(parts[2]) if parts.size() > 2 else &"", out)
	get_tree().quit()


func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.72, 0.78, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	ground.collision_layer = Creature.WORLD_MASK
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	var snow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	snow.mesh = plane
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.93, 0.95, 1.0)
	snow.material_override = white
	ground.add_child(snow)
	add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	add_child(_cam)
	_cam.make_current()
	_stones = Node3D.new()
	add_child(_stones)


func _film(who: StringName, speed: float, hint: StringName, out: String) -> void:
	for s in _stones.get_children():
		s.queue_free()
	var body: Node3D
	var skeleton: Skeleton3D
	var bones := PAWS
	var size := 2.4
	if CREATURES.has(who):
		var c := (load(CREATURES[who]) as PackedScene).instantiate() as Creature
		add_child(c)
		c.scripted = true
		c.navigate = false
		c.gait_hint = hint if hint in [&"stalk", &"graze"] else &""
		skeleton = c.animator.skeleton
		size = c.data.body_length
		body = c
	else:
		body = (load("res://characters/%s/%s_model.tscn" % [who, who]) as PackedScene).instantiate() as Node3D
		add_child(body)
		skeleton = body.get(&"skeleton") as Skeleton3D
		bones = FEET
		size = 1.9
	body.global_position = Vector3(0.0, 0.02, 0.0)
	var ids: Array[int] = []
	for b in bones:
		ids.append(skeleton.find_bone(b))
	var low: Array[float] = []
	var down: Array[bool] = []
	for _i in ids:
		low.append(INF)
		down.append(false)
	# About two strides of film, after a run-up to settle the gait.
	var film_ticks := int(clampf(size * 2.6 / maxf(absf(speed), 0.2), 1.2, 6.0) * 60.0)
	var sheet := Image.create(TILE.x * 4, TILE.y * 2, false, Image.FORMAT_RGB8)
	var taken := 0
	for tick in 150 + film_ticks:
		if body is Creature:
			(body as Creature).move_direction = Vector3.FORWARD
			(body as Creature).move_speed = speed
		else:
			body.global_position += Vector3.FORWARD * speed / 60.0
		await get_tree().physics_frame
		await get_tree().process_frame
		for i in ids.size():
			var p := skeleton.global_transform * skeleton.get_bone_global_pose(ids[i]).origin
			low[i] = minf(low[i], p.y)
			var is_down := tick > 60 and p.y < low[i] + 0.015
			if is_down and not down[i] and tick >= 150:
				_stone(Vector3(p.x, 0.0, p.z), size)
			down[i] = is_down
		var at := body.global_position
		_cam.global_position = at + Vector3(size * 4.2, size * 0.55, 0.0)
		_cam.look_at(at + Vector3(0.0, size * 0.22, 0.0))
		if tick >= 150 and taken < FRAMES and (tick - 150) >= taken * film_ticks / FRAMES:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(TILE.x, TILE.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((taken % 4) * TILE.x, (taken / 4) * TILE.y))
			taken += 1
	var label := "%s_%s" % [who, hint if hint != &"" else StringName(("%.1f" % speed).replace(".", "_"))]
	sheet.save_png(out.path_join(label + ".png"))
	print("%s: %d frames over %.1f s at %.1f m/s" % [label, taken, film_ticks / 60.0, speed])
	body.queue_free()
	await get_tree().process_frame


## A flat dark stone where a foot came down.
func _stone(at: Vector3, size: float) -> void:
	var m := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = size * 0.035
	disc.bottom_radius = size * 0.035
	disc.height = 0.012
	m.mesh = disc
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.12, 0.2)
	m.material_override = dark
	_stones.add_child(m)
	m.global_position = at + Vector3(0.0, 0.006, 0.0)
