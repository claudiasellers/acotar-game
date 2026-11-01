## Stills of the coffered ceilings over the Act II rooms (L24-7):
##   godot res://tools/act2_ceiling_shot.tscn -- [out_dir]
## Loads the estate, then for the dining hall, Feyre's bedroom, her bath and
## the entrance hall (also at night)
## stands a camera at eye height in the room and looks across and up, so the
## ceiling and the top of the far wall share the frame. Writes <room>.png.
extends Node

const ESTATE := "res://world/spring_court/manor_estate/manor_estate.tscn"
## room id, level, eye point in the room's rect (0..1), look point (0..1), look height above floor.
const VIEWS := [
	[&"dining_hall", 0, Vector2(0.5, 0.92), Vector2(0.5, 0.05), 3.4],
	[&"feyre_bedroom", 1, Vector2(0.5, 0.9), Vector2(0.5, 0.1), 3.0],
	[&"feyre_bath", 1, Vector2(0.15, 0.9), Vector2(0.85, 0.1), 2.8],
	[&"entrance_hall", 0, Vector2(0.5, 0.95), Vector2(0.5, 0.1), 3.6],
]
## Views shot again at night (the room's story scenes play in the dark).
const NIGHT := [&"entrance_hall"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_environment("SHOTS_OUT")
	if out == "":
		out = "user://"
	DirAccess.make_dir_recursive_absolute(out)
	var estate := (load(ESTATE) as PackedScene).instantiate()
	get_tree().root.add_child(estate)
	get_tree().current_scene = estate
	if estate.get(&"feyre") == null:
		estate.call(&"_add_preview_environment")
	Clock.from_dict({"time_of_day": 11.0 / 24.0, "day": 2})
	Clock.paused = true
	var rooms := {}
	for layout in ManorHouseBuilder.load_layouts():
		for r: ManorRoomDef in layout.rooms:
			rooms["%s@%d" % [r.id, r.level]] = r
	var cam := Camera3D.new()
	cam.fov = 70.0
	estate.add_child(cam)
	cam.make_current()
	await _seconds(4.0 if OS.get_environment("SHOTS_QUALITY") == "look" else 1.0)
	var shots: Array = []
	for v in VIEWS:
		shots.append([v, false])
		if NIGHT.has(v[0]):
			shots.append([v, true])
	for shot in shots:
		var v: Array = shot[0]
		var night: bool = shot[1]
		Clock.from_dict({"time_of_day": (23.0 if night else 11.0) / 24.0, "day": 2})
		var r: ManorRoomDef = rooms.get("%s@%d" % [v[0], v[1]])
		if r == null:
			print("no room ", v[0])
			continue
		var y := ManorHouseBuilder.floor_y(r.level)
		var eye: Vector2 = r.rect.position + r.rect.size * (v[2] as Vector2)
		var at: Vector2 = r.rect.position + r.rect.size * (v[3] as Vector2)
		cam.global_position = Vector3(eye.x, y + 1.6, eye.y)
		cam.look_at(Vector3(at.x, y + float(v[4]), at.y))
		await _seconds(3.0 if night else 1.5)
		var coffers := estate.find_child("Coffers", true, false)
		print("probe: %s coffered=%s" % [v[0], ManorRoomLook.is_coffered(r)])
		if DisplayServer.get_name() == "headless":
			print("still %s (headless: not drawn)" % v[0])
			continue
		await RenderingServer.frame_post_draw
		var img := get_tree().root.get_texture().get_image()
		if img != null and not img.is_empty():
			var still := "%s_ceiling%s" % [v[0], "_night" if night else ""]
			img.save_png(out.path_join(still + ".png"))
			print("saved %s.png" % still)
		if coffers == null:
			print("probe: no Coffers node in the estate")
	get_tree().quit()


func _seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
