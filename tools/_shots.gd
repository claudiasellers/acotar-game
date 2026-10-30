extends SceneTree

const SHOTS := [
	["border_woods", Vector3(196, 3.0, 742), Vector2(212, 668), 12.5, "border_falls_midday"],
	["border_woods", Vector3(-250, 2.2, 1010), Vector2(-345, 1010), 19.6, "border_willow_dusk"],
	["eastern_woods", Vector3(1300, 2.0, -250), Vector2(1560, -430), 13.0, "eastern_bogge_edge"],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.global_shader_parameter_set(&"magic_amount", 1.0)
	RenderingServer.global_shader_parameter_set(&"snow_cover", 0.0)
	var region: WoodsRegion = null
	var current := ""
	for shot in SHOTS:
		if shot[0] != current:
			if region != null:
				region.queue_free()
				await process_frame
			current = shot[0]
			region = load("res://world/spring_court/%s/%s.tscn" % [current, current]).instantiate()
			root.add_child(region)
			region.build_now()
		var env_node := _environment(shot[3])
		root.add_child(env_node)
		var cam := Camera3D.new()
		var p: Vector3 = shot[1]
		var target: Vector2 = shot[2]
		cam.position = Vector3(p.x, WorldHeight.height_at(p.x, p.z) + p.y, p.z)
		cam.fov = 70.0
		root.add_child(cam)
		cam.look_at(Vector3(target.x, WorldHeight.height_at(target.x, target.y) + 5.0, target.y))
		cam.make_current()
		var clock := root.get_node_or_null(^"/root/Clock")
		if clock != null:
			clock.time_of_day = shot[3] / 24.0
			clock.paused = true
		for i in 240:
			await process_frame
			if (region.get_node("GroundCover") as DetailScatter).cell_count() >= 9 and i > 60:
				break
		for i in 20:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("/tmp/claude-0/shots/%s.png" % shot[4])
		print("shot ", shot[4])
		env_node.queue_free()
		cam.queue_free()
	quit()


func _environment(hour: float) -> Node3D:
	var holder := Node3D.new()
	var dusk := hour > 18.0
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.55, 0.68, 0.98) if not dusk else Color(0.38, 0.36, 0.70)
	sm.sky_horizon_color = Color(1.0, 0.8, 0.88) if not dusk else Color(1.0, 0.62, 0.62)
	sm.ground_horizon_color = Color(0.98, 0.86, 0.8)
	sm.ground_bottom_color = Color(0.55, 0.7, 0.45)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.18
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.86, 0.92)
	env.fog_density = 0.0025
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.35
	env.adjustment_brightness = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	holder.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.8) if not dusk else Color(1.0, 0.62, 0.48)
	sun.light_energy = 1.35 if not dusk else 0.6
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-55.0 if not dusk else -10.0), deg_to_rad(-35.0 if not dusk else -110.0), 0)
	holder.add_child(sun)
	return holder
