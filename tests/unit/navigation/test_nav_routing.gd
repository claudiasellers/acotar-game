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


func test_feet_above_the_mesh_still_pass_each_corner() -> void:
	# On steps the mover's feet ride the treads while the mesh's corner lies on
	# the ramp below (the beast on the manor's front step, L86-29): a corner
	# under him must count as passed, or he steers at his own feet and jitters.
	_two_rooms()
	NavBaker.bake_area(_root, AABB(Vector3(-10, -1, -6), Vector3(20, 5, 12)), _root)
	var walker := Node3D.new()
	_root.add_child(walker)
	walker.global_position = Vector3(-5, 0, -2)
	var mover := NavMover.on(walker)
	for i in 120:
		await wait_physics_frames(1)
		if mover.has_mesh_at(walker.global_position):
			break
	var goal := Vector3(5, 1.2, -2)
	walker.global_position.y = 1.2  # inside ON_MESH, but over path_desired_distance in 3D
	for i in 600:
		var step := mover.steer(goal)
		var next := walker.global_position + step.normalized() * minf(0.08, walker.global_position.distance_to(goal))
		assert_false(_through_wall(walker.global_position, next), "never through the shared wall")
		walker.global_position = next
		if walker.global_position.distance_to(goal) < 0.5:
			break
		await wait_physics_frames(1)
	assert_lt(walker.global_position.distance_to(goal), 0.6, "round by the door and arrives")


func test_next_corner_skips_one_underfoot() -> void:
	var path := PackedVector3Array([Vector3(0, 0, 0), Vector3(0.2, -1.2, 0.1), Vector3(4, -1.2, 0)])
	var to := NavMover.next_corner(path, 1, Vector3(0, 0, 0), 1.0)
	assert_almost_eq(to.x, 4.0, 0.001, "the corner right below him counts as passed")
	assert_eq(to.y, 0.0, "flat")
	assert_eq(NavMover.next_corner(path, 0, Vector3(4, 0, 0), 1.0), Vector3.ZERO, "at the far end nothing is ahead, not even the start")


## L86-31: set off from the path's start, a metre on, the start is behind him
## (more than `reach` back on the ground) and must never turn him round.
func test_next_corner_never_turns_back_to_the_start() -> void:
	# The manor's front steps: the path from where he stood, to the door.
	var path := PackedVector3Array([Vector3(0, 8.25, -25.63), Vector3(0, 8.25, -27.75)])
	var to := NavMover.next_corner(path, 0, Vector3(0, 8.9, -26.8), 1.0)
	assert_eq(to, Vector3.ZERO, "the door's corner is within reach and the start is behind: nothing to turn to")
	var longer := PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -3), Vector3(5, 0, -3)])
	to = NavMover.next_corner(longer, 0, Vector3(0, 0, -1.2), 1.0)
	assert_lt(to.z, 0.0, "on along the path, never back to its start: %s" % to)
	assert_almost_eq(to.z, -1.8, 0.001, "to the next corner ahead")
	# Past the path's end at the mesh's edge (the front door), on toward a goal
	# beyond it: the end is behind him, not a corner to go back to.
	to = NavMover.next_corner(path, 0, Vector3(0, 8.9, -28.1), 0.3)
	assert_eq(to, Vector3.ZERO, "nothing behind him to turn back to: he goes on straight")


func _through_wall(a: Vector3, b: Vector3) -> bool:
	if signf(a.x) == signf(b.x) or a.x == 0.0:
		return false
	var z := lerpf(a.z, b.z, absf(a.x) / maxf(absf(b.x - a.x), 0.0001))
	return z < 2.4 or z > 4.2


func test_parse_runs_on_the_main_thread_and_bake_callback_lands() -> void:
	_two_rooms()
	NavBaker.last_parse_thread = -1
	var source := NavBaker.parse(_root)
	assert_eq(NavBaker.last_parse_thread, OS.get_main_thread_id(), "parse reads the tree on the main thread")
	var region := NavigationRegion3D.new()
	_root.add_child(region)
	var done := [false]
	var job := NavBaker.bake(region, source, AABB(Vector3(-10, -1, -6), Vector3(20, 5, 12)), true, func() -> void: done[0] = true)
	for i in 300:
		if done[0]:
			break
		await wait_physics_frames(1)
	assert_true(done[0], "async bake finished")
	assert_eq(int(job[0]), -1, "landing claimed the pool task")
	assert_gt(region.navigation_mesh.get_polygon_count() if region.navigation_mesh else 0, 0)


## T146 contract: a NavBaker leaving the tree never leaves its tile bake running
## on a thread (one finishing during engine shutdown aborted the process).
func test_leaving_the_tree_waits_for_the_tile_bake() -> void:
	_two_rooms()
	var baker := NavBaker.new()
	_root.add_child(baker)
	var aabb := AABB(Vector3(-10, -1, -6), Vector3(20, 5, 12))
	baker._bake_job = NavBaker.bake(baker.tile_region, NavBaker.parse(_root), aabb, true)
	var job := baker._bake_job
	assert_gte(int(job[0]), 0, "a threaded bake hands back its pool task")
	var t0 := Time.get_ticks_msec()
	_root.remove_child(baker)
	assert_eq(int(job[0]), -1, "leaving the tree claimed the bake")
	assert_lt(Time.get_ticks_msec() - t0, 10000, "and only waited for the bake itself")
	baker.free()


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


## The server keys navmesh edges on a grid of map cell size x this scale. At
## 1.0 (0.25 m) distinct terrain vertices a few cm apart share a key and every
## dense bake logs "Navigation region synchronization had N edge error(s)" (T142).
func test_edge_merge_grid_is_finer_than_the_bake() -> void:
	var scale := float(ProjectSettings.get_setting("navigation/3d/merge_rasterizer_cell_scale", 1.0))
	assert_lte(scale * 0.25, 0.01, "merge rasterizer cell at most 1 cm")
