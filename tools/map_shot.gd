## Milestone screenshots of the map in the real game (needs a GPU or
## lavapipe; not headless):
##   xvfb-run godot --rendering-driver vulkan res://tools/map_shot.tscn -- [out_dir] [no3d]
## no3d leaves the world undrawn (HUD only) for slow software renderers.
## Runs act1_game, walks Feyre along ROUTE (teleporting between stops and
## uncovering the ground between them the way her walking would), lets each
## stop stream in so she can notice landmarks, then saves minimap.png (play
## view) and full_map.png (the map open).
extends Node

## World XZ stops: the cottage, the village, the old estate, into the forest,
## through the Wall and a little way into the Spring Court, then home.
const ROUTE: Array[Vector2] = [
	Vector2(-150, 2190), Vector2(60, 2240), Vector2(375, 2250), Vector2(560, 2400),
	Vector2(380, 2140), Vector2(100, 2080), Vector2(-350, 2200), Vector2(-640, 2300),
	Vector2(-420, 1900), Vector2(-300, 1700), Vector2(-100, 1500), Vector2(-100, 1380),
	Vector2(-60, 1150), Vector2(-200, 950), Vector2(-120, 1300), Vector2(-100, 1560),
	Vector2(-140, 1950), Vector2(-150, 2120),
]
const STEP := 16.0
const STOP_SECONDS := 2.5


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://"
	get_tree().root.size = Vector2i(1920, 1080)
	var game: Node = (load("res://story/act1/act1_game.tscn") as PackedScene).instantiate()
	add_child(game)
	var t := 0.0
	while not game.get(&"spawned") and t < 40.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	await get_tree().create_timer(5.0).timeout  # the opening shot hands over
	var feyre: Node3D = game.get(&"feyre")
	var hud := get_tree().root.find_child("WorldMapHud", true, false) as WorldMapHud
	if hud == null:
		for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if n is WorldMapHud:
				hud = n
	feyre.set_physics_process(false)
	# The walk only needs the HUD's logic; skip 3D drawing until the shots
	# (software renderers draw the world at a few frames a minute).
	get_viewport().disable_3d = true
	for i in ROUTE.size():
		var to := ROUTE[i]
		if i > 0:
			var from := ROUTE[i - 1]
			var n := ceili(from.distance_to(to) / STEP)
			for k in n + 1:
				var p := from.lerp(to, float(k) / n)
				hud.reveal.reveal(p.x, p.y)
		var next := ROUTE[mini(i + 1, ROUTE.size() - 1)]
		_place(feyre, to, next if i + 1 < ROUTE.size() else Vector2(60, 2240))
		WorldStreamer.update_for(feyre.global_position)
		await get_tree().create_timer(STOP_SECONDS).timeout
		print("MAPSHOT stop %d/%d" % [i + 1, ROUTE.size()])
	get_viewport().disable_3d = args.has("no3d")
	await get_tree().create_timer(2.0).timeout
	await _save(out_dir.path_join("minimap.png"))
	hud.open_full_map()
	hud.full_map.view_center = Vector2(-120, 1700)
	hud.full_map.view_width = 2300.0
	await get_tree().create_timer(1.5).timeout
	await _save(out_dir.path_join("full_map.png"))
	print("MAPSHOT %s | %s" % [out_dir, hud.stats_line()])
	get_tree().quit(0)


func _place(feyre: Node3D, at: Vector2, facing: Vector2) -> void:
	feyre.global_position = Vector3(at.x, WorldHeight.height_at(at.x, at.y) + 0.2, at.y)
	var d := facing - at
	var model: Node3D = feyre.get(&"model")
	if model and d.length() > 0.1:
		model.rotation.y = atan2(-d.x, -d.y)


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
