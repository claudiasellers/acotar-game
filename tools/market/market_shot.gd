## Cloud shots of the village market (lane L53), like tools/world_shot.gd but
## with the market dressing, Feyre and the sell screen:
##   xvfb-run godot --rendering-driver vulkan res://tools/market/market_shot.tscn -- <shot> <out.png>
## Shots: road (the whole market from the cottage road at eye height),
## stall (the cobbler's and the clothier's stalls with the woman at the well),
## menu (the mercenary's sell screen with the pelt and a hide).
extends Node

## shot: [eye, look-at, eye height]
const SHOTS := {
	"road": [Vector3(352.0, 0, 2243.0), Vector3(378.0, 0, 2264.0), 1.7],
	"stall": [Vector3(383.5, 0, 2250.5), Vector3(371.0, 0, 2266.0), 1.7],
	"menu": [Vector3(372.0, 0, 2253.0), Vector3(376.2, 0, 2256.6), 1.7],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "road"
	var out := args[1] if args.size() > 1 else "user://market_%s.png" % id
	var shot: Array = SHOTS[id]
	Clock.paused = true
	Clock.time_of_day = 0.45
	var root := get_tree().root
	root.size = Vector2i(1920, 1080)
	var world: World = load("res://world/shared/world/world.tscn").instantiate()
	root.add_child(world)
	ShotQuality.guard_software_renderer(root, world)
	var cam := Camera3D.new()
	var eye: Vector3 = shot[0]
	var at: Vector3 = shot[1]
	eye.y = WorldHeight.height_at(eye.x, eye.z) + float(shot[2])
	at.y = WorldHeight.height_at(at.x, at.z) + 1.6
	cam.position = eye
	cam.far = 1200.0
	cam.fov = 62.0
	world.add_child(cam)
	cam.look_at(at)
	cam.make_current()
	world.grade.swap_to(&"human_winter", 0.0)
	for f in DirAccess.get_files_at("res://data/regions/human_realm"):
		if f.ends_with(".tres"):
			var def := load("res://data/regions/human_realm/" + f) as RegionDef
			if def and Vector2(def.center.x - eye.x, def.center.z - eye.z).length() < def.radius + 400.0:
				world.regions.add_child((load(def.scene_path) as PackedScene).instantiate())
	var dressing := MarketDressing.new()
	world.add_child(dressing)
	# CastPresence isn't running here: stand her at her spot as it would.
	var merc: Node3D = load("res://creatures/people/scenes/human_woman.tscn").instantiate()
	merc.set(&"wander_radius", 0.0)
	merc.add_to_group(DialogueDirector.PRESENCE_GROUP)
	merc.set_meta(&"speaker", &"mercenary")
	world.add_child(merc)
	merc.global_transform = Transform3D(Basis(Vector3.UP, dressing.market.mercenary_yaw), dressing.market.mercenary_at)
	if id == "menu":
		var feyre: Node3D = load("res://characters/feyre/model/feyre_model.tscn").instantiate()
		WardrobeApplier.dress(feyre)
		world.add_child(feyre)
		feyre.global_position = dressing.mercenary_station.global_position
		feyre.look_at(dressing.market.mercenary_at, Vector3.UP, true)
	for i in 240:
		await get_tree().process_frame
	if id == "menu":
		Gameplay.inventory.coin = 3
		Gameplay.inventory.add(&"obj_wolf_pelt", 1)
		Gameplay.inventory.add(&"ing_hide", 2)
		MarketMenu.open_for(get_tree(), dressing.market.mercenary, merc)
		for i in 20:
			await get_tree().process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("SHOT market_%s -> %s | draw_calls %d" % [id, out,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	get_tree().quit(0)
