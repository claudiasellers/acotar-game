## The title reads (the director's look pass on step 8c): the menu over the
## brightest backdrop, and the small print on the journal's first page.
extends GutTest

const TITLE_SCENE := "res://ui/title/title_screen.tscn"


func after_each() -> void:
	GameSettings.pending_load_slot = ""


func _title() -> Control:
	var t := (load(TITLE_SCENE) as PackedScene).instantiate() as Control
	add_child_autofree(t)
	return t


## The menu reads over the brightest thing
## the backdrop can show (white), through the dim and the smear it is on.
func test_the_menu_reads_over_the_brightest_backdrop() -> void:
	var t := _title()
	var band := t.get_node(^"Band") as PanelContainer
	assert_eq(band.theme_type_variation, &"LineBand")
	var menu := t.get_node(^"Menu") as Control
	await wait_process_frames(2)
	assert_true(band.get_global_rect().encloses(menu.get_global_rect()), "the smear lies under every choice")
	assert_true(band.get_global_rect().encloses((t.get_node(^"Tagline") as Control).get_global_rect()))
	assert_lt(band.get_index(), menu.get_index(), "and behind them")
	for act: JournalTheme.Act in [JournalTheme.Act.HUMAN, JournalTheme.Act.SPRING]:
		var c := JournalTheme.colors(act)
		var scrim: Color = c[&"scrim"]
		var behind := Color.WHITE.lerp(Color(scrim, 1.0), scrim.a).lerp(c[&"ink"], JournalTheme.BAND_DEPTH)
		for token: StringName in [&"paper", &"glow"]:
			assert_gte(_contrast(c[token], behind), 4.5, "act %d: %s on the smear" % [act, token])


## Every word on the stories page and on the question is 16 px or more and
## 4.5 to 1 on the page.
func test_the_small_print_on_the_first_page_reads() -> void:
	var t := _title()
	t.call(&"_on_load")
	var slots := t.get_node(^"Slots") as TitleSlots
	var paper := JournalTheme.color(&"paper")
	for view in ["stories", "question"]:
		if view == "question":
			slots.call(&"_ask", SaveSystem.SLOTS[0])
		# Let the page's deferred focus land before it is read or changed.
		await wait_process_frames(2)
		var words := slots.find_children("*", "Label", true, false) + slots.find_children("*", "Button", true, false)
		assert_gt(words.size(), 2, view)
		for w: Control in words:
			if w.is_queued_for_deletion():
				continue
			assert_gte(w.get_theme_font_size(&"font_size"), 16, "%s: %s" % [view, w.get(&"text")])
			assert_gte(_contrast(w.get_theme_color(&"font_color"), paper), 4.5, "%s: %s" % [view, w.get(&"text")])
	slots.close()
	await wait_process_frames(2)


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * float(lin.call(c.r)) + 0.7152 * float(lin.call(c.g)) + 0.0722 * float(lin.call(c.b))
