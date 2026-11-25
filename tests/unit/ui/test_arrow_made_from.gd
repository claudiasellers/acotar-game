# gate: when:ui/satchel/satchel_menu.gd,data/recipes/*,systems/crafting/*
## An arrow's page in the satchel says what it is made from, so the "make an
## arrow" key has somewhere to point.
extends GutTest


func test_an_arrow_says_what_it_is_made_from() -> void:
	assert_eq(SatchelMenu.made_from(&"arrow_wood"), "Made from 1 arrow shaft, 1 fletching, 1 arrowhead.")
	assert_eq(SatchelMenu.made_from(&"ing_rose_red"), "", "only arrows")
	assert_eq(SatchelMenu.made_from(&"arrow_nobody_makes"), "")
	for recipe in Crafting.all_recipes():
		if String(recipe.id).begins_with("arrow_"):
			var said := SatchelMenu.made_from(recipe.id)
			assert_true(said.begins_with("Made from ") and not said.contains("mat_") and not said.contains("ing_"), "%s names its parts in words: %s" % [recipe.id, said])
