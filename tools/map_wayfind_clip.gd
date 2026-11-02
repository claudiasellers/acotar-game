## Proof of the way to the player's map pin, from the real game through
## Feyre's own camera (needs a renderer; not headless):
##   xvfb-run godot --rendering-driver opengl3 res://tools/map_wayfind_clip.tscn -- <out_dir> [beat...]
## Pins the village from the cottage yard, then: looking away (the pin rides
## the screen edge, the faelight wind streams off towards it), turning to
## face it (the beam over the trees, the pin floating over it), and nearer
## and nearer. Writes <beat>_##.jpg frames (1280x720).
extends Node

const PIN := Vector2(375, 2250)
## [label, where she stands, camera faces the pin? (else north), frames]
const BEATS := [
	["away", Vector2(-150, 2190), false, 10],
	["toward", Vector2(-150, 2190), true, 10],
	["nearer", Vector2(150, 2225), true, 6],
	["close", Vector2(330, 2245), true, 6],
]
const FRAME_GAP := 0.2
const SAVE_SIZE := Vector2i(1280, 720)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://wayfind"
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().root.size = Vector2i(1920, 1080)
	var game: Node = (load("res://story/act1/act1_game.tscn") as PackedScene).instantiate()
	add_child(game)
	var t := 0.0
	while not game.get(&"spawned") and t < 60.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	await get_tree().create_timer(5.0).timeout  # the opening shot hands over
	var feyre: Node3D = game.get(&"feyre")
	# Software renderers draw a frame in seconds: skip drawing while setting
	# up, and slow game time while capturing so the effects move at their
	# own pace between frames.
	var capture_scale := 1.0 if args.has("realtime") else 0.04
	var hud: WorldMapHud = null
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n is WorldMapHud:
			hud = n
	for beat: Array in BEATS:
		if _named_beats(args) and not args.has(String(beat[0])):
			continue  # beats named after the out dir: only those
		var at: Vector2 = beat[1]
		feyre.global_position = Vector3(at.x, WorldHeight.height_at(at.x, at.y) + 0.3, at.y)
		WorldStreamer.update_for(feyre.global_position)
		var look := (PIN - at).normalized() if beat[2] else Vector2(0, -1)
		var yaw := atan2(-look.x, -look.y)
		feyre.call(&"nudge_camera", angle_difference(feyre.call(&"camera_yaw"), yaw), 0.0)
		var model: Node3D = feyre.get(&"model")
		if model:
			model.rotation.y = yaw
		get_viewport().disable_3d = true
		await get_tree().create_timer(3.0).timeout  # let the region and camera settle
		if not hud.pin.active:
			hud.set_pin(PIN)
		hud.wind.gust()
		await get_tree().create_timer(0.6).timeout  # the gust gets going
		get_viewport().disable_3d = false
		Engine.time_scale = capture_scale
		for i in int(beat[3]):
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.resize(SAVE_SIZE.x, SAVE_SIZE.y, Image.INTERPOLATE_BILINEAR)
			img.save_jpg("%s/%s_%02d.jpg" % [out_dir, beat[0], i], 0.88)
			await get_tree().create_timer(FRAME_GAP * capture_scale).timeout
		Engine.time_scale = 1.0
		print("WAYFIND %s: %d frames, marker %s edge=%s, wind %s heading %s" % [beat[0], beat[3],
			hud.marker.shown_at, hud.marker.on_edge, hud.wind.gusting, hud.wind.heading])
	get_tree().quit(0)


func _named_beats(args: PackedStringArray) -> bool:
	for beat: Array in BEATS:
		if args.has(String(beat[0])):
			return true
	return false
