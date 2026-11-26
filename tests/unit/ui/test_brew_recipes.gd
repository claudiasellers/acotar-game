# gate: when:ui/chemistry/*,systems/chemistry/*,data/chemistry/*,data/stations/*,ui/menu/open_tin.gd
## The brewing page lists the recipes she knows beside her bags (owner,
## 2026-11-25): picking one lays its makings in the pot and sets how to work
## it, one she lacks something for says what, one worked elsewhere says
## where, and a brew she has not found is never listed.
extends GutTest

var menu: BrewMenu
var bench: CookingStation


func before_each() -> void:
	Gameplay.reset()
	bench = CookingStation.new()
	bench.station = load("res://data/stations/stillroom.tres")
	add_child_autofree(bench)
	menu = BrewMenu.new()
	add_child_autofree(menu)


func after_each() -> void:
	menu.close()


func _row(id: StringName) -> Button:
	return menu._recipes.get_node_or_null(String(id)) as Button


func test_nothing_is_listed_until_she_knows_it() -> void:
	Gameplay.inventory.add(&"ing_honey", 1)
	menu.open(null, bench)
	assert_eq(menu.known_recipes().size(), 0)
	assert_null(_row(&"brew_healing_salve"), "discovery stays hers")
	assert_false(menu.pick(&"brew_healing_salve"))
	assert_true(menu._recipes.get_child(0) is Label, "the page says why it is empty")


func test_picking_a_recipe_lays_its_makings_and_brews_it() -> void:
	Gameplay.inventory.add(&"ing_willow_bark", 1)
	Gameplay.inventory.add(&"ing_honey", 1)
	Gameplay.collection.mark(&"brew_healing_salve", &"recipes", false)
	menu.open(null, bench)
	await wait_process_frames(2)
	var row := _row(&"brew_healing_salve")
	assert_not_null(row)
	assert_false(row.disabled)
	assert_eq(menu.recipe_line(RecipeUnlocks.get_recipe(&"brew_healing_salve")), "willow bark, honey")
	row.pressed.emit()
	assert_eq(menu.chosen, [&"ing_willow_bark", &"ing_honey"] as Array[StringName])
	assert_eq(menu.method, &"salve")
	assert_eq(menu.laid(), &"brew_healing_salve")
	await wait_process_frames(2)
	assert_true(_row(&"brew_healing_salve").button_pressed, "the laid recipe is the one marked")
	var r := menu.brew()
	assert_true(r.ok)
	assert_eq(r.brew, &"brew_healing_salve")


func test_picking_the_laid_recipe_again_empties_the_pot() -> void:
	Gameplay.inventory.add(&"ing_willow_bark", 1)
	Gameplay.inventory.add(&"ing_honey", 1)
	Gameplay.collection.mark(&"brew_healing_salve", &"recipes", false)
	menu.open(null, bench)
	assert_true(menu.pick(&"brew_healing_salve"))
	assert_true(menu.pick(&"brew_healing_salve"))
	assert_eq(menu.chosen.size(), 0)


func test_a_recipe_she_lacks_something_for_says_what() -> void:
	Gameplay.inventory.add(&"ing_willow_bark", 1)
	Gameplay.collection.mark(&"brew_healing_salve", &"recipes", false)
	menu.open(null, bench)
	await wait_process_frames(2)
	assert_true(_row(&"brew_healing_salve").disabled)
	assert_eq(menu.recipe_line(RecipeUnlocks.get_recipe(&"brew_healing_salve")), "Missing honey")
	assert_false(menu.pick(&"brew_healing_salve"))
	assert_eq(menu.chosen.size(), 0)


func test_a_recipe_worked_elsewhere_says_where_and_comes_last() -> void:
	for id in [&"ing_willow_bark", &"ing_honey", &"ing_venison", &"ing_hazelnut"]:
		Gameplay.inventory.add(id, 1)
	Gameplay.collection.mark(&"brew_hearty_stew", &"recipes", false)
	Gameplay.collection.mark(&"brew_healing_salve", &"recipes", false)
	menu.open(null, bench)
	await wait_process_frames(2)
	var stew := RecipeUnlocks.get_recipe(&"brew_hearty_stew")
	assert_false(menu.made_here(stew), "the stillroom has no stew pot")
	assert_eq(menu.recipe_line(stew), "Over a hearth")
	assert_true(_row(&"brew_hearty_stew").disabled)
	var order := menu.known_recipes().map(func(r: Dictionary) -> StringName: return r.id)
	assert_eq(order[0], &"brew_healing_salve", "what she can make here and now comes first")
	assert_gt(order.find(&"brew_hearty_stew"), order.find(&"brew_healing_salve"))
	await wait_process_frames(2)
	assert_eq(menu._grid.get_child_count(), 4, "venison has no picture of its own and still gets a tile")


func test_a_brew_she_made_is_a_recipe_she_knows() -> void:
	Gameplay.inventory.add(&"ing_willow_bark", 2)
	Gameplay.inventory.add(&"ing_honey", 2)
	menu.open(null, bench)
	menu.toggle(&"ing_willow_bark")
	menu.toggle(&"ing_honey")
	menu.set_method(&"salve")
	assert_true(menu.brew().ok)
	await wait_process_frames(2)
	assert_not_null(_row(&"brew_healing_salve"))
	assert_false(_row(&"brew_healing_salve").disabled, "and she has the makings for another")
