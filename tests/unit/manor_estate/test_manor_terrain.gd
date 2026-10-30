## The estate's height provider: pads are flat, edges meet the macro height.
extends GutTest


func test_house_pad_is_flat_at_the_estate_base() -> void:
	var base := ManorSitePlan.base_y()
	for p in [Vector2(0, 0), Vector2(0, -26), Vector2(-80, -50), Vector2(80, -50), Vector2(0, -80)]:
		assert_almost_eq(WorldHeight.height_at(p.x, p.y), base, 0.05, "pad at %s" % p)


func test_rose_garden_sits_one_flight_below_the_terrace() -> void:
	var c := ManorSitePlan.ROSE_GARDEN.get_center()
	assert_almost_eq(WorldHeight.height_at(c.x, c.y), ManorSitePlan.base_y() - 1.8, 0.05)


func test_edges_meet_the_macro_height() -> void:
	for p in [Vector2(-599, -100), Vector2(599, 0), Vector2(0, -499), Vector2(200, 299)]:
		assert_almost_eq(WorldHeight.height_at(p.x, p.y), MacroHeight.height_at(p.x, p.y), 0.25)


func test_pond_is_a_basin() -> void:
	var c := ManorSitePlan.POND_CENTER
	assert_lt(WorldHeight.height_at(c.x, c.y), ManorTerrain.pond_level() - 1.5)


func test_no_cliffs_on_the_walkable_estate() -> void:
	var worst := 0.0
	for xi in range(-560, 561, 20):
		for zi in range(-460, 281, 20):
			worst = maxf(worst, rad_to_deg(acos(WorldHeight.normal_at(xi, zi, 1.0).y)))
	assert_lt(worst, 40.0, "steepest slope %.1f deg" % worst)


func test_cellar_pit_sits_below_the_cellar_floor() -> void:
	var cellar_floor := ManorHouseBuilder.floor_y(-1)
	for p in [Vector2(0, -50), Vector2(58, -50), Vector2(-58, -50), Vector2(-38, -32)]:
		assert_lt(WorldHeight.height_at(p.x, p.y), cellar_floor - 0.3, "pit at %s" % p)
