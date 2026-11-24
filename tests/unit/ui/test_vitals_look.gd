# gate: when:ui/hud/vitals/*,ui/theme/*
## The vitals pieces in their final art (plan step 8b): every colour is a
## JournalTheme token (test_one_look.gd keeps that for every UI script), a
## status is a pan like the paint tin's (dark and cracked for a bad one) and the health bar says how much she has in figures.
extends GutTest


func test_both_acts_carry_the_same_vitals_tokens() -> void:
	var human: Dictionary = JournalTheme.VITALS[JournalTheme.Act.HUMAN]
	var spring: Dictionary = JournalTheme.VITALS[JournalTheme.Act.SPRING]
	assert_eq(human.keys(), spring.keys())
	for token: StringName in human:
		assert_eq(JournalTheme.color(token), JournalTheme.VITALS[JournalTheme.act()][token], "color() answers for %s" % token)
		assert_false(JournalTheme.colors(JournalTheme.Act.HUMAN).has(token), "%s is not also an act token" % token)
	assert_ne(human.health, spring.health, "her blood is duller in the human realm")


func test_the_bar_and_the_pans_draw_without_error() -> void:
	var bar := VitalsHealthBar.new()
	add_child_autofree(bar)
	bar.points = 58
	bar.set_health(0.58)
	bar.venom = 0.5
	bar.healing = true
	var row := VitalsStatusRow.new()
	add_child_autofree(row)
	var list: Array[Dictionary] = []
	for tag: StringName in [&"heal", &"at_ease", &"drowsy", &"chilled", &"venom", &"warm", &"swift"]:
		list.append({"tag": tag, "magnitude": 0.6, "seconds_left": 2.0, "total": 40.0})
	row.set_statuses(list)
	assert_eq(row.shown.size(), VitalsStatusRow.MAX_SHOWN)
	assert_eq(row.overflow, 2)
	await wait_process_frames(4)
	assert_eq(get_theme_font_size_of(&"VitalsFigure"), 15)
	assert_eq(VitalsStatusRow.CRACKS.size(), 4, "a bad status's pan is cracked")


func get_theme_font_size_of(variation: StringName) -> int:
	return ThemeDB.get_project_theme().get_font_size(&"font_size", variation)
