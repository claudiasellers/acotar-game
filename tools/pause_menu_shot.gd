## Milestone screenshots of the pause menu and title screen (needs a GPU or
## lavapipe; not headless):
##   xvfb-run godot --rendering-driver vulkan res://tools/pause_menu_shot.tscn -- <menu|menu_large|title|title_load|title_overwrite> [out.png]
## The title_load and title_overwrite views write sample saves into user://saves,
## so run them only with a scratch data folder (godot.sh, the shots lane).
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
	if id.begins_with("title_"):
		_sample_saves()
	var scene := (load(TITLE if id.begins_with("title") else GREYBOX) as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	for i in 90:
		await get_tree().process_frame
	if id.begins_with("menu"):
		var menu := scene.find_children("*", "SettingsPanel", true, false)
		(menu[0] as SettingsPanel).open()
		for i in 30:
			await get_tree().process_frame
	if id == "title_load":
		scene.call(&"_on_load")
	elif id == "title_overwrite":
		scene.call(&"_on_new_game")
		var slots := scene.get_node(^"Slots") as TitleSlots
		(slots.get_node(^"slot_0/Pick") as Button).pressed.emit()
	if id.begins_with("title_"):
		await get_tree().create_timer(3.5).timeout  # past the title's fade-in
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	GameSettings.set_value(&"text_size", text_size)
	get_tree().quit()


## Story 1 as a save from before slots, Story 3 a later one, Story 2 empty.
func _sample_saves() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.SAVE_DIR)
	var now := int(Time.get_unix_time_from_system())
	var stories := {
		"slot_0": {"clock": {"day": 6}, "phase": {"phase": "p2_grounds"}},
		"slot_2": {"clock": {"day": 2}, "phase": {"phase": "p0_winter"}, "play_seconds": 2710, "saved_at": now - 86400 * 2},
	}
	for slot: String in stories:
		var data: Dictionary = stories[slot]
		data["version"] = SaveSystem.FORMAT_VERSION
		data.phase["phase_set"] = "res://data/phases/spring_court_phases.tres"
		var f := FileAccess.open("%s/%s.json" % [SaveSystem.SAVE_DIR, slot], FileAccess.WRITE)
		f.store_string(JSON.stringify(data))
		f.close()
