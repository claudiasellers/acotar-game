# gate: when:ui/menu/open_tin.gd,ui/menu/book_kit.gd,ui/menu/meter_row.gd,ui/theme/*,ui/chemistry/brew_menu.gd,ui/mare/mare_tending_view.gd
extends GutTest
## The places she works with her hands open her paint tin along the foot of
## the screen (owner, 2026-11-26: "The Open Tin"): one kit draws the tray, its
## pans, wells, lid and key caps, and no station frames itself.

const STATIONS: Array[String] = ["res://ui/chemistry/brew_menu.gd", "res://ui/mare/mare_tending_view.gd"]
const SCREEN := Vector2(1920, 1080)

var host: Control
var tin: OpenTin


func before_each() -> void:
	host = Control.new()
	host.size = SCREEN
	add_child_autofree(host)
	tin = OpenTin.lay(host)


func test_the_tray_lies_along_the_foot_and_leaves_the_world_clear() -> void:
	var left := tin.compartment(300.0)
	OpenTin.head(left, "Stillroom", "0 / 27 brews")
	tin.compartment().add_child(OpenTin.section("What's in my bags"))
	await wait_process_frames(2)
	var tray := tin.tray.get_rect()
	assert_almost_eq(tray.position.x, OpenTin.EDGE.x, 0.5, "in from the left")
	assert_almost_eq(SCREEN.x - tray.end.x, OpenTin.EDGE.x, 0.5, "and the right")
	assert_almost_eq(SCREEN.y - tray.end.y, OpenTin.EDGE.y, 0.5, "and up from the foot")
	assert_lte(tray.size.y, OpenTin.MAX_HEIGHT)
	assert_eq(tin.clear_height(), tray.position.y, "everything above the tray is the world's")
	assert_false(tin.covers(Vector2(960, tray.position.y - 10.0)))
	assert_true(tin.covers(Vector2(960, tray.position.y + 10.0)))
	assert_eq(tin.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a click above the tray goes through to the station")
	assert_eq(tin.tray.mouse_filter, Control.MOUSE_FILTER_STOP, "a click on the tray does not")
	assert_null(tin.get_node_or_null(^"Scrim"), "a station the world turns under takes no scrim")
	assert_eq(tin.row.get_child_count(), 3, "two compartments and the rule between them")
	assert_true(tin.row.get_child(1) is OpenTin.Rule)
	assert_eq((left.get_node("Title") as Label).theme_type_variation, &"TinTitle")
	assert_eq((left.get_node("Sub") as Label).text, "0 / 27 brews")


func test_a_station_that_stops_the_world_takes_a_thin_scrim() -> void:
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var dim := OpenTin.lay(layer, true)
	assert_eq(layer.layer, UiLayers.SCREEN, "on the screen layer")
	var scrim := dim.get_node_or_null(^"Scrim") as ColorRect
	assert_not_null(scrim)
	assert_almost_eq(scrim.color.a, JournalTheme.color(&"scrim").a * OpenTin.SCRIM_DEPTH, 0.001, "thin, so the bench reads")
	assert_eq(scrim.get_index(), 0, "under the tin")


func test_the_chosen_pan_stands_proud_and_is_named_on_the_tag() -> void:
	var col := tin.compartment()
	var pans := HBoxContainer.new()
	pans.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(pans)
	var a := OpenTin.pan(BookKit.picture(Icons.texture(Icons.TEND, &"care"), Vector2.ZERO), "Brush and treats")
	var b := OpenTin.pan(BookKit.picture(Icons.texture(Icons.TEND, &"mane"), Vector2.ZERO), "Mane")
	pans.add_child(a)
	pans.add_child(b)
	await wait_process_frames(2)
	assert_eq(a.theme_type_variation, JournalTheme.TIN_PAN)
	assert_eq(a.focus_mode, Control.FOCUS_ALL, "a pad can reach it")
	assert_eq(a.radius(), OpenTin.Pan.DISC * 0.5)
	assert_true((a.get_node("Name") as Label).visible, "its name is under it")
	var seat := a.disc_centre().y
	a.choose(true)
	tin.name_pan(a)
	await wait_process_frames(2)
	assert_eq(a.radius(), OpenTin.Pan.DISC_CHOSEN * 0.5, "chosen, it grows")
	assert_lt(a.disc_centre().y, seat, "and stands proud")
	assert_gte(a.disc_centre().y - a.radius(), -1.0, "inside its own room")
	assert_false((a.get_node("Name") as Label).visible, "its name moves to the tag")
	var tag := tin.get_node("Tag") as Label
	assert_true(tag.visible)
	assert_eq(tag.text, "Brush and treats")
	assert_true(tag.uppercase)
	assert_almost_eq(tag.get_rect().get_center().y, tin.clear_height(), 1.0, "on the tray's top edge")
	assert_almost_eq(tag.get_rect().get_center().x, a.global_position.x + a.disc_centre().x, 1.0, "over its pan")
	assert_eq(b.radius(), OpenTin.Pan.DISC * 0.5, "the others stay seated")
	tin.name_pan(null)
	assert_false(tag.visible)


func test_a_small_pan_carries_a_count_and_says_when_it_is_in_the_pot() -> void:
	var pan := OpenTin.pan(BookKit.picture(Icons.texture(Icons.TEND, &"care"), Vector2.ZERO), "", true)
	tin.compartment().add_child(pan)
	assert_eq(pan.radius(), OpenTin.Pan.DISC_SMALL * 0.5)
	assert_eq(pan.custom_minimum_size.y, OpenTin.Pan.small_height())
	assert_false(pan.toggle_mode, "it is pressed, not chosen")
	pan.count("×3")
	assert_eq((pan.get_node("Count") as Label).text, "×3")
	assert_eq((pan.get_node("Count") as Label).theme_type_variation, JournalTheme.COUNT_BADGE)
	assert_null(pan.get_node_or_null(^"InPot"))
	pan.in_pot = true
	assert_true((pan.get_node("InPot") as Label).visible)
	pan.in_pot = false
	assert_false((pan.get_node("InPot") as Label).visible)
	pan.wished = true
	assert_true(pan.disabled, "a wished-for thing cannot be pressed")
	assert_almost_eq(pan.modulate.a, OpenTin.Pan.WISHED_ALPHA, 0.001)


func test_wells_lid_slip_and_key_caps() -> void:
	var plain := OpenTin.well()
	var ringed := OpenTin.well(true)
	assert_eq(plain.theme_type_variation, &"TinWell")
	assert_eq(ringed.theme_type_variation, &"TinWellChosen")
	plain.free()
	ringed.free()
	var b := OpenTin.button("Make it")
	assert_eq(b.theme_type_variation, &"SatchelTab")
	assert_eq(b.focus_mode, Control.FOCUS_ALL)
	b.free()
	tin.compartment(300.0)
	assert_false(tin.has_lid())
	var page := tin.lid(372.0)
	page.add_child(BookKit.label("What I know of her", &"SatchelBody"))
	await wait_process_frames(2)
	var lid := tin.get_node("Lid") as PanelContainer
	assert_eq(lid.theme_type_variation, &"TinLid")
	assert_almost_eq(lid.get_rect().end.y, tin.clear_height() + OpenTin.LID_SEAT, 1.0, "it stands on the tray")
	assert_almost_eq(lid.position.x, tin.tray.position.x + OpenTin.LID_IN, 1.0, "at its left end")
	assert_lte(lid.size.y, OpenTin.LID_MAX)
	assert_true(tin.covers(lid.get_rect().get_center()), "the lid is the tin's, not the world's")
	assert_eq(tin.lid(372.0), page, "asked again, the same lid")
	assert_eq(page.get_child_count(), 0, "wiped")
	for i in 60:
		page.add_child(BookKit.label("line %d" % i, &"SatchelBody"))
	await wait_process_frames(2)
	assert_almost_eq(lid.size.y, OpenTin.LID_MAX, 1.0, "a long read scrolls inside the lid")
	tin.drop_lid()
	await wait_process_frames(2)
	assert_false(tin.has_lid())
	var note := tin.slip(520.0)
	note.add_child(BookKit.label("Made", &"PageSection"))
	await wait_process_frames(2)
	var slip := tin.get_node("Slip") as PanelContainer
	assert_almost_eq(slip.get_rect().end.y, tin.clear_height() - OpenTin.SLIP_UP, 1.0, "above the tray")
	assert_almost_eq(slip.get_rect().end.x, tin.tray.get_rect().end.x - OpenTin.LID_IN, 1.0, "at its right end")
	tin.drop_slip()
	assert_false(tin.has_slip())
	var hints := OpenTin.hints([["Esc", "Step away"], ["E", "Brew"]])
	assert_eq(hints.get_child_count(), 2)
	var cap := hints.get_child(0).get_child(0) as PanelContainer
	assert_eq(cap.theme_type_variation, &"TinKey", "a paper cap, so it reads on the tin")
	assert_eq((cap.get_node("Key") as Label).theme_type_variation, &"TinKeyLabel")
	hints.free()
	var pressed: Array = []
	var done := OpenTin.hint_button("T", "Done")
	add_child_autofree(done)
	done.pressed.connect(func() -> void: pressed.append(true))
	assert_gt(done.custom_minimum_size.x, 40.0, "as big as its cap and word")
	done.pressed.emit()
	assert_eq(pressed.size(), 1)


func test_a_meter_on_the_tin_is_the_same_meter() -> void:
	var line := MeterRow.on_tin(MeterRow.make(Icons.texture(Icons.TEND, &"care"), "Coat", &"SatchelMeter", 0.5, 1.0, "Dull"))
	add_child_autofree(line)
	var meter := line.get_node("Meter") as ProgressBar
	assert_eq(meter.custom_minimum_size, MeterRow.SIZE, "one size of meter everywhere")
	assert_eq(meter.theme_type_variation, &"SatchelMeter", "its fill is still its own")
	assert_true(meter.has_theme_stylebox_override(&"background"), "its track shows the tin through")
	assert_eq((line.get_node("Name") as Label).theme_type_variation, &"TinLabel")
	assert_eq((line.get_node("Word") as Label).theme_type_variation, &"TinWord")


func test_no_station_frames_itself() -> void:
	var bad := RegEx.create_from_string(
			"LoosePage\\.|&\"scrim\"|&\"SatchelKey\"|&\"SatchelCard\"|&\"TinTray\"|&\"TinWell|&\"TinLid\"|&\"TinKey\"|StyleBoxFlat\\.new\\(\\)|CenterContainer\\.new\\(\\)")
	for path in STATIONS:
		var src := FileAccess.get_file_as_string(path)
		assert_true(src.contains("OpenTin.lay("), "%s opens the tin" % path)
		var hits := []
		for line in src.split("\n"):
			if not line.strip_edges().begins_with("#") and bad.search(line):
				hits.append(line.strip_edges())
		assert_eq(hits, [], "%s builds a tray, a well, a lid, a scrim or key caps of its own. Fix: OpenTin.lay(parent), tin.compartment(), OpenTin.pan / well / button / hints, tin.lid(width), tin.slip(width)" % path)


## Type on the tin holds 7 to 1 on its ink, and the key cap's letter on its
## paper, in both acts (the Menu B spec's floor).
func test_type_on_the_tin_reads() -> void:
	for act: JournalTheme.Act in [JournalTheme.Act.HUMAN, JournalTheme.Act.SPRING]:
		var c := JournalTheme.colors(act)
		var t := JournalTheme.build(act)
		for v: StringName in [&"TinTitle", &"TinSub", &"TinSection", &"TinLabel", &"TinHint", &"TinWord", &"TinTag"]:
			assert_gte(t.get_font_size(&"font_size", v), 15, "act %d: %s" % [act, v])
			assert_gte(JournalTheme.contrast(t.get_color(&"font_color", v), c[&"ink"]), 7.0, "act %d: %s on the tin" % [act, v])
		assert_gte(JournalTheme.contrast(t.get_color(&"font_color", &"TinKeyLabel"), c[&"paper"]), 7.0, "act %d: the cap's letter" % act)
		assert_eq((t.get_stylebox(&"panel", &"TinTray") as StyleBoxFlat).bg_color, c[&"ink"], "the tray is the strap's ink")
		assert_eq((t.get_stylebox(&"panel", &"TinWell") as StyleBoxFlat).bg_color, c[&"paper"], "a well is her paper")
