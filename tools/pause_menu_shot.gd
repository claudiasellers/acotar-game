## Milestone screenshots of the pause menu and title screen (needs a GPU or
## lavapipe; not headless):
##   xvfb-run godot --rendering-driver vulkan res://tools/pause_menu_shot.tscn -- <menu|menu_large|title> [out.png]
extends Node

const GREYBOX := "res://story/act1/greybox/act1_greybox.tscn"
const TITLE := "res://ui/title/title_screen.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "menu"
	var out := args[1] if args.size() > 1 else "user://%s.png" % id
	var text_size: int = GameSettings.get_value(&"text_size")
	if id == "menu_large":
		GameSettings.set_value(&"text_size", GameSettings.TEXT_SIZES.size() - 1)
	var scene := (load(TITLE if id == "title" else GREYBOX) as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	for i in 90:
		await get_tree().process_frame
	if id.begins_with("menu"):
		var menu := scene.find_children("*", "SettingsPanel", true, false)
		(menu[0] as SettingsPanel).open()
		for i in 30:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	GameSettings.set_value(&"text_size", text_size)
	get_tree().quit()
