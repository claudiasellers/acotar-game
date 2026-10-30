## Woods lane: streaming a woods region in is scheduled under the shared
## FrameBudget (4 ms of main-thread work a frame), and the worker-built
## MultiMesh buffers match the scatter contract's transforms.
extends GutTest

## CI gates only what is deterministic: the scheduler's own rule (no job
## starts once the frame's accounted budget is spent) and that the build is
## spread over frames. Wall clock depends on the machine (shared CI runners
## blow any fixed bar), so frame timings are logged here, and real frame
## timing is R9's milestone profiling.
const JOBS_PER_FRAME := 4
const SCENE := "res://world/spring_court/suriel_glade/suriel_glade.tscn"


func _stream_in() -> WoodsRegion:
	var region: WoodsRegion = load(SCENE).instantiate()
	add_child(region)
	await wait_until(func() -> bool: return region.is_built, 60.0)
	return region


func test_async_build_is_scheduled_in_the_frame_budget() -> void:
	# The first build warms the engine once per session (particle shaders,
	# caches) on the real clock.
	var warm := await _stream_in()
	warm.free()
	# Then stream on the test clock: every job costs a quarter of the budget,
	# so scheduling no longer depends on how fast this machine is.
	FrameBudget.reset_stats()
	FrameBudget.fixed_cost_usec = FrameBudget.BUDGET_USEC / JOBS_PER_FRAME
	var start := Engine.get_process_frames()
	var region := await _stream_in()
	var frames := Engine.get_process_frames() - start
	FrameBudget.fixed_cost_usec = 0
	var costs := FrameBudget.frame_costs()
	var jobs := FrameBudget.jobs_accounted
	gut.p("suriel_glade streamed in %d frames, %d jobs on %d of them; measured slowest job %s, %d us; cache %s" % [
			frames, jobs, costs.size(), FrameBudget.slowest_job, FrameBudget.max_job_usec, region.used_cache])
	assert_true(region.is_built)
	assert_eq(FrameBudget.late_starts, 0, "no job starts after the frame's budget is spent")
	assert_eq(FrameBudget.queued_jobs_started, jobs, "every job's cost is accounted")
	assert_gt(jobs, 40, "the build is many small jobs")
	assert_eq(costs.size(), ceili(float(jobs) / JOBS_PER_FRAME),
			"frames with work = ceil(accounted cost / budget): every frame but the last is full")
	for i in costs.size() - 1:
		if costs[i] != FrameBudget.BUDGET_USEC:
			assert_eq(costs[i], FrameBudget.BUDGET_USEC, "frame %d is filled to the budget" % i)
			break
	assert_gte(region.landmark_count, 3)
	assert_gt(get_tree().get_nodes_in_group(&"forage_field").size(), 20)
	region.free()


func test_frame_budget_defers_a_job_that_will_not_fit() -> void:
	FrameBudget.reset_stats()
	FrameBudget.job_max[&"_test_slow"] = FrameBudget.BUDGET_USEC
	var ran: Array[String] = []
	var queue: Array[Callable] = [_test_fast.bind(ran), _test_slow.bind(ran)]
	await wait_frames(1)
	assert_eq(FrameBudget.run(queue), 1, "the slow job waits for a fresh frame")
	await wait_frames(1)
	assert_eq(FrameBudget.run(queue), 0)
	assert_eq(ran, ["fast", "slow"])
	assert_eq(FrameBudget.late_starts, 0)


func test_worker_buffer_matches_scatter_transforms() -> void:
	var layer := ScatterLayer.new()
	layer.instances = PackedFloat32Array([10.0, 2.0, -5.0, 0.7, 1.3, -40.0, 8.5, 22.0, 2.9, 0.6])
	var origin := Vector3(16.0, 0.0, 16.0)
	var buf := SlicedScatterField.transforms_buffer(layer.instances, PackedInt32Array([1, 0]), origin)
	# Reference: Godot's documented TRANSFORM_3D layout, 3x4 row-major.
	var want := PackedFloat32Array()
	for j in 2:
		var t := layer.transform_of(1 - j)
		var b := t.basis
		var o := t.origin - origin
		want.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z])
	assert_eq(buf.size(), want.size())
	for i in want.size():
		assert_almost_eq(buf[i], want[i], 0.0001, "float %d" % i)


func test_ground_cover_cells_build_from_worker_buffers() -> void:
	var def: WoodsRegionDef = load("res://data/regions/spring_court/suriel_glade_biomes.tres")
	var cover := DetailScatter.new()
	cover.def = def
	cover.bounds = SurielGladeTerrain.BOUNDS
	add_child(cover)
	var p := SurielGladeTerrain.SNARE_SITE
	var key := Vector2i(floori(p.x / DetailScatter.CELL), floori(p.y / DetailScatter.CELL))
	var placements := cover.placements_for(key)
	var buffers := cover.buffers_for(key)
	assert_eq(buffers.keys().size(), placements.keys().size())
	for species: StringName in placements:
		assert_eq((buffers[species] as PackedFloat32Array).size() / 12, (placements[species] as PackedFloat32Array).size() / ScatterLayer.STRIDE)
	cover.build_around(Vector3(p.x, 0.0, p.y))
	assert_gt(cover.cell_count(), 4)
	cover.free()


func _test_fast(ran: Array[String]) -> void:
	ran.append("fast")


func _test_slow(ran: Array[String]) -> void:
	ran.append("slow")
