# gate: when:ui/mare/*,ui/menu/meter_row.gd,ui/menu/open_tin.gd,ui/theme/journal_theme.gd,systems/mount/mare_tack.gd,systems/mount/mare_care.gd,data/mount/decor/*,ui/theme/icons/tend/*,systems/bonds/*
## The tending screen (owner, 2026-11-26: "needs A LOT of work"; "icons in
## uniform with our theme"; then the Open Tin): her paint tin along the foot
## of the screen and the mare above it, pans in two groups, her coat and bond
## as the Bonds page's meters, treats as the satchel's pictures in small pans,
## dress-up pieces in wells with enamel swatches, her page on the tin's lid. What tending does (shine, treats, pieces) is
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


func test_every_tab_is_a_pan_with_its_picture_in_two_groups() -> void:
	var ids: Array = [MareTendingView.CARE, MareTendingView.HER]
	ids.append_array(MareTack.SLOTS)
	assert_eq(view._tabs.keys(), ids, "care and her page, then one pan for each dress-up slot")
	for id: StringName in ids:
		assert_true(Icons.has(Icons.TEND, id), "%s has its picture" % id)
		assert_ne(MareTendingView.tab_name(id), "", "%s has its name" % id)
		assert_true(view._tabs[id] is OpenTin.Pan, "%s is a pan of the tin" % id)
		assert_eq((view._tabs[id] as OpenTin.Pan).text_name, MareTendingView.tab_name(id))
	assert_ne((view._tabs[MareTendingView.HER] as Button).get_parent(), (view._tabs[&"mane"] as Button).get_parent(),
			"care and dress-up are two groups")
	assert_true((view._tabs[MareTendingView.CARE] as Button).button_pressed, "it opens on care")
	assert_eq((view.tin.get_node("Tag") as Label).text, "Brush and treats", "the chosen pan is named on the tag")
	view.step(1)
	assert_eq(view._tab, MareTendingView.HER, "RB steps to the next pan")
	view.step(-2)
	assert_eq(view._tab, MareTack.SLOTS[-1], "and LB goes round the other way")


func test_the_tin_keeps_to_the_foot_and_the_rest_is_hers_to_brush() -> void:
	var screen := view.size
	for id: StringName in view._tabs:
		view._show(id)
		await wait_process_frames(3)
		assert_lte(view.tin.tray.size.y, OpenTin.MAX_HEIGHT, "%s: the tray stays low" % id)
		assert_almost_eq(view.tin.tray.position.y + view.tin.tray.size.y, screen.y - OpenTin.EDGE.y, 1.0, "%s: on the foot" % id)
	view._show(&"garland")
	await wait_process_frames(3)
	var top := view.tin.clear_height()
	assert_true(view._over_mare(Vector2(screen.x * 0.5, top - 8.0)), "just above the tray is hers")
	assert_true(view._over_mare(Vector2(screen.x - 40.0, 40.0)), "and so is the far corner: no paper down the side")
	assert_false(view._over_mare(Vector2(screen.x * 0.5, top + 8.0)), "the tray is not")
	var src := FileAccess.get_file_as_string("res://ui/mare/mare_tending_view.gd")
	assert_false(src.contains("PANEL_FRACTION"), "the right-hand paper is gone")


func test_her_coat_and_her_bond_are_the_same_meters_the_bonds_page_draws() -> void:
	var coat := view._meters.get_node("Coat").get_node("Meter") as ProgressBar
	assert_eq(coat.custom_minimum_size, MeterRow.SIZE)
	assert_eq(coat.value, 0.0)
	MareCare.brush(MareCare.BRUSH_TO_FULL)
	view._refresh_shine()
	assert_eq(coat.value, 1.0, "brushed to a gleam")
	assert_eq((view._meters.get_node("Coat").get_node("Word") as Label).text, "Gleaming")
	var closeness := view._meters.get_node_or_null(String(BondBook.CLOSENESS))
	assert_not_null(closeness, "her closeness, as on her Bonds page")
	assert_eq((closeness.get_node("Meter") as ProgressBar).theme_type_variation, JournalTheme.measure_meter(BondBook.CLOSENESS),
			"in its own paint")
	assert_eq((closeness.get_node("Name") as Label).theme_type_variation, &"TinLabel", "worded for the tin")


