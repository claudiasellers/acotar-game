extends GutTest
## Lane L32: the woods' leaf-litter paint follows the trees. Out in a woods
## meadow the ground reads grass; under the groves it reads forest floor.

const GroundComposition := preload("res://world/spring_court/shared/ground_composition.gd")


func _shares(region: String, biomes: Array, provider: Variant) -> Dictionary:
	var def := load("res://data/regions/spring_court/%s_biomes.tres" % region) as WoodsRegionDef
	var rect: Rect2 = def.provider.BOUNDS
	var trees: Array = []
	var pts := WoodsScatter.place(def, rect, "tree")
	for id: StringName in pts:
		var l := ScatterLayer.new()
		l.instances = pts[id]
		trees.append(l)
	var field := GroundComposition.canopy(rect, trees)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var open := [0, 0]  # [samples, floor-dominant]
	var under := [0, 0]
	for i in 20000:
		var p := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		if not (provider.biome_at(p.x, p.y) in biomes):
			continue
		var tex: Vector3i = provider.texture_at(p.x, p.y)
		if tex.x != WorldHeight.Tex.FOREST_FLOOR:
			continue  # paths and water keep their own paint
		var d := GroundComposition.distance(field, p.x, p.y)
		var floor_dominant := 1 if tex.z < 128 else 0
		if d > 20.0:
			open[0] += 1
			open[1] += floor_dominant
		elif d < 4.0:
			under[0] += 1
			under[1] += floor_dominant
	return {"open": float(open[1]) / maxf(open[0], 1.0), "under": float(under[1]) / maxf(under[0], 1.0),
			"n": [open[0], under[0]]}


func test_border_woods_meadows_read_grass_and_groves_read_floor() -> void:
	var s := _shares("border_woods", [&"spring_woodland"], BorderWoodsTerrain)
	gut.p("border_woods spring_woodland: %s" % s)
	assert_gt(s["n"][0], 100, "enough open samples")
	assert_lt(s["open"], 0.25, "the meadows between groves are grass, not bare dirt")
	assert_gt(s["under"], 0.6, "under the groves the leaf litter stays")


func test_eastern_woods_gaps_read_moss() -> void:
	var s := _shares("eastern_woods", [&"deep_wood", &"beech_hall", &"fern_hollow"], EasternWoodsTerrain)
	gut.p("eastern_woods: %s" % s)
	if s["n"][0] > 50:
		assert_lt(s["open"], 0.25, "gaps in the eastern woods are moss, not bare dirt")
	assert_gt(s["under"], 0.6, "under the groves the leaf litter stays")
