## Contract test for the manor façade (L42, audit A8): every outer window has
## a surround, the dressing keeps every outer door clear, the stone and slate
## stay under the glare cap, and the windows only glow after sundown.
extends GutTest

var house: Node3D
var all: ManorHouseIndex
var plan: Dictionary
var holder: Node3D


func after_all() -> void:
	holder.free()


func before_all() -> void:
	holder = Node3D.new()
	add_child(holder)
	house = ManorHouseBuilder.build(holder)
	all = ManorHouseIndex.new(ManorHouseBuilder.load_layouts())
	plan = ManorFacade.placements(all, house.get_meta(&"facade_windows", []))


func _count(id: StringName) -> int:
	return (plan.get(id, []) as Array).size()


func test_report() -> void:
	var line := PackedStringArray()
	for id in ManorFacade.PIECES:
		line.append("%s %d" % [String(id).trim_prefix("facade_"), _count(id)])
	gut.p("runs %d, windows %d, panes %d | %s" % [(plan.runs as Array).size(),
		(house.get_meta(&"facade_windows", []) as Array).size(), _count(&"panes"), ", ".join(line)])
	assert_gt((plan.runs as Array).size(), 20)


func test_every_outer_window_has_a_surround_and_a_pane() -> void:
	var windows: Array = house.get_meta(&"facade_windows", [])
	assert_gt(windows.size(), 60)
	var surrounds := _count(&"facade_surround_arch") + _count(&"facade_surround_pediment") \
			+ _count(&"facade_surround_segment") + _count(&"facade_surround_simple")
	assert_eq(surrounds, windows.size())
	assert_eq(_count(&"panes"), windows.size())
	assert_eq(_count(&"views"), windows.size(), "a view from inside each window (D2)")
	assert_eq(_count(&"facade_inner_reveal"), windows.size(), "a lined reveal and sill inside each window (D2)")
	for id in [&"facade_surround_arch", &"facade_surround_pediment", &"facade_surround_segment", &"facade_surround_simple"]:
		assert_gt(_count(id), 0, "%s is used" % id)
	assert_gt(_count(&"facade_shutters"), 0)


func test_order_and_greenery_counts() -> void:
	assert_gt(_count(&"facade_pilaster"), 60)
	assert_gt(_count(&"facade_string_course"), 40)
	assert_gt(_count(&"facade_cornice"), 40)
	assert_gt(_count(&"facade_plinth"), 40)
	assert_gte(_count(&"facade_balcony"), 8)
	# Roses and ivy on at least 30% of the lower two storeys' bays.
	var low := ManorHouseBuilder.floor_y(2) - 1.0
	var bays := (plan[&"facade_pilaster"] as Array).filter(func(x: Transform3D) -> bool: return x.origin.y < low).size()
	var green := _count(&"facade_climber_rose") + _count(&"facade_ivy")
	gut.p("greenery %d over %d lower bays" % [green, bays])
	assert_gte(float(green) / bays, 0.3)
	assert_gt(_count(&"facade_wisteria"), 3)


func test_dressing_keeps_outer_doors_clear() -> void:
	var blocked := PackedStringArray()
	for run: Dictionary in plan.runs:
		for d in all.doors_on_level(run.level):
			var off: Vector2 = d.at - (run.a as Vector2)
			if absf(off.dot(run.out)) > ManorHouseBuilder.DOOR_TOLERANCE:
				continue
			var along := off.dot(run.dir)
			if along < 0.0 or along > run.length:
				continue
			var y0 := ManorHouseBuilder.floor_y(run.level)
			# The doorway, 1.2 m out from the wall face.
			var c := (run.a as Vector2) + (run.dir as Vector2) * along + (run.out as Vector2) * 0.7
			var size := Vector3(absf(run.dir.x) * (d.width - 0.1) + absf(run.out.x) * 1.0, d.height - 0.2,
					absf(run.dir.y) * (d.width - 0.1) + absf(run.out.y) * 1.0)
			var door_box := AABB(Vector3(c.x, y0 + 0.1, c.y) - Vector3(size.x * 0.5, 0, size.z * 0.5), size)
			for id in ManorFacade.PIECES:
				if id in [&"facade_plinth", &"facade_string_course", &"facade_cornice", &"facade_inner_reveal"]:
					continue
				var meshes := PropModels.pair(ManorFacade.MODEL_DIR + String(id) + ".glb", String(id))
				for xf: Transform3D in plan[id]:
					if (xf * (meshes[0] as Mesh).get_aabb()).intersects(door_box):
						blocked.append("%s over door at %s L%d" % [id, d.at, d.level])
	assert_eq(blocked, PackedStringArray())


func test_nothing_in_the_trellis_zone_below_its_top() -> void:
	var top := ManorSitePlan.base_y() + ManorFacade.TRELLIS_TOP
	var bad := 0
	for id in [&"facade_climber_rose", &"facade_ivy", &"facade_balcony"]:
		for xf: Transform3D in plan[id]:
			var p := xf.origin
			if p.z < -71.5 and p.z > -72.6 and p.x > ManorFacade.TRELLIS_X.x and p.x < ManorFacade.TRELLIS_X.y and p.y < top:
				bad += 1
	assert_eq(bad, 0)


func test_glare_cap_and_slate() -> void:
	# Read the defaults from the shader source (headless has no shader compiler).
	var re := RegEx.create_from_string("uniform vec3 (\\w+) : source_color = vec3\\(([^)]*)\\)")
	var found := 0
	for m in re.search_all(ManorFacade.stone().shader.code):
		var v := m.get_string(2).split(",")
		var mx := maxf(float(v[0]), maxf(float(v[1]), float(v[2])))
		assert_lte(mx, ManorFacade.MAX_ALBEDO, "%s albedo" % m.get_string(1))
		found += 1
	assert_eq(found, 3, "three stone tints")
	var slate := ManorFacade.roof_material(EstateKit.SLATE)
	assert_true(slate is ShaderMaterial, "lilac roofs get fish-scale slate")
	assert_false(ManorFacade.roof_material(EstateKit.GOLD) is ShaderMaterial, "gilt stays plain")


