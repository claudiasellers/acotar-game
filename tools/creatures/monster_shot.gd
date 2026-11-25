## A monster on a plain stage, for judging the model and its clips by eye
## before it goes into the game (lane L83). Renders in the cloud under xvfb:
##   xvfb-run -a godot --path . res://tools/creatures/monster_shot.tscn -- <out_dir> <scene> [name] [stills]
## A scene that is not a Creature (a story actor, a bare model) is posed from
## `stills`, "clip@seconds,clip@seconds,...", straight from its clips.
## Several scenes joined by commas are small parts shown one by one (the
## Bogge's kit): <name>_parts.png and <name>_clips.png.
## <name>_turn.png: three views of the standing creature. <name>_close.png: the
## head and a hand. <name>_clips.png: eight moments from its clips, played
## through its own CreatureAnimator where that matters (the first tile is the
## creature walking on its own legs; an attack is started with play_attack).
## Prints the triangle count and each tile's clip and time.
extends Node

const SIZE := Vector2i(1920, 1080)
const TILE := Vector2i(960, 540)
## Clip stills: [clip, seconds into it]. Missing clips are skipped.
const STILLS: Array[Array] = [[&"run", 0.1], [&"stalk", 0.3], [&"attack_naga_lunge", 0.2],
		[&"coil_hold", 0.2], [&"death_throat", 3.0], [&"bask", 1.0]]
## The attack whose tell is shown through play_attack.
const TELL := &"naga_claw"

var _out := "user://monster_shot"
var _name := "monster"
var _cam: Camera3D
var _stage: Node3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <out_dir> <creature scene> [name]")
		get_tree().quit(2)
		return
	_out = args[0]
	_name = args[2] if args.size() > 2 else args[1].get_file().get_basename()
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = SIZE
	_build_stage()
	if args[1].contains(","):
		await _run_parts(args[1].split(","))
		return
	var scene := load(args[1]) as PackedScene
	var node := scene.instantiate()
	if not node is Creature:
		await _run_model(node as Node3D, args[3] if args.size() > 3 else "")
		return
	var c := node as Creature
	_stage.add_child(c)
	c.set_physics_process(false)
	c.set_process(false)
	c.model.position = Vector3.ZERO
	await _settle(0.6)
	var tris := 0
	for m: MeshInstance3D in c.model.find_children("*", "MeshInstance3D", true, false):
		for s in m.mesh.get_surface_count():
			tris += m.mesh.surface_get_array_index_len(s) / 3
	print("%s: %d triangles, animator %s" % [_name, tris, c.animator != null])
	var h := c.data.body_height
	# Three views of it standing.
	var sheet := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8)
	var third := Vector2i(SIZE.x / 3, SIZE.y)
	for i in 3:
		var yaw: float = [0.6, PI * 0.5, PI - 0.5][i]
		_look(Vector3(sin(yaw), 0.0, -cos(yaw)) * h * 2.3 + Vector3.UP * h * 0.62, Vector3.UP * h * 0.52, 34.0)
		var img := await _grab()
		var x0 := (SIZE.x - third.x) / 2
		sheet.blit_rect(img, Rect2i(Vector2i(x0, 0), third), Vector2i(i * third.x, 0))
	sheet.save_png("%s/%s_turn.png" % [_out, _name])
	# Head, then a hand.
	var close := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8)
	var head := _bone_point(c, &"head", Vector3.UP * h * 0.93)
	var hand := _bone_point(c, &"hand_r", Vector3(-0.4, h * 0.5, 0.0))
	var views: Array[Array] = [[head + Vector3(0.5, 0.08, -0.85), head + Vector3(0.0, -0.02, -0.15), 30.0],
			[hand + Vector3(-0.5, 0.25, -0.75), hand + Vector3(0.0, -0.06, 0.0), 30.0]]
	for i in 2:
		_look(views[i][0], views[i][1], views[i][2])
		var img := await _grab()
		close.blit_rect(img, Rect2i(Vector2i(SIZE.x / 4, 0), Vector2i(SIZE.x / 2, SIZE.y)), Vector2i(i * SIZE.x / 2, 0))
	close.save_png("%s/%s_close.png" % [_out, _name])
	# Clips.
	var clips := Image.create(TILE.x * 4, TILE.y * 2, false, Image.FORMAT_RGB8)
	var a := c.animator
	var n := 0
	_look(Vector3(2.9, h * 0.5, -3.6) * (h / 1.95), Vector3(0.0, h * 0.42, 0.25), 28.0)
	if a != null:
		# Through the animator, stepped by hand so the times are exact: the
		# walk blend at walking speed, then an attack's tell from play_attack.
		# The walk for real: its own legs carry it at walking speed, and the
		# animator picks the gait from how fast the body actually goes.
		var cam_from := _cam.global_position
		c.scripted = true
		c.navigate = false
		c.set_physics_process(true)
		for i in 100:
			c.move_direction = -c.global_basis.z
			c.move_speed = c.data.walk_speed
			await get_tree().physics_frame
		_cam.global_position = cam_from + c.global_position
		print("tile 0: walking at %.2f m/s, gait %s, rate %.2f" % [c.get_real_velocity().length(), a.loco[a.gait], a.gait_rate()])
		a.tree.active = false
		_tile(clips, await _grab(), n)
		n += 1
		c.set_physics_process(false)
		c.move_speed = 0.0
		c.velocity = Vector3.ZERO
		c.global_position = Vector3.ZERO
		_cam.global_position = cam_from
		a.tree.active = true
		a.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		await _physics(30)
		a.tree.advance(0.8)
		var lands := a.play_attack(TELL)
		if lands >= 0.0:
			await _physics(8)
			a.tree.advance(0.0)       # the seek to the clip's start takes one step
			a.tree.advance(0.45)
			print("tile %d: play_attack(%s), blow lands in %.3f s" % [n, TELL, lands])
			_tile(clips, await _grab(), n)
			n += 1
		# The rest straight from the clips.
		a.tree.active = false
		for still in STILLS:
			var clip: StringName = still[0]
			if not a.anim.has_animation(clip) or n >= 8:
				continue
			a.anim.play(clip)
			a.anim.seek(float(still[1]), true)
			a.anim.pause()
			print("tile %d: %s at %.2f s" % [n, clip, still[1]])
			_tile(clips, await _grab(), n)
			n += 1
	clips.save_png("%s/%s_clips.png" % [_out, _name])
	print("saved %s/%s_{turn,close,clips}.png" % [_out, _name])
	get_tree().quit(0)


