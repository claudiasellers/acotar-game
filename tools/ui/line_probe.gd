## Saves one frame of each voice of LinePresenter over the brightest ground
## the act has (noon snow, a Spring path at noon), with Feyre in the follow
## camera and the in-play HUD.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --audio-driver Dummy --path . \
##     res://tools/ui/line_probe.tscn -- <dir> [phase]
## (A scene, not a -s script, so the autoloads exist.)
extends Node

const FEYRE := "res://characters/feyre/feyre.tscn"
const SETTLE_FRAMES := 40
## label -> [voice, who, text]
const LINES := {
	"said": [LinePresenter.Voice.SAID, "Lucien", "You'll want to keep to the path, human. The wood doesn't like strangers."],
	"said_long": [LinePresenter.Voice.SAID, "Tamlin", "The food is safe for you to eat. The table is laid every evening whether anyone sits at it or not, so you may as well sit, and eat, and stop looking at the door."],
	"thought": [LinePresenter.Voice.THOUGHT, "", "Someone should have held his hand. I should have."],
	"thought_long": [LinePresenter.Voice.THOUGHT, "", "Eight days of snow, and the doe is the first thing I have seen worth an arrow. If I miss, there is nothing for the pot tonight and nothing to sell tomorrow."],
	"told": [LinePresenter.Voice.TOLD, "", "The forest had become a labyrinth of snow and ice."],
	"whisper": [LinePresenter.Voice.WHISPER, "", "Please. Look at me. I will be gentle."],
	"dread": [LinePresenter.Voice.DREAD, "", "Stay with the High Lord, human. That is all you can do. Do not go looking for answers after today."],
}
## The brightest ground each act has: noon snow, and a Spring path at noon.
const GROUND := {"p1": Color(0.97, 0.98, 1.0), "p3": Color(0.62, 0.93, 0.5)}


func _ready() -> void:
	get_tree().create_timer(120.0, true).timeout.connect(func() -> void:
		push_error("line_probe: timed out")
		get_tree().quit(1))
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() >= 1 else "user://lines"
	if args.size() >= 2:
		PhaseManager.current_phase = StringName(args[1])
		JournalTheme.apply()
	DirAccess.make_dir_recursive_absolute(dir)
	var ground := StandardMaterial3D.new()
	ground.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.albedo_color = GROUND.get(String(PhaseManager.current_phase).left(2), GROUND["p3"])
	var floor := CSGBox3D.new()
	floor.size = Vector3(400, 1, 400)
	floor.position.y = -0.5
	floor.use_collision = true
	floor.material = ground
	add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	add_child((load(FEYRE) as PackedScene).instantiate())
	var lines := LinePresenter.of(get_tree())
	for label: String in LINES:
		lines.clear()
		lines.say(LINES[label][0], LINES[label][1], LINES[label][2], null, 30.0)
		for i in SETTLE_FRAMES + (120 if LINES[label][0] == LinePresenter.Voice.DREAD else 0):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/line_%s.png" % [dir, label])
		print("line_probe: saved ", label)
	print("line_probe: done")
	get_tree().quit()
