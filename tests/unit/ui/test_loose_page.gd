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
	var page := LoosePage.lay(layer, 600.0, 2)
	assert_eq(layer.layer, UiLayers.SCREEN, "on the screen layer")
	assert_eq(page.sheet.theme_type_variation, LoosePage.SHEET)
	assert_eq(page.sheet.custom_minimum_size.x, 600.0)
	assert_eq(page.column.get_parent(), page.sheet)
	assert_not_null(page.root.get_node_or_null(^"Scrim"), "the world dims behind it")
	assert_true(JournalTheme.build(JournalTheme.Act.HUMAN).has_stylebox(&"panel", LoosePage.SHEET), "the theme draws the paper")


func test_heading_and_key_caps() -> void:
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var page := LoosePage.lay(layer, 600.0, 2)
	var head := page.head()
	head[0].text = "Stillroom"
	head[1].text = "3 / 27"
	assert_eq(head[0].theme_type_variation, &"SatchelHeading")
	var dab := head[0].get_node_or_null(^"Dab") as TextureRect
	assert_not_null(dab, "one dab of her paint under the page's name")
	assert_eq(dab.modulate, Color(JournalTheme.wash(2), LoosePage.DAB_LIFT), "in the station's wash, laid on thick")
	assert_true(dab.show_behind_parent, "under the letters, not over them")
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


## Small type on a loose page reads: 16 px or more, and 4.5 to 1 on the
## loose page's paper in both acts (the director's look pass on step 6).
func test_type_on_a_loose_page_reads() -> void:
	for act: JournalTheme.Act in [JournalTheme.Act.HUMAN, JournalTheme.Act.SPRING]:
		var c := JournalTheme.colors(act)
		var t := JournalTheme.build(act)
		for v: StringName in [&"SatchelHeading", &"PageSection", &"SatchelBody", &"SatchelSmall", &"SatchelCount"]:
			assert_gte(t.get_font_size(&"font_size", v), 16, "act %d: %s" % [act, v])
			assert_gte(JournalTheme.contrast(t.get_color(&"font_color", v), c[&"paper_deep"]), 4.5, "act %d: %s on the loose page" % [act, v])
		# Thin strokes never reach their full colour on screen: small type is bold.
		var small := t.get_font(&"font", &"SatchelSmall") as FontVariation
		assert_gte(int(small.variation_opentype.get(TextServerManager.get_primary_interface().name_to_tag("wght"), 0)), 700, "act %d: small type is bold" % act)


## No two names on the stones' sketch touch, and none sits on another whorl.
func test_names_on_the_stones_sketch_keep_apart() -> void:
	var defs := WhorlStones.defs()
	assert_gte(defs.size(), 5, "the land has stones to draw")
	var sketch := WhorlSketch.new()
	add_child_autofree(sketch)
	sketch.here = defs[0]
	sketch.stones = defs.slice(1)
	sketch.size = Vector2(500, 380)
	var rects := sketch.label_rects()
	assert_eq(rects.size(), defs.size(), "every stone is named")
	var ids := rects.keys()
	for i in ids.size():
		assert_true(Rect2(Vector2.ZERO, sketch.size).encloses(rects[ids[i]]), "%s is on the sketch" % ids[i])
		for j in range(i + 1, ids.size()):
			assert_false((rects[ids[i]] as Rect2).intersects(rects[ids[j]]), "%s and %s" % [ids[i], ids[j]])
		for d in defs:
			if d.id != ids[i]:
				var mark := sketch.mark_rect(d)
				assert_false((rects[ids[i]] as Rect2).intersects(mark), "%s is clear of the whorl at %s" % [ids[i], d.id])


## The old card look is gone: nothing in the game names it.
func test_the_old_card_look_is_gone() -> void:
	assert_false(FileAccess.file_exists("res://ui/ui_style.gd"))
	var users: Array[String] = []
	_users_of("res://", "UiStyle", users)
	assert_eq(users, [] as Array[String], "write it on JournalTheme")


func _users_of(dir: String, word: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d in ["addons", "tests"]:
			continue
		_users_of(dir.path_join(d), word, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and FileAccess.get_file_as_string(dir.path_join(f)).contains(word):
			out.append(dir.path_join(f))
