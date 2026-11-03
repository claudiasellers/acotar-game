## Contract: NavBaker bakes walkable ground from static colliders and NavMover
## routes round walls through a door, falling back to straight steering when
## no navmesh is there (T5).
extends GutTest

var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


## Two 8x8 m rooms side by side along X, a 1.6 m door in the shared wall at z = +3.
func _two_rooms() -> void:
	_box(Vector3(0, -0.25, 0), Vector3(17, 0.5, 9))           # floor
	_box(Vector3(0, 1.5, -4.5), Vector3(17, 3, 0.2))          # north wall
	_box(Vector3(0, 1.5, 4.5), Vector3(17, 3, 0.2))           # south wall
	_box(Vector3(-8.5, 1.5, 0), Vector3(0.2, 3, 9))           # west wall
	_box(Vector3(8.5, 1.5, 0), Vector3(0.2, 3, 9))            # east wall
	_box(Vector3(0, 1.5, -1.0), Vector3(0.2, 3, 7.0))         # shared wall, z -4.5..2.5
	# door gap z 2.5..4.1, then a stub to the south wall
	_box(Vector3(0, 1.5, 4.3), Vector3(0.2, 3, 0.4))


func test_routes_through_the_door() -> void:
	_two_rooms()
	var region := NavBaker.bake_area(_root, AABB(Vector3(-10, -1, -6), Vector3(20, 5, 12)), _root)
	assert_not_null(region.navigation_mesh)
	assert_gt(region.navigation_mesh.get_polygon_count(), 0, "baked polygons")
	var walker := Node3D.new()
	_root.add_child(walker)
	walker.global_position = Vector3(-5, 0, -2)
	var mover := NavMover.on(walker)
	# Regions sync on the server's own iterations (async): wait until it has polygons.
	for i in 120:
		await wait_physics_frames(1)
		if mover.has_mesh_at(walker.global_position):
			break
	var goal := Vector3(5, 0, -2)
	assert_true(mover.has_mesh_at(walker.global_position), "on the mesh")
	var length := mover.path_length_to(goal)
	var straight := walker.global_position.distance_to(goal)
	assert_gt(length, straight + 3.0, "goes round by the door, not through the wall (%.1f m)" % length)
	assert_lt(length, straight * 1.5 + 9.0, "no wild detour (%.1f m)" % length)
	var dir := mover.steer(goal)
	assert_gt(dir.z, 0.3, "first heads south toward the door")
	for i in 600:
		var step := mover.steer(goal)
		walker.global_position += step.normalized() * minf(0.08, walker.global_position.distance_to(goal))
		if walker.global_position.distance_to(goal) < 0.5:
			break
		await wait_physics_frames(1)
	assert_lt(walker.global_position.distance_to(goal), 0.6, "arrives")


func test_parse_runs_on_the_main_thread_and_bake_callback_lands() -> void:
	_two_rooms()
	NavBaker.last_parse_thread = -1
	var source := NavBaker.parse(_root)
	assert_eq(NavBaker.last_parse_thread, OS.get_main_thread_id(), "parse reads the tree on the main thread")
	var region := NavigationRegion3D.new()
	_root.add_child(region)
	var done := [false]
	NavBaker.bake(region, source, AABB(Vector3(-10, -1, -6), Vector3(20, 5, 12)), true, func() -> void: done[0] = true)
	for i in 300:
		if done[0]:
			break
		await wait_physics_frames(1)
	assert_true(done[0], "async bake finished")
	assert_gt(region.navigation_mesh.get_polygon_count() if region.navigation_mesh else 0, 0)


func test_without_a_navmesh_it_steers_straight() -> void:
	var walker := Node3D.new()
	_root.add_child(walker)
	walker.global_position = Vector3(500, 0, 500)
	var mover := NavMover.on(walker)
	await wait_physics_frames(2)
	var dir := mover.steer(Vector3(510, 0, 500))
	assert_almost_eq(dir.normalized().x, 1.0, 0.001, "straight at the goal")


func _box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	col.shape = b
	body.add_child(col)
	_root.add_child(body)
	body.position = at
