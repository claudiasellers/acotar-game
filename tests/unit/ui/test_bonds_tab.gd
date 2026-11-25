# gate: when:systems/bonds/*,ui/bonds/*,data/mount/mare_page.tres,systems/mount/mare_bond.gd,data/phases/*,ui/menu/menu_tab.gd
## The Bonds page (owner, 2026-11-25): who Feyre knows and what has passed
## between them, told as dated moments in her hand and never as a number.
## BondBook reads story flags; nobody is listed before they come into her
## life; the mare's memories are her own page's.
extends GutTest

var _day: int


func before_each() -> void:
	WorldState.clear()
	WorldDeltas.clear()
	_day = Clock.day


func after_each() -> void:
	Clock.day = _day
	WorldState.clear()
	WorldDeltas.clear()


func _ids() -> Array:
	return BondBook.known().map(func(b: Dictionary) -> StringName: return b.id)


func _raise(flag: String, day: int) -> void:
	Clock.day = day
	WorldState.set_flag(flag, true)
	BondBook.stamp(flag, true)


func test_only_her_family_is_known_at_the_start() -> void:
	assert_eq(_ids(), [&"nesta", &"elain", &"father"])
	_raise("beast_claim_accepted", 2)
	assert_has(_ids(), &"tamlin")
	assert_does_not_have(_ids(), &"lucien", "nobody is listed before they come into her life")


func test_what_she_calls_him_changes_when_she_learns_his_name() -> void:
	_raise("beast_claim_accepted", 2)
	var tamlin := BondBook.get_bond(&"tamlin")
	assert_eq(BondBook.called(tamlin), "The beast")
	_raise("first_dinner_eaten", 3)
	assert_eq(BondBook.called(tamlin), "Tamlin")


func test_moments_keep_their_day_and_run_oldest_first() -> void:
	_raise("beast_claim_accepted", 2)
	_raise("first_dinner_eaten", 3)
	_raise("tamlin_wound_dressed", 9)
	_raise("puca_resisted", 5)
	var days := BondBook.moments(BondBook.get_bond(&"tamlin")).map(func(m: Dictionary) -> int: return m.day)
	assert_eq(days, [2, 3, 5, 9])
	Clock.day = 30
	BondBook.stamp("puca_resisted", true)
	assert_eq(BondBook.day_of("puca_resisted"), 5, "the first day is the one kept")
	BondBook.stamp("fact.not_a_moment", true)
	assert_eq(BondBook.day_of("fact.not_a_moment"), 0, "only moments are kept")


func test_these_days_is_the_newest_moment_that_says() -> void:
	_raise("first_dinner_eaten", 3)
	var lucien := BondBook.get_bond(&"lucien")
	assert_string_contains(BondBook.these_days(lucien), "despises")
	_raise("bogge_survived", 4)
	_raise("suriel_bound", 8)
	assert_string_contains(BondBook.these_days(lucien), "patrol", "a moment that says nothing new leaves the last word standing")


func test_the_mare_keeps_her_own_pages_memories() -> void:
	_raise("wall_crossed", 2)
	var mare := BondBook.get_bond(&"mare")
	assert_eq(BondBook.called(mare), "The white mare", "she has no name")
	assert_eq(BondBook.moments(mare).size(), 1)
	_raise("first_dinner_eaten", 3)
	_raise("fact.mare_ridden", 4)
	_raise(MareBond.DID_PREFIX + "answered", 6)
	var page := load(BondBook.MARE_PAGE) as MarePageData
	var past := BondBook.moments(mare)
	assert_eq(past[-1].then, page.note(&"answered").memory)
	assert_eq(past[-1].day, 6)
	assert_eq(BondBook.these_days(mare), page.now[MareBond.tier()])


func test_no_line_is_a_number_and_every_story_flag_is_a_real_one() -> void:
	var phases := FileAccess.get_file_as_string("res://data/phases/spring_court_phases.tres")
	var digits := RegEx.create_from_string("[0-9]")
	for b in BondBook.BONDS:
		assert_gt((b.moments as Array).size(), 0, "%s has a first moment" % b.id)
		for m: Dictionary in BondBook.all_moments(b):
			for key in ["then", "now"]:
				assert_null(digits.search(String(m.get(key, ""))), "%s: a bond is never a number (R2)" % m.flag)
			assert_ne(String(m.then), "")
			if m.flag != "" and not String(m.flag).begins_with("fact."):
				assert_string_contains(phases, "\"%s\"" % m.flag, "a phase flag that exists")


func test_the_page_lists_who_she_knows_and_turns_to_one() -> void:
	_raise("beast_claim_accepted", 2)
	_raise("first_dinner_eaten", 3)
	var tab := BondsTab.new()
	add_child_autofree(tab)
	await wait_process_frames(2)
	assert_true(tab.has_news(), "something has passed that she has not looked at")
	tab._shown()
	assert_false(tab.has_news())
	assert_eq(tab._rows.size(), BondBook.known().size())
	assert_eq(tab.showing, &"tamlin", "it opens on the first she knows")
	assert_eq(tab._name.text, "Tamlin")
	assert_eq(tab._past.get_child_count(), 2)
	(tab._rows[&"alis"] as Button).pressed.emit()
	assert_eq(tab._name.text, "Alis")
	assert_string_contains(tab._days.text, "Brisk")
	var first := tab._past.get_child(0)
	assert_eq((first.get_child(0) as Label).text, "Day 3")
	WorldState.set_flag("gallery_opened", true)
	assert_true(tab.has_news(), "and the mark comes back when something more does")


func test_a_flag_coming_up_in_play_is_stamped_by_the_page() -> void:
	var tab := BondsTab.new()
	add_child_autofree(tab)
	Clock.day = 7
	WorldState.set_flag("stranger_met", true)
	assert_eq(BondBook.day_of("stranger_met"), 7)
