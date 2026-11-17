extends GutTest
## Contract test for tending the white mare (L47-7, docs/contracts/mare_bond.md):
## the dress-up table, making and wearing pieces from found things, the look on
## her, brushing to a shine and treats.

const HORSE := preload("res://creatures/fae/white_horse.tscn")

var inv: Inventory


func before_each() -> void:
	WorldDeltas.clear()
	inv = Inventory.new()


func test_the_table_is_full_and_under_the_albedo_cap() -> void:
	var pieces := MareTack.all_pieces()
	assert_gte(pieces.size(), 40, "a real dress-up collection")
	for s in MareTack.SLOTS:
		assert_gt(MareTack.in_slot(s).size(), 2, "slot %s has choices" % s)
		if not s in MareTack.OPTIONAL:
			assert_true(MareTack.is_starter(MareTack.in_slot(s)[0]), "slot %s starts with her own look" % s)
	for p in pieces:
		assert_eq(p.canon, "X", "dress-up is invented (%s)" % p.id)
		for c in p.colors:
			assert_lte(maxf(c.r, maxf(c.g, c.b)), CandyMaterial.MAX_ALBEDO + 0.001, "%s under the 0.85 cap" % p.id)
		if p.model != "":
			assert_true(ResourceLoader.exists(p.model), "%s model exists" % p.id)
		for key: String in p.inputs:
			if not key.begins_with("tag:"):
				assert_true(ItemCatalog.has(StringName(key)), "%s needs a real item: %s" % [p.id, key])


func test_making_uses_found_things_and_keeps_the_piece() -> void:
	var p := MareTack.piece(&"garland_lilac")
	assert_false(MareTack.owned(p.id))
	assert_false(MareTack.can_make(p, inv), "nothing to make it from")
	inv.add(&"ing_lilac", 3)
	inv.add(&"ing_lavender", 2)
	inv.add(&"ing_spider_silk", 1)
	assert_true(MareTack.can_make(p, inv))
	assert_true(MareTack.make(p, inv))
	assert_true(MareTack.owned(p.id))
	assert_eq(inv.count(&"ing_lilac") + inv.count(&"ing_lavender"), 0, "the blooms went into it")
	assert_false(MareTack.make(p, inv), "made once")


func test_wearing_and_taking_off() -> void:
	assert_eq(MareTack.worn_in(&"cloth").id, &"cloth_rose", "her own rose cloth to start")
	assert_null(MareTack.worn_in(&"garland"), "no garland to start")
	assert_false(MareTack.wear(MareTack.piece(&"cloth_lilac")), "can't wear what isn't made")
	inv.add(&"ing_lilac", 4)
	inv.add(&"ing_spider_silk", 1)
	MareTack.make(MareTack.piece(&"cloth_lilac"), inv)
	assert_true(MareTack.wear(MareTack.piece(&"cloth_lilac")))
	assert_eq(MareTack.worn_in(&"cloth").id, &"cloth_lilac")
	MareTack.take_off(&"cloth")
	assert_eq(MareTack.worn_in(&"cloth").id, &"cloth_rose", "an always-on slot falls back to her own")


func test_the_look_recolours_her_and_hangs_pieces() -> void:
	var horse := HORSE.instantiate() as WhiteHorse
	add_child_autofree(horse)
	await wait_process_frames(2)
	var outfit := {&"cloth": MareTack.piece(&"cloth_mint"), &"garland": MareTack.piece(&"garland_rose"),
		&"tail": MareTack.piece(&"tail_sky")}
	MareLook.apply(horse, outfit, 1.0)
	var mi := MareLook._mesh(horse)
	var idx := MareLook._surface_index(mi)
	# The cloth is on the saddle now (MareSaddle, L47-8), not her own mesh.
	var saddle: MeshInstance3D = null
	var at := -1
	for m in MareSaddle.saddle_meshes(horse):
		if MareLook._surface_index(m).has("SaddleCloth"):
			saddle = m
			at = MareLook._surface_index(m)["SaddleCloth"]
	assert_not_null(saddle, "the saddle has a cloth")
	if saddle == null:
		return
	var cloth := saddle.get_surface_override_material(at)
	assert_not_null(cloth, "the saddle cloth is recoloured")
	assert_almost_eq((cloth.get(&"albedo_color") as Color).g, MareTack.piece(&"cloth_mint").colors[0].g, 0.01)
	assert_not_null(mi.get_surface_override_material(idx["Coat"]), "her groomed coat")
	assert_has(MareLook.hung(horse), "garland")
	assert_has(MareLook.hung(horse), "tail")
	MareLook.apply(horse, {}, 0.0)
	assert_eq(MareLook.hung(horse).size(), 0, "pieces come off")
	assert_null(saddle.get_surface_override_material(at), "back to her own")


func test_brushing_shines_and_fades() -> void:
	var cared := []
	var hook := func(kind: StringName, n: int) -> void: cared.append(kind)
	MareCare.on_care.append(hook)
	assert_almost_eq(MareCare.shine(), 0.0, 0.001)
	MareCare.brush(MareCare.BRUSH_TO_FULL * 0.5)
	assert_almost_eq(MareCare.shine(), 0.5, 0.01)
	MareCare.brush(MareCare.BRUSH_TO_FULL)
	assert_almost_eq(MareCare.shine(), 1.0, 0.001)
	assert_eq(cared.count(&"brushed"), 1, "a full brushing is a deed of care, once a day")
	MareCare.brush(1.0)
	assert_eq(cared.count(&"brushed"), 1)
	Clock.day += 1
	assert_almost_eq(MareCare.shine(), 1.0 - MareCare.FADE_PER_DAY, 0.01, "it fades by the day")
	Clock.day -= 1
	MareCare.on_care.erase(hook)


func test_treats_from_the_satchel_three_a_day() -> void:
	inv.add(&"ing_manor_fruit", 5)
	inv.add(&"ing_nettle", 1)
	assert_false(MareCare.feed(&"ing_nettle", inv), "not a treat")
	for i in 3:
		assert_true(MareCare.feed(&"ing_manor_fruit", inv))
	assert_false(MareCare.feed(&"ing_manor_fruit", inv), "she's had her fill")
	assert_eq(inv.count(&"ing_manor_fruit"), 2, "the refused one stays in the satchel")
	Clock.day += 1
	assert_eq(MareCare.treats_today(), 0, "a new day")
	Clock.day -= 1
