## Proof shots for the whorl stones' corner tips (R17): the real streamed
## world, Feyre walking up to the Heron Stones in Starlight Glen. Saves the
## tip in sight of the unmarked pair, at arm's length, after she paints her
## mark, and the ride tip at the marked pair once the manor's pair is marked:
##   xvfb-run godot --resolution 1280x720 res://tools/fast_travel/whorl_tips_proof.tscn -- <out_dir>
extends Node

const FEYRE := preload("res://characters/feyre/feyre.tscn")
const AT := &"heron_stones"
const OPEN: Array = ["manor_estate", "manor_grounds", "border_woods", "eastern_woods", "starlight_glen", "rosewild",
	"fae_village", "western_fells", "blossom_vale", "hill_of_the_rite", "solstice_meadow", "blighted_reaches"]

var _out := "user://whorl_tips_proof"


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
	GameSettings.set_value(&"key_hints", true)
	KeyHints.of(get_tree()).forget_taught()
	PhaseManager.from_dict({"phase_set": "res://data/phases/spring_court_phases.tres", "phase": "p4_wider_court", "unlocked_regions": OPEN})
	var world := load("res://world/shared/world/world.tscn").instantiate() as World
	get_tree().root.add_child(world)
	world.grade.swap_to(&"spring", 0.0)
	WorldStreamer.configure_from_tree("res://data/regions", world.regions)
	world.add_child(WhorlStones.new())
	var here := WhorlStones.get_def(AT)
	var t := WhorlStone.ground_transform(here)
	var feyre := FEYRE.instantiate() as Feyre
	world.add_child(feyre)
	feyre.teleport(t * Vector3(0.0, 0.3, 11.0))
	WorldStreamer.track(feyre)
	WorldStreamer.update_for(feyre.global_position)
	world.add_child(WorldMapHud.new())
	var waited := 0
	while not (WorldStreamer.is_ready(here.region_id) and _stone() != null) and waited < 3000:
		await get_tree().process_frame
		waited += 1
	feyre.teleport(t * Vector3(0.0, 0.3, 11.0))
	feyre.model.rotation.y = deg_to_rad(here.yaw_degrees)
	feyre.recenter_camera()
	await _frames(60)
	var hints := KeyHints.of(get_tree())
	print("whorl_tips_proof: ready after %d frames; tip=%s text=%s" % [waited, hints.current, hints.text()])
	await _shot("1_in_sight")
	Input.action_press(&"move_forward")
	var steps := 0
	while steps < 24 * 6 and Vector2(feyre.global_position.x - t.origin.x, feyre.global_position.z - t.origin.z).length() > 1.4:
		await get_tree().process_frame
		steps += 1
	Input.action_release(&"move_forward")
	await _frames(20)
	print("whorl_tips_proof: in reach; tip=%s text=%s" % [hints.current, hints.text()])
	await _shot("2_in_reach")
	feyre.interactor.interact()
	await _frames(48)
	print("whorl_tips_proof: marked=%s tip=%s" % [WhorlStones.is_marked(AT), hints.current])
	await _shot("3_marked")
	WhorlStones.mark(&"manor_drive")
	await _frames(20)
	print("whorl_tips_proof: second pair marked; tip=%s text=%s" % [hints.current, hints.text()])
	await _shot("4_ride_tip")
	print("whorl_tips_proof: flags=%s" % WorldState.all_flags())
	get_tree().quit()


func _stone() -> WhorlStone:
	for s in get_tree().get_nodes_in_group(WhorlStones.GROUP):
		if (s as WhorlStone).def.id == AT:
			return s
	return null


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
