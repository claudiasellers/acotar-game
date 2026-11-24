## Contract test for the one look (docs/contracts/ui-theme.md): JournalTheme
## builds the project-wide theme, in the human realm's tokens or the Spring
## Court's, and nothing else gives a Control a theme.
extends GutTest

const VARIATIONS := {
	&"PanelContainer": [
		&"SatchelCard", &"SatchelDetail", &"NotifyCard", &"SatchelChip", &"SatchelKey",
		&"QuickBarSlot", &"QuickBarSlotSelected",
	],
	&"Button": [&"SatchelTab", &"MenuTab", &"SatchelSlot", &"BookTab"],
	&"Label": [
		&"SatchelHeading", &"MenuTitle", &"PageSection", &"SatchelBody", &"SatchelSmall", &"SatchelWhere",
		&"SatchelKeyLabel", &"SatchelCount", &"SatchelPin", &"QuickBarKey", &"QuickBarCount",
		&"NotifyText", &"ThoughtText",
	],
	&"ProgressBar": [&"SatchelMeter"],
}
const TOKENS: Array[StringName] = [
	&"paper", &"paper_deep", &"ink", &"ink_soft", &"accent", &"glow", &"rare", &"danger",
	&"line", &"leather", &"scrim",
]
## The pause panel's own theme, until the pause joins the book (plan step 4).
const OWN_THEME_UNTIL_STEP_4 := [
	"res://ui/pause_menu/pause_style.gd", "res://ui/pause_menu/controls_hint.gd", "res://ui/settings_panel.gd",
]
const SKIP_DIRS := ["res://addons", "res://tests", "res://tools", "res://.godot", "res://.lanes"]

var _phase_before: StringName


func before_each() -> void:
	_phase_before = PhaseManager.current_phase


func after_each() -> void:
	PhaseManager.current_phase = _phase_before
	JournalTheme.apply()


func test_both_acts_build_every_variation() -> void:
	for act: JournalTheme.Act in [JournalTheme.Act.HUMAN, JournalTheme.Act.SPRING]:
		var t := JournalTheme.build(act)
		for base: StringName in VARIATIONS:
			for v: StringName in VARIATIONS[base]:
				assert_eq(t.get_type_variation_base(v), base, "act %d: %s" % [act, v])
		for v: StringName in VARIATIONS[&"PanelContainer"]:
			assert_true(t.has_stylebox(&"panel", v), "act %d: %s has no panel" % [act, v])
		for v: StringName in VARIATIONS[&"Button"]:
			for state in JournalTheme.BUTTON_STATES:
				assert_true(t.has_stylebox(state, v), "act %d: %s has no %s" % [act, v, state])
		for v: StringName in VARIATIONS[&"Label"]:
			assert_true(t.has_font(&"font", v) and t.has_font_size(&"font_size", v), "act %d: %s has no type" % [act, v])


func test_both_acts_carry_the_same_colour_tokens() -> void:
	for act: JournalTheme.Act in [JournalTheme.Act.HUMAN, JournalTheme.Act.SPRING]:
		var t := JournalTheme.build(act)
		assert_eq(JournalTheme.colors(act).keys(), TOKENS, "act %d tokens" % act)
		for token in TOKENS:
			assert_eq(t.get_color(token, JournalTheme.COLOR_TYPE), JournalTheme.colors(act)[token], String(token))


func test_type_is_marcellus_nunito_and_cormorant() -> void:
	assert_string_contains(JournalTheme.font("display").resource_path, "Marcellus")
	var body := JournalTheme.font("body", 700) as FontVariation
	assert_string_contains(body.base_font.resource_path, "Nunito")
	assert_eq(body.variation_opentype, {"wght": 700})
	assert_string_contains((JournalTheme.font("hand") as FontVariation).base_font.resource_path, "CormorantI")
	assert_same(JournalTheme.build(JournalTheme.Act.SPRING).default_font.get(&"base_font"), body.base_font)


