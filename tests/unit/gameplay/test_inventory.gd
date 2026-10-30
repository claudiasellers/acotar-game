extends GutTest

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new()


func test_routes_by_kind_and_weight() -> void:
	inv.add(&"arrow_wood", 3)
	inv.add(&"col_odd_stone")
	inv.add(&"ing_snowdrop", 2)
	inv.add(&"ing_venison")
	assert_eq(inv.container_of(&"arrow_wood"), Inventory.QUIVER)
	assert_eq(inv.container_of(&"col_odd_stone"), Inventory.KEEPSAKES)
	assert_eq(inv.container_of(&"ing_snowdrop"), Inventory.POUCH)
	assert_eq(inv.container_of(&"ing_venison"), Inventory.SATCHEL)
	assert_eq(inv.arrow_count(), 3)


func test_pouch_overflows_into_satchel_then_refuses() -> void:
	# Pouch holds 12 units of SMALL (1 unit) items; satchel 40.
	var added := inv.add(&"ing_pine_resin", 60)
	assert_eq(added, 52)
	assert_eq(int(inv.contents(Inventory.POUCH).get(&"ing_pine_resin", 0)), 12)
	assert_eq(int(inv.contents(Inventory.SATCHEL).get(&"ing_pine_resin", 0)), 40)


func test_quiver_capacity() -> void:
	assert_eq(inv.add(&"arrow_wood", 40), 30)


func test_encumbrance_slows() -> void:
	assert_eq(inv.speed_multiplier(), 1.0)
	inv.add(&"ing_hide", 5)  # 5 x LARGE (8) = 40 units
	assert_lt(inv.speed_multiplier(), 1.0)
	assert_gte(inv.speed_multiplier(), Inventory.MIN_SPEED_MULTIPLIER)


func test_sell_and_buy() -> void:
	inv.add(&"ing_wolf_pelt")
	var earned := inv.sell(&"ing_wolf_pelt")
	assert_eq(earned, 8)
	assert_eq(inv.coin, 8)
	assert_true(inv.buy(&"mat_arrowhead", 2))
	assert_eq(inv.coin, 6)
	assert_false(inv.buy(&"mat_arrowhead", 100))


func test_aliases_land_on_lore_ids() -> void:
	inv.add(&"deer_venison")
	assert_eq(inv.count(&"ing_venison"), 1)


func test_save_round_trip() -> void:
	inv.add(&"ing_snowdrop", 2)
	inv.add(&"arrow_ash")
	inv.coin = 5
	inv.add_dish({"name": "Venison stew", "food_days": 2.0})
	var copy := Inventory.new()
	copy.load_state(JSON.parse_string(JSON.stringify(inv.save_state())))
	assert_eq(copy.count(&"ing_snowdrop"), 2)
	assert_eq(copy.arrow_count(&"arrow_ash"), 1)
	assert_eq(copy.coin, 5)
	assert_eq(copy.dishes.size(), 1)
