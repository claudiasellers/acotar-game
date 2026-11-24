# gate: when:ui/hud/key_prompt.gd,ui/collection_book/find_card.gd,ui/theme/*,ui/frame/*,systems/interaction/*,systems/bow/quiver_card.gd,story/act1/key_prompts.gd,story/act1/act1_milestones.gd,ui/chemistry/brew_prompt.gd,ui/market/market_prompt.gd
## Notices and prompts (plan step 8a). Every key prompt in play is one
## KeyPrompt: a dark pill with a paper key cap that reads on snow, naming the
## key as it is bound on what she is holding. Every notice goes through one
## queue: finds, rewards and notes are dark pills that wait out dread, and a
## chapter heading is a title that does not wait.
extends GutTest

const WHITE := Color(1, 1, 1)

var keeper: Node
var prompt: KeyPrompt


func before_each() -> void:
	SatchelHud.pad_active = false
	StoryControl.set_mode(StoryControl.Mode.FULL)
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	FindCard.clear(get_tree())
	keeper = Node.new()
	add_child_autofree(keeper)
	prompt = KeyPrompt.make(keeper)


func after_each() -> void:
	SatchelHud.pad_active = false
	StoryControl.set_mode(StoryControl.Mode.FULL)
	FindCard.clear(get_tree())


func test_a_prompt_is_a_key_cap_and_its_words_on_a_dark_pill() -> void:
	assert_false(prompt.visible, "hidden until told")
	assert_eq(prompt.get_parent(), HudLayout.of(get_tree()).zone(HudLayout.Zone.PROMPT))
	prompt.say("E", "step in")
	assert_true(prompt.visible)
	assert_eq(prompt.theme_type_variation, &"PromptPill")
	assert_eq(prompt.text(), "E   step in")
	var row := prompt.get_node(^"Row")
	assert_eq((row.get_child(0) as Control).theme_type_variation, &"PromptKey")
	assert_eq((row.get_child(1) as Label).theme_type_variation, &"PromptText")
	prompt.say("E", "")
	assert_eq(prompt.text(), "", "no words, no prompt")
	await wait_seconds(KeyPrompt.FADE + 0.15)
	assert_false(prompt.visible, "faded out")


func test_a_row_of_keys_and_words_alone() -> void:
	prompt.says(KeyPrompts.row(&"beast"))
	assert_eq(prompt.text(), "E   throw the knife  ·  Left mouse   the bracelets  ·  or stand still")
	var caps := 0
	for c in prompt.get_node(^"Row").get_children():
		if (c as Control).theme_type_variation == &"PromptKey":
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
	for id: StringName in KeyPrompts.PROMPTS:
		for pair: Array in KeyPrompts.row(id):
			assert_ne(pair[1], "", "%s says what the key does" % id)
		assert_ne(KeyPrompts.row(id)[0][0], "", "%s opens on a key" % id)


func test_the_press_card_and_the_quiver_card_wear_the_same_pill() -> void:
	var card := PressCard.find_or_make(keeper)
	card.show_text("eat")
	assert_eq(card.text(), "E   eat")
	PressCard.hide_on(keeper)
	assert_eq(card.text(), "")
	var quiver := QuiverCard.new()
	add_child_autofree(quiver)
	assert_eq(quiver._panel.theme_type_variation, &"PromptPill")
	assert_eq(quiver._label.theme_type_variation, &"PromptText")
	assert_eq(quiver._panel.get_parent(), HudLayout.of(get_tree()).zone(HudLayout.Zone.BOW))


## WCAG contrast of the pills' type over white snow, in both acts.
func test_pills_read_on_snow_in_both_acts() -> void:
	for act: JournalTheme.Act in JournalTheme.Act.values():
		var c := JournalTheme.colors(act)
		var pill: Color = WHITE.lerp(c.ink, JournalTheme.PILL_DEPTH)
		var who: String = JournalTheme.Act.keys()[act]
		assert_gt(_contrast(c.paper, pill), 7.0, "%s: words on the pill" % who)
		assert_gt(_contrast(c.ink, c.paper), 7.0, "%s: the key on its cap" % who)
		assert_gt(_contrast(c.glow, pill), 4.5, "%s: a notice's kicker" % who)
		assert_gt(_contrast(pill, WHITE), 7.0, "%s: the pill itself on snow" % who)
	var theme := JournalTheme.build(JournalTheme.Act.HUMAN)
	for v: StringName in [&"PromptText", &"PromptKeyLabel", &"NoticeKicker", &"NoticeBody"]:
		assert_gte(theme.get_font_size(&"font_size", v), 14, "%s is readable" % v)


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)


func _cards() -> Array[Node]:
	return get_tree().get_nodes_in_group(FindCard.GROUP).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())


func test_a_find_is_a_dark_pill_and_a_rare_one_has_a_gold_rim() -> void:
	FindCard.show_find(get_tree(), &"ing_bilberry", &"ingredients")
	var card := _cards()[0] as PanelContainer
	assert_eq(card.theme_type_variation, &"NoticeCard")
	assert_eq(card.get_parent(), HudLayout.of(get_tree()).zone(HudLayout.Zone.NOTICE))
	assert_eq((card.find_child("Title", true, false) as Label).theme_type_variation, &"NoticeTitle")
	var line := card.find_child("Line", true, false) as Label
	assert_eq(line.theme_type_variation, &"NoticeBody")
	assert_between(line.custom_minimum_size.x, 40.0, FindCard.LINE_WIDTH, "the line is as wide as its words, to a limit")
	FindCard.clear(get_tree())
	await wait_frames(2)
	FindCard.show_find(get_tree(), &"ing_rose_gold", &"ingredients")
	assert_eq((_cards()[0] as PanelContainer).theme_type_variation, &"NoticeRare")


func test_a_heading_is_a_title_that_does_not_wait_on_a_staged_moment() -> void:
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	FindCard.note(get_tree(), "A rabbit. Something, at least.")
	assert_eq(_cards().size(), 0, "the note waits")
	FindCard.heading(get_tree(), "The Beast at the Door")
	assert_eq(_cards().size(), 1)
	var card := _cards()[0] as PanelContainer
	assert_eq(card.theme_type_variation, &"LineBand")
	var title := card.get_node(^"Title") as Label
	assert_eq(title.theme_type_variation, &"ChapterTitle")
	assert_eq(title.text, "The Beast at the Door")
	assert_eq(FindCard.pending(), 2, "the note is still queued behind it")
	StoryControl.set_mode(StoryControl.Mode.FULL)
	await wait_seconds(FindCard.HEADING_HOLD + FindCard.HEADING_FADE * 2.0 + 0.3)
	assert_eq(_cards().size(), 1, "then the note has its turn")
	assert_eq((_cards()[0] as PanelContainer).theme_type_variation, &"NoticeCard")


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
			"res://ui/market/market_prompt.gd", "res://ui/collection_book/find_card.gd"]:
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
