extends GutTest

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new()


func test_wood_arrow_from_shaft_fletching_head() -> void:
	inv.add(&"ing_hazel_rod")
	inv.add(&"ing_flint")
	inv.add(&"ing_crow_feather", 2)
	assert_eq(Crafting.craft(Crafting.recipe(&"carve_shaft"), inv), 2)
	assert_eq(Crafting.craft(Crafting.recipe(&"knap_arrowhead"), inv), 2)
	assert_eq(Crafting.craft(Crafting.recipe(&"arrow_wood"), inv), 1)
	assert_eq(inv.arrow_count(&"arrow_wood"), 1)
	assert_eq(inv.count(&"mat_shaft"), 1)
	assert_eq(inv.count(&"ing_crow_feather"), 1)


func test_ash_arrow_cannot_be_crafted() -> void:
	# Keeper (book-verified): the ash arrow is a rare bought item, not craftable.
	assert_null(Crafting.recipe(&"arrow_ash"))
	assert_true(ItemCatalog.has(&"arrow_ash"))


func test_missing_input_fails_and_consumes_nothing() -> void:
	inv.add(&"mat_shaft")
	inv.add(&"ing_hawk_feather")
	assert_eq(Crafting.craft(Crafting.recipe(&"arrow_wood"), inv), 0)
	assert_eq(inv.count(&"mat_shaft"), 1)
	assert_eq(inv.count(&"ing_hawk_feather"), 1)


## Ash is lethal to fae by the creature's lethal_arrow_ids, not by the arrow;
## the arrow only hits harder and breaks less (health-interactions §2.2).
func test_ash_arrow_hits_harder_and_breaks_less() -> void:
	var ash := load("res://data/arrows/ash.tres") as ArrowData
	var wood := load("res://data/arrows/wood.tres") as ArrowData
	assert_gt(ash.damage, wood.damage)
	assert_lt(ash.stone_break_chance, wood.stone_break_chance)
