## Woods lane: biome data, height providers and the flora library.
extends GutTest

const REGIONS := [&"border_woods", &"eastern_woods", &"suriel_glade"]


func _def(id: StringName) -> WoodsRegionDef:
	return load("res://data/regions/spring_court/%s_biomes.tres" % id)


func test_every_region_offers_25_plus_gatherable_types() -> void:
	for id in REGIONS:
		var ids := {}
		for b in _def(id).biomes:
			for k in b.forage:
				ids[k] = true
		assert_gte(ids.size(), 25, "%s gatherable types" % id)


func test_every_biome_the_provider_returns_has_data() -> void:
	for id in REGIONS:
		var def := _def(id)
		var known := def.biome_map()
		var seen := {}
		var b: Rect2 = def.provider.BOUNDS
		for x in range(int(b.position.x) + 5, int(b.end.x), 25):
			for z in range(int(b.position.y) + 5, int(b.end.y), 25):
				seen[def.provider.biome_at(float(x), float(z))] = true
		for biome in seen:
			assert_true(known.has(biome), "%s: biome %s has a WoodsBiome" % [id, biome])
		assert_gte(seen.size(), 4 if id == &"suriel_glade" else 8, "%s biome variety" % id)


func test_every_species_and_forage_visual_builds_a_mesh() -> void:
	for species in FloraLibrary.SPECIES:
		var m := FloraLibrary.mesh(species)
		assert_true(m != null and m.get_surface_count() == 1, "mesh for %s" % species)
	for id in REGIONS:
		var def := _def(id)
		for b in def.biomes:
			for k in b.forage:
				assert_true(FloraLibrary.has(def.forage_visuals.get(k, &"")), "%s visual for %s" % [id, k])
			for k in b.trees.keys() + b.shrubs.keys() + b.detail.keys():
				assert_true(FloraLibrary.has(k), "%s species %s" % [id, k])


func test_providers_are_finite_and_keep_the_thornwater_carved() -> void:
	for x in range(-700, 500, 97):
		for z in range(300, 1400, 89):
			assert_true(is_finite(BorderWoodsTerrain.height_at(x, z)))
	var on_river := MacroHeight.THORNWATER[7]  # (-350, 980), inside the Border Woods
	var bed := BorderWoodsTerrain.height_at(on_river.x, on_river.y)
	assert_lt(bed, MacroHeight.land_height_at(on_river.x, on_river.y) - 2.0, "river bed stays carved")
	assert_eq(BorderWoodsTerrain.biome_at(on_river.x, on_river.y), &"brook")


func test_dread_tips_from_pretty_to_horror() -> void:
	var T := EasternWoodsTerrain
	assert_almost_eq(T.dread_at(T.BOGGE_HEART.x, T.BOGGE_HEART.y), 1.0, 0.001)
	assert_almost_eq(T.dread_at(T.STREAM_GLEN.x, T.STREAM_GLEN.y), 0.0, 0.001)
	# The transition band is readable: dread ramps over ~140 m, not a wall.
	var mid := T.dread_at(T.BOGGE_HEART.x - T.BOGGE_HEART.z - T.DREAD_BAND * 0.5, T.BOGGE_HEART.y)
	assert_between(mid, 0.2, 0.8)
	assert_eq(T.biome_at(T.BOGGE_HEART.x, T.BOGGE_HEART.y), &"bogge_territory")
	assert_eq(SurielGladeTerrain.biome_at(SurielGladeTerrain.SNARE_SITE.x, SurielGladeTerrain.SNARE_SITE.y), &"snare_glade")


func test_providers_are_registered_with_world_height() -> void:
	var ids := []
	for p in WorldHeight.providers():
		ids.append(p.id)
	for id in REGIONS:
		assert_has(ids, id)