func test_treats_are_the_satchels_pictures_and_what_she_likes_when_there_are_none() -> void:
	var treats := view._body.find_child("Treats", true, false)
	assert_gt(treats.get_child_count(), 0, "with none, the ones she likes are shown")
	for pan: OpenTin.Pan in treats.get_children():
		assert_true(pan.small)
		assert_true(pan.disabled, "a wished-for treat cannot be fed")
		assert_true(pan.wished)
	assert_not_null(view._body.get_node_or_null(^"Brushing"), "the brushing line has its own well")
	Gameplay.inventory.add(&"ing_clover", 3)
	view._show(MareTendingView.CARE)
	treats = view._body.find_child("Treats", true, false)
	assert_eq(treats.get_child_count(), 1)
	var clover := treats.get_child(0) as OpenTin.Pan
	assert_false(clover.disabled)
	assert_eq((clover.get_node("Count") as Label).text, "×3")
	view._feed(&"ing_clover", null)
	assert_eq(Gameplay.inventory.count(&"ing_clover"), 2, "fed from the pan")
	assert_eq(MareCare.treats_today(), 1)


func test_a_dress_up_piece_is_a_well_with_its_colours_and_what_making_it_takes() -> void:
	view._show(&"garland")
	assert_true((view._tabs[&"garland"] as Button).button_pressed)
	var pieces := view._body.find_child("Pieces", true, false)
	assert_not_null(pieces.get_node_or_null(^"Nothing"), "a slot she can leave bare offers it first")
	assert_eq(pieces.get_child(0).name, &"Nothing")
	var lilac := MareTack.piece(&"garland_lilac")
	var card := pieces.get_node(String(lilac.id)) as PanelContainer
	assert_not_null(card)
	assert_eq(card.theme_type_variation, &"TinWell")
	assert_eq(card.custom_minimum_size.x, MareTendingView.WELL_WIDTH, "wells are one width")
	assert_gt(lilac.colors.size(), 0)
	var texts: Array[String] = []
	for l in card.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	assert_has(texts, lilac.display_name)
	for need: Array in MareTack.needs(lilac, Gameplay.inventory):
		assert_true(texts.any(func(t: String) -> bool: return t.begins_with(String(need[0]))), "%s is listed" % need[0])
	assert_eq(card.find_children("*", "Button", true, false).size(), 1, "one thing to press")


func test_what_she_wears_is_ringed_and_says_so() -> void:
	var worn := MareTack.worn_in(&"mane")
	assert_not_null(worn, "she has a mane dressing from the start")
	view._show(&"mane")
	var card := view._body.find_child("Pieces", true, false).get_node(String(worn.id)) as PanelContainer
	assert_eq(card.theme_type_variation, &"TinWellChosen", "ringed in gold")
	assert_eq((card.find_child("OnHer", true, false) as Label).text, "on her")
	var texts: Array[String] = []
	for l in card.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	assert_has(texts, "She's wearing it")
	assert_eq(card.find_children("*", "Button", true, false).size(), 0, "nothing to press on what she already wears")


func test_her_page_stands_on_the_lid() -> void:
	assert_false(view.tin.has_lid())
	view._show(MareTendingView.HER)
	assert_true(view.tin.has_lid(), "her page is a read, so it stands up")
	assert_eq(view._body.get_child_count(), 0, "and the row under the pans is empty")
	var said: Array[String] = []
	for l in view.tin.get_node("Lid").find_children("*", "Label", true, false):
		said.append((l as Label).text)
	assert_has(said, MarePage.now_line())
	view._show(MareTendingView.CARE)
	await wait_process_frames(2)
	assert_false(view.tin.has_lid(), "the lid goes down with her page")
