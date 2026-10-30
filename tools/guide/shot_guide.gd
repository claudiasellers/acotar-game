## Milestone shot of a thought card over a backdrop image (needs a display:
## xvfb-run, vulkan; a scene so the autoloads exist).
##   xvfb-run godot --path . --rendering-driver vulkan res://tools/guide/shot_guide.tscn -- <backdrop.png> <out.png> <thread> <tier>
extends Node

const BOOK := preload("res://data/guide/act1_guide.tres")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var backdrop := TextureRect.new()
	backdrop.texture = ImageTexture.create_from_image(Image.load_from_file(args[0]))
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	get_window().size = Vector2i(1920, 1080)
	add_child(backdrop)
	var journal := GuideJournal.new(BOOK)
	add_child(journal)
	await get_tree().process_frame
	for t in BOOK.threads:
		if String(t.id) == args[2]:
			journal.show_thought(t, int(args[3]), int(args[3]) == 0)
	for i in 60:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args[1])
	get_tree().quit()
