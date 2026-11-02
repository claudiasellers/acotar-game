## Woods trees must show early in a stream-in (the cloud shots and slow
## machines saw bare ground for minutes): trees queue first, nothing invisible
## queues ahead of them, one slow job does not throttle its kind for the rest
## of the session, and shot tools can see that a region is still building.
extends GutTest

const SCENE := "res://world/spring_court/suriel_glade/suriel_glade.tscn"


func _queued(fallback: bool) -> Array[String]:
	var region: WoodsRegion = load(SCENE).instantiate()
	region.build_terrain_fallback = fallback
	region._fingerprint = WoodsScatterCache.fingerprint_for(region.def)
	region._places = WoodsRegion.own_places(region.def)
	PlaceComposer.prewarm(region._places)
	region._prepare()
	region._queue_jobs()
	var out: Array[String] = []
	for job in region._jobs:
		var m := String(job.get_method())
		if m == "_job_scatter_chunk":
			m += ":" + String(job.get_bound_arguments()[0])
		out.append(m)
	region.free()
	return out


func test_trees_queue_before_shrubs_colliders_and_forage() -> void:
	var q := _queued(false)
	var first_tree := q.find("_job_scatter_chunk:tree")
	var last_tree := q.rfind("_job_scatter_chunk:tree")
	assert_gt(first_tree, 0, "tree chunks queued")
	assert_lt(last_tree, q.find("_job_scatter_chunk:shrub"), "every tree before the first shrub")
	assert_lt(q.find("_job_scatter_chunk:shrub"), q.find("_job_colliders"), "shrubs before trunk colliders")
	assert_lt(q.find("_job_colliders"), q.find("_job_scatter_chunk:forage"), "colliders before forage")
	assert_lt(q.find("_job_scatter_chunk:forage"), q.find("_job_landmarks"), "scatter before dressing")
	assert_lt(last_tree, q.size() / 4, "trees are in the first quarter of the build")


func test_no_fallback_ground_jobs_when_terrain_is_live() -> void:
	assert_false(_queued(false).has("_job_terrain_chunk"), "nothing invisible ahead of the trees")
	var with_ground := _queued(true)
	assert_lt(with_ground.rfind("_job_terrain_chunk"), with_ground.find("_job_scatter_chunk:tree"),
			"standalone, the stand-in ground comes first so trees never float")


func test_standalone_region_is_not_under_live_terrain() -> void:
	var region: WoodsRegion = load(SCENE).instantiate()
	assert_false(WoodsRegion.terrain_is_live(region), "outside the tree")
	region.free()


func test_region_is_shot_busy_until_built() -> void:
	var region: WoodsRegion = load(SCENE).instantiate()
	region.build_ambient_life = false
	add_child(region)
	assert_true(region.is_in_group(WoodsRegion.BUSY_GROUP), "busy while building")
	await wait_until(func() -> bool: return region.is_built, 60.0)
	assert_true(region.is_built)
	assert_false(region.is_in_group(WoodsRegion.BUSY_GROUP), "leaves the group when built")
	region.free()


func test_one_spike_does_not_pin_a_kind_to_one_job_a_frame() -> void:
	FrameBudget.reset_stats()
	var ran: Array[String] = []
	var queue: Array[Callable] = [_spiky.bind(ran, 6000)]
	for i in 12:
		queue.append(_spiky.bind(ran, 0))
	await wait_process_frames(1)
	FrameBudget.run(queue)
	assert_eq(ran.size(), 1, "the spike runs alone")
	await wait_process_frames(1)
	FrameBudget.run(queue)
	assert_gte(ran.size(), 4, "the next frame packs several cheap jobs of that kind")
	assert_eq(FrameBudget.late_starts, 0)


func _spiky(ran: Array[String], usec: int) -> void:
	if usec > 0:
		OS.delay_usec(usec)
	ran.append("job")


func test_flora_mesh_off_the_main_thread_does_not_poison_the_cache() -> void:
	var species := &""
	for s: StringName in FloraLibrary.SPECIES:
		if FloraLibrary.has_model(s):
			species = s
			break
	assert_ne(species, &"", "a species with a Blender model")
	FloraLibrary._near.erase(species)
	FloraLibrary._arrays.erase("%s:1" % species)  # cold: as if no main-thread load came first
	var task := WorkerThreadPool.add_task(func() -> void: FloraLibrary.mesh(species), true)
	WorkerThreadPool.wait_for_task_completion(task)
	assert_false(FloraLibrary.has_mesh(species), "nothing cached from the worker")
	assert_gt(FloraLibrary.mesh(species).get_surface_count(), 0, "the main thread still builds the real mesh")
