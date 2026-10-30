extends GutTest


func test_cold_rises_in_frost_and_falls_by_the_fire() -> void:
	var e := ElementState.new()
	autofree(e)
	for i in 600:
		e.step(0.1, -8.0, 0.0, &"snow", 0.0)
	assert_gt(e.cold, 0.5)
	for i in 300:
		e.step(0.1, -8.0, 0.0, &"snow", 1.0)
	assert_lt(e.cold, 0.05)


func test_insulation_lowers_cold() -> void:
	var bare := ElementState.new()
	var cloaked := ElementState.new()
	autofree(bare)
	autofree(cloaked)
	cloaked.insulation = 0.7
	for i in 1000:
		bare.step(0.1, -8.0, 0.0, &"snow", 0.0)
		cloaked.step(0.1, -8.0, 0.0, &"snow", 0.0)
	assert_lt(cloaked.cold, bare.cold * 0.5)


func test_rain_wets_heat_dries_wet_smothers_fire() -> void:
	var e := ElementState.new()
	autofree(e)
	for i in 600:
		e.step(0.1, 5.0, 1.0, &"rain", 0.0)
	assert_true(e.is_wet())
	e.ignite()
	assert_eq(e.fire, 0.0, "too wet to burn")
	for i in 600:
		e.step(0.1, 5.0, 0.0, &"rain", 1.0)
	assert_false(e.is_wet())
	e.ignite(0.8)
	assert_gt(e.fire, 0.5)
	e.soak()
	assert_lt(e.fire, 0.01)


func test_weather_wind_is_horizontal_and_deterministic() -> void:
	var w := Weather.new()
	autofree(w)
	var a := w.wind_at_time(Vector3(10, 0, 5), 3.0)
	assert_eq(a.y, 0.0)
	assert_true(a.is_equal_approx(w.wind_at_time(Vector3(10, 0, 5), 3.0)))
	assert_between(a.length(), w.wind_speed, w.wind_speed + w.gust_strength + 0.01)


func test_hunger_and_cold_widen_sway_food_and_steady_help() -> void:
	var b := BodyState.new()
	autofree(b)
	b.hunger = 0.0
	var fed := b.sway_multiplier()
	b.hunger = 0.8
	b.cold = 0.6
	var cold_hungry := b.sway_multiplier()
	assert_gt(cold_hungry, fed * 1.8)
	assert_gt(b.tremor_degrees(), 0.3)
	b.eat({"hunger_relief": 0.5, "effects": {&"steady": 2.0}, "duration": 60.0})
	assert_almost_eq(b.hunger, 0.3, 0.001)
	assert_lt(b.sway_multiplier(), cold_hungry)
	b.step(61.0)
	assert_eq(b.effect(&"steady"), 0.0, "effects wear off")


func test_food_tally() -> void:
	var t := FoodTally.new()
	var seen := []
	t.stock_changed.connect(func(d: float) -> void: seen.append(d))
	var inv := Inventory.new()
	inv.add(&"ing_venison", 2)
	assert_almost_eq(t.give_item(&"ing_venison", inv, 2), 3.0, 0.001)
	assert_almost_eq(t.days_of_food, 4.5, 0.001)
	t.consume_day()
	assert_almost_eq(t.days_of_food, 3.5, 0.001)
	assert_eq(seen.size(), 2)
	assert_eq(t.give_item(&"ing_snowdrop", inv), 0.0)
