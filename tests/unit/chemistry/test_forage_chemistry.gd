## Contract: forage chemistry (lane L62). Named brews come from what forage
## does, not fixed recipes; every world station that should brew does; a new
## brew is discovered once; steeped arrows reach L59's ElementField; a drunk
## brew is felt.
extends GutTest


func before_each() -> void:
	Gameplay.reset()
	WorldState.clear()
	Clock.paused = true


func after_each() -> void:
	Clock.paused = false
	var menu := BrewMenu.find(get_tree())
	if menu:
		menu.close()
		menu.free()


func _items(ids: Array) -> Array[IngredientData]:
	var out: Array[IngredientData] = []
	for id in ids:
		out.append(ItemCatalog.get_item(StringName(id)) as IngredientData)
	return out


func test_every_brew_is_made_by_its_witness_forage() -> void:
	var rules := BrewBook.rules()
	assert_gte(rules.size(), 24, "at least 24 brews to find")
	for r in rules:
		var station := load("res://data/stations/%s.tres" % r.witness_station) as StationData
		assert_not_null(station, "%s: station %s" % [r.id, r.witness_station])
		var items := _items(r.witness)
		assert_false(items.has(null), "%s: every witness is a real ingredient" % r.id)
		var usable := r.methods.filter(func(m: StringName) -> bool: return station.methods.has(m))
		assert_false(usable.is_empty(), "%s: %s can work it" % [r.id, r.witness_station])
		var result := Chemistry.combine(items, station, usable[0])
		assert_true(result.ok, "%s: %s" % [r.id, result.get("reason", "")])
		assert_eq(result.get("brew", &""), r.id, "%s witness makes %s" % [r.id, result.get("brew", &"")])
		assert_ne(r.note, "", "%s has Feyre's note" % r.id)


func test_brews_are_recognised_by_tags_not_recipes() -> void:
	# Two different quiet forageables both make a Hush steep.
	var still := load("res://data/stations/stillroom.tres") as StationData
	var a := Chemistry.combine(_items(["ing_hollow_root", "ing_lavender"]), still, &"steep")
	var b := Chemistry.combine(_items(["ing_hollow_root", "ing_wild_hyacinth"]), still, &"steep")
	assert_eq(a.brew, &"brew_hush_steep")
	assert_eq(b.brew, &"brew_hush_steep")
	# Every effect tag is the heart of at least one brew.
	var covered := {}
	for r in BrewBook.rules():
		for key: Variant in r.need:
			covered[StringName(key)] = true
	for tag in [&"warm", &"cool", &"bright", &"quiet", &"swift", &"strong", &"steady", &"keen", &"heal", &"harm", &"fae_toll"]:
		assert_true(covered.has(tag), "a brew needs %s" % tag)


func test_world_stations_brew() -> void:
	for id in [&"hearth", &"kitchen", &"bread_oven", &"stillroom"]:
		var manor := ManorStation.new()
		manor.station_id = id
		manor.display_name = "Test %s" % id
		add_child_autofree(manor)
		var bound := ChemistryStations.bind(manor, id)
		assert_not_null(bound, "%s brews" % id)
		assert_eq(bound.station.display_name, "Test %s" % id, "keeps the room's name")
		assert_false(bound.is_in_group(&"station"), "no second interactable")
		assert_eq(ChemistryStations.bind(manor, id), bound, "binds once")
	var cottage := Node3D.new()
	cottage.add_to_group(ChemistryStations.HEARTH_GROUP)
	add_child_autofree(cottage)
	assert_eq(ChemistryStations.bind(cottage).station.id, &"hearth", "the cottage hearth brews")
	var wardrobe := ManorStation.new()
	wardrobe.station_id = &"wardrobe"
	add_child_autofree(wardrobe)
	assert_null(ChemistryStations.bind(wardrobe, &"wardrobe"))


func test_first_brew_is_discovered_once_with_a_card() -> void:
	var feyre := Feyre.new()
	add_child_autofree(feyre)
	var hearth := CookingStation.new()
	hearth.station = load("res://data/stations/hearth.tres")
	add_child_autofree(hearth)
	Gameplay.inventory.add(&"ing_snowdrop", 2)
	var menu := BrewMenu.open_for(feyre, hearth)
	assert_not_null(menu)
	assert_true(menu.is_open())
	assert_true(menu.toggle(&"ing_snowdrop"))
	menu.set_method(&"infuse")
	assert_string_contains(menu.hunch(), "know")
	var first := menu.brew()
	assert_true(first.ok)
	assert_eq(first.brew, &"brew_steadying_tea")
	assert_true(first.new_brew, "first time: a discovery")
	assert_true(menu._reveal.visible, "the discovery card shows")
	assert_true(Gameplay.journal.has_brew(&"brew_steadying_tea"))
	menu.toggle(&"ing_snowdrop")
	assert_string_contains(menu.hunch(), "made this before", "she now knows it by name")
	var again := menu.brew()
	assert_false(again.new_brew, "second time: no new card")
	assert_false(menu._reveal.visible)
	var saved := Gameplay.journal.save_state()
	Gameplay.journal.brews.clear()
	Gameplay.journal.load_state(saved)
	assert_true(Gameplay.journal.has_brew(&"brew_steadying_tea"), "survives a save")
	menu.close()
	assert_false(get_tree().paused)


