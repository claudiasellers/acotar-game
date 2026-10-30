## Milestone screenshots and render stats for the world (needs a GPU or
## lavapipe; not headless):
##   xvfb-run godot --rendering-driver vulkan res://tools/world_shot.tscn -- <shot_id> [out.png]
## Loads the World scene plus the regions near the viewpoint, sets the clock
## and grade, waits for things to settle, saves a PNG and prints draw calls and
## primitives (hardware-independent budget numbers).
extends Node

## shot id: [camera position, look-at point, time of day 0-1, grade]
const SHOTS := {
	"cottage_snow": [Vector3(-112, 0, 2152), Vector3(-150, 0, 2161), 0.42, &"human_winter"],
	"village_market": [Vector3(345, 0, 2210), Vector3(385, 0, 2252), 0.5, &"human_winter"],
	"wall_seam": [Vector3(-110, 0, 1470), Vector3(-100, 0, 1380), 0.62, &"human_winter"],
	"hunting_forest": [Vector3(-380, 0, 1690), Vector3(-420, 0, 1722), 0.35, &"human_winter"],
	"burnt_estate": [Vector3(-590, 0, 2290), Vector3(-640, 0, 2332), 0.7, &"human_winter"],
	# These two use the regions' authored shot_frame markers once loaded.
	"opening_dawn": [Vector3(-142, 0, 2186), Vector3(-160, 0, 2120), 0.27, &"human_winter"],
	"wall_defile": [Vector3(-95, 0, 1446), Vector3(-100, 0, 1396), 0.62, &"human_winter"],
	"wall_crossing": [Vector3(-100, 0, 1362), Vector3(-150, 0, 1080), 0.62, &"spring"],
	"wall_crossing_spring": [Vector3(-100, 0, 1420), Vector3(-100, 0, 1300), 0.55, &"spring"],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "cottage_snow"
	var out := args[1] if args.size() > 1 else "user://%s.png" % id
	var shot: Array = SHOTS[id]
	Clock.paused = true
	Clock.time_of_day = shot[2]
	var root := get_tree().root
	root.size = Vector2i(1920, 1080)
	var world: World = load("res://world/shared/world/world.tscn").instantiate()
	root.add_child(world)
	var cam := Camera3D.new()
	var eye: Vector3 = shot[0]
	var at: Vector3 = shot[1]
	eye.y = WorldHeight.height_at(eye.x, eye.z) + 1.7
	at.y = WorldHeight.height_at(at.x, at.z) + 1.2
	cam.position = eye
	cam.far = 1200.0
	cam.fov = 70.0
	world.add_child(cam)
	cam.look_at(at)
	cam.make_current()
	world.grade.swap_to(shot[3], 0.0)
	var with_regions := not args.has("noregions")
	for def in (_region_defs() if with_regions else []):
		if Vector2(def.center.x - eye.x, def.center.z - eye.z).length() < def.radius + 400.0:
			var scene: PackedScene = load(def.scene_path)
			if scene != null:
				world.regions.add_child(scene.instantiate())
	await get_tree().process_frame
	# Authored frames (cottage OpeningCamera, wall_crossing_frame) win.
	for m in get_tree().get_nodes_in_group(&"shot_frame"):
		if m.get_meta(&"shot", "") == id:
			cam.global_transform = (m as Node3D).global_transform
			cam.fov = (m as Node3D).get_meta(&"fov", 50.0)
	for i in 30:
		await get_tree().process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	var draw := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	print("SHOT %s -> %s | draw_calls %d | primitives %d | objects %d" % [id, out, draw, prims, objs])
	get_tree().quit(0)


func _region_defs() -> Array[RegionDef]:
	var out: Array[RegionDef] = []
	for realm in ["human_realm", "spring_court"]:
		var dir := DirAccess.open("res://data/regions/%s" % realm)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".tres"):
				var def := load("res://data/regions/%s/%s" % [realm, f]) as RegionDef
				if def != null:
					out.append(def)
	return out
