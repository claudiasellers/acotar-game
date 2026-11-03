extends SceneTree
## Renders the same spheres with BaseMaterial3D and with CandyMaterial.from_base
## (render program T2) and prints the mean per-pixel delta per case.
##   xvfb-run godot --path . -s tools/render/candy_parity.gd [-- out_dir]

const SIZE := Vector2i(320, 320)

func _cases() -> Array:
	var out := []
	var a := StandardMaterial3D.new()
	out.append(["default", a])
	var b := StandardMaterial3D.new()
	b.albedo_color = Color(0.95, 0.62, 0.72)
	b.roughness = 0.6
	out.append(["rose_satin", b])
	var c := StandardMaterial3D.new()
	c.albedo_color = Color(1.0, 0.8, 0.4)
	c.metallic = 1.0
	c.roughness = 0.3
	c.rim_enabled = true
	c.rim = 0.3
	c.rim_tint = 1.0
	out.append(["gold_rim", c])
	var d := StandardMaterial3D.new()
	d.albedo_color = Color(0.9, 0.9, 1.0)
	d.roughness = 0.18
	d.clearcoat_enabled = true
	d.clearcoat = 0.7
	d.clearcoat_roughness = 0.15
	out.append(["pearl_coat", d])
	var e := StandardMaterial3D.new()
	e.albedo_color = Color(0.4, 0.8, 1.0, 0.5)
	e.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	e.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	out.append(["unshaded_alpha", e])
	var f := StandardMaterial3D.new()
	f.albedo_color = Color(0.3, 0.2, 0.15)
	f.emission_enabled = true
	f.emission = Color(1.0, 0.5, 0.2)
	f.emission_energy_multiplier = 1.5
	out.append(["ember", f])
	return out


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else ""
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.45, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.5, 0.6)
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var omni := OmniLight3D.new()
	omni.position = Vector3(-1.5, 0.5, 1.5)
	omni.light_color = Color(1.0, 0.7, 0.8)
	omni.omni_range = 5.0
	vp.add_child(omni)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 3.2)
	vp.add_child(cam)
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	mi.mesh = sphere
	vp.add_child(mi)
	var total := 0.0
	var cases := _cases()
	for cs in cases:
		var shots: Array[Image] = []
		for candy in [false, true]:
			var base: BaseMaterial3D = cs[1]
			mi.material_override = CandyMaterial.from_base(base) if candy else base
			for i in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			shots.append(vp.get_texture().get_image())
		var dsum := 0.0
		for y in SIZE.y:
			for x in SIZE.x:
				var p := shots[0].get_pixel(x, y)
				var q := shots[1].get_pixel(x, y)
				dsum += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) / 3.0
		var mean := dsum / float(SIZE.x * SIZE.y)
		total += mean
		print("PARITY %-16s mean delta %.2f%%" % [cs[0], mean * 100.0])
		if out_dir != "":
			shots[0].save_png(out_dir.path_join("%s_std.png" % cs[0]))
			shots[1].save_png(out_dir.path_join("%s_candy.png" % cs[0]))
	print("PARITY overall mean delta %.2f%%" % (total / cases.size() * 100.0))
	quit()