## A model that is not a Creature (a story actor's: the Suriel). `stills` is
## "clip@seconds,clip@seconds,..."; the first is also the pose of the turnaround.
func _run_model(m: Node3D, stills: String) -> void:
	_stage.add_child(m)
	if m.get(&"model") is Node3D:
		m.set_process(false)
		m = m.get(&"model")
	var anim := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := m.find_child("Skeleton3D", true, false) as Skeleton3D
	var list: Array[Array] = []
	for part in stills.split(",", false):
		list.append([StringName(part.get_slice("@", 0)), float(part.get_slice("@", 1))])
	var pose := func(clip: StringName, at: float) -> void:
		if anim != null and anim.has_animation(clip):
			anim.play(clip)
			anim.seek(at, true)
			anim.pause()
	if not list.is_empty():
		pose.call(list[0][0], list[0][1])
	await _settle(0.6)
	var tris := 0
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(s) / 3
	var point := func(bone: StringName) -> Vector3:
		return sk.global_transform * sk.get_bone_global_pose(maxi(sk.find_bone(bone), 0)).origin
	var head: Vector3 = point.call(&"head")
	var h := head.y * 1.1
	# a small creature is looked at from closer
	var near := clampf(h / 2.0, 0.22, 1.0)
	print("%s: %d triangles, %d clips" % [_name, tris, anim.get_animation_list().size() if anim else 0])
	var sheet := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8)
	var third := Vector2i(SIZE.x / 3, SIZE.y)
	for i in 3:
		var yaw: float = [0.6, PI * 0.5, PI - 0.5][i]
		_look(Vector3(sin(yaw), 0.0, -cos(yaw)) * maxf(h, 0.56) * 2.3 + Vector3.UP * h * 0.62, Vector3.UP * h * 0.52, 34.0)
		var img := await _grab()
		sheet.blit_rect(img, Rect2i(Vector2i((SIZE.x - third.x) / 2, 0), third), Vector2i(i * third.x, 0))
	sheet.save_png("%s/%s_turn.png" % [_out, _name])
	var close := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8)
	var hand: Vector3 = point.call(&"hand_r" if sk.find_bone(&"hand_r") >= 0 else &"paw_leg_r")
	var views: Array[Array] = [[head + Vector3(0.32, 0.06, -0.8) * near, head + Vector3(0.0, 0.06, -0.12) * near, 30.0],
			[hand + Vector3(-0.5, 0.2, -0.75) * near, hand + Vector3(0.0, -0.1, 0.0) * near, 30.0]]
	for i in 2:
		_look(views[i][0], views[i][1], views[i][2])
		var img := await _grab()
		close.blit_rect(img, Rect2i(Vector2i(SIZE.x / 4, 0), Vector2i(SIZE.x / 2, SIZE.y)), Vector2i(i * SIZE.x / 2, 0))
	close.save_png("%s/%s_close.png" % [_out, _name])
	var clips := Image.create(TILE.x * 4, TILE.y * 2, false, Image.FORMAT_RGB8)
	_look(Vector3(2.9, 1.0, -3.6) * maxf(h, 0.44) * 0.72, Vector3(0.0, h * 0.56, 0.25), 28.0)
	var n := 0
	for still in list:
		if n >= 8 or anim == null or not anim.has_animation(still[0]):
			continue
		pose.call(still[0], still[1])
		print("tile %d: %s at %.2f s" % [n, still[0], still[1]])
		_tile(clips, await _grab(), n)
		n += 1
	clips.save_png("%s/%s_clips.png" % [_out, _name])
	print("saved %s/%s_{turn,close,clips}.png" % [_out, _name])
	get_tree().quit(0)


