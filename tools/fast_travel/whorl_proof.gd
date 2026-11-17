## Proof clip for fast travel (R17): in the real streamed world, Feyre walks up
## to the whorl stones inside the Rosewild's briar gate, paints her mark (sparkle,
## chime, bounce), presses E again, picks the manor's stones on the card, and
## rides there. One frame_####.jpg per frame for ffmpeg, plus a printed log:
##   xvfb-run godot --fixed-fps 24 --resolution 1280x720 res://tools/fast_travel/whorl_proof.tscn -- <out_dir>
extends Node

const FEYRE := preload("res://characters/feyre/feyre.tscn")
const FROM := &"briar_gate"
const TO := &"manor_drive"
const OPEN: Array = ["manor_estate", "manor_grounds", "border_woods", "eastern_woods", "starlight_glen", "rosewild",
	"fae_village", "western_fells", "blossom_vale", "hill_of_the_rite", "solstice_meadow", "blighted_reaches"]

var _out := "user://whorl_proof"
var _frame := 0
var _capturing := false
var _feyre: Feyre
var _caption: Label


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
	WhorlStones.mark(TO)
	var from := WhorlStones.get_def(FROM)
	var t := WhorlStone.ground_transform(from)
	_feyre = FEYRE.instantiate() as Feyre
	world.add_child(_feyre)
	_feyre.teleport(t * Vector3(0.0, 0.3, 7.5))
	WorldStreamer.track(_feyre)
	WorldStreamer.update_for(_feyre.global_position)
	_caption_layer()
	var waited := 0
	while not (WorldStreamer.is_ready(from.region_id) and _stone(FROM) != null) and waited < 3000:
		await get_tree().process_frame
		waited += 1
	_feyre.teleport(t * Vector3(0.0, 0.3, 7.5))
	_feyre.model.rotation.y = deg_to_rad(from.yaw_degrees)
	_feyre.recenter_camera()
	await _frames(30)
	print("whorl_proof: rosewild ready after %d frames; stone at %s" % [waited, _stone(FROM).global_position])
	_capturing = true
	_say("Inside the Rosewild's briar gate: two mossy stones, a faint whorl on each")
	await _frames(30)
	Input.action_press(&"move_forward")
	var steps := 0
	while steps < 24 * 5 and Vector2(_feyre.global_position.x - t.origin.x, _feyre.global_position.z - t.origin.z).length() > 1.2:
		await get_tree().process_frame
		steps += 1
	Input.action_release(&"move_forward")
	await _frames(12)
	var d := Vector2(_feyre.global_position.x - t.origin.x, _feyre.global_position.z - t.origin.z).length()
	print("whorl_proof: she stands %.2f m from the pair's middle" % d)
	_say("E: she traces the whorl and paints her rose beside it")
	var used := _feyre.interactor.interact()
	print("whorl_proof: first E used=%s marked=%s" % [used, WhorlStones.is_marked(FROM)])
	await _frames(int(24 * 2.6))
	_say("E again: the stones she has marked")
	_feyre.interactor.interact()
	print("whorl_proof: card open=%s" % WhorlTravelCard.is_open())
	await _frames(int(24 * 2.2))
	_say("")
	var ride := WhorlTravelCard.current().choose(WhorlStones.get_def(TO)) if WhorlTravelCard.is_open() else null
	var f := 0
	while ride != null and is_instance_valid(ride) and not ride.arrived and f < 24 * 60:
		await get_tree().process_frame
		f += 1
	var at := WhorlStone.arrival_point(WhorlStones.get_def(TO))
	print("whorl_proof: rode in %d frames; she is %.2f m from the manor stones' arrival point" % [f, _feyre.global_position.distance_to(at)])
	_say("The manor's stones, by the drive")
	await _frames(int(24 * 3.0))
	print("whorl_proof: flags=%s" % WorldState.all_flags())
	_capturing = false
	get_tree().quit()


func _stone(id: StringName) -> WhorlStone:
	for s in get_tree().get_nodes_in_group(WhorlStones.GROUP):
		if (s as WhorlStone).def.id == id:
			return s
	return null


func _caption_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_caption = UiStyle.label("", 20)
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -44
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override(&"font_color", Color(1, 1, 1))
	_caption.add_theme_color_override(&"font_outline_color", Color(0.25, 0.15, 0.25))
	_caption.add_theme_constant_override(&"outline_size", 8)
	layer.add_child(_caption)


func _say(text: String) -> void:
	_caption.text = text


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _process(_delta: float) -> void:
	if not _capturing:
		return
	var img := get_viewport().get_texture().get_image()
	if img and not img.is_empty():
		img.save_jpg("%s/frame_%04d.jpg" % [_out, _frame], 0.9)
		_frame += 1
