extends GutTest
## Lane L32 contract: every wider-court landmark has a setting (forecourt,
## collar, light, particles, sound) and the ground layers read the canopy.

const GroundComposition := preload("res://world/spring_court/shared/ground_composition.gd")
const CONTENT_DIR := "res://data/regions/spring_court/content/"
const CLUTTER := [&"rock", &"pebble", &"shrub", &"deadwood"]


func test_every_court_landmark_has_a_complete_setting() -> void:
	var t := PlaceComposer.table()
	assert_not_null(t, "data/places/court_places.tres missing")
	var missing: Array[String] = []
	var broken: Array[String] = []
	for f in DirAccess.get_files_at(CONTENT_DIR):
		var content := load(CONTENT_DIR + f) as CourtRegionContent
		for lm in content.landmarks:
			var s := t.find(lm.id)
			if s == null:
				missing.append(String(lm.id))
				continue
			if s.center.distance_to(lm.position) > 0.5 or s.radius < 6.0:
				broken.append("%s: centre/radius" % lm.id)
			for m in Array(s.collar_meshes) + Array(s.props) + ([String(s.frame_mesh)] if s.frame_mesh != &"" else []):
				if not CourtAssets.has_model(StringName(m)):
					broken.append("%s: no model %s" % [lm.id, m])
			if s.fx_id != &"" and not ResourceLoader.exists(PlaceComposer.FX_DIR % s.fx_id):
				broken.append("%s: no fx %s" % [lm.id, s.fx_id])
			if s.sound_cue != "":
				var cue := load(s.sound_cue) as SoundCue
				if cue == null or cue.streams.is_empty() or cue.streams[0] == null or not cue.loop:
					broken.append("%s: sound %s" % [lm.id, s.sound_cue])
	assert_eq(missing, [] as Array[String], "landmarks without a PlaceSetting")
	assert_eq(broken, [] as Array[String], "incomplete settings")


func test_role_weights_follow_the_canopy() -> void:
	var w := func(r: StringName, d: float) -> float: return GroundComposition.weight(r, d)
	assert_gt(w.call(&"shrub", 9.0), w.call(&"shrub", 50.0) * 3.0, "shrubs gather at the wood edge")
	assert_gt(w.call(&"shrub", 9.0), w.call(&"shrub", 0.0), "the mantle is denser than under the canopy")
	assert_gt(w.call(&"deadwood", 2.0), w.call(&"deadwood", 40.0) * 10.0, "logs lie under trees")
	assert_gt(w.call(&"flower", 30.0), w.call(&"flower", 1.0) * 4.0, "flowers leave the shade")
	assert_eq(GroundComposition.role(&"rock_mossy_a"), &"rock")
	assert_eq(GroundComposition.role(&"flora_bush_rose"), &"shrub")
	assert_eq(GroundComposition.role(&"woods_fallen_log"), &"deadwood")
	assert_eq(GroundComposition.role(&"fence_rail"), &"other")


func test_forecourts_stay_clear_and_collars_are_planted() -> void:
	var content := load(CONTENT_DIR + "rosewild.tres") as CourtRegionContent
	var places := PlaceComposer.in_rect(PlaceComposer.table(), content.bounding_rect())
	assert_eq(places.size(), content.landmarks.size())
	var layers := CourtScatterGenerator.decor_layers(content)
	var intruders := 0
	var collar := 0
	for layer in layers:
		if layer.tags.has("place"):
			collar += layer.count()
			continue
		var mesh_id := StringName(String(layer.id).substr(9))
		if not layer.tags.has("tree") and not CLUTTER.has(GroundComposition.role(mesh_id)):
			continue
		for i in layer.count():
			var p := layer.position_of(i)
			if PlaceComposer.blocks(places, Vector2(p.x, p.z)):
				intruders += 1
	assert_eq(intruders, 0, "trees, rocks, shrubs or logs inside a forecourt")
	assert_gt(collar, 60 * places.size(), "each place gets a planted collar")


func test_place_layers_are_deterministic() -> void:
	var places := PlaceComposer.table().settings.slice(0, 6)
	var typed: Array[PlaceSetting] = []
	typed.assign(places)
	var mesh_for := func(_id: StringName) -> Mesh: return null
	var flat := func(_p: Vector2) -> float: return 0.0
	var all := func(_p: Vector2) -> bool: return true
	var a := PlaceComposer.layers(typed, 7, mesh_for, flat, all)
	var b := PlaceComposer.layers(typed, 7, mesh_for, flat, all)
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].instances, b[i].instances)


## L32-3 regression: a region worker that loads an un-prewarmed model can
## deadlock against the main thread. After CourtRegion.prewarm(), generating
## a region's layers must not load anything new.
func test_prewarm_covers_everything_the_worker_loads() -> void:
	for id in ["fae_village", "rosewild", "starlight_glen"]:
		var content := load(CONTENT_DIR + id + ".tres") as CourtRegionContent
		# From a cold cache, so earlier tests' loads can't hide a gap.
		CourtAssets._lock.lock()
		CourtAssets._meshes.clear()
		CourtAssets._scenes.clear()
		CourtAssets._resources.clear()
		CourtAssets._lock.unlock()
		CourtRegion.prewarm(content)
		CourtAssets._lock.lock()
		var meshes := CourtAssets._meshes.size()
		var scenes := CourtAssets._scenes.size()
		var resources := CourtAssets._resources.size()
		CourtAssets._lock.unlock()
		CourtScatterGenerator.forage_layers(content)
		CourtScatterGenerator.decor_layers(content)
		assert_eq(CourtAssets._meshes.size(), meshes, "%s: the worker loaded a mesh prewarm missed" % id)
		assert_eq(CourtAssets._scenes.size(), scenes, "%s: the worker loaded a scene prewarm missed" % id)
		assert_eq(CourtAssets._resources.size(), resources, "%s: the worker loaded a resource prewarm missed" % id)


## The threaded path finishes (polled with a hard deadline instead of
## blocking, so a regression fails here rather than hanging the suite).
func test_threaded_region_with_places_builds_in_time() -> void:
	var region: CourtRegion = (load("res://world/spring_court/fae_village/fae_village.tscn") as PackedScene).instantiate()
	region.threaded = true
	add_child_autofree(region)
	var deadline := Time.get_ticks_msec() + 60_000
	while not region.is_built and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_true(region.is_built, "fae_village (7 places) built within 60 s on the threaded path")
	assert_eq(get_tree().get_nodes_in_group(&"place_setting").size(), 7)
