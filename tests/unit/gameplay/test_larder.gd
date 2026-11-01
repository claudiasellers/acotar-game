extends GutTest
## The manor kitchen's dead chicken: canon Suriel bait, one a day.


func after_each() -> void:
	Clock.day = 1


func test_chicken_is_a_canon_manor_meat() -> void:
	var item := ItemCatalog.get_item(&"ing_dead_chicken") as IngredientData
	assert_not_null(item)
	assert_eq(item.icon, &"meat")
	assert_true(item.tags.has(&"vital"))
	assert_almost_eq(SnarePlan.bait_score(&"ing_dead_chicken"), 0.85, 0.001, "the book's bait")


func test_larder_gives_one_a_day() -> void:
	Clock.day = 3
	var l: LarderPickup = autofree(LarderPickup.new())
	add_child(l)
	assert_true(l.is_in_group(&"forage"))
	assert_eq(l.harvest(), &"ing_dead_chicken")
	assert_eq(l.harvest(), &"", "only one today")
	assert_false(l.visible)
	Clock.day = 4
	assert_eq(l.harvest(), &"ing_dead_chicken", "restocked next morning")


func test_kitchen_has_the_larder() -> void:
	var layout: ManorHouseLayout = load("res://data/regions/spring_court/manor_estate/house/service.tres")
	var found := layout.secrets.filter(func(s: ManorSecretDef) -> bool: return s.kind == &"larder" and s.item_id == &"ing_dead_chicken")
	assert_eq(found.size(), 1)
