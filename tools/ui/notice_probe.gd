## Saves one frame of each notice and key prompt over the brightest ground the
## act has (noon snow, a Spring path at noon), with Feyre in the follow camera
## and the in-play HUD: a find, a rare find, a note, a chapter heading, the
## press prompt, the beast's row of keys, the quiver card, the pickup log and the paint tin.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --audio-driver Dummy --path . \
##     res://tools/ui/notice_probe.tscn -- <dir> [phase]
## (A scene, not a -s script, so the autoloads exist.)
extends Node

const FEYRE := "res://characters/feyre/feyre.tscn"
## Notices and the quiver card come and go inside two seconds: catch them
## this long after they are asked for.
const CATCH_SECONDS := 0.7
## Two good statuses and two bad, for the vitals frame.
const VITALS_SHOWN: Array[StringName] = [&"heal", &"at_ease", &"drowsy", &"chilled"]
## The brightest ground each act has: noon snow, and a Spring path at noon.
const GROUND := {"p1": Color(0.97, 0.98, 1.0), "p3": Color(0.62, 0.93, 0.5)}


func _ready() -> void:
	get_tree().create_timer(120.0, true).timeout.connect(func() -> void:
		push_error("notice_probe: timed out")
		get_tree().quit(1))
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() >= 1 else "user://notices"
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
	var feyre := (load(FEYRE) as PackedScene).instantiate() as Feyre
	add_child(feyre)
	for i in 20:
		await get_tree().process_frame

	var tree := get_tree()
	for id: StringName in [&"ing_bilberry", &"ing_primrose", &"ing_rose_hip"]:
		Gameplay.inventory.add(id, 6)
	var satchel := SatchelHud.new()
	add_child(satchel)
	add_child(VitalsHud.new())
	var press := PressCard.find_or_make(self)
	var keys := KeyPrompt.make(self)
	var steps := {
		"find": func() -> void: FindCard.show_find(tree, &"ing_bilberry", &"ingredients"),
		"find_rare": func() -> void: FindCard.show_find(tree, &"ing_rose_gold", &"ingredients"),
		"note": func() -> void: FindCard.note(tree, "Two more flowers for a crown."),
		"heading": func() -> void: FindCard.heading(tree, "The Wolf in the Snow"),
		"prompt": func() -> void: press.show_text("step in"),
		"prompt_row": func() -> void:
			press.show_text("")
			keys.says(KeyPrompts.row(&"beast")),
		"quiver": func() -> void:
			keys.clear()
			feyre.bow_controller.quiver_card.show_card(),
		"pickups": func() -> void:
			Gameplay.inventory.add(&"ing_rose_hip", 2)
			Gameplay.inventory.add(&"ing_bilberry", 3)
			Gameplay.inventory.add(&"ing_lavender", 1)
			Gameplay.inventory.add(&"ing_rose_hip", 1),
		"vitals": func() -> void:
			var v := Vitals.of(feyre)
			v.health = 58.0
			for tag: StringName in VITALS_SHOWN:
				v.apply_status(&"probe", tag, 0.6, 40.0)
			v.health_changed.emit(v.health, VitalsState.MAX_HEALTH, -1.0, &"probe"),
		"tin": func() -> void: satchel.bar.pinned.emit(1, satchel.bar.entry(1)),
		"tin_chord": func() -> void: satchel._set_chord(true),
	}
	for label: String in steps:
		FindCard.clear(tree)
		await tree.process_frame
		(steps[label] as Callable).call()
		await tree.create_timer(CATCH_SECONDS).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/notice_%s.png" % [dir, label])
		print("notice_probe: saved ", label)
	print("notice_probe: done")
	tree.quit()
