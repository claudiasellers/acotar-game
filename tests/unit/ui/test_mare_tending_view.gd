# gate: when:ui/mare/*,ui/menu/meter_row.gd,systems/mount/mare_tack.gd,systems/mount/mare_care.gd,data/mount/decor/*,ui/theme/icons/tend/*,systems/bonds/*
## The tending screen (owner, 2026-11-26: "needs A LOT of work"; "icons in
## uniform with our theme"): picture tabs in two groups, her coat and bond as
## the Bonds page's meters, treats as the satchel's pictures, dress-up pieces
## with enamel swatches. What tending does (shine, treats, pieces) is
## MareCare's and MareTack's and is tested with them.
extends GutTest

var feyre: Node3D
var view: MareTendingView


func before_each() -> void:
	WorldState.clear()
	WorldDeltas.clear()
	Gameplay.reset()
	feyre = Node3D.new()
	add_child_autofree(feyre)
	view = MareTendingView.open(self, null, feyre, Gameplay.inventory)
	await wait_process_frames(2)


func after_each() -> void:
	if is_instance_valid(view):
		view.close()
	await wait_process_frames(2)
	Gameplay.reset()
	WorldState.clear()
	WorldDeltas.clear()


func test_every_tab_is_a_picture_with_its_name_in_two_groups() -> void:
	var ids: Array = [MareTendingView.CARE, MareTendingView.HER]
	ids.append_array(MareTack.SLOTS)
	assert_eq(view._tabs.keys(), ids, "care and her page, then one tab for each dress-up slot")
	for id: StringName in ids:
		assert_true(Icons.has(Icons.TEND, id), "%s has its picture" % id)
		assert_ne(MareTendingView.tab_name(id), "", "%s has its name" % id)
		assert_eq((view._tabs[id] as Button).custom_minimum_size, MareTendingView.TAB_SIZE, "one size of tab")
	assert_ne((view._tabs[MareTendingView.HER] as Button).get_parent(), (view._tabs[&"mane"] as Button).get_parent(),
			"care and dress-up are two rows")
	assert_true((view._tabs[MareTendingView.CARE] as Button).button_pressed, "it opens on care")


func test_her_coat_and_her_bond_are_the_same_meters_the_bonds_page_draws() -> void:
	var coat := view._meters.get_node("Coat").get_node("Meter") as ProgressBar
	assert_eq(coat.custom_minimum_size, MeterRow.SIZE)
	assert_eq(coat.value, 0.0)
	MareCare.brush(MareCare.BRUSH_TO_FULL)
	view._refresh_shine()
	assert_eq(coat.value, 1.0, "brushed to a gleam")
	assert_eq((view._meters.get_node("Coat").get_node("Word") as Label).text, "Gleaming")
	assert_not_null(view._meters.get_node_or_null(String(BondBook.CLOSENESS)), "her closeness, as on her Bonds page")


func test_treats_are_the_satchels_pictures_and_what_she_likes_when_there_are_none() -> void:
	var treats := view._body.get_node("Treats")
	assert_gt(treats.get_child_count(), 0, "with none, the ones she likes are shown")
	for b: Button in treats.get_children():
		assert_true(b.disabled, "a wished-for treat cannot be fed")
	Gameplay.inventory.add(&"ing_clover", 3)
	view._show(MareTendingView.CARE)
	treats = view._body.get_node("Treats")
	assert_eq(treats.get_child_count(), 1)
	assert_false((treats.get_child(0) as Button).disabled)
	view._feed(&"ing_clover", null)
	assert_eq(Gameplay.inventory.count(&"ing_clover"), 2, "fed from the tile")
	assert_eq(MareCare.treats_today(), 1)


func test_a_dress_up_piece_shows_its_colours_and_what_making_it_takes() -> void:
	view._show(&"garland")
	assert_true((view._tabs[&"garland"] as Button).button_pressed)
	var pieces := view._body.get_node("Pieces")
	var lilac := MareTack.piece(&"garland_lilac")
	var card := pieces.get_node(String(lilac.id))
	assert_not_null(card)
	assert_gt(lilac.colors.size(), 0)
	var texts: Array[String] = []
	for l in card.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	assert_has(texts, lilac.display_name)
	for need: Array in MareTack.needs(lilac, Gameplay.inventory):
		assert_true(texts.any(func(t: String) -> bool: return t.begins_with(String(need[0]))), "%s is listed" % need[0])
