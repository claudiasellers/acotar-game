extends GutTest

const STATIONS := ["hearth", "campfire", "manor_kitchen", "stillroom", "fae_potion_room", "starlight_pool", "rite_cave_fire"]


func before_each() -> void:
	Gameplay.reset()
	WorldState.clear()
	Clock.paused = true


func after_each() -> void:
	Clock.paused = false


func _station(id: String) -> CookingStation:
	var s := CookingStation.new()
	s.station = load("res://data/stations/%s.tres" % id)
	add_child_autofree(s)
	return s


func test_every_station_cooks_its_methods_and_refuses_others() -> void:
	Clock.from_dict({"time_of_day": 0.95, "day": 1})
	WorldState.set_flag("calanmai_attended", true)
	for id in STATIONS:
		var s := _station(id)
		for method in s.station.methods:
			Gameplay.inventory.add(&"ing_venison")
			Gameplay.inventory.add(&"ing_willow_bark")
			Gameplay.inventory.add(&"arrow_wood", 2)
			var ids: Array[StringName] = [&"ing_willow_bark"]
			if Chemistry.FOOD_METHODS.has(method) or method == &"stew":
				ids = [&"ing_venison"]
			var r := s.cook(ids, method)
			assert_true(r.ok, "%s should %s: %s" % [id, method, r.get("reason", "")])
		if not s.station.methods.has(&"distill"):
			Gameplay.inventory.add(&"ing_willow_bark")
			assert_false(s.cook([&"ing_willow_bark"] as Array[StringName], &"distill").ok, "%s can't distill" % id)


func test_starlight_pool_only_at_night() -> void:
	var pool := _station("starlight_pool")
	Clock.from_dict({"time_of_day": 0.5, "day": 1})
	assert_ne(pool.unavailable_reason(), "")
	Clock.from_dict({"time_of_day": 0.95, "day": 1})
	assert_eq(pool.unavailable_reason(), "")


func test_rite_fire_waits_for_calanmai() -> void:
	var fire := _station("rite_cave_fire")
	assert_ne(fire.unavailable_reason(), "")
	WorldState.set_flag("calanmai_attended", true)
	assert_eq(fire.unavailable_reason(), "")


func test_each_steep_makes_its_arrow() -> void:
	var still := _station("stillroom")
	var cases := {
		&"arrow_sleep": [&"ing_hollow_root", &"ing_lavender"],
		&"arrow_fire": [&"ing_pine_resin", &"ing_madder"],
		&"arrow_frost": [&"ing_willow_bark", &"ing_ice_moss", &"ing_snowdrop"],
		&"arrow_light": [&"ing_moss", &"ing_clay", &"ing_glowcap"],
		&"arrow_lure": [&"ing_honey", &"ing_wild_strawberry"],
	}
	for arrow: StringName in cases:
		Gameplay.inventory.add(&"arrow_wood", 5)
		var ids: Array[StringName] = []
		for id: StringName in cases[arrow]:
			ids.append(id)
			Gameplay.inventory.add(id)
		var r := still.cook(ids, &"steep")
		assert_true(r.ok, "%s: %s" % [arrow, r.get("reason", "")])
		assert_eq(Gameplay.inventory.arrow_count(arrow), 5, String(arrow))


func test_steep_needs_wood_arrows_and_bind() -> void:
	var still := _station("stillroom")
	Gameplay.inventory.add(&"ing_lavender")
	assert_false(still.cook([&"ing_lavender"] as Array[StringName], &"steep").ok, "no bind")
	Gameplay.inventory.add(&"ing_hollow_root")
	assert_false(still.cook([&"ing_hollow_root"] as Array[StringName], &"steep").ok, "no arrows")
	assert_eq(Gameplay.inventory.count(&"ing_hollow_root"), 1, "nothing consumed")


func test_ash_never_goes_in_the_pot() -> void:
	var still := _station("stillroom")
	Gameplay.inventory.add(&"ing_ash_wood")
	Gameplay.inventory.add(&"ing_honey")
	Gameplay.inventory.add(&"arrow_wood", 3)
	assert_false(still.cook([&"ing_ash_wood", &"ing_honey"] as Array[StringName], &"steep").ok)


func test_ten_arrow_types_and_new_recipes() -> void:
	assert_eq(BowController.arrow_types().size(), 10)
	assert_eq(BowController.arrow_types()[0], &"arrow_wood")
	var inv := Gameplay.inventory
	inv.add(&"ing_shed_antler")
	inv.add(&"mat_shaft")
	inv.add(&"ing_hawk_feather")
	assert_eq(Crafting.craft(Crafting.recipe(&"barbed_heads"), inv), 2)
	assert_eq(Crafting.craft(Crafting.recipe(&"arrow_barbed"), inv), 1)
	inv.add(&"arrow_wood", 2)
	inv.add(&"ing_sinew", 2)
	assert_eq(Crafting.craft(Crafting.recipe(&"arrow_rope"), inv), 1)
	inv.add(&"ing_pine_resin")
	inv.add(&"ing_charcoal")
	assert_eq(Crafting.craft(Crafting.recipe(&"arrow_signal"), inv), 1)


func test_bows_each_trade_something() -> void:
	var hunting := load("res://data/bows/hunting_bow.tres") as BowData
	for id in ["yew_longbow", "fae_recurve", "sentry_warbow", "gilded_bow"]:
		var b := load("res://data/bows/%s.tres" % id) as BowData
		var better := b.max_speed > hunting.max_speed or b.draw_time < hunting.draw_time or b.sway_degrees < hunting.sway_degrees
		assert_true(better, "%s improves on something" % id)
		assert_true(ItemCatalog.has(StringName("bow_" + id)))
	var war := load("res://data/bows/sentry_warbow.tres") as BowData
	assert_gt(war.draw_time, hunting.draw_time, "the warbow's power costs draw time")
	var fae := load("res://data/bows/fae_recurve.tres") as BowData
	assert_lt(fae.loudness, hunting.loudness)


func test_element_effects_on_targets() -> void:
	var target := StaticBody3D.new()
	var e := ElementState.new()
	e.name = "ElementState"
	target.add_child(e)
	add_child_autofree(target)
	assert_eq(ArrowEffects.element_state_of(target), e)
	for effect in [&"fire", &"frost"]:
		var data := (load("res://data/arrows/%s.tres" % effect) as ArrowData)
		var arrow := Arrow.create(data)
		add_child_autofree(arrow)
		ArrowEffects.apply(arrow, target, Vector3.ZERO)
		assert_eq(arrow.get_meta(&"arrow_effect"), effect)
	assert_gt(e.cold, 0.5, "frost chilled it")
	assert_gt(get_tree().get_nodes_in_group(ArrowEffects.LIGHT_GROUP).size(), 0)
