## Stills of Feyre's manor plan (needs a renderer; not headless):
##   xvfb-run godot --rendering-driver opengl3 res://tools/manor_map_shots.tscn -- <out_dir>
## No world is loaded: a stand-in house node and Feyre in her bedroom, the
## real WorldMapHud over a plain wall colour. Pencil on arrival, then ink
## after the hall map with more rooms walked, on both floors.
extends Node

const ManorPlan := preload("res://ui/map/manor_plan.gd")
const WALKED: Array[StringName] = [&"entrance_hall", &"library", &"dining_hall", &"gallery", &"music_room",
	&"garden_saloon", &"west_corridor", &"drawing_room", &"tamlin_study", &"painting_room", &"upper_hall",
	&"svc_kitchen", &"svc_passage_0", &"morning_room"]

var _flags: Dictionary = {"fact.manor_arrived": true}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://manor_map"
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().root.size = Vector2i(1920, 1080)
	var wall := ColorRect.new()
	wall.color = Color(0.86, 0.93, 0.86)
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wall)
	var house := Node3D.new()
	add_child(house)
	var feyre := Node3D.new()
	feyre.add_to_group(&"player")
	add_child(feyre)
	var hud := WorldMapHud.new()
	add_child(hud)
	hud.manor_house = house
	hud.manor.has_flag = func(f: String) -> bool: return _flags.has(f)
	var bed := hud.manor.index.find_room(&"feyre_bedroom")
	var c := bed.rect.get_center() + Vector2(-2.0, 3.0)
	feyre.global_position = Vector3(c.x, ManorHouseBuilder.floor_y(1) + 0.05, c.y)
	await _settle()
	await _shot(out_dir, "minimap_pencil", Rect2i(1560, 0, 360, 360))
	hud.full_map.open()
	await _settle()
	await _shot(out_dir, "page_pencil_first_floor")
	hud.full_map.close()
	_flags["manor_map_drawn"] = true
	for id in WALKED:
		hud.manor.seen[id] = true
	await _settle()
	await _shot(out_dir, "minimap_ink", Rect2i(1560, 0, 360, 360))
	hud.full_map.open()
	await _settle()
	await _shot(out_dir, "page_ink_first_floor")
	hud.full_map.step_floor(-1)
	await _settle()
	await _shot(out_dir, "page_ink_ground_floor")
	print("MANOR SHOTS inside=%s room=%s floors=%s" % [hud.manor.inside, hud.manor.room, hud.full_map.floors()])
	get_tree().quit(0)


func _settle() -> void:
	for i in 6:
		await RenderingServer.frame_post_draw


func _shot(out_dir: String, name: String, crop: Rect2i = Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if crop.size != Vector2i.ZERO:
		img = img.get_region(crop)
	img.save_png("%s/%s.png" % [out_dir, name])
