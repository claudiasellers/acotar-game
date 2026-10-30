extends GutTest

const ICONS: Array[StringName] = [&"flower", &"berry", &"leaf", &"mushroom", &"feather", &"gem", &"drop",
	&"twig", &"shell", &"meat", &"pelt", &"trinket"]


func before_each() -> void:
	Gameplay.reset()


func _findables() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for id in ItemCatalog.all_ids():
		var item := ItemCatalog.get_item(id)
		if item is IngredientData or item is CollectibleData:
			out.append(item)
	return out


func test_every_find_has_an_icon_and_a_hint() -> void:
	for item in _findables():
		assert_true(ICONS.has(item.icon), "%s icon %s" % [item.id, item.icon])
		assert_ne(item.hint, "", "%s hint" % item.id)


func test_rare_share_and_windows() -> void:
	var all := _findables()
	var rare := all.filter(func(i: ItemData) -> bool: return i.is_rare())
	var share := float(rare.size()) / all.size()
	assert_between(share, 0.10, 0.15, "rare share")
	var shiny := rare.filter(func(i: ItemData) -> bool: return i.rarity == &"shiny")
	assert_between(shiny.size(), 4, rare.size() / 2, "about a third shine")
	for i: ItemData in rare:
		assert_ne(i.bound, &"", "%s is bound to a window" % i.id)


func test_window_gate() -> void:
	var dawn := ItemData.new()
	dawn.bound = &"dawn"
	assert_true(ForageRegistry.in_window(dawn, 6.0))
	assert_false(ForageRegistry.in_window(dawn, 12.0))
	var rain := ItemData.new()
	rain.bound = &"rain"
	assert_false(ForageRegistry.in_window(rain, 12.0, &"clear"))
	assert_true(ForageRegistry.in_window(rain, 12.0, &"rain"))
	assert_true(ForageRegistry.in_window(ItemCatalog.get_item(&"ing_acorn"), 3.0), "common finds are always there")
	assert_false(ForageRegistry.in_window(ItemCatalog.get_item(&"ing_moonflower"), 12.0), "moonflower waits for night")


func test_combo_climbs_and_resets() -> void:
	Juice.combo_step(100000)
	assert_eq(Juice.combo_step(101000), 1)
	assert_eq(Juice.combo_step(103500), 2, "within 3 s of the last pick")
	for i in 10:
		Juice.combo_step(104000 + i * 100)
	assert_eq(Juice.combo_step(106000), Juice.COMBO_STEPS.size() - 1, "holds on the top note")
	assert_eq(Juice.combo_step(110000), 0, "a gap resets it")


func test_pickup_token_arcs_and_frees() -> void:
	var collector := Node3D.new()
	add_child_autofree(collector)
	var token := Juice.arc_token(Vector3(3, 0, 0), collector, Color.HOT_PINK)
	assert_true(is_instance_valid(token))
	await wait_seconds(Juice.ARC_SECONDS + 0.15)
	assert_false(is_instance_valid(token), "token lands in 0.25 s and is gone")


func test_pages_have_rewards_and_grant_them() -> void:
	for tab in [&"ingredients", &"keepsakes", &"recipes", &"truths", &"wardrobe"]:
		assert_gte(CollectionBook.rewards(tab).size(), 3, "%s rewards" % tab)
	var book := Gameplay.collection
	watch_signals(book)
	var first := book.next_reward(&"ingredients")
	assert_eq(first.need, 10)
	var n := 0
	for i in ItemCatalog.ingredients():
		if n == 10:
			break
		if Gameplay.inventory.add(i.id) > 0:
			n += 1
	assert_signal_emitted(book, "reward_earned")
	assert_true(book.is_claimed(first))
	assert_gt(Gameplay.inventory.count(first.reward_id), 0, "paint cake granted")
	assert_ne(book.next_reward(&"ingredients"), first)
	var copy := CollectionBook.new()
	copy.load_state(JSON.parse_string(JSON.stringify(book.save_state())))
	assert_true(copy.is_claimed(first), "claimed rewards are saved")


func test_weave_a_crown_and_wear_it() -> void:
	var inv := Gameplay.inventory
	assert_eq(CrownWeaver.weave(inv, Gameplay.wardrobe), &"", "no blooms, no crown")
	inv.add(&"ing_rose_red", 3)
	inv.add(&"ing_primrose", 1)
	assert_eq(CrownWeaver.blooms_missing(inv), 1)
	inv.add(&"ing_dandelion", 1)
	var piece := CrownWeaver.weave(inv, Gameplay.wardrobe)
	assert_eq(piece, &"woven_crown_rose", "coloured by the blooms she has most of")
	assert_eq(Gameplay.wardrobe.equipped_in(&"head"), piece, "worn at once")
	assert_eq(inv.count(&"ing_rose_red") + inv.count(&"ing_primrose") + inv.count(&"ing_dandelion"), 0)


func test_find_cards_queue_without_pausing() -> void:
	FindCard.clear(get_tree())
	FindCard.show_find(get_tree(), &"ing_rose_gold", &"ingredients")
	FindCard.show_find(get_tree(), &"ing_acorn", &"ingredients")
	assert_eq(FindCard.pending(), 2)
	assert_false(get_tree().paused)
	await wait_seconds(FindCard.HOLD + FindCard.FADE * 2.0 + 0.2)
	assert_eq(FindCard.pending(), 1, "one at a time, 1.2 s each")
	FindCard.clear(get_tree())
