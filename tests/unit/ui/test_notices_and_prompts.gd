# gate: when:ui/hud/key_prompt.gd,ui/hud/chapter_heading.gd,ui/hud/pickup_log.gd,ui/theme/*,ui/frame/*,systems/interaction/*,systems/bow/quiver_card.gd,story/act1/key_prompts.gd,story/act1/act1_milestones.gd,ui/chemistry/brew_prompt.gd,ui/market/market_prompt.gd
## Notices and prompts (plan step 8a). Every key prompt in play is one
## KeyPrompt: a slip of paper with an ink key cap that reads on snow, naming the
## key as it is bound on what she is holding. What she gains is the log's to
## tell and a chapter heading stands alone at the top (test_pickup_log.gd).
extends GutTest

const WHITE := Color(1, 1, 1)

var keeper: Node
var prompt: KeyPrompt


func before_each() -> void:
	SatchelHud.pad_active = false
	StoryControl.set_mode(StoryControl.Mode.FULL)
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	ChapterHeading.clear(get_tree())
	keeper = Node.new()
	add_child_autofree(keeper)
	prompt = KeyPrompt.make(keeper)


func after_each() -> void:
	SatchelHud.pad_active = false
	StoryControl.set_mode(StoryControl.Mode.FULL)
	ChapterHeading.clear(get_tree())


func test_a_prompt_is_a_key_cap_and_its_words_on_a_slip() -> void:
	assert_false(prompt.visible, "hidden until told")
	assert_eq(prompt.get_parent(), HudLayout.of(get_tree()).zone(HudLayout.Zone.PROMPT))
	prompt.say("E", "step in")
	assert_true(prompt.visible)
	assert_eq(prompt.theme_type_variation, &"PromptPill")
	assert_eq(prompt.text(), "E   step in")
	var row := prompt.get_node(^"Row")
	assert_eq((row.get_child(0) as Control).theme_type_variation, &"SatchelKey")
	assert_eq((row.get_child(1) as Label).theme_type_variation, &"PromptText")
	prompt.say("E", "")
	assert_eq(prompt.text(), "", "no words, no prompt")
	await wait_seconds(KeyPrompt.FADE + 0.15)
	assert_false(prompt.visible, "faded out")


func test_a_row_of_keys_and_words_alone() -> void:
	prompt.says(KeyHints.row(&"beast"))
	assert_eq(prompt.text(), "E   throw the knife  ·  Left mouse   the bracelets  ·  or stand still")
	var caps := 0
	for c in prompt.get_node(^"Row").get_children():
		if (c as Control).theme_type_variation == &"SatchelKey":
			caps += 1
	assert_eq(caps, 2, "standing still has no key")
	prompt.clear()
	assert_false(prompt.showing())


func test_keys_are_named_as_bound_on_what_she_holds() -> void:
	assert_eq(KeyPrompt.key(&"interact"), "E")
	assert_eq(KeyPrompt.key(&"aim"), "Right mouse")
	assert_eq(KeyPrompt.key(&"fire"), "Left mouse")
	assert_ne(KeyPrompt.key(&"cycle_arrow"), "")
	SatchelHud.pad_active = true
	assert_eq(KeyPrompt.key(&"interact"), "X")
	assert_eq(KeyPrompt.key(&"aim"), "LT")
	assert_eq(KeyPrompt.key(&"fire"), "RT")
	SatchelHud.pad_active = false
	for id: StringName in KeyHints.ROWS:
		for pair: Array in KeyHints.row(id):
			assert_ne(pair[1], "", "%s says what the key does" % id)
		assert_ne(KeyHints.row(id)[0][0], "", "%s opens on a key" % id)


func test_the_press_card_is_a_key_prompt_and_the_quiver_card_a_dark_pill() -> void:
	var card := PressCard.find_or_make(keeper)
	card.show_text("eat")
	assert_eq(card.text(), "E   eat")
	PressCard.hide_on(keeper)
	assert_eq(card.text(), "")
	var quiver := QuiverCard.new()
	add_child_autofree(quiver)
	assert_eq(quiver._panel.theme_type_variation, &"BowCard")
	assert_eq(quiver._label.theme_type_variation, &"BowText")
	assert_eq(quiver._panel.get_parent(), HudLayout.of(get_tree()).zone(HudLayout.Zone.BOW))