func test_the_human_realm_is_warm_not_grey() -> void:
	var human := JournalTheme.colors(JournalTheme.Act.HUMAN)
	for token in [&"line", &"leather", &"accent", &"paper"]:
		var c: Color = human[token]
		assert_gt(c.r, c.b, "%s leans warm" % token)
	assert_gt((human[&"line"] as Color).s, 0.3, "the rule is brass, not smoke")


func test_it_is_the_project_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom"), JournalTheme.THEME_PATH)
	var live := ThemeDB.get_project_theme()
	assert_not_null(live)
	assert_eq(live.get_type_variation_base(&"SatchelCard"), &"PanelContainer")
	var label := Label.new()
	label.theme_type_variation = &"MenuTitle"
	add_child_autofree(label)
	assert_eq(label.get_theme_font_size(&"font_size"), 40, "a bare Control wears it with no code")


func test_the_project_theme_follows_the_story_across_the_wall() -> void:
	var live := ThemeDB.get_project_theme()
	PhaseManager.current_phase = &"p1_test"
	JournalTheme.apply()
	assert_eq(JournalTheme.act(), JournalTheme.Act.HUMAN)
	assert_eq(live.get_color(&"ink", JournalTheme.COLOR_TYPE), JournalTheme.colors(JournalTheme.Act.HUMAN)[&"ink"])
	PhaseManager.current_phase = &"p2_test"
	JournalTheme.apply()
	assert_eq(JournalTheme.act(), JournalTheme.Act.SPRING)
	assert_same(ThemeDB.get_project_theme(), live, "the same theme, rewritten in place")
	assert_eq(live.get_color(&"ink", JournalTheme.COLOR_TYPE), JournalTheme.colors(JournalTheme.Act.SPRING)[&"ink"])
	assert_eq(JournalTheme.color(&"leather"), JournalTheme.colors(JournalTheme.Act.SPRING)[&"leather"])


func test_nothing_else_makes_or_sets_a_theme() -> void:
	var bad := RegEx.create_from_string("(\\.|^\\s*)theme\\s*=[^=]|\\bTheme\\.new\\(|ThemeDB\\.")
	var hits: Array[String] = []
	_scan("res://", bad, hits)
	assert_eq(hits, [], "a theme made or set outside JournalTheme")


func _scan(dir: String, bad: RegEx, hits: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		var path := dir.path_join(sub)
		if not sub.begins_with(".") and path not in SKIP_DIRS:
			_scan(path, bad, hits)
	for file in DirAccess.get_files_at(dir):
		var path := dir.path_join(file)
		if not file.ends_with(".gd") or path == "res://ui/theme/journal_theme.gd" or path in OWN_THEME_UNTIL_STEP_4:
			continue
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			if not line.strip_edges().begins_with("#") and bad.search(line):
				hits.append("%s:%d" % [path, n])


## Type on a page reads: every book label is 16 px or more, and both inks
## reach 4.5 to 1 on both papers in both acts (the director's look pass on
## step 3).
func test_type_on_the_page_reads() -> void:
	for act: JournalTheme.Act in [JournalTheme.Act.HUMAN, JournalTheme.Act.SPRING]:
		var c := JournalTheme.colors(act)
		for ink: StringName in [&"ink", &"ink_soft"]:
			for paper: StringName in [&"paper", &"paper_deep"]:
				assert_gte(_contrast(c[ink], c[paper]), 4.5, "act %d: %s on %s" % [act, ink, paper])
		var t := JournalTheme.build(act)
		for v: StringName in [&"SatchelHeading", &"MenuTitle", &"PageSection", &"SatchelBody", &"SatchelSmall",
				&"SatchelWhere", &"SatchelKeyLabel", &"SatchelCount", &"SatchelPin"]:
			assert_gte(t.get_font_size(&"font_size", v), 16, "act %d: %s" % [act, v])
			var tint := t.get_color(&"font_color", v)
			if v != &"SatchelKeyLabel":  # paper type on a dark key cap
				assert_gte(_contrast(tint, c[&"paper"]), 4.5, "act %d: %s colour on the page" % [act, v])


## WCAG contrast ratio of two opaque colours.
func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * float(lin.call(c.r)) + 0.7152 * float(lin.call(c.g)) + 0.0722 * float(lin.call(c.b))
