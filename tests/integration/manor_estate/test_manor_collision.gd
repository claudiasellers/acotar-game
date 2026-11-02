## Contract (owner, T038): she walks in at the front door, and no jump, however
## many in a chain and at whatever speed, takes her out of a manor room. The walls
## hold on their own (the sweep stops her); what let her out was a ledge climb past
## the wall and the rooms under the roof having no lid.
extends GutTest

const SCENE := preload("res://world/spring_court/manor_estate/manor_estate.tscn")
const FEYRE := preload("res://characters/feyre/feyre.tscn")
## Room, her yaw toward a blank stretch of wall, and where she runs from.
const RUNS: Array[Array] = [
	[&"entrance_hall", PI * 0.5, Vector2(-6, -44)],
	[&"library", -PI * 0.5, Vector2(-24, -66)],
	[&"map_room", 0.0, Vector2(-33, -44)],
]

var estate: ManorEstate
var f: Feyre
var all: ManorHouseIndex


func before_all() -> void:
	PhaseManager.start(load("res://data/phases/spring_court_phases.tres"), &"p2_grounds")
	estate = SCENE.instantiate()
	estate.build_scatter = false
	estate.build_grounds = false
	add_child(estate)
	all = ManorHouseIndex.new(ManorHouseBuilder.load_layouts())
	f = FEYRE.instantiate() as Feyre
	estate.add_child(f)
	Engine.max_physics_steps_per_frame = 16
	Engine.time_scale = 8.0
	await wait_physics_frames(5)


func after_all() -> void:
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
	estate.free()


func after_each() -> void:
	for a in [&"move_forward", &"sprint", &"jump"]:
		Input.action_release(a)


func _room(id: StringName) -> ManorRoomDef:
	for r in all.interior_rooms():
		if r.id == id:
			return r
	return null


func _face(yaw: float) -> void:
	f.nudge_camera(angle_difference(f.camera_yaw(), yaw), 0.0)
	f.model.rotation.y = yaw


func test_she_walks_in_at_the_front_door() -> void:
	var gate := estate.house.get_node("Gate_manor_house") as RegionGate
	assert_false(gate.is_locked())
	for sprint: bool in [false, true]:
		f.teleport(Vector3(0.0, WorldHeight.height_at(0.0, -16.0) + 0.4, -16.0))
		_face(0.0)
		await wait_physics_frames(5)
		Input.action_press(&"move_forward")
		if sprint:
			Input.action_press(&"sprint")
		for i in 180:
			await get_tree().physics_frame
			if f.global_position.z < -30.0:
				break
		after_each()
		assert_lt(f.global_position.z, -30.0, "through the doors, in the entrance hall (sprint %s)" % sprint)


func test_jump_chains_never_leave_the_room() -> void:
	for run: Array in RUNS:
		var r := _room(run[0])
		var y0 := ManorHouseBuilder.floor_y(r.level)
		for sprint: bool in [false, true]:
			for jumps in [2, 3]:
				var from: Vector2 = run[2]
				f.teleport(Vector3(from.x, y0 + 0.1, from.y))
				_face(run[1])
				await wait_physics_frames(2)
				Input.action_press(&"move_forward")
				if sprint:
					Input.action_press(&"sprint")
				for t in 100:
					await get_tree().physics_frame
					if t in [12, 24, 36].slice(0, jumps):
						Input.action_press(&"jump")
					else:
						Input.action_release(&"jump")
				after_each()
				var p := f.global_position
				assert_true(r.rect.has_point(Vector2(p.x, p.z)) and p.y < y0 + ManorHouseBuilder.ceiling_of(r),
						"%s: sprint %s, %d jumps, ended at %s" % [r.id, sprint, jumps, p])


func test_every_room_has_a_lid() -> void:
	await get_tree().physics_frame
	var space := f.get_world_3d().direct_space_state
	var open := PackedStringArray()
	for r in all.interior_rooms():
		if r.level < 0:
			continue
		var y0 := ManorHouseBuilder.floor_y(r.level)
		var c := r.rect.get_center()
		var top := y0 + ManorHouseBuilder.ceiling_of(r)
		# A stairwell's lid is a storey on, in the room the stairs lead to.
		var query := PhysicsRayQueryParameters3D.create(Vector3(c.x, top - 0.2, c.y),
				Vector3(c.x, top + ManorSitePlan.HOUSE_STOREY + 0.4, c.y), EstateKit.WORLD_LAYER)
		if space.intersect_ray(query).is_empty():
			open.append(String(r.id))
	assert_eq(open, PackedStringArray(), "a jump chain reaches 9 m: nothing over these rooms")
