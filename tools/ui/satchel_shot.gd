## Opens the satchel page on a stocked satchel and saves one frame, for
## before/after shots of the I menu without loading the world.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver vulkan \
##     --audio-driver Dummy --path . res://tools/ui/satchel_shot.tscn -- <out.png> [phase] [select_id] [pocket]
## (A scene, not a -s script, so the autoloads exist.)
extends Node

const STOCK := {
	&"ing_bilberry": 6, &"ing_chanterelle": 3, &"ing_moonflower": 1, &"ing_primrose": 4,
	&"ing_rose_hip": 5, &"ing_hazelnut": 8, &"ing_lavender": 2, &"ing_foxglove": 1,
	&"ing_honey": 1, &"ing_watermint": 3, &"ing_wild_strawberry": 7, &"ing_elderflower": 2,
	&"col_odd_stone": 1, &"col_river_glass": 2, &"col_blue_jay_feather": 1,
	&"col_painted_pebble": 1, &"col_robin_egg_shell": 1, &"arrow_wood": 12, &"ing_crow_feather": 3,
}


func _ready() -> void:
	get_tree().create_timer(120.0, true).timeout.connect(func() -> void:
		push_error("satchel_shot: timed out")
		get_tree().quit(1))
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://satchel.png"
	var phase := args[1] if args.size() > 1 else "p2_manor"
	var pick := StringName(args[2]) if args.size() > 2 else &"ing_moonflower"
	var pocket := StringName(args[3]) if args.size() > 3 else SatchelEntries.ALL
	var pm := get_tree().root.get_node_or_null(^"PhaseManager")
	if pm:
		pm.set(&"current_phase", StringName(phase))
	var inv := Gameplay.inventory
	for id: StringName in STOCK:
		inv.add(id, STOCK[id])
	var menu := SatchelMenu.new(QuickBar.current())
	add_child(menu)
	await get_tree().process_frame
	menu.open()
	menu.set_pocket(pocket)
	for i in 30:
		await get_tree().process_frame
	menu.select(pick)
	for it in menu.get(&"_items"):
		if it.id == pick:
			(it.node as Control).grab_focus()
	for i in 150:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("shot: ", out)
	get_tree().quit()
