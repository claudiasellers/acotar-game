# gate: when:ui/satchel/satchel_menu.gd,data/recipes/*,systems/crafting/*
## An arrow's page in the satchel says what it is made from, so the "make an
## arrow" key has somewhere to point.
extends GutTest


func test_an_arrow_says_what_it_is_made_from() -> void:
	# The plain arrow names each of its recipe's parts, as the data has them.
	var said := SatchelMenu.made_from(&"arrow_wood")
	var recipe := Crafting.recipe(&"arrow_wood")
	assert_not_null(recipe, "the plain arrow has a recipe")
	for key: String in recipe.inputs:
		var part := ItemCatalog.get_item(StringName(key))
		var word := key.trim_prefix("tag:") if key.begins_with("tag:") else (part.display_name.to_lower() if part else key)
		assert_string_contains(said, "%d %s" % [int(recipe.inputs[key]), word], "names %s" % key)
	assert_eq(SatchelMenu.made_from(&"ing_rose_red"), "", "only arrows")
	assert_eq(SatchelMenu.made_from(&"arrow_nobody_makes"), "")
	for recipe in Crafting.all_recipes():
		if String(recipe.id).begins_with("arrow_"):
			var said := SatchelMenu.made_from(recipe.id)
			assert_true(said.begins_with("Made from ") and not said.contains("mat_") and not said.contains("ing_"), "%s names its parts in words: %s" % [recipe.id, said])
