extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	PhaseManager.start(load("res://data/phases/spring_court_phases.tres"), &"p2_grounds")
	var estate: ManorEstate = (load("res://world/spring_court/manor_estate/manor_estate.tscn") as PackedScene).instantiate()
	estate.build_scatter = false
	estate.build_grounds = false
	add_child(estate)
	var f := (load("res://characters/feyre/feyre.tscn") as PackedScene).instantiate() as Feyre
	estate.add_child(f)
	f.vitals.health_changed.connect(func(h: float, _m: float, d: float, src: StringName) -> void: print("DOOR health ", h, " d=", d, " src=", src, " down=", f.vitals.is_down))
	Engine.max_physics_steps_per_frame = 16
	Engine.time_scale = 8.0
	for i in 5:
		await get_tree().physics_frame
	print("DOOR spawn y=", f.global_position.y, " vy=", f.velocity.y, " fall=", f.vitals._fall_speed)
	f.teleport(Vector3(0.0, WorldHeight.height_at(0.0, -16.0) + 0.4, -16.0))
	f.nudge_camera(angle_difference(f.camera_yaw(), 0.0), 0.0)
	f.model.rotation.y = 0.0
	for i in 5:
		await get_tree().physics_frame
	Input.action_press(&"move_forward")
	for i in 180:
		await get_tree().physics_frame
		if i % 10 == 0:
			print("DOOR t=", i, " z=%.3f y=%.3f vel=%s floor=%s mode=%d down=%s hp=%.1f st=%s winded=%s grab=%s iframes=%.2f" % [f.global_position.z, f.global_position.y, f.velocity, f.is_on_floor(), StoryControl.mode, f.vitals.is_down, f.vitals.health, f.get(&"stamina"), f.call(&"is_winded") if f.has_method(&"is_winded") else "?", f.vitals.is_grabbed(), f.vitals._iframes])
		if f.global_position.z < -30.0:
			break
	print("DOOR end z=", f.global_position.z)
	var out := OS.get_cmdline_user_args()
	if out.size() > 0:
		DirAccess.make_dir_recursive_absolute(out[0])
		get_viewport().get_texture().get_image().save_png(out[0].path_join("door.png"))
	Input.action_release(&"move_forward")
	Engine.time_scale = 1.0
	get_tree().quit()
