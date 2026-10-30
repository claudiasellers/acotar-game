## Before/after shots for the landscape composition pass (needs a GPU or
## lavapipe; not headless; the Mac shot service runs it as a probe, see
## docs/contracts/shots.md):
##   xvfb-run godot --rendering-driver vulkan res://tools/landscape/landscape_shot.tscn -- <shot_id> [out.png]
## Same set-up as tools/world_shot.gd, with fixed Spring Court cameras: eye
## level, raised (canopy massing) and straight down (plan view of the layout).
extends Node

## shot id: [eye xz, look-at xz, eye height above ground, time of day, plan size (0 = perspective)]
const SHOTS := {
	# The first sight of the court from the Wall gap (world_shot wall_crossing_spring).
	"bw_walk": [Vector2(-100, 1380), Vector2(-150, 1080), 1.7, 0.45, 0.0],
	"bw_raised": [Vector2(-300, 1290), Vector2(-300, 850), 40.0, 0.45, 0.0],
	"bw_plan": [Vector2(-250, 900), Vector2(-250, 900), 420.0, 0.5, 600.0],
	"bv_walk": [Vector2(900, 1100), Vector2(1000, 980), 1.7, 0.45, 0.0],
	"bv_raised": [Vector2(780, 1250), Vector2(1000, 950), 45.0, 0.45, 0.0],
	"bv_plan": [Vector2(1000, 950), Vector2(1000, 950), 420.0, 0.5, 700.0],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "bw_walk"
	var out := args[1] if args.size() > 1 else "user://%s.png" % id
	var shot: Array = SHOTS[id]
	Clock.paused = true
	Clock.time_of_day = shot[3]
	var root := get_tree().root
	root.size = Vector2i(1920, 1080)
	var world: World = load("res://world/shared/world/world.tscn").instantiate()
	root.add_child(world)
	world.grade.swap_to(StringName(args[2]) if args.size() > 2 else &"spring", 0.0)
	# lavapipe turns bloom into white blobs with black specks; only there is it switched off.
	if RenderingServer.get_video_adapter_name().containsn("llvmpipe"):
		var env: Environment = (world.get_node("WorldEnvironment") as WorldEnvironment).environment
		env.glow_enabled = false
	var eye_xz: Vector2 = shot[0]
	var at_xz: Vector2 = shot[1]
	var plan: float = shot[4]
	var cam := Camera3D.new()
	cam.far = 1500.0
	world.add_child(cam)
	if plan > 0.0:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = plan
		cam.position = Vector3(eye_xz.x, WorldHeight.height_at(eye_xz.x, eye_xz.y) + shot[2], eye_xz.y)
		cam.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	else:
		cam.fov = 60.0
		cam.position = Vector3(eye_xz.x, WorldHeight.height_at(eye_xz.x, eye_xz.y) + shot[2], eye_xz.y)
		cam.look_at(Vector3(at_xz.x, WorldHeight.height_at(at_xz.x, at_xz.y) + 1.2, at_xz.y))
	cam.make_current()
	for def in _region_defs():
		if Vector2(def.center.x - eye_xz.x, def.center.z - eye_xz.y).length() < def.radius + 100.0:
			var scene: PackedScene = load(def.scene_path)
			if scene != null:
				world.regions.add_child(scene.instantiate())
	await get_tree().process_frame
	# Finish the regions' threaded builds before the frame is taken.
	for region in world.regions.get_children():
		if region.has_method(&"build_now"):
			region.build_now()
	for i in 60:
		await get_tree().process_frame
	# Look-tier shots on the Mac: let TAA, GI and streaming settle.
	if OS.get_environment("SHOTS_QUALITY") == "look":
		await get_tree().create_timer(4.0).timeout
	root.get_texture().get_image().save_png(out)
	var draw := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("SHOT %s -> %s | draw_calls %d" % [id, out, draw])
	get_tree().quit(0)


func _region_defs() -> Array[RegionDef]:
	var out: Array[RegionDef] = []
	var dir := DirAccess.open("res://data/regions/spring_court")
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var def := load("res://data/regions/spring_court/%s" % f) as RegionDef
			if def != null:
				out.append(def)
	return out
