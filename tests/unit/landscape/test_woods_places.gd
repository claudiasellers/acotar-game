extends GutTest
## Lane L32 contract, woods slice: the woods regions' named places each have
## a setting, their forecourts stay clear of trees and shrubs, the collar is
## planted, and the threaded build gives each its light, particles and sound.

const REGIONS := ["border_woods", "eastern_woods", "suriel_glade"]


func _def(region: String) -> WoodsRegionDef:
	return load("res://data/regions/spring_court/%s_biomes.tres" % region) as WoodsRegionDef


func test_every_woods_place_is_complete_and_inside_one_region() -> void:
	var t := PlaceComposer.table(WoodsRegion.PLACES_TABLE)
	assert_not_null(t, "data/places/woods_places.tres missing")
	var owned := 0
	for r in REGIONS:
		owned += WoodsRegion.own_places(_def(r)).size()
	assert_eq(owned, t.settings.size(), "every woods place belongs to exactly one region")
	var broken: Array[String] = []
	for s in t.settings:
		if s.radius < 6.0 or s.collar_meshes.is_empty():
			broken.append("%s: radius/collar" % s.id)
		for m in Array(s.collar_meshes) + Array(s.props) + ([String(s.frame_mesh)] if s.frame_mesh != &"" else []):
			if not CourtAssets.has_model(StringName(m)):
				broken.append("%s: no model %s" % [s.id, m])
		if s.fx_id != &"" and not ResourceLoader.exists(PlaceComposer.FX_DIR % s.fx_id):
			broken.append("%s: no fx %s" % [s.id, s.fx_id])
		if s.sound_cue != "" and not ResourceLoader.exists(s.sound_cue):
			broken.append("%s: sound %s" % [s.id, s.sound_cue])
	assert_eq(broken, [] as Array[String], "incomplete woods settings")


func test_forecourts_clear_and_collars_planted() -> void:
	var def := _def("suriel_glade")
	var places := WoodsRegion.own_places(def)
	assert_gt(places.size(), 0, "the snare site has a setting")
	PlaceComposer.prewarm(places)
	var rect: Rect2 = def.provider.BOUNDS
	for kind in ["tree", "shrub"]:
		var raw := WoodsScatter.place(def, rect, kind)
		var margin := WoodsRegion.PLACE_TREE_MARGIN if kind == "tree" else 0.0
		var kept := WoodsRegion.clear_forecourts(raw, places, margin)
		for id: StringName in kept:
			var inst: PackedFloat32Array = kept[id]
			for o in range(0, inst.size(), ScatterLayer.STRIDE):
				assert_false(PlaceComposer.blocks(places, Vector2(inst[o], inst[o + 2]), margin),
						"%s %s stands in a forecourt" % [kind, id])
	var layers := WoodsRegion.place_layers(def, places)
	var planted := 0
	for l in layers:
		assert_not_null(l.mesh, "%s has a mesh" % l.id)
		planted += l.count()
	assert_gt(planted, 40, "collar beds are planted round the snare site")
	var again := WoodsRegion.place_layers(def, places)
	assert_eq(again.size(), layers.size(), "deterministic layer set")
	for i in layers.size():
		assert_eq(again[i].instances, layers[i].instances, "deterministic %s" % layers[i].id)


func test_the_region_build_gives_each_place_its_light_fx_and_sound() -> void:
	var region := (load("res://world/spring_court/suriel_glade/suriel_glade.tscn") as PackedScene).instantiate() as WoodsRegion
	region.build_ground_cover = false
	region.build_ambient_life = false
	add_child_autofree(region)
	region.build_now()
	var holder := region.get_node_or_null("Places")
	assert_not_null(holder, "the region builds its Places")
	if holder == null:
		return
	assert_not_null(holder.get_node_or_null("PlaceScatter"), "collar scatter field")
	var snare := holder.get_node_or_null("Place_suriel_snare")
	assert_not_null(snare, "the snare site has its setting node")
	if snare != null:
		assert_not_null(snare.get_node_or_null("Sound"), "running water at the snare")
		assert_null(snare.get_node_or_null("Glow"), "no lamp at the snare: it stays tense")


## L32-3's deadlock class: from a cold cache, what the region warms on the
## main thread covers everything its worker and its node jobs then load.
func test_prewarm_covers_everything_the_woods_worker_loads() -> void:
	for r in REGIONS:
		var def := _def(r)
		CourtAssets._lock.lock()
		CourtAssets._meshes.clear()
		CourtAssets._scenes.clear()
		CourtAssets._resources.clear()
		CourtAssets._lock.unlock()
		var places := WoodsRegion.prewarm_places(def)
		assert_gt(places.size(), 0, "%s has named places" % r)
		CourtAssets._lock.lock()
		var meshes := CourtAssets._meshes.size()
		var scenes := CourtAssets._scenes.size()
		var resources := CourtAssets._resources.size()
		CourtAssets._lock.unlock()
		WoodsRegion.place_layers(def, places)
		var holder := Node3D.new()
		add_child_autofree(holder)
		PlaceComposer.build_nodes(holder, places)
		assert_eq(CourtAssets._meshes.size(), meshes, "%s: a mesh prewarm missed" % r)
		assert_eq(CourtAssets._scenes.size(), scenes, "%s: a scene prewarm missed" % r)
		assert_eq(CourtAssets._resources.size(), resources, "%s: a resource prewarm missed" % r)


## The threaded path finishes (polled with a deadline, so a regression fails
## here rather than hanging the suite).
func test_threaded_woods_region_with_places_builds_in_time() -> void:
	var region := (load("res://world/spring_court/suriel_glade/suriel_glade.tscn") as PackedScene).instantiate() as WoodsRegion
	region.build_ground_cover = false
	region.build_ambient_life = false
	add_child_autofree(region)
	var deadline := Time.get_ticks_msec() + 60_000
	while not region.is_built and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_true(region.is_built, "suriel_glade built within 60 s on the threaded path")
	assert_not_null(region.get_node_or_null("Places/Place_suriel_snare"), "the snare's setting node")
