# gate: when:systems/wardrobe/*,data/wardrobe/*,ui/dressing_room/*,tools/gen_gameplay_data.py
## Contract for the wearables loop (L64): clothes are purely aesthetic, every
## piece has a way to reach Feyre, and the wardrobe restocks with the story.
extends GutTest


func test_clothes_are_purely_aesthetic() -> void:
	assert_false(&"warmth" in WardrobePiece.new(), "pieces carry no stats")
	var w := Wardrobe.new()
	var looks: Array = [[], [&"ball_gown_rose", &"satin_slippers_pearl", &"tiara_gold"], [&"riding_leathers", &"riding_boots"]]
	for look: Array in looks:
		for id: StringName in look:
			w.grant(id)
			w.equip(id)
		assert_eq(w.warmth(), Wardrobe.DRESSED_WARMTH, "warmth in %s" % [look])
		assert_eq(w.swift(), 0.0, "swift in %s" % [look])
		assert_eq(w.stealth(), 0.0, "stealth in %s" % [look])
	for slot in WardrobePiece.SLOTS:
		w.unequip_slot(slot)
	assert_eq(w.warmth(), Wardrobe.DRESSED_WARMTH, "even with nothing on")


func test_every_piece_has_a_route() -> void:
	var woven := {}
	for file in ResourceLoader.list_directory("res://data/recipes"):
		var r := load("res://data/recipes".path_join(file)) as CraftRecipe if file.ends_with(".tres") else null
		if r and r.wardrobe_piece != &"":
			woven[r.wardrobe_piece] = true
	var orphans: Array[StringName] = []
	for p in WardrobeCatalog.all_pieces():
		if not WardrobeStock.ROUTES.has(p.source) or (p.source == &"woven" and not woven.has(p.id)):
			orphans.append(p.id)
	assert_gt(WardrobeCatalog.all_pieces().size(), 165)
	assert_eq(orphans, [] as Array[StringName], "pieces nobody can get")


func test_wardrobe_restocks_with_the_story() -> void:
	assert_eq(WardrobeStock.phase_index(&"p3_house_and_woods"), 3)
	assert_eq(WardrobeStock.phase_index(&""), WardrobeStock.ALL_PHASES)
	var w := Wardrobe.new()
	assert_eq(w.unseen(), [] as Array[StringName], "her cottage things are not new")
	var grounds := WardrobeStock.restock(w, 2)
	assert_gt(grounds.size(), 20, "the manor opens the gowns")
	assert_true(grounds.all(func(id: StringName) -> bool: return WardrobeCatalog.piece(id).phase <= 2))
	var house := WardrobeStock.restock(w, 3)
	assert_gt(house.size(), 0, "more hangs there next phase")
	assert_true(house.all(func(id: StringName) -> bool: return WardrobeCatalog.piece(id).phase == 3))
	assert_eq(WardrobeStock.restock(w, 3).size(), 0, "nothing twice")
	assert_eq(w.unseen().size(), grounds.size() + house.size(), "all New until seen")
	var copy := Wardrobe.new()
	copy.load_state(JSON.parse_string(JSON.stringify(w.save_state())))
	assert_true(copy.is_unseen(house[0]), "New survives a save")
	w.mark_seen(house)
	assert_false(w.is_unseen(house[0]))
	assert_ne(WardrobeStock.arrivals_line(grounds), "")


func test_human_realm_is_humble_and_hers() -> void:
	var w := Wardrobe.new()
	var cottage := WardrobeCatalog.all_pieces().filter(func(p: WardrobePiece) -> bool:
		return p.source == WardrobeStock.COTTAGE)
	assert_gte(cottage.size(), 7, "the hunter kit plus her few other things")
	for p: WardrobePiece in cottage:
		assert_eq(p.phase, 0, String(p.id))
		assert_true(w.owns(p.id), "%s is hers from the start" % p.id)
	assert_eq(w.equipped_in(&"top"), &"hunter_tunic", "she still starts in the patched tunic")


func test_satchel_holds_only_small_things() -> void:
	for tab in ["Gowns", "Tops", "Shoes", "Makeup"]:
		assert_false(DressingRoomView.SATCHEL_TABS.has(tab), "%s stays at a wardrobe" % tab)
	assert_eq(DressingRoomView.category_of(WardrobeCatalog.piece(&"elains_ribbon")), "Crowns")
	assert_eq(DressingRoomView.category_of(WardrobeCatalog.piece(&"hunter_cloak")), "Cloaks")


func test_arrivals_and_satchel_screens() -> void:
	Gameplay.reset()
	var feyre := Feyre.new()
	add_child_autofree(feyre)
	await wait_process_frames(2)
	WardrobeStock.restock(Gameplay.wardrobe, 2)
	Gameplay.wardrobe.mark_seen()
	PhaseManager.current_phase = &"p3_house_and_woods"
	DressingRoom.open(feyre, &"wardrobe")
	await wait_process_frames(2)
	var view := get_tree().root.get_node("DressingRoom/DressingRoomView") as DressingRoomView
	assert_gt(view.arrivals.size(), 0, "phase 3 hangs new things")
	assert_true(view.arrivals_label.visible and view.arrivals_label.text.begins_with("%d new" % view.arrivals.size()))
	assert_gt(view.find_children("NewRibbon", "", true, false).size(), 0, "New ribbons on their cards")
	assert_string_contains(view.found_label.text, " of %d found" % WardrobeCatalog.all_pieces().size())
	DressingRoom.close_room(feyre)
	assert_eq(Gameplay.wardrobe.unseen(), [] as Array[StringName], "seen once she has looked")
	DressingRoom.open(feyre, DressingRoom.SATCHEL)
	await wait_process_frames(2)
	view = get_tree().root.get_node("DressingRoom/DressingRoomView") as DressingRoomView
	for i in view.tabs.get_tab_count():
		assert_has(DressingRoomView.SATCHEL_TABS, String(view.tabs.get_tab_control(i).name))
	assert_false(view.arrivals_label.visible)
	DressingRoom.close_room(feyre)
	await wait_process_frames(2)
	PhaseManager.current_phase = &""
	Gameplay.reset()