## WCAG contrast of the pills' type over white snow, in both acts.
func test_pills_read_on_snow_in_both_acts() -> void:
	for act: JournalTheme.Act in JournalTheme.Act.values():
		var c := JournalTheme.colors(act)
		var pill: Color = WHITE.lerp(c.ink, JournalTheme.PILL_DEPTH)
		var who: String = JournalTheme.Act.keys()[act]
		assert_gt(JournalTheme.contrast(c.paper, pill), 7.0, "%s: words on a dark pill" % who)
		assert_gt(JournalTheme.contrast(c.ink, c.paper), 7.0, "%s: a prompt's words on its slip, and the key on its cap" % who)
		assert_gt(JournalTheme.contrast(c.line, WHITE), 3.0, "%s: the slip's rim on snow" % who)
		assert_gt(JournalTheme.contrast(c.glow, pill), 4.5, "%s: a row's kicker in the log" % who)
		assert_gt(JournalTheme.contrast(pill, WHITE), 7.0, "%s: the pill itself on snow" % who)
	var theme := JournalTheme.build(JournalTheme.Act.HUMAN)
	for v: StringName in [&"PromptText", &"BowText", &"SatchelKeyLabel", &"PickupKicker", &"PickupLine"]:
		assert_gte(theme.get_font_size(&"font_size", v), 14, "%s is readable" % v)



## A note says what she got or what she sees, never what is left to do (R2):
## no count of what remains, no "more ... for", no "to go".
func test_no_note_counts_what_is_left_to_do() -> void:
	var callers: Array[String] = []
	_scan("res://", ".note(", callers)
	assert_gt(callers.size(), 3)
	var left := RegEx.create_from_string("(?i)%d|\\bmore\\b|\\bto go\\b|\\bleft to\\b|\\bstill need|\\bremaining\\b")
	for path in callers:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.contains("PickupLog.of(") and line.contains(".note(") and not line.strip_edges().begins_with("#"):
				assert_null(left.search(line), "%s: %s" % [path, line.strip_edges()])


## Nothing but KeyPrompt puts a piece in the PROMPT zone, and no notice or
## prompt carries its own colours, fonts or boxes.
func test_one_prompt_piece_and_no_looks_of_their_own() -> void:
	var placers: Array[String] = []
	_scan("res://", "Zone.PROMPT", placers)
	placers.erase("res://ui/frame/hud_layout.gd")
	assert_eq(placers, ["res://ui/hud/key_prompt.gd"] as Array[String], "one piece shows every key prompt")
	var off := RegEx.create_from_string("StyleBox\\w*\\.new|add_theme_(font|color|stylebox)_override|Color\\(|SystemFont|\\.ttf")
	for path: String in ["res://ui/hud/key_prompt.gd", "res://systems/interaction/press_card.gd",
			"res://systems/bow/quiver_card.gd",
			"res://story/act1/key_prompts.gd", "res://ui/chemistry/brew_prompt.gd",
			"res://ui/market/market_prompt.gd", "res://ui/hud/chapter_heading.gd", "res://ui/hud/pickup_log.gd"]:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		assert_gt(lines.size(), 1, "%s exists" % path)
		for i in lines.size():
			if lines[i].strip_edges().begins_with("#"):
				continue
			assert_null(off.search(lines[i]), "%s:%d has a look of its own: %s" % [path, i + 1, lines[i].strip_edges()])


func _scan(dir: String, word: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d in ["addons", "tests", "tools", "docs"]:
			continue
		_scan(dir.path_join(d), word, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and FileAccess.get_file_as_string(dir.path_join(f)).contains(word):
			out.append(dir.path_join(f))


## Act I's milestone layer builds (its hush wears the horror palette's pall)
## and its headings are chapter headings.
func test_act_one_milestones_are_chapter_headings() -> void:
	assert_eq(JournalTheme.color(&"pall"), JournalTheme.HORROR[&"pall"], "a token both acts share")
	var ms := Act1Milestones.new()
	add_child_autofree(ms)
	ms._quiet_for = 0.0
	assert_true(ms.trigger(&"scene:wolf_kill"))
	assert_false(ms.trigger(&"scene:wolf_kill"), "once")
	var card := get_tree().get_first_node_in_group(ChapterHeading.GROUP)
	assert_eq((card.get_node(^"Title") as Label).text, "The Wolf in the Snow")
