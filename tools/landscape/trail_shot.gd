## Before/after shots of the Act I deer trail and the doe's line (needs a GPU
## or lavapipe; the Mac shot service runs it as a probe, docs/contracts/shots.md):
##   godot res://tools/landscape/trail_shot.tscn -- <shot_id> [out.png]
## Loads the World, the human-realm regions near the camera and Act I's
## wayfinding (the trail band, the doe prints, the crows), at dawn in winter.
extends Node

const COTTAGE_GEN := preload("res://world/human_realm/cottage/cottage_gen.gd")

## shot id: [eye on: "trail" | "doe", eye index, look index, eye height, time of day]
## Negative indices count from the end of the line.
const SHOTS := {
	"trail_opening": ["opening", 0, 0, 0.0, 0.262],
	"trail_start": ["trail", 0, 24, 1.6, 0.3],
	"trail_treeline": ["doe", 4, 40, 1.6, 0.3],
	"doe_mid": ["doe", 180, 215, 1.6, 0.35],
	"doe_raised": ["doe", 0, 120, 30.0, 0.35],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "trail_start"
	var out := args[1] if args.size() > 1 else "user://%s.png" % id
	var shot: Array = SHOTS[id]
	Clock.paused = true
	Clock.time_of_day = shot[4]
	var root := get_tree().root
	root.size = Vector2i(1920, 1080)
	var world: World = load("res://world/shared/world/world.tscn").instantiate()
	root.add_child(world)
	world.grade.swap_to(&"human_winter", 0.0)
	if RenderingServer.get_video_adapter_name().containsn("llvmpipe"):
		(world.get_node("WorldEnvironment") as WorldEnvironment).environment.glow_enabled = false
	var line: PackedVector2Array = Act1Wayfinding.track_points() if shot[0] == "doe" else COTTAGE_GEN.deer_trail_points()
	var ei: int = shot[1] if shot[1] >= 0 else line.size() + shot[1]
	var li: int = mini(shot[2] if shot[2] >= 0 else line.size() + shot[2], line.size() - 1)
	var eye := line[ei]
	var at := line[li]
	var cam := Camera3D.new()
	cam.far = 1500.0
	cam.fov = 60.0
	world.add_child(cam)
	cam.position = Vector3(eye.x, WorldHeight.height_at(eye.x, eye.y) + shot[3], eye.y)
	cam.look_at(Vector3(at.x, WorldHeight.height_at(at.x, at.y) + 0.8, at.y))
	cam.make_current()
	for def in _region_defs():
		if Vector2(def.center.x - eye.x, def.center.z - eye.y).length() < def.radius + 150.0:
			var scene: PackedScene = load(def.scene_path)
			if scene != null:
				world.regions.add_child(scene.instantiate())
	world.add_child(Act1Wayfinding.new())
	await get_tree().process_frame
	for region in world.regions.get_children():
		if region.has_method(&"build_now"):
			region.build_now()
	# The cottage's authored opening frame wins for "trail_opening".
	if shot[0] == "opening":
		for m in get_tree().get_nodes_in_group(&"shot_frame"):
			if m.get_meta(&"shot", "") == "opening_dawn":
				cam.global_transform = (m as Node3D).global_transform
				cam.fov = (m as Node3D).get_meta(&"fov", 50.0)
	for i in 60:
		await get_tree().process_frame
	if OS.get_environment("SHOTS_QUALITY") == "look":
		await get_tree().create_timer(4.0).timeout
	root.get_texture().get_image().save_png(out)
	print("SHOT %s -> %s | draw_calls %d" % [id, out,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	get_tree().quit(0)


func _region_defs() -> Array[RegionDef]:
	var out: Array[RegionDef] = []
	var dir := DirAccess.open("res://data/regions/human_realm")
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var def := load("res://data/regions/human_realm/%s" % f) as RegionDef
			if def != null:
				out.append(def)
	return out