func test_steeped_arrows_reach_the_element_field() -> void:
	var field := ElementField.new()
	field.follow_world_wind = false
	add_child_autofree(field)
	field.set_physics_process(false)
	field.add_patch(Vector3.ZERO, 1.0, &"grass", 1.0)
	var fire := Arrow.create(load("res://data/arrows/fire.tres") as ArrowData)
	add_child_autofree(fire)
	ArrowEffects.apply(fire, null, Vector3.ZERO)
	assert_gt(field.burning_count(), 0, "a fire arrow lights dry grass")
	var frost := Arrow.create(load("res://data/arrows/frost.tres") as ArrowData)
	add_child_autofree(frost)
	ArrowEffects.apply(frost, null, Vector3.ZERO)
	assert_eq(field.burning_count(), 0, "a frost arrow puts it out")
	assert_eq(field.ignite_at(Vector3.ZERO, 0.5), 0, "and leaves it too wet to relight")
	var still := load("res://data/stations/stillroom.tres") as StationData
	var steep := Chemistry.combine(_items(["ing_pine_resin", "ing_madder"]), still, &"steep")
	assert_eq(steep.element, &"fire")
	assert_eq(CookingStation.steeped_arrow_for(steep), &"arrow_fire")


func test_drunk_brews_are_felt() -> void:
	var feyre := Feyre.new()
	add_child_autofree(feyre)
	assert_not_null(feyre.body_state)
	assert_eq(BrewEffects.scent_scale(feyre), 1.0)
	var tells := BrewTells.ensure(feyre)
	assert_eq(BrewTells.ensure(feyre), tells, "one set of tells")
	tells._process(0.1)
	assert_eq(tells.showing().size(), 0, "nothing shows without a brew")
	var still := load("res://data/stations/stillroom.tres") as StationData
	feyre.body_state.eat(Chemistry.combine(_items(["ing_lavender", "ing_wild_hyacinth"]), still, &"distill"))
	assert_lt(BrewEffects.scent_scale(feyre), 0.5, "a hush draught masks her scent")
	feyre.body_state.eat(Chemistry.combine(_items(["ing_glowcap", "ing_moss"]), still, &"distill"))
	tells._process(0.1)
	assert_true(tells.showing().has(&"bright"), "a glow draught: motes catch the light round her")
	assert_eq(tells.find_children("*", "Light3D", true, false).size(), 0, "no light comes from her")


func test_gathering_a_whole_combo_unlocks_its_recipe() -> void:
	var book := Gameplay.collection
	watch_signals(book)
	Gameplay.inventory.add(&"ing_lavender")
	assert_false(book.is_found(&"brew_hush_draught"), "half a combo unlocks nothing")
	Gameplay.inventory.add(&"ing_wild_hyacinth")
	assert_true(book.is_found(&"brew_hush_draught"), "the whole combo unlocks it")
	assert_true(book.is_new(&"brew_hush_draught"))
	assert_signal_emitted_with_parameters(book, "discovered", [&"brew_hush_draught", &"recipes"])
	var page: Array = book.entries(&"recipes").filter(func(e: Dictionary) -> bool: return e.id == &"brew_hush_draught")
	assert_string_contains(String(page[0].note), "lavender + wild hyacinth in the stillroom", "the page says how")
	assert_not_null(page[0].icon, "with its bottle")
	var ids := book.entries(&"recipes").map(func(e: Dictionary) -> StringName: return e.id)
	assert_false(ids.has(&"snowdrop_infusion"), "a dish that is a brew's combo has one page")
	assert_eq(ids.size(), RecipeUnlocks.all().size())
	FindCard.clear(get_tree())
	FindCard.show_find(get_tree(), &"brew_hush_draught", &"recipes")
	FindCard.show_find(get_tree(), &"roast_venison", &"recipes")
	assert_eq(FindCard.pending(), 1, "two unlocks at once share one card")
	FindCard.clear(get_tree())
	var copy := CollectionBook.new()
	copy.load_state(book.save_state())
	assert_eq(copy.new_count(&"recipes"), book.new_count(&"recipes"), "survives a save")
