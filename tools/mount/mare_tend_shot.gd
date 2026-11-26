## Look check for the tending screen (L47-7): Feyre beside the mare on the cloud
## meadow, the screen open on Care (brushed half-way), then Garland, then after
## making and putting on a lilac garland. Cloud:
##   xvfb-run godot --rendering-method gl_compatibility res://tools/mount/mare_tend_shot.tscn -- <out_dir>
extends "res://tools/mount/mare_stage.gd"


func _run() -> void:
	_set_world()
	StoryControl.set_mode(StoryControl.Mode.FULL)
	WorldState.set_flag("first_dinner_eaten", true)
	WorldState.set_flag("fact.mare_ridden", true)
	for id: String in ["ing_lilac", "ing_lavender", "ing_crocus"]:
		Gameplay.inventory.add(StringName(id), 2)
	Gameplay.inventory.add(&"ing_spider_silk", 3)
	Gameplay.inventory.add(&"ing_manor_fruit", 2)
	Gameplay.inventory.add(&"ing_clover", 4)
	feyre = FEYRE.instantiate() as Node3D
	add_child(feyre)
	feyre.global_position = Vector3(10, 0.05, 10)
	director = MountDirector.new()
	add_child(director)
	for i in 10:
		await get_tree().process_frame
	var m := director.spawn_mare(Vector3(11.6, 0.05, 10.0), 0.0)
	for i in 10:
		await get_tree().process_frame
	var v := director.open_tending()
	MareCare.brush(4.5)
	v._apply(false)
	v._show(MareTendingView.CARE)
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/tend_care.png" % out)
	v._show(&"garland")
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/tend_garland.png" % out)
	v._make(MareTack.piece(&"garland_lilac"))
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/tend_made.png" % out)
	for id: StringName in v._tabs:
		v._show(id)
		for i in 3:
			await get_tree().process_frame
		print("TEND tray %s: %d tall, clear above %d" % [id, int(v.tin.tray.size.y), int(v.tin.clear_height())])
	v._show(MareTendingView.HER)
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/tend_her.png" % out)
	print("TEND worn garland: %s, hung %s" % [MareTack.worn_in(&"garland").id if MareTack.worn_in(&"garland") else "none", MareLook.hung(m.horse)])
	get_tree().quit()
