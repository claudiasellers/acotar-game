## Milestone shot of the brewing screen (lane L62), UI only (no Feyre, F46):
##   xvfb-run godot --rendering-driver vulkan res://tools/chemistry/brew_shot.tscn -- [discover|hunch] [out.png]
extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "discover"
	var out := args[1] if args.size() > 1 else "user://brew_%s.png" % mode
	Gameplay.reset()
	for pair in [[&"ing_lavender", 3], [&"ing_wild_hyacinth", 2], [&"ing_glowcap", 4], [&"ing_moss", 2],
			[&"ing_willow_bark", 2], [&"ing_honey", 2], [&"ing_foxglove", 1], [&"ing_hollow_root", 2],
			[&"ing_pine_resin", 3], [&"ing_madder", 2], [&"ing_elderflower", 3], [&"ing_rose_red", 4],
			[&"ing_moonflower", 1], [&"ing_wild_strawberry", 5], [&"ing_snowdrop", 2], [&"arrow_wood", 6]]:
		Gameplay.inventory.add(pair[0], pair[1])
	# She has used these before, so she knows their tags.
	for id in [&"ing_lavender", &"ing_wild_hyacinth", &"ing_glowcap", &"ing_moss"]:
		Gameplay.journal.learned_tags[String(id)] = (ItemCatalog.get_item(id) as IngredientData).tags.map(
				func(t: StringName) -> String: return String(t))
	var bg := ColorRect.new()
	bg.color = Color(0.32, 0.27, 0.3)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = -1
	layer.add_child(bg)
	get_tree().root.add_child(layer)
	var station := CookingStation.new()
	station.station = load("res://data/stations/stillroom.tres")
	get_tree().root.add_child(station)
	var menu := BrewMenu.new()
	get_tree().root.add_child(menu)
	menu.open(null, station)
	menu.toggle(&"ing_lavender")
	menu.toggle(&"ing_wild_hyacinth")
	menu.set_method(&"distill")
	if mode == "discover":
		menu.brew()
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
