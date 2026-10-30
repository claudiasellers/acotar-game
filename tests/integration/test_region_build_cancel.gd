## Region streaming shutdown (act1-fixlist F14): freeing a region while its
## worker is still generating (quitting the game, a teleport) cancels the
## worker instead of waiting out the whole build.
extends GutTest

## Done-when bar: quitting mid-build exits in under 3 s.
const MAX_JOIN_MSEC := 3000


func _free_mid_build(path: String) -> int:
	var region: Node = load(path).instantiate()
	if "use_cache" in region:
		region.use_cache = false  # the slow path: generate everything
	add_child(region)
	await wait_frames(3)
	var t := Time.get_ticks_msec()
	remove_child(region)  # _exit_tree: cancel, then join the worker
	var msec := Time.get_ticks_msec() - t
	region.free()
	return msec


func test_freeing_a_woods_region_mid_build_cancels_its_worker() -> void:
	var msec := await _free_mid_build("res://world/spring_court/border_woods/border_woods.tscn")
	gut.p("border_woods joined in %d ms" % msec)
	assert_lt(msec, MAX_JOIN_MSEC)


func test_freeing_a_court_region_mid_build_cancels_its_worker() -> void:
	var msec := await _free_mid_build("res://world/spring_court/rosewild/rosewild.tscn")
	gut.p("rosewild joined in %d ms" % msec)
	assert_lt(msec, MAX_JOIN_MSEC)


func test_a_region_put_back_after_a_cancel_builds_again() -> void:
	var region: WoodsRegion = load("res://world/spring_court/suriel_glade/suriel_glade.tscn").instantiate()
	region.build_ground_cover = false
	add_child(region)
	await wait_frames(2)
	remove_child(region)  # cancels the build in flight
	add_child(region)
	await wait_until(func() -> bool: return region.is_built, 60.0)
	assert_true(region.is_built, "rebuilt after coming back")
	assert_gt(get_tree().get_nodes_in_group(&"forage_field").size(), 20)
	region.free()
