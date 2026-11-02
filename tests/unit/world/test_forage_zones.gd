## Spring Court forage keyed to L09's landscape zones (ForageZones): shade
## finds under the grove core, hedgerow finds on the wood's edge, meadow finds
## in the open, in both the woods regions and the wider court, with every
## kind still placed and the R1 density bar (>= 25 types, >= 300 per km²) held.
extends GutTest

const ForageZones := preload("res://world/spring_court/shared/forage_zones.gd")
const LandscapeLayout := preload("res://world/spring_court/shared/landscape_layout.gd")


func test_kinds_sort_into_shade_hedge_and_meadow() -> void:
	for id: StringName in [&"ing_moss", &"ing_glowcap", &"ing_wild_garlic", &"ing_oak_gall", &"col_acorn_caps"]:
		assert_eq(ForageZones.affinity(id), ForageZones.SHADE, String(id))
	for id: StringName in [&"ing_blackberry", &"ing_rose_hip", &"ing_hazelnut", &"ing_honeysuckle", &"ing_primrose"]:
		assert_eq(ForageZones.affinity(id), ForageZones.HEDGE, String(id))
	for id: StringName in [&"ing_clover", &"ing_cowslip", &"ing_wild_thyme", &"ing_red_poppy", &"col_dandelion_clock"]:
		assert_eq(ForageZones.affinity(id), ForageZones.MEADOW, String(id))
	for id: StringName in [&"ing_river_silt", &"col_odd_stone", &"ing_water_lily", &"col_coin_old"]:
		assert_eq(ForageZones.affinity(id), ForageZones.NEUTRAL, String(id))


func test_zone_shares_sum_to_one_and_neutral_fits_everywhere() -> void:
	var layout := LandscapeLayout.make(7, Rect2(0, 0, 400, 400))
	for i in 50:
		var p := Vector2(i * 7.9, i * 6.3)
		var s := ForageZones.shares(layout, p, 0.45)
		assert_almost_eq(s.x + s.y + s.z, 1.0, 0.001)
		assert_almost_eq(ForageZones.fit(&"col_odd_stone", s), 1.0, 0.001)


## Share of a group's placements in (open, edge, core).
func _mean_shares(points: Array, shares_at: Callable) -> Vector3:
	var sum := Vector3.ZERO
	for p: Vector2 in points:
		sum += shares_at.call(p)
	return sum / maxf(points.size(), 1)


func test_wider_court_forage_follows_the_zones() -> void:
	var content := load("res://data/regions/spring_court/content/western_fells.tres") as CourtRegionContent
	var forage := CourtScatterGenerator.forage_layers(content)
	var zones := CourtScatterGenerator.forage_zone_map(content)
	var groups := {ForageZones.SHADE: [], ForageZones.HEDGE: [], ForageZones.NEUTRAL: []}
	var total := 0
	for layer in forage:
		total += layer.count()
		var a := ForageZones.affinity(layer.ingredient_id)
		if groups.has(a):
			for i in layer.count():
				var p := layer.position_of(i)
				(groups[a] as Array).append(Vector2(p.x, p.z))
	var at := func(p: Vector2) -> Vector3: return CourtScatterGenerator.zone_shares(content, zones, p)
	var shade := _mean_shares(groups[ForageZones.SHADE], at)
	var hedge := _mean_shares(groups[ForageZones.HEDGE], at)
	var neutral := _mean_shares(groups[ForageZones.NEUTRAL], at)
	assert_gt(shade.y + shade.z, (neutral.y + neutral.z) * 2.0, "shade finds sit in the woods, not the open")
	assert_gt(hedge.y, neutral.y * 2.0, "hedgerow finds gather on the wood's edge")
	assert_gte(forage.size(), 25, "R1 types")
	assert_gte(total / (content.area_m2() / 1_000_000.0), 300.0, "R1 placements per km²")


func test_woods_drifts_settle_into_their_zone_and_keep_every_kind() -> void:
	var def := load("res://data/regions/spring_court/eastern_woods_biomes.tres") as WoodsRegionDef
	var forage := WoodsScatter.place(def, def.provider.BOUNDS, "forage")
	var layout := LandscapeLayout.make(def.seed, def.provider.BOUNDS)
	var biomes := def.biome_map()
	var shade := []
	var hedge := []
	var neutral := []
	for id: StringName in forage:
		var inst: PackedFloat32Array = forage[id]
		var a := ForageZones.affinity(id)
		var into: Array = shade if a == ForageZones.SHADE else (hedge if a == ForageZones.HEDGE else (neutral if a == ForageZones.NEUTRAL else []))
		for o in range(0, inst.size(), ScatterLayer.STRIDE):
			into.append(Vector2(inst[o], inst[o + 2]))
	var at := func(p: Vector2) -> Vector3:
		var b: WoodsBiome = biomes.get(def.provider.biome_at(p.x, p.y))
		return ForageZones.shares(layout, p, WoodsScatter._open(b)) if b else Vector3(1, 0, 0)
	var h := _mean_shares(hedge, at)
	var n := _mean_shares(neutral, at)
	assert_gt(h.y, n.y * 1.8, "hedgerow drifts gather on the wood's edge")
	assert_gt(_mean_shares(shade, at).z, 0.5, "shade drifts sit mostly under the grove core")
	assert_gte(forage.size(), 38, "every kind the eastern woods grew before is still placed")
