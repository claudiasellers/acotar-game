## R17 bench for L45-6: the cave's campfire and a Calanmai pyre's flames, and
## the Rite cave's stone, under the hill's night grade, without the world.
##   godot res://tools/playtest/calanmai_fire_shot.tscn -- [out_dir]
## Writes fire_campfire_2m.png, fire_bonfire_3m.png and fire_cave_wall.png.
extends Node

const PROPS := ["rite_cave_wall_a", "rite_cave_pillar", "rite_cave_wall_b"]

var _cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_environment("SHOTS_OUT")
	if out == "":
		out = "user://"
	DirAccess.make_dir_recursive_absolute(out)
	var root := Node3D.new()
	add_child(root)
	_environment(root)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80, 80)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.09, 0.085, 0.07)
	fm.roughness = 0.95
	floor_mesh.material = fm
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	root.add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	root.add_child(_cam)

	# The cave: walls either side of a trench, a pillar beyond, the fire between.
	var x := -3.2
	for id: String in PROPS:
		var mi := MeshInstance3D.new()
		mi.mesh = CourtAssets.mesh(StringName(id))
		root.add_child(mi)
		mi.position = Vector3(x, 0.0, -3.0 if id.ends_with("pillar") else -1.0)
		mi.rotation.y = PI * 0.5 if x < 0.0 else -PI * 0.5
		x += 3.2
	var fire := CalanmaiFire.campfire()
	root.add_child(fire)
	var stand := StandIns.figure("high_fae_male")
	if stand:
		root.add_child(stand)
		stand.position = Vector3(1.0, 0.0, -1.2)
		stand.look_at(Vector3(0, stand.position.y, 2.0), Vector3.UP)
	await _seconds(2.5)
	_look(Vector3(0.4, 1.55, 2.0), Vector3(0.0, 0.5, 0.0))
	await _shot(out.path_join("fire_campfire_2m.png"))
	_look(Vector3(0.6, 1.6, 1.4), Vector3(-3.0, 1.5, -1.0))
	await _shot(out.path_join("fire_cave_wall.png"))
	fire.queue_free()
	if stand:
		stand.queue_free()

	# A pyre on the hill, burning, seen from 3 m.
	var pyre := CalanmaiKit.prop(&"calanmai_pyre")
	var at := Vector3(0.0, 0.0, -14.0)
	if pyre:
		root.add_child(pyre)
		pyre.position = at
	var big := CalanmaiFire.bonfire(3.2)
	root.add_child(big)
	big.position = at
	await _seconds(2.5)
	_look(at + Vector3(0.6, 1.7, 3.0 + 2.1), at + Vector3(0.0, 2.2, 0.0))
	await _shot(out.path_join("fire_bonfire_3m.png"))
	get_tree().quit(0)


func _environment(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.025, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.73, 0.53, 0.74)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(1, 1, 1) if OS.get_environment("BENCH_DAY") == "1" else Color(0.55, 0.6, 0.85)
	moon.light_energy = 2.5 if OS.get_environment("BENCH_DAY") == "1" else 0.08
	moon.rotation_degrees = Vector3(-35, -70, 0)
	root.add_child(moon)


func _look(from: Vector3, to: Vector3) -> void:
	_cam.global_position = from
	_cam.look_at(to, Vector3.UP)


func _shot(path: String) -> void:
	await _seconds(0.6)
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(path)
	print("shot ", path)


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
