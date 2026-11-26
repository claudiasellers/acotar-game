## Shot of steeping a weapon at a hearth (L75, monster-gear §1.4), UI only
## (no Feyre, F46): she holds a scythe-glaive (two slots) and carries fire,
## frost and sleep arrows; the fire one is spent, so the page shows the log
## line and the frost button still offered (no sleep button: no Tier I Hush).
##   godot res://tools/weapons/steep_shot.tscn -- [out.png]
extends Node

const GLAIVE := &"wpn_gloamer_scythe_glaive"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://steep_shot.png"
	Gameplay.reset()
	for pair in [[&"ing_lavender", 3], [&"ing_willow_bark", 2], [&"ing_honey", 2], [&"ing_moss", 2],
			[&"arrow_fire", 3], [&"arrow_frost", 2], [&"arrow_sleep", 2]]:
		Gameplay.inventory.add(pair[0], pair[1])
	var bg := ColorRect.new()
	bg.color = Color(0.32, 0.27, 0.3)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = -1
	layer.add_child(bg)
	get_tree().root.add_child(layer)
	var her := Node3D.new()
	her.name = "Her"
	get_tree().root.add_child(her)
	WeaponRack.of(her).add(GLAIVE)
	var hearth := CookingStation.new()
	hearth.station = load("res://data/stations/hearth.tres")
	get_tree().root.add_child(hearth)
	var menu := BrewMenu.new()
	get_tree().root.add_child(menu)
	menu.open(null, hearth, WeaponRack.of(her))
	for i in 4:
		await get_tree().process_frame
	var offered := WeaponSteep.offers(WeaponRack.of(her), Gameplay.inventory)
	print("offered before: ", offered)
	var r := menu.steep_blade(&"arrow_fire")
	print("steep: ", r)
	print("offered after: ", WeaponSteep.offers(WeaponRack.of(her), Gameplay.inventory))
	print("glaive shares: ", WeaponRack.of(her).held_instance().imbue.shares(Clock.day))
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
