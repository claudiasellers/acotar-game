extends GutTest


func test_falloff_reaches_zero_at_radius() -> void:
	assert_eq(BeastActor.falloff(0.0), 1.0)
	assert_eq(BeastActor.falloff(BeastActor.RADIUS), 0.0)
	assert_eq(BeastActor.falloff(30.0), 0.0)
	assert_gt(BeastActor.falloff(4.0), BeastActor.falloff(10.0))


func test_stages_drive_pressure() -> void:
	var beast := preload("res://creatures/beast/beast_actor.tscn").instantiate() as BeastActor
	add_child_autofree(beast)
	assert_eq(beast.pressure_at(Vector3.ZERO), 0.0)
	var door := Node3D.new()
	add_child_autofree(door)
	beast.begin_approach(door)
	assert_eq(beast.stage, BeastActor.Stage.APPROACH)
	beast.break_door()
	beast._process(0.016)
	assert_eq(beast.stage, BeastActor.Stage.PRESENCE, "the break is a one-frame spike")
	assert_gt(beast.pressure_at(beast.global_position + Vector3(2, 0, 0)), 0.5)
	beast.withdraw()
	for i in 200:
		beast._process(0.05)
	assert_lt(beast.intensity, 0.25)


func test_lights_gutter_near_the_beast() -> void:
	var beast := preload("res://creatures/beast/beast_actor.tscn").instantiate() as BeastActor
	add_child_autofree(beast)
	var light := OmniLight3D.new()
	light.light_energy = 2.0
	light.add_to_group(BeastActor.LIGHT_GROUP)
	add_child_autofree(light)
	light.global_position = Vector3(1, 0, 0)
	beast.break_door()
	beast._process(0.016)
	assert_lt(light.light_energy, 1.0)