func test_windows_glow_only_after_sundown() -> void:
	assert_lt(ManorFacadeGlow.amount(0.5), 0.05, "noon")
	assert_lt(ManorFacadeGlow.amount(0.35), 0.05, "morning")
	assert_gt(ManorFacadeGlow.amount(0.74), 0.5, "dusk")
	assert_gt(ManorFacadeGlow.amount(0.9), 0.95, "night")


func test_kit_models_are_in_budget() -> void:
	for id in ManorFacade.PIECES:
		var meshes := PropModels.pair(ManorFacade.MODEL_DIR + String(id) + ".glb", String(id))
		assert_eq(meshes.size(), 2, "%s has LOD0 and LOD1" % id)
		if meshes.size() == 2:
			assert_lte(PropModels.tri_count(meshes[0]), 3000, "%s tris" % id)


func test_facade_node_is_built_into_the_house() -> void:
	var f := house.get_node_or_null(^"Facade")
	assert_not_null(f)
	if f:
		var mmis := f.find_children("*", "MultiMeshInstance3D", false, false)
		gut.p("facade multimeshes (draw calls before shadows): %d" % mmis.size())
		assert_lte(mmis.size(), 16)


## F39: a 1.4 m lane from the drive, up the front steps and to the front door
## is clear for her capsule (no riser, column, pilaster or balcony in the way).
func test_front_steps_walk_in_is_clear() -> void:
	await get_tree().physics_frame
	var ramps := ManorFacade.step_ramps(all)
	var front: Dictionary = {}
	for r: Dictionary in ramps:
		if absf((r.from as Vector3).x) < 1.0 and (r.from as Vector3).z > -28.0:
			front = r
	assert_false(front.is_empty(), "a walk-in ramp over the front flight")
	if front.is_empty():
		return
	assert_gte(front.width, 1.4)
	var slope := rad_to_deg(atan2((front.to as Vector3).y - (front.from as Vector3).y,
			Vector2((front.to as Vector3).x - (front.from as Vector3).x, (front.to as Vector3).z - (front.from as Vector3).z).length()))
	gut.p("front ramp %s -> %s, slope %.1f deg, width %.1f m" % [front.from, front.to, slope, front.width])
	assert_lt(slope, 40.0, "within her 45 degree floor limit")
	var door_z := ManorSitePlan.FRONT_DOOR.z + 0.5   # capsule front 0.2 m short of the closed leaves
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	var space := (house.get_world_3d() as World3D).direct_space_state
	var lift := Vector3(0, 0.85 + 0.06, 0)
	var blocked := PackedStringArray()
	for x in [-0.7, 0.0, 0.7]:
		var path: Array[Vector3] = [Vector3(x, (front.from as Vector3).y, -15.0), Vector3(x, (front.from as Vector3).y, (front.from as Vector3).z),
			Vector3(x, (front.to as Vector3).y, (front.to as Vector3).z), Vector3(x, (front.to as Vector3).y, door_z)]
		for i in path.size() - 1:
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = capsule
			q.collision_mask = EstateKit.WORLD_LAYER
			q.transform = Transform3D(Basis.IDENTITY, path[i] + lift)
			q.motion = path[i + 1] - path[i]
			var hit := space.cast_motion(q)
			if hit.size() == 2 and hit[0] < 1.0:
				blocked.append("x %.1f leg %d stops at %.0f%%" % [x, i, hit[0] * 100.0])
	assert_eq(blocked, PackedStringArray())


func test_every_outside_flight_gets_a_ramp() -> void:
	var ramps := ManorFacade.step_ramps(all)
	gut.p("step ramps: %d" % ramps.size())
	assert_gte(ramps.size(), 4, "front flight and the three garden flights")


## F39 as a walk: her capsule (Feyre's body settings) walks from the drive
## straight to the front door on a flat ground plane and must arrive.
func test_capsule_walks_up_the_front_steps() -> void:
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	gs.shape = box
	ground.add_child(gs)
	ground.position = Vector3(0, ManorSitePlan.base_y() - 0.5, -10)
	ground.collision_layer = EstateKit.WORLD_LAYER
	holder.add_child(ground)
	for x in [-0.7, 0.0, 0.7]:
		var reached := await _walk(Vector3(x, ManorSitePlan.base_y() + 0.9, -16.0), ManorSitePlan.FRONT_DOOR.z + 0.6)
		assert_true(reached, "walks from the drive to the door at x %.1f" % x)
	ground.free()


func _walk(from: Vector3, to_z: float) -> bool:
	var body := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	body.add_child(cs)
	body.collision_layer = 0
	body.collision_mask = EstateKit.WORLD_LAYER
	body.floor_snap_length = 0.4
	holder.add_child(body)
	body.global_position = from
	var ok := false
	for i in 240:   # 4 s at 60 Hz, 4.5 m/s
		await get_tree().physics_frame
		body.velocity = Vector3(0, body.velocity.y - 9.8 / 60.0 if not body.is_on_floor() else 0.0, -4.5)
		body.move_and_slide()
		if body.global_position.z <= to_z:
			ok = true
			break
	gut.p("walk x %.1f ends at %s" % [from.x, body.global_position.snapped(Vector3.ONE * 0.01)])
	body.free()
	return ok
