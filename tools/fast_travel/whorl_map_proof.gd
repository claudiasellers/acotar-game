## Proof shots for the whorl stones on her map (R17): the real streamed world
## with WorldMapHud, Feyre at the Rosewild's briar gate. Several places are
## sketched, two pairs marked (briar_gate, manor_drive). Saves the minimap in
## play, then the full map opened wide and zoomed in, to <out_dir>:
##   xvfb-run godot --resolution 1280x720 res://tools/fast_travel/whorl_map_proof.tscn -- <out_dir>
extends Node

const FEYRE := preload("res://characters/feyre/feyre.tscn")
const AT := &"briar_gate"
const MARKED: Array[StringName] = [&"briar_gate", &"manor_drive"]
const SKETCHED: Array[StringName] = [&"manor_estate", &"rosewild", &"solstice_meadow", &"fae_village",
	&"hill_of_the_rite"]
const OPEN: Array = ["manor_estate", "manor_grounds", "border_woods", "eastern_woods", "starlight_glen", "rosewild",
	"fae_village", "western_fells", "blossom_vale", "hill_of_the_rite", "solstice_meadow", "blighted_reaches"]

var _out := "user://whorl_map_proof"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else _out
	DirAccess.make_dir_recursive_absolute(_out)
	Clock.paused = true
	Clock.time_of_day = 0.42
	WorldDeltas.clear()
	PhaseManager.from_dict({"phase_set": "res://data/phases/spring_court_phases.tres", "phase": "p4_wider_court", "unlocked_regions": OPEN})
	var world := load("res://world/shared/world/world.tscn").instantiate() as World
	get_tree().root.add_child(world)
	world.grade.swap_to(&"spring", 0.0)
	WorldStreamer.configure_from_tree("res://data/regions", world.regions)
	world.add_child(WhorlStones.new())
	for id in MARKED:
		WhorlStones.mark(id)
	var here := WhorlStones.get_def(AT)
	var t := WhorlStone.ground_transform(here)
	var feyre := FEYRE.instantiate() as Feyre
	world.add_child(feyre)
	feyre.teleport(t * Vector3(-14.0, 0.3, 42.0))
	WorldStreamer.track(feyre)
	WorldStreamer.update_for(feyre.global_position)
	var hud := WorldMapHud.new()
	world.add_child(hud)
	MapSettings.set_minimap_shown(true)
	var waited := 0
	while not WorldStreamer.is_ready(here.region_id) and waited < 3000:
		await get_tree().process_frame
		waited += 1
	feyre.teleport(t * Vector3(-14.0, 0.3, 42.0))
	feyre.model.rotation.y = deg_to_rad(here.yaw_degrees)
	feyre.recenter_camera()
	for id in SKETCHED:
		hud.reveal_place(id, false)
	await _frames(90)
	var shown := WhorlMapMarks.shown(hud.reveal).map(func(d: WhorlStoneDef) -> String:
		return "%s%s" % [d.id, " (marked)" if WhorlStones.is_marked(d.id) else ""])
	print("whorl_map_proof: ready after %d frames; map shows %s" % [waited, shown])
	await _shot("minimap")
	MenuShell.open_tab(get_tree(), &"map")
	await _frames(30)
	var fm := hud.full_map
	fm.view_center = Vector2(-40.0, -400.0)
	fm.view_width = 3000.0
	await _frames(20)
	await _shot("full_map_wide")
	fm.view_center = Vector2(-40.0, -600.0)
	fm.view_width = 640.0
	await _frames(20)
	await _shot("full_map_close")
	print("whorl_map_proof: flags=%s" % WorldState.all_flags())
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("whorl_map_proof: saved %s" % name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
