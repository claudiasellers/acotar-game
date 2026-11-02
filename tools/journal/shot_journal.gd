## Milestone shot of Feyre's sketchbook over a backdrop image (L54; needs a
## display: xvfb-run, vulkan; a scene so the autoloads exist). No Feyre model.
##   xvfb-run godot --path . --rendering-driver vulkan res://tools/journal/shot_journal.tscn -- \
##       <backdrop.png> <out.png> <phase> <flag,flag,...> <seconds_on_step> <hints_to_reveal>
extends Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	get_window().size = Vector2i(1920, 1080)
	var backdrop := TextureRect.new()
	backdrop.texture = ImageTexture.create_from_image(Image.load_from_file(args[0]))
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(backdrop)
	var phase := StringName(args[2])
	var flags := {}
	for f in args[3].split(",", false):
		flags[f] = true
	PhaseManager.current_phase = phase
	var j := StoryJournal.new()
	j.phase_getter = func() -> StringName: return phase
	j.has_flag = func(f: String) -> bool: return flags.has(f)
	add_child(j)
	await get_tree().process_frame
	j.open()
	if j.entry:
		j.ladder.tick(j.entry.id, float(args[4]))
		for i in int(args[5]):
			j.think()
			for k in 20:
				await get_tree().process_frame
		j.refresh()
	for i in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args[1])
	get_tree().quit()
