## Saves one frame of each voice of LinePresenter, a short line and a long
## one, over lit ground with Feyre and the in-play HUD.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --audio-driver Dummy --path . \
##     res://tools/ui/line_probe.tscn -- <dir> [phase]
## (A scene, not a -s script, so the autoloads exist.)
extends Node

const FEYRE := "res://characters/feyre/feyre.tscn"
const SETTLE_FRAMES := 40
const LINES := {
	"said": ["Lucien", "You'll want to keep to the path, human. The wood doesn't like strangers."],
	"said_long": ["Tamlin", "The food is safe for you to eat. The table is laid every evening whether anyone sits at it or not, so you may as well sit, and eat, and stop looking at the door."],
	"thought": ["", "Someone should have held his hand. I should have."],
	"thought_long": ["", "Eight days of snow, and the doe is the first thing I have seen worth an arrow. If I miss, there is nothing for the pot tonight and nothing to sell tomorrow."],
}


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
	var floor := CSGBox3D.new()
	floor.size = Vector3(60, 1, 60)
	floor.position.y = -0.5
	floor.use_collision = true
	add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	add_child((load(FEYRE) as PackedScene).instantiate())
	var lines := LinePresenter.of(get_tree())
	for label: String in LINES:
		var voice := LinePresenter.Voice.THOUGHT if label.begins_with("thought") else LinePresenter.Voice.SAID
		lines.say(voice, LINES[label][0], LINES[label][1], null, 30.0)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/line_%s.png" % [dir, label])
		print("line_probe: saved ", label)
	print("line_probe: done")
	get_tree().quit()
