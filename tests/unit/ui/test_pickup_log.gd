# gate: when:ui/hud/pickup_log.gd,ui/hud/chapter_heading.gd,ui/theme/*,ui/frame/*,systems/interaction/*,ui/satchel/satchel_hud.gd
## The log is the one place she is told what she gains (owner, 2026-11-24): a
## pickup, a first find, a recipe, a reward and a short note are all rows in
## HudLayout's PICKUPS zone, and the top of the screen is for chapter headings
## alone. Rows wait out dread and staged moments; a heading does not.
extends GutTest

var log: PickupLog
var hud: HudLayout


func before_each() -> void:
	hud = HudLayout.of(get_tree())
	StoryControl.set_mode(StoryControl.Mode.FULL)
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	ChapterHeading.clear(get_tree())
	log = PickupLog.of(get_tree())
	log.clear()
	await wait_process_frames(2)


func after_each() -> void:
	StoryControl.set_mode(StoryControl.Mode.FULL)
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	ChapterHeading.clear(get_tree())
	log.clear()


func _rows() -> Array[PickupLog.Row]:
	var out: Array[PickupLog.Row] = []
	for row in log.get_children():
		if not row.is_queued_for_deletion():
			out.append(row as PickupLog.Row)
	return out


func _name(id: StringName) -> String:
	return ItemCatalog.get_item(id).display_name


func test_there_is_one_log_and_it_lives_in_its_zone() -> void:
	assert_eq(log.get_parent(), hud.zone(HudLayout.Zone.PICKUPS))
	assert_same(PickupLog.of(get_tree()), log)
	assert_lte(HudLayout.CORNERS[HudLayout.Zone.PICKUPS][1].x + PickupLog.WIDTH as float, HudLayout.LANE_LEFT,
			"the log keeps left of the lane lines stand in")


func test_a_first_find_is_the_pickups_own_row_with_a_kicker_and_a_line() -> void:
	log.add(&"ing_bilberry", 2)
	log.find(&"ing_bilberry", &"ingredients")
	assert_eq(_rows().size(), 1, "one row, not a row and a card")
	var row := _rows()[0]
	assert_eq(row.text(), "%s  ×2" % _name(&"ing_bilberry"))
	assert_eq(row.kicker(), "New")
	assert_eq(row.line(), ItemCatalog.get_item(&"ing_bilberry").description)
	assert_eq(row.theme_type_variation, &"PickupRow")
	assert_eq((row.find_child("Kicker", true, false) as Label).theme_type_variation, &"PickupKicker")
	assert_eq((row.find_child("Line", true, false) as Label).theme_type_variation, &"PickupLine")
	log.add(&"ing_bilberry", 1)
	assert_eq(_rows().size(), 1)
	assert_eq(row.text(), "%s  ×3" % _name(&"ing_bilberry"), "more of it adds to the same row")
	assert_eq(row.kicker(), "New", "and it is still new")


func test_the_find_may_come_before_the_pickup() -> void:
	log.find(&"ing_bilberry", &"ingredients")
	log.add(&"ing_bilberry", 1)
	assert_eq(_rows().size(), 1)
	assert_eq(_rows()[0].text(), "%s  ×1" % _name(&"ing_bilberry"))


func test_a_plain_pickup_has_no_kicker_and_goes_sooner_than_one_to_read() -> void:
	log.add(&"ing_rose_hip", 1)
	log.add(&"ing_bilberry", 1)
	log.find(&"ing_bilberry", &"ingredients")
	var plain := _rows()[0].find_child("Kicker", true, false) as Label
	assert_false(plain.visible)
	assert_false((_rows()[0].find_child("Line", true, false) as Label).visible)
	await wait_seconds(PickupLog.HOLD + PickupLog.FADE + 0.3)
	assert_eq(log.lines(), PackedStringArray(["%s  ×1" % _name(&"ing_bilberry")]), "the new one is still there to read")
	assert_gt(PickupLog.HOLD_READ, PickupLog.HOLD)


func test_a_rare_find_says_so() -> void:
	log.find(&"ing_rose_gold", &"ingredients")
	assert_eq(_rows()[0].kicker(), "A shiny find!" if ItemCatalog.get_item(&"ing_rose_gold").rarity == &"shiny" else "A rare find!")


