## Cloud shots of the village market (lane L53), like tools/world_shot.gd but
## with the market dressing, Feyre and the sell screen:
##   xvfb-run godot --rendering-driver vulkan res://tools/market/market_shot.tscn -- <shot> <out.png>
## Shots: road (the whole market from the cottage road at eye height),
## stall (the cobbler's and the clothier's stalls with the woman at the well),
## menu (the mercenary's sell screen with the pelt and a hide).
extends Node

## shot: [eye, look-at, eye height]
const SHOTS := {
	"road": [Vector3(345.0, 0, 2238.0), Vector3(376.0, 0, 2262.0), 1.7],
	"stall": [Vector3(381.5, 0, 2257.5), Vector3(371.0, 0, 2267.5), 1.7],
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
	# CastPresence isn't running here: stand the market's people at their spots as it would.
	var merc: Node3D = null
	var roster := load(CastPresence.ROSTER_PATH) as PresenceRoster
	for sp in roster.spots:
		var sid := String(sp.id)
		if sp.region != &"village" or not (sid.begins_with("market_") or sid in ["mercenary_well", "woman_stall", "peddler_stall", "man_well"]):
			continue
		if not ResourceLoader.exists(sp.scene) or not sp.phases.has("p0_winter"):
			continue
		var npc: Node3D = (load(sp.scene) as PackedScene).instantiate()
		npc.set(&"wander_radius", 0.0)
		npc.add_to_group(DialogueDirector.PRESENCE_GROUP)
		npc.set_meta(&"speaker", sp.speaker)
		world.add_child(npc)
		npc.global_position = Vector3(sp.at.x, WorldHeight.height_at(sp.at.x, sp.at.y), sp.at.y)
		npc.rotation.y = deg_to_rad(sp.yaw_deg)
		if sid == "mercenary_well":
			merc = npc
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
