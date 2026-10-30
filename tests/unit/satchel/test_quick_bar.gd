## Contract test for the satchel lane (L14): quick bar pins, use rules,
## auto-fill, save round trip, the page's entry list and its sound hooks.
extends GutTest

class FakeFeyre:
	extends Node
	var body_state: BodyState = BodyState.new()
	var bow_controller: BowController = BowController.new()

var inv: Inventory
var bar: QuickBar
var who: FakeFeyre


func before_each() -> void:
	inv = Inventory.new()
	bar = QuickBar.new(inv)
	who = FakeFeyre.new()
	SatchelSounds.fired.clear()


func after_each() -> void:
	who.body_state.free()
	who.bow_controller.free()
	who.free()


func test_first_usable_pickups_fill_empty_slots_in_order() -> void:
	inv.add(&"arrow_wood", 5)
	inv.add(&"ing_bilberry", 3)
	inv.add(&"col_odd_stone")  # a keepsake: not usable, never pinned
	assert_eq(bar.entry(0), &"arrow_wood")
	assert_eq(bar.entry(1), &"ing_bilberry")
	assert_eq(bar.entry(2), &"")
	assert_eq(bar.count(1), 3)


func test_unpinnable_entries_are_refused() -> void:
	inv.add(&"col_odd_stone")
	assert_false(bar.pin(0, &"col_odd_stone"))
	assert_false(bar.pin(QuickBar.SLOTS, &"arrow_wood"))


func test_pin_moves_and_swaps() -> void:
	inv.add(&"arrow_wood", 1)
	inv.add(&"ing_bilberry", 1)
	assert_true(bar.pin(1, &"arrow_wood"))
	assert_eq(bar.entry(1), &"arrow_wood")
	assert_eq(bar.entry(0), &"ing_bilberry")
	assert_eq(bar.next_slot_for(&"arrow_wood"), 2)


func test_eating_from_the_bar_spends_one_and_feeds_her() -> void:
	inv.add(&"ing_bilberry", 2)
	var hunger := who.body_state.hunger
	assert_true(bar.use(0, who))
	assert_eq(inv.count(&"ing_bilberry"), 1)
	assert_lt(who.body_state.hunger, hunger)


func test_an_arrow_slot_nocks_that_arrow() -> void:
	inv.add(&"arrow_fire", 2)
	assert_true(bar.use(0, who))
	assert_eq(who.bow_controller.selected, &"arrow_fire")
	assert_eq(inv.count(&"arrow_fire"), 2, "nocking doesn't spend the arrow")


func test_dishes_stack_auto_pin_and_are_eaten() -> void:
	inv.add_dish({"key": "stew", "name": "Rabbit stew", "hunger_relief": 0.3})
	inv.add_dish({"key": "stew", "name": "Rabbit stew", "hunger_relief": 0.3})
	assert_eq(bar.entry(0), &"dish:stew")
	assert_eq(bar.count(0), 2)
	assert_true(bar.use(0, who))
	assert_eq(inv.dishes.size(), 1)
	var dishes := SatchelEntries.list(inv, SatchelEntries.DISHES)
	assert_eq(dishes.size(), 1)
	assert_eq(dishes[0].count, 1)


func test_empty_slot_keeps_its_pin_and_refuses_use() -> void:
	inv.add(&"ing_bilberry", 1)
	assert_true(bar.use(0, who))
	assert_eq(bar.entry(0), &"ing_bilberry")
	assert_false(bar.use(0, who))


func test_cleared_slot_is_not_refilled_by_the_same_item() -> void:
	inv.add(&"ing_bilberry", 1)
	bar.clear(0)
	inv.add(&"ing_bilberry", 1)
	assert_eq(bar.entry(0), &"")


func test_save_round_trip() -> void:
	inv.add(&"arrow_wood", 1)
	bar.pin(3, &"arrow_wood")
	var data := JSON.parse_string(JSON.stringify(bar.save_state())) as Dictionary
	var other := QuickBar.new(Inventory.new())
	other.load_state(data)
	assert_eq(other.entry(3), &"arrow_wood")
	other.inventory.add(&"arrow_wood", 1)
	assert_eq(other.entry(0), &"", "a saved 'seen' id isn't auto-placed again")


func test_page_lists_every_entry_with_inventory_counts() -> void:
	inv.add(&"arrow_wood", 4)
	inv.add(&"ing_pine_resin", 20)  # spills from the pouch into the satchel
	inv.add(&"col_odd_stone")
	inv.add_dish({"key": "tea", "name": "Pine tea"})
	var all := SatchelEntries.list(inv)
	var ids := all.map(func(e: Dictionary) -> StringName: return e.id)
	assert_eq(ids.size(), 4)
	for e in all:
		assert_eq(int(e.count), SatchelEntries.count(inv, e.id), String(e.id))
	assert_eq(SatchelEntries.list(inv, Inventory.SATCHEL).size(), 1)


func test_menu_sound_hooks_fire() -> void:
	inv.add(&"ing_bilberry", 2)
	var menu := SatchelMenu.new(bar)
	add_child_autofree(menu)
	menu.open()
	menu.set_pocket(Inventory.POUCH)
	menu.select(&"ing_bilberry")
	menu.pin_selected(2)
	menu.use_selected()
	menu.close()
	for kind in [&"open", &"page", &"pin", &"use", &"close"]:
		assert_eq(int(SatchelSounds.fired.get(kind, 0)), 0, String(kind))
	assert_false(get_tree().paused)


func test_worn_satchel_hides_under_gowns() -> void:
	var tunic := WardrobePiece.new()
	tunic.slots = [&"top"]
	var gown := WardrobePiece.new()
	gown.slots = [&"top", &"bottom"]
	assert_true(SatchelWorn.fits_outfit([tunic] as Array[WardrobePiece]))
	assert_false(SatchelWorn.fits_outfit([tunic, gown] as Array[WardrobePiece]))


func test_a_bar_on_a_stocked_inventory_fills_from_it() -> void:
	var stocked := Inventory.new()
	stocked.add(&"ing_bilberry", 2)
	stocked.add(&"arrow_wood", 3)
	var fresh := QuickBar.new(stocked)
	assert_eq(fresh.entry(0), &"arrow_wood", "arrows first")
	assert_eq(fresh.entry(1), &"ing_bilberry")