func test_a_truth_a_note_and_a_reward_are_rows() -> void:
	log.find(&"fact.suriel_home", &"truths")
	log.note("A brace of rabbits.")
	var prize := CollectionReward.new()
	prize.reward_id = &"ing_acorn"
	prize.label = "A pouch of acorns"
	prize.need = 5
	prize.tab = &"ingredients"
	log.reward(prize)
	var texts := log.lines()
	assert_eq(texts, PackedStringArray(["Something true", "A brace of rabbits.", "A pouch of acorns"]))
	assert_eq(_rows()[0].kicker(), "A new truth")
	assert_eq(_rows()[1].kicker(), "", "a note is one line and nothing else")
	assert_eq(_rows()[2].kicker(), "Collection reward")
	assert_string_starts_with(_rows()[2].line(), "A reward for 5 ")
	log.note("A brace of rabbits.")
	assert_eq(_rows().size(), 3, "the same note again is the same row")


func test_recipes_unlocked_together_share_one_row() -> void:
	log.find(&"brew_hush_draught", &"recipes")
	log.find(&"roast_venison", &"recipes")
	await wait_process_frames(2)
	assert_eq(_rows().size(), 1)
	assert_eq(_rows()[0].kicker(), "2 recipes unlocked")
	assert_string_contains(_rows()[0].line(), "her book")


func test_sketches_and_paintings_are_not_told_here() -> void:
	log.find(&"anything", &"sketches")
	log.find(&"anything", &"paintings")
	assert_eq(_rows().size(), 0)


func test_the_oldest_row_makes_room() -> void:
	for text: String in ["one", "two", "three", "four", "five"]:
		log.note(text)
	assert_eq(_rows().size(), PickupLog.MAX_ROWS)
	assert_eq(log.lines()[0], "two")


func test_dread_holds_everything_and_calm_lets_it_show_in_order() -> void:
	EventBus.mood_requested.emit(&"dread", 0.6, 2.0)
	assert_true(UiMode.quiet(get_tree()))
	log.find(&"fact.suriel_home", &"truths")
	log.add(&"ing_bilberry", 1)
	log.note("Something else.")
	await wait_seconds(0.6)
	assert_eq(_rows().size(), 0, "nothing lands while the Suriel is frightening")
	assert_eq(log.waiting(), 3, "held, not dropped")
	EventBus.mood_requested.emit(&"calm", 0.0, 2.0)
	assert_false(UiMode.quiet(get_tree()))
	await wait_process_frames(3)
	assert_eq(log.waiting(), 0)
	assert_eq(log.lines(), PackedStringArray(["Something true", "%s  ×1" % _name(&"ing_bilberry"), "Something else."]))


func test_a_staged_moment_holds_rows_but_a_heading_opens_it() -> void:
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	log.note("A rabbit. Something, at least.")
	assert_eq(_rows().size(), 0, "the note waits")
	ChapterHeading.show(get_tree(), "The Beast at the Door")
	var cards := get_tree().get_nodes_in_group(ChapterHeading.GROUP)
	assert_eq(cards.size(), 1)
	var card := cards[0] as PanelContainer
	assert_eq(card.get_parent(), hud.zone(HudLayout.Zone.NOTICE))
	assert_eq(card.theme_type_variation, &"LineBand")
	assert_eq((card.get_node(^"Title") as Label).theme_type_variation, &"ChapterTitle")
	assert_eq((card.get_node(^"Title") as Label).text, "The Beast at the Door")
	assert_eq(ChapterHeading.pending(), 1)
	assert_eq(log.waiting(), 1)
	StoryControl.set_mode(StoryControl.Mode.FULL)
	await wait_process_frames(3)
	assert_eq(log.lines(), PackedStringArray(["A rabbit. Something, at least."]), "then the note has its turn")


func test_headings_come_one_at_a_time() -> void:
	ChapterHeading.show(get_tree(), "The Wolf in the Snow")
	ChapterHeading.show(get_tree(), "Coin for the Winter")
	assert_eq(ChapterHeading.pending(), 2)
	assert_eq(get_tree().get_nodes_in_group(ChapterHeading.GROUP).size(), 1)
	ChapterHeading.clear(get_tree())
	assert_eq(ChapterHeading.pending(), 0)


## Only the chapter heading stands at the top centre, and nothing tells of a
## find anywhere but the log.
func test_nothing_else_stands_in_the_notice_zone() -> void:
	var placing := RegEx.create_from_string("Zone\\.NOTICE\\b")
	var offenders := PackedStringArray()
	for path in _scripts("res://"):
		if path.begins_with("res://tests/") or path.begins_with("res://addons/") or path == "res://ui/hud/chapter_heading.gd" \
				or path == "res://ui/frame/hud_layout.gd":
			continue
		if placing.search(FileAccess.get_file_as_string(path)):
			offenders.append(path)
	assert_eq(offenders, PackedStringArray(), "only ChapterHeading places in NOTICE")


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_scripts(dir.path_join(d)))
	return out
