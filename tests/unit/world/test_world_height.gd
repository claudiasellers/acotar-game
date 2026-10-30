extends GutTest

const FLAT := preload("res://tests/unit/world/fixtures/flat_100_provider.gd")


func _provider(bounds: Rect2, priority: int = 0) -> HeightProvider:
	var p := HeightProvider.new()
	p.id = &"test"
	p.bounds = bounds
	p.fade = 64.0
	p.height_script = FLAT
	p.priority = priority
	return p


func after_each() -> void:
	WorldHeight.set_providers(null)


func test_macro_is_deterministic_and_bounded() -> void:
	var a := MacroHeight.height_at(123.0, -456.0)
	assert_eq(MacroHeight.height_at(123.0, -456.0), a)
	for p in [Vector2(0, 0), Vector2(-1900, 0), Vector2(1500, 2400), Vector2(-1700, -1900)]:
		var h := MacroHeight.height_at(p.x, p.y)
		assert_between(h, -40.0, 220.0, "macro height at %s" % p)


func test_river_is_carved_below_its_banks() -> void:
	var on := MacroHeight.THORNWATER[6]
	var bank := on + Vector2(0, 60)
	assert_lt(MacroHeight.height_at(on.x, on.y), MacroHeight.land_height_at(on.x, on.y) - 2.0)
	assert_almost_eq(MacroHeight.height_at(bank.x, bank.y), MacroHeight.land_height_at(bank.x, bank.y), 0.001)


func test_provider_wins_inside_and_fades_to_macro_at_edge() -> void:
	WorldHeight.set_providers([_provider(Rect2(0, 0, 400, 400))])
	assert_almost_eq(WorldHeight.height_at(200, 200), 100.0, 0.001)
	assert_almost_eq(WorldHeight.height_at(-1, 200), MacroHeight.height_at(-1, 200), 0.001)
	var mid := WorldHeight.height_at(32, 200)
	var macro := MacroHeight.height_at(32, 200)
	assert_between(mid, minf(macro, 100.0), maxf(macro, 100.0))


func test_provider_texture_rule_is_used_inside() -> void:
	WorldHeight.set_providers([_provider(Rect2(0, 0, 400, 400))])
	assert_eq(WorldHeight.texture_at(200, 200), Vector3i(WorldHeight.Tex.PATH, WorldHeight.Tex.SNOW, 7))


func test_default_texture_is_snow_south_of_wall_and_grass_north() -> void:
	WorldHeight.set_providers([])
	assert_eq(WorldHeight.texture_at(300, WorldMap.WALL_Z + 300).x, WorldHeight.Tex.SNOW)
	assert_eq(WorldHeight.texture_at(300, -200).x, WorldHeight.Tex.SPRING_GRASS)


func test_registry_file_loads() -> void:
	WorldHeight.set_providers(null)
	assert_not_null(WorldHeight.providers())