## Small parts that are never a whole body (the Bogge's claws, jaw and eye),
## given as "scene,scene,...": each floats at chest height, facing the camera.
## <name>_parts.png: each part from the front quarter. <name>_clips.png: its
## `surface`, `hold` and `lunge` clips part by part.
func _run_parts(scenes: PackedStringArray) -> void:
	var parts: Array[Node3D] = []
	var tris := 0
	for path in scenes:
		var m := (load(path) as PackedScene).instantiate() as Node3D
		_stage.add_child(m)
		m.position = Vector3(0.0, 1.2, 0.0)
		m.visible = false
		parts.append(m)
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				tris += mi.mesh.surface_get_array_index_len(s) / 3
	print("%s: %d triangles in %d parts" % [_name, tris, parts.size()])
	var pose := func(m: Node3D, clip: StringName, at: float) -> void:
		var anim := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim != null and anim.has_animation(clip):
			anim.play(clip)
			anim.seek(at, true)
			anim.pause()
	# The Bogge's wood is the darkest place in the court: judge its pieces at dusk.
	for sun: DirectionalLight3D in _stage.find_children("*", "DirectionalLight3D", true, false):
		sun.light_energy = 0.55
	for we: WorldEnvironment in _stage.find_children("*", "WorldEnvironment", true, false):
		we.environment.ambient_light_energy = 0.4
	var sheet := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8)
	var views: Array[Array] = [[0, Vector3(0.62, 1.42, -1.0)], [1, Vector3(0.75, 1.4, -1.15)], [2, Vector3(0.3, 1.3, -0.62)], [1, Vector3(-0.25, 1.05, -1.25)]]
	for i in views.size():
		var m: Node3D = parts[mini(views[i][0], parts.size() - 1)]
		m.visible = true
		pose.call(m, &"hold", 0.0)
		_look(views[i][1], Vector3(0.0, 1.14, -0.2 if views[i][0] != 2 else -0.06), 30.0)
		await _settle(0.3)
		var img := await _grab()
		img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((i % 2) * TILE.x, (i / 2) * TILE.y))
		m.visible = false
	sheet.save_png("%s/%s_parts.png" % [_out, _name])
	var clips := Image.create(TILE.x * 4, TILE.y * 3, false, Image.FORMAT_RGB8)
	_look(Vector3(1.25, 1.5, -0.95), Vector3(0.0, 1.1, -0.12), 34.0)
	var beats: Array[Array] = [[&"surface", 0.17], [&"surface", 0.3], [&"hold", 1.0], [&"lunge", 0.2]]
	for i in mini(parts.size(), 3):
		parts[i].visible = true
		for j in beats.size():
			pose.call(parts[i], beats[j][0], beats[j][1])
			_tile(clips, await _grab(), i * 4 + j)
		parts[i].visible = false
	clips.save_png("%s/%s_clips.png" % [_out, _name])
	print("saved %s/%s_{parts,clips}.png" % [_out, _name])
	get_tree().quit(0)


func _tile(sheet: Image, img: Image, i: int) -> void:
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((i % 4) * TILE.x, (i / 4) * TILE.y))


func _bone_point(c: Creature, bone: StringName, fallback: Vector3) -> Vector3:
	var sk := c.animator.skeleton if c.animator else null
	if sk == null or sk.find_bone(bone) < 0:
		return fallback
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


func _look(from: Vector3, at: Vector3, fov: float) -> void:
	_cam.global_position = from
	_cam.look_at(at)
	_cam.fov = fov


func _grab() -> Image:
	# The prints a walking creature leaves are the game's, not the model's.
	for layer: Node3D in get_tree().get_nodes_in_group(TrackLayer.GROUP):
		layer.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _settle(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame


## An overcast spring clearing in miniature: soft sky light, a low warm sun,
## mossy ground. No emissive props, so the creature's own values read true.
func _build_stage() -> void:
	_stage = Node3D.new()
	add_child(_stage)
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
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	_stage.add_child(sun)
	sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(205.0), 0.0)
	var ground := StaticBody3D.new()
	ground.collision_layer = Creature.WORLD_MASK
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	mesh.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.25, 0.14)
	gm.roughness = 0.95
	mesh.material_override = gm
	ground.add_child(mesh)
	_stage.add_child(ground)
	_cam = Camera3D.new()
	_stage.add_child(_cam)
	_cam.make_current()
