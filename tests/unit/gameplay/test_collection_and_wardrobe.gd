extends GutTest


func before_each() -> void:
	Gameplay.reset()


func test_wardrobe_is_big_enough() -> void:
	assert_gte(WardrobeCatalog.all_pieces().size(), 150, "pieces")
	assert_gte(WardrobeCatalog.all_hair().size(), 14, "hairstyles")
	assert_gte(WardrobeCatalog.all_makeup().size(), 50, "makeup looks")
	var masks := WardrobeCatalog.all_pieces().filter(func(p: WardrobePiece) -> bool: return p.slots.has(&"mask"))
	assert_gte(masks.size(), 8, "masks")


func test_every_piece_uses_known_slots() -> void:
	for p in WardrobeCatalog.all_pieces():
		assert_false(p.slots.is_empty(), "%s has a slot" % p.id)
		for s in p.slots:
			assert_true(WardrobePiece.SLOTS.has(s), "%s slot %s" % [p.id, s])
	for m in WardrobeCatalog.all_makeup():
		assert_true(MakeupData.CHANNELS.has(m.channel), "%s channel" % m.id)


func test_earrings_and_bracelet_wear_together() -> void:
	var w := Gameplay.wardrobe
	w.grant(&"pearl_earrings")
	w.grant(&"charm_bracelet")
	assert_true(w.equip(&"pearl_earrings"))
	assert_true(w.equip(&"charm_bracelet"))
	assert_eq(w.equipped_in(&"ears"), &"pearl_earrings")
	assert_eq(w.equipped_in(&"wrist"), &"charm_bracelet")


func test_first_pickup_is_discovered_and_new() -> void:
	var book := Gameplay.collection
	var before := book.progress(&"ingredients")
	assert_gt(before.y, 100, "every ingredient is listed")
	watch_signals(book)
	Gameplay.inventory.add(&"ing_acorn", 2)
	assert_true(book.is_found(&"ing_acorn"))
	assert_true(book.is_new(&"ing_acorn"))
	assert_signal_emit_count(book, "discovered", 1)
	Gameplay.inventory.add(&"ing_acorn")
	assert_signal_emit_count(book, "discovered", 1, "only the first time")
	assert_eq(book.progress(&"ingredients").x, before.x + 1)
	Gameplay.inventory.add(&"col_acorn_cap")
	assert_true(book.is_found(&"col_acorn_cap"))
	assert_eq(book.new_count(&"keepsakes"), 1)
	book.seen(&"ingredients")
	assert_false(book.is_new(&"ing_acorn"))
	assert_eq(book.new_count(), 1, "keepsake still new")


func test_tabs_fill_from_their_sources() -> void:
	var book := Gameplay.collection
	assert_gt(book.progress(&"wardrobe").x, 0, "starting clothes count, quietly")
	assert_eq(book.new_count(&"wardrobe"), 0)
	Gameplay.wardrobe.grant(&"pearl_earrings")
	assert_true(book.is_new(&"pearl_earrings"))
	Gameplay.sketchbook.add(&"sketch_test", "A test sketch")
	assert_eq(book.progress(&"sketches"), Vector2i(1, -1))
	var ings: Array[IngredientData] = [ItemCatalog.get_item(&"ing_blackberry") as IngredientData]
	var result := Chemistry.combine(ings, load("res://data/stations/campfire.tres") as StationData, &"infuse")
	if result.get("ok", false):
		Gameplay.journal.record(result)
		assert_true(book.is_found(&"blackberry_tea"), "named dish becomes a recipe entry")
	assert_eq(book.progress(&"recipes").y, Chemistry.dishes().size())


func test_arrows_and_materials_stay_out_of_the_book() -> void:
	assert_false(Gameplay.collection.mark(&"arrow_wood"))
	assert_false(Gameplay.collection.mark(&"mat_shaft"))


func test_save_round_trip() -> void:
	Gameplay.inventory.add(&"ing_acorn")
	var data: Dictionary = JSON.parse_string(JSON.stringify(Gameplay.collection.save_state()))
	var copy := CollectionBook.new()
	copy.load_state(data)
	assert_true(copy.is_found(&"ing_acorn"))
	assert_true(copy.is_new(&"ing_acorn"))


func test_woven_crowns_use_the_woven_mesh() -> void:
	for c in [&"rose", &"butter", &"lilac", &"pearl", &"sky"]:
		var p := WardrobeCatalog.piece(StringName("woven_crown_%s" % c))
		assert_eq(p.mesh_path, "res://characters/feyre/wardrobe/woven_crown.glb")


func test_every_piece_names_a_mesh() -> void:
	for p in WardrobeCatalog.all_pieces():
		assert_true(p.mesh_path.begins_with("res://characters/feyre/wardrobe/") and not p.mesh_path.ends_with("/.glb"),
			"%s mesh %s" % [p.id, p.mesh_path])
