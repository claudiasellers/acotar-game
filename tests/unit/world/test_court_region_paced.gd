## Contract (T161): a streamed-in court region builds its main-thread half
## (scatter chunks, landmarks, creatures...) a few steps a frame under
## FrameBudget, not all in the frame its worker finishes, and ends up with
## exactly what the synchronous build makes.
extends GutTest

const SCENE := "res://world/spring_court/rosewild/rosewild.tscn"


func _counts(region: CourtRegion) -> Dictionary:
	var out := {}
	for child in region.get_children():
		out[String(child.name)] = child.get_child_count()
	return out


func test_threaded_build_is_spread_over_frames_and_matches_the_sync_build() -> void:
	var sync := (load(SCENE) as PackedScene).instantiate() as CourtRegion
	sync.threaded = false
	add_child(sync)
	var want := _counts(sync)
	remove_child(sync)
	sync.free()

	var region := (load(SCENE) as PackedScene).instantiate() as CourtRegion
	add_child(region)
	var paced_frames := 0
	var deadline := Time.get_ticks_msec() + 180_000
	while not region.is_built and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if region._task < 0 and not region._warming and not region.is_built:
			paced_frames += 1
	assert_true(region.is_built, "rosewild finished its threaded build (cap 180 s)")
	assert_gt(paced_frames, 1, "the main-thread build took several frames, not one")
	assert_eq(_counts(region), want, "the paced build makes the same nodes as the sync build")
	remove_child(region)
	region.free()
