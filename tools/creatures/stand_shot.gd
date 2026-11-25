## People standing in a row, from the front and from behind, for judging how
## they hold themselves at rest (arms, shoulders, hands against clothes).
##   godot res://tools/creatures/stand_shot.tscn -- <out_dir> [feyre lucien elain human_man ...]
## Each name is `feyre` (the player as she plays), a cast id
## (characters/<id>/<id>_model.tscn) or a figure in creatures/models/people.
## Writes stand_front.png and stand_back.png, taken two seconds into the idle.
## Needs a window (xvfb + lavapipe in the cloud, or the Mac shot queue,
## docs/SHOTS.md). The numbers are tools/creatures/arm_clip_probe.gd.
extends Node3D

const SIZE := Vector2i(1920, 1080)
const SPACING := 0.85


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://stand"
	var who := args.slice(1) if args.size() > 1 else PackedStringArray(["feyre", "lucien", "tamlin", "nesta", "elain", "human_man", "human_woman"])
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = SIZE
	get_window().content_scale_size = SIZE
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.72, 0.78, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.84, 0.95)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var ground := StaticBody3D.new()
	ground.collision_layer = Creature.WORLD_MASK
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	var snow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	snow.mesh = plane
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.93, 0.95, 1.0)
	snow.material_override = white
	ground.add_child(snow)
	add_child(ground)
	for i in who.size():
		var body := _stand(who[i])
		if body == null:
			print("%s: not found" % who[i])
			continue
		add_child(body)
		body.global_position = Vector3((i - (who.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
	var cam := Camera3D.new()
	cam.fov = 22.0
	add_child(cam)
	var back := maxf(who.size() * SPACING * 1.75, 6.0)
	for k in 120:
		await get_tree().physics_frame
	# Everyone faces -Z.
	for view: Array in [["stand_front", -1.0], ["stand_back", 1.0]]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-42.0, 205.0 if view[1] < 0.0 else 25.0, 0.0)
		add_child(sun)
		cam.global_position = Vector3(0.0, 1.05, back * view[1])
		cam.look_at(Vector3(0.0, 0.95, 0.0))
		cam.make_current()
		for k in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(view[0] + ".png"))
		sun.free()
	print("stand: %s" % ", ".join(who))
	get_tree().quit()


func _stand(id: String) -> Node3D:
	if id == "feyre":
		return (load("res://characters/feyre/feyre.tscn") as PackedScene).instantiate() as Node3D
	var cast := "res://characters/%s/%s_model.tscn" % [id, id]
	if ResourceLoader.exists(cast):
		return (load(cast) as PackedScene).instantiate() as Node3D
	var figure := "res://creatures/models/people/%s.gltf" % id
	if not ResourceLoader.exists(figure):
		return null
	var body := (load(figure) as PackedScene).instantiate() as Node3D
	var player := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player and player.has_animation(&"idle"):
		player.play(&"idle")
	return body
