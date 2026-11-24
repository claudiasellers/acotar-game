## How readable the ch1 wolf hunt is under its real light (lane L18-11): the
## hunting forest by day, human_winter, the scene's own dread (0.5 once the doe
## has been seen), the doe and the great wolf at their WolfKill spots, and the
## scene's lighting rig (WolfHuntLighting) open as in the hunt.
##   godot res://tools/lighting/wolf_hunt_light_probe.tscn -- <out_dir> shot=<0..3> [off] [numbers]
## Shots: 0 doe look (no dread yet), 1 his eyes, 2 clearing wide (her own
## camera, the user's frame), 3 lining up (he has her). off: without the rig
## (grade only). numbers: print, save nothing.
## One shot per process: cloud lavapipe segfaults in its rasterizer as soon as
## a camera in the forest is moved or switched (world_shot never moves its
## camera), so each shot's camera is placed before the forest loads. A bare
## camera stands in for Feyre's (lavapipe also crashes on her, F46).
## Prints: frame mean luma (Rec. 709 on the 8-bit frame, 0..255), near-black
## share (<30), clipped share (>235) and the mean luma in the actor's screen box;
## writes wolf_hunt_<shot>.png.
extends Node

const ANCHOR := Vector3(-360.0, 0.0, 1682.0)  # act1_wolf_clearing
const DOE_OFFSET := Vector3(0, 0, -22)  # WolfKill.doe_offset
const WOLF_OFFSET := Vector3(14, 0, -30)  # WolfKill.wolf_offset
const SHOTS := ["doe look", "his eyes", "clearing wide", "lining up"]
const RIG := "res://story/staging/wolf_hunt_lighting.gd"


## Stands in for the WolfKill space: the rig reads these.
class FakeSpace:
	extends Node3D
	var running: bool = true
	var space_id: StringName = &"wolf_kill"
	var doe: Node3D
	var wolf: Node3D


var _out := "user://wolf_hunt_light"
var _numbers := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else _out
	_numbers = args.has("numbers")
	var lit := not args.has("off")
	var shot := 0
	for a in args:
		if a.begins_with("shot="):
			shot = clampi(int(a.trim_prefix("shot=")), 0, SHOTS.size() - 1)
	DirAccess.make_dir_recursive_absolute(_out)
	Clock.paused = true
	Clock.time_of_day = 0.42
	get_tree().root.size = Vector2i(1920, 1080)
	var world := load("res://world/shared/world/world.tscn").instantiate() as World
	get_tree().root.add_child(world)
	# Cloud lavapipe: MSAA off, terrain clamped (it segfaults otherwise).
	ShotQuality.guard_software_renderer(get_tree().root, world)
	world.grade.swap_to(&"human_winter", 0.0)
	var doe_at := _ground(ANCHOR + DOE_OFFSET)
	var wolf_at := _ground(ANCHOR + WOLF_OFFSET)
	var cam := _camera(shot, doe_at, wolf_at)
	world.add_child(cam)
	cam.look_at(cam.get_meta(&"look"), Vector3.UP)
	cam.make_current()
	var def := load("res://data/regions/human_realm/hunting_forest.tres") as RegionDef
	world.regions.add_child((load(def.scene_path) as PackedScene).instantiate())
	await _settle(2.0)
	# The clearing's own WolfKill would start and put its own actors down.
	for wk in get_tree().root.find_children("*", "WolfKill", true, false):
		wk.queue_free()
	var space := FakeSpace.new()
	world.add_child(space)
	space.global_position = _ground(ANCHOR)
	var doe := (load("res://creatures/prey/deer.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(doe)
	doe.global_position = doe_at
	doe.rotation.y = PI * 0.5
	doe.set_physics_process(false)
	space.doe = doe
	var wolf := (load("res://creatures/wolves/great_wolf.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(wolf)
	wolf.global_position = wolf_at
	wolf.look_at(doe_at, Vector3.UP, true)
	wolf.set_physics_process(false)
	space.wolf = wolf
	if lit and ResourceLoader.exists(RIG):
		space.add_child((load(RIG) as GDScript).new())
	# The rig opens on the space's `running`; the doe look comes first.
	await _settle(3.5)
	if shot > 0:
		# The scene's dread, as WolfKill asks it after the doe look.
		EventBus.mood_requested.emit(&"dread", 0.5, 1.0)
		await _settle(2.0)
	await _grab(shot, cam, wolf if shot in [1, 3] else doe)
	get_tree().quit(0)


## Each shot's camera: from, height, look at, fov.
func _camera(shot: int, doe_at: Vector3, wolf_at: Vector3) -> Camera3D:
	var frames := [
		[ANCHOR + Vector3(0.8, 0, 3.0), 2.0, doe_at + Vector3.UP * 0.8, 48.0],
		[ANCHOR + Vector3(0.8, 0, 3.0), 2.0, wolf_at + Vector3.UP * 0.9, 36.0],
		[ANCHOR + Vector3(0.0, 0, 4.0), 2.3, doe_at.lerp(_ground(ANCHOR), 0.4) + Vector3.UP * 0.6, 70.0],
		[ANCHOR + Vector3(4.0, 0, -8.0), 1.8, (wolf_at + doe_at) * 0.5 + Vector3.UP * 0.8, 40.0],
	]
	var f: Array = frames[shot]
	var cam := Camera3D.new()
	cam.far = 1200.0
	cam.fov = f[3]
	cam.position = _ground(f[0]) + Vector3.UP * float(f[1])
	cam.set_meta(&"look", f[2])
	return cam


func _grab(shot: int, cam: Camera3D, actor: Node3D) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var size := img.get_size()
	var total := 0.0
	var dark := 0
	var clip := 0
	var n := 0
	for y in range(0, size.y, 4):
		for x in range(0, size.x, 4):
			var l := _luma(img.get_pixel(x, y))
			total += l
			dark += 1 if l < 20.0 else 0
			clip += 1 if l > 235.0 else 0
			n += 1
	var box := _actor_box(cam, actor, size)
	var bt := 0.0
	var bn := 0
	for y in range(box.position.y, box.end.y, 2):
		for x in range(box.position.x, box.end.x, 2):
			bt += _luma(img.get_pixel(x, y))
			bn += 1
	print("WOLFLIGHT %d %-14s frame mean %5.1f  crushed %4.1f%%  clipped %4.1f%%  actor mean %5.1f" % [
		shot, SHOTS[shot], total / n, 100.0 * dark / n, 100.0 * clip / n, bt / maxi(bn, 1)])
	if not _numbers:
		img.save_png(_out + "/wolf_hunt_%d.png" % shot)


## The actor's screen rectangle from its body's corners (1.4 m tall, 2 m long).
func _actor_box(cam: Camera3D, actor: Node3D, size: Vector2i) -> Rect2i:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for dx in [-1.0, 1.0]:
		for dy in [0.0, 1.4]:
			for dz in [-1.0, 1.0]:
				var p := cam.unproject_position(actor.global_position + Vector3(dx, dy, dz))
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var r := Rect2i(Vector2i(lo), Vector2i(hi - lo))
	return r.intersection(Rect2i(Vector2i.ZERO, size))


static func _luma(c: Color) -> float:
	return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.z) + 0.05, p.z)


func _settle(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await get_tree().process_frame
