# gate: when:ui/menu/loose_page.gd,ui/menu/book_kit.gd,ui/theme/*,ui/chemistry/brew_menu.gd,ui/market/market_menu.gd,ui/studio/studio_ui.gd,ui/mare/mare_tending_view.gd,systems/fast_travel/whorl_travel_card.gd,systems/fast_travel/whorl_ride.gd,ui/ui_style.gd
extends GutTest
## The stations she opens with E are loose pages of the journal: one kit lays
## the paper, the heading and the key caps, and no station frames itself.

const STATIONS: Array[String] = [
	"res://ui/chemistry/brew_menu.gd", "res://ui/market/market_menu.gd", "res://ui/studio/studio_ui.gd",
	"res://ui/mare/mare_tending_view.gd", "res://systems/fast_travel/whorl_travel_card.gd",
	"res://systems/fast_travel/whorl_ride.gd",
]


func test_a_page_is_paper_on_a_scrim_with_a_column_to_write_in() -> void:
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var page := LoosePage.lay(layer, 600.0)
	assert_eq(layer.layer, UiLayers.SCREEN, "on the screen layer")
	assert_eq(page.sheet.theme_type_variation, LoosePage.SHEET)
	assert_eq(page.sheet.custom_minimum_size.x, 600.0)
	assert_eq(page.column.get_parent(), page.sheet)
	assert_not_null(page.root.get_node_or_null(^"Scrim"), "the world dims behind it")
	assert_true(JournalTheme.build(JournalTheme.Act.HUMAN).has_stylebox(&"panel", LoosePage.SHEET), "the theme draws the paper")


func test_heading_and_key_caps() -> void:
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var page := LoosePage.lay(layer, 600.0)
	var head := page.head()
	head[0].text = "Stillroom"
	head[1].text = "3 / 27"
	assert_eq(head[0].theme_type_variation, &"SatchelHeading")
	page.set_hints([["E", "Brew"], ["Esc", "Step away"]])
	var hints := page.column.get_node(^"Hints")
	assert_eq(hints.get_child_count(), 2)
	page.set_hints([["Esc", "Step away"]])
	assert_eq(hints.get_child_count(), 1, "set again, the old caps go")
	assert_eq(page.column.get_child(page.column.get_child_count() - 1), hints, "the caps are the foot of the page")
	var b := LoosePage.button("Brew")
	assert_eq(b.theme_type_variation, &"SatchelTab")
	assert_eq(b.focus_mode, Control.FOCUS_ALL, "a pad can reach it")
	b.free()


func test_no_station_frames_itself() -> void:
	var bad := RegEx.create_from_string("UiStyle|&\"scrim\"|&\"SatchelKey\"|StyleBoxFlat\\.new\\(\\).*panel_box|CenterContainer\\.new\\(\\)")
	for path in STATIONS:
		var src := FileAccess.get_file_as_string(path)
		assert_true(src.contains("LoosePage."), "%s is laid by LoosePage" % path)
		if path.ends_with("whorl_ride.gd"):
			continue  # its leaf fills the screen and centres one mark
		var hits := []
		for line in src.split("\n"):
			if not line.strip_edges().begins_with("#") and bad.search(line):
				hits.append(line.strip_edges())
		assert_eq(hits, [], "%s builds a scrim, a card or key caps of its own" % path)


func test_the_old_card_look_makes_no_screens() -> void:
	var src := FileAccess.get_file_as_string("res://ui/ui_style.gd")
	assert_false(src.contains("func modal"), "no modal: screens are loose pages or the book")
	assert_false(src.contains("func button"), "no buttons of its own")
