## Screenshots of furnished manor rooms from two corners each (L38 review shots).
##   godot res://tools/manor_estate/room_shot.tscn -- <room[@level]>[,<room>...] [out_dir] [hour]
## An hour (0-24, e.g. 20) sets the clock before the shots; without one it is left alone.
## A room may name its own views instead of the corners, room-local x/z from
## the rect's min corner: entrance_hall:10/1.5=10/20+2/14=18/17 saves _v1, _v2
## (from=to; the shots queue takes no '>').
## Loads the real estate, then stands a camera at eye height in a room's
## corners, looking across it, and saves room_<id>_<a|b>.png. Lit as the game
## lights it (ShotLook): day through the windows, plus the rooms' own lamps.
extends Node

const ESTATE := "res://world/spring_court/manor_estate/manor_estate.tscn"
const EYE := 1.65
const INSET := 2.0       # clear of the corner plants and pedestals


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var which: PackedStringArray = (args[0] if args.size() > 0 else "dining_hall").split(",")
	var out := args[1] if args.size() > 1 else OS.get_environment("SHOTS_OUT")
	if out == "":
		out = "user://"
	if args.size() > 2 and args[2].is_valid_float():
		Clock.time_of_day = args[2].to_float() / 24.0
		Clock.paused = true
	var estate := (load(ESTATE) as PackedScene).instantiate()
	get_tree().root.add_child(estate)
	get_tree().current_scene = estate
	if estate.get(&"feyre") == null:
		ShotLook.dress(estate, &"manor_interior")
	var feyre = estate.get(&"feyre")
	if feyre is Node3D:
		(feyre as Node3D).visible = false
	var cam := Camera3D.new()
	cam.fov = 72.0
	cam.far = 200.0
	estate.add_child(cam)
	cam.make_current()
	await _frames(30)
	var settle := 3.0 if OS.get_environment("SHOTS_QUALITY") == "look" else 0.5
	var rooms := {}
	for layout in ManorHouseBuilder.load_layouts():
		for r: ManorRoomDef in layout.rooms:
			rooms["%s@%d" % [r.id, r.level]] = r
			if not rooms.has(String(r.id)):
				rooms[String(r.id)] = r
	for spec in which:
		var key := spec.get_slice(":", 0)
		var r: ManorRoomDef = rooms.get(key)
		if r == null:
			push_error("room_shot: no room %s" % key)
			continue
		var y := ManorHouseBuilder.floor_y(r.level)
		var lo := r.rect.position + Vector2(INSET, INSET)
		var hi := r.rect.end - Vector2(INSET, INSET)
		var views := {"a": [lo, hi], "b": [hi, lo]}
		if spec.contains(":"):
			views = {}
			var n := 0
			for v in spec.get_slice(":", 1).split("+"):
				var ends := v.replace(">", "=").split("=")
				if ends.size() != 2:
					continue
				n += 1
				views["v%d" % n] = [r.rect.position + _xz(ends[0]), r.rect.position + _xz(ends[1])]
		for tag: String in views:
			var from: Vector2 = views[tag][0]
			var to: Vector2 = views[tag][1]
			var aim := from.lerp(to, 0.65)
			cam.global_position = Vector3(from.x, y + EYE, from.y)
			cam.look_at(Vector3(aim.x, y + 0.9, aim.y), Vector3.UP)
			await _seconds(settle)
			await RenderingServer.frame_post_draw
			var path := out.path_join("room_%s_L%d_%s.png" % [r.id, r.level, tag])
			get_tree().root.get_texture().get_image().save_png(path)
			print("saved ", path)
	get_tree().quit()


func _xz(s: String) -> Vector2:
	return Vector2(s.get_slice("/", 0).to_float(), s.get_slice("/", 1).to_float())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
