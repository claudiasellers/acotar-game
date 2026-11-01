## Before/after shots of Spring Court ground blending (needs a GPU or lavapipe;
## not headless):
##   xvfb-run godot --rendering-driver vulkan res://tools/ground/ground_shot.tscn -- <shot_id> <out_prefix> [all|layers]
## Same set-up as tools/landscape/landscape_shot.gd. `layers` also saves the
## view with Terrain3D hidden and with region content hidden, to tell which
## surface draws what.
extends Node

## shot id: [eye xz, look-at xz, eye height above ground, time of day]
const SHOTS := {
	"bv_walk": [Vector2(900, 1100), Vector2(1000, 980), 1.7, 0.45],
	"bv_raised": [Vector2(780, 1250), Vector2(1000, 950), 45.0, 0.45],
	"bw_walk": [Vector2(-100, 1380), Vector2(-150, 1080), 1.7, 0.45],
	"bw_ground": [Vector2(-260, 820), Vector2(-230, 790), 6.0, 0.45],
	"ew_ground": [Vector2(900, 120), Vector2(940, 80), 6.0, 0.45],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "bv_walk"
	var prefix := args[1] if args.size() > 1 else "user://%s" % id
	var layers := args.size() > 2 and args[2] == "layers"
	var shot: Array = SHOTS[id]
	Clock.paused = true
	Clock.time_of_day = shot[3]
	var root := get_tree().root
	root.size = Vector2i(1920, 1080)
	var world: World = load("res://world/shared/world/world.tscn").instantiate()
	root.add_child(world)
	world.grade.swap_to(&"spring", 0.0)
	if RenderingServer.get_video_adapter_name().containsn("llvmpipe"):
		(world.get_node("WorldEnvironment") as WorldEnvironment).environment.glow_enabled = false
	var eye: Vector2 = shot[0]
	var at: Vector2 = shot[1]
	var cam := Camera3D.new()
	cam.far = 1500.0
	cam.fov = 60.0
	world.add_child(cam)
	cam.position = Vector3(eye.x, WorldHeight.height_at(eye.x, eye.y) + shot[2], eye.y)
	cam.look_at(Vector3(at.x, WorldHeight.height_at(at.x, at.y) + 0.5, at.y))
	cam.make_current()
	for def in _region_defs():
		if Vector2(def.center.x - eye.x, def.center.z - eye.y).length() < def.radius + 100.0:
			var scene: PackedScene = load(def.scene_path)
			if scene != null:
				world.regions.add_child(scene.instantiate())
	await get_tree().process_frame
	for region in world.regions.get_children():
		if region.has_method(&"build_now"):
			region.build_now()
	for i in 60:
		await get_tree().process_frame
	if OS.get_environment("SHOTS_QUALITY") == "look":
		await get_tree().create_timer(4.0).timeout
	_save("%s.png" % prefix)
	var fallbacks := 0
	for n in world.find_children("TerrainFallback", "", true, false):
		if (n as Node3D).is_visible_in_tree():
			fallbacks += 1
	print("GROUND %s visible TerrainFallback nodes: %d" % [id, fallbacks])
	if layers and world.terrain != null:
		world.terrain.visible = false
		for i in 5:
			await get_tree().process_frame
		_save("%s_noterrain.png" % prefix)
		world.terrain.visible = true
		world.regions.visible = false
		for i in 5:
			await get_tree().process_frame
		_save("%s_terrainonly.png" % prefix)
	get_tree().quit(0)


func _save(path: String) -> void:
	get_tree().root.get_texture().get_image().save_png(path)
	print("SHOT -> %s" % path)


func _region_defs() -> Array[RegionDef]:
	var out: Array[RegionDef] = []
	var dir := DirAccess.open("res://data/regions/spring_court")
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var def := load("res://data/regions/spring_court/%s" % f) as RegionDef
			if def != null:
				out.append(def)
	return out
