## Look check for the mare's dress-up (L47-7): the white horse in three outfits
## (her own, a lilac set, a pearl-and-sky set), near-side and three-quarter
## views, no world. Cloud:
##   xvfb-run godot --rendering-method gl_compatibility res://tools/mount/mare_decor_shot.tscn -- <out_dir>
extends Node3D

const HORSE := preload("res://creatures/fae/white_horse.tscn")
const OUTFITS := {
	"own": [],
	"lilac": ["cloth_lilac", "mane_lavender", "brow_lilac", "garland_lilac", "bows_lilac", "tail_lilac", "tack_silver", "hooves_lilac"],
	"pearl": ["cloth_peri", "mane_pearl", "brow_sky", "garland_pearl", "bows_sky", "tail_rose", "tack_rosegold", "hooves_gold"],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://mare_decor"
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.72, 0.78, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, -0.9, 0)
	sun.light_energy = 0.8
	add_child(sun)
	var horse := HORSE.instantiate() as WhiteHorse
	add_child(horse)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 38.0
	for i in 6:
		await get_tree().process_frame
	for name: String in OUTFITS:
		var outfit := {}
		for s in MareTack.SLOTS:
			var p := MareTack.worn_in(s)
			if p:
				outfit[s] = p
		for id: String in OUTFITS[name]:
			var p := MareTack.piece(StringName(id))
			outfit[p.slot] = p
		MareLook.apply(horse, outfit, 1.0 if name != "own" else 0.0)
		print("%s: hung %s" % [name, MareLook.hung(horse)])
		for view: Array in [["side", Vector3(-5.2, 1.7, -0.6), Vector3(0, 1.45, -0.25)], ["front", Vector3(-2.6, 2.1, -3.6), Vector3(0, 1.75, -0.6)]]:
			cam.look_at_from_position(view[1], view[2])
			for i in 4:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, name, view[0]])
	get_tree().quit()
