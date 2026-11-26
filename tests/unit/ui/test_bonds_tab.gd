# gate: when:systems/bonds/*,ui/bonds/*,data/mount/mare_page.tres,systems/mount/mare_bond.gd,data/phases/*,ui/menu/menu_tab.gd
## The Bonds page (owner, 2026-11-25): who Feyre knows and what has passed
## between them, told as dated moments in her hand, and read by one set of
## measures drawn as marks (owner, 2026-11-26); no figure is written in a line.
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


func test_everyone_has_a_portrait_and_it_changes_with_what_she_sees() -> void:
	for b in BondBook.BONDS:
		assert_true(Icons.has(Icons.BONDS, StringName(b.get("face", b.id))), "%s has a first portrait" % b.id)
		for m: Dictionary in BondBook.all_moments(b):
			if m.has("face"):
				assert_true(Icons.has(Icons.BONDS, m.face), "%s is drawn" % m.face)
	_raise("beast_claim_accepted", 2)
	assert_eq(BondBook.face(BondBook.get_bond(&"tamlin")), &"tamlin_beast")
	_raise("first_dinner_eaten", 3)
	assert_eq(BondBook.face(BondBook.get_bond(&"tamlin")), &"tamlin")
	assert_eq(BondBook.face(BondBook.get_bond(&"alis")), &"alis")
	_raise("glamour_lifted", 20)
	assert_eq(BondBook.face(BondBook.get_bond(&"alis")), &"alis_true", "her true face, once the glamour lifts")
	var tab := BondsTab.new()
	add_child_autofree(tab)
	await wait_process_frames(2)
	tab._shown()
	assert_eq(tab._face.texture, Icons.texture(Icons.BONDS, &"tamlin"))


func test_no_line_is_a_number_and_every_story_flag_is_a_real_one() -> void:
	var phases := FileAccess.get_file_as_string("res://data/phases/spring_court_phases.tres")
	var digits := RegEx.create_from_string("[0-9]")
	for b in BondBook.BONDS:
		assert_gt((b.moments as Array).size(), 0, "%s has a first moment" % b.id)
		for m: Dictionary in BondBook.all_moments(b):
			for key in ["then", "now"]:
				assert_null(digits.search(String(m.get(key, ""))), "%s: her lines carry no figure" % m.flag)
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


func _measure(id: StringName, what: StringName) -> Dictionary:
	for m in BondBook.measures(BondBook.get_bond(id)):
		if m.id == what:
			return m
	return {}


func test_everyone_is_read_by_the_same_measures_in_the_same_order() -> void:
	var legend := BondBook.MEASURES.map(func(m: Dictionary) -> StringName: return m.id)
	for b in BondBook.BONDS:
		var read := BondBook.measures(b).map(func(m: Dictionary) -> StringName: return m.id)
		assert_eq(read, legend, "%s: one legend for every bond" % b.id)
		for m in BondBook.measures(b):
			assert_gt(int(m.of), 0, "%s %s: a meter has a length" % [b.id, m.id])
			assert_between(int(m.filled), 0, int(m.of), "%s %s: never past full" % [b.id, m.id])
	for m in BondBook.MEASURES:
		assert_ne(String(m.says), "", "%s is explained in the legend" % m.id)
		assert_true(Icons.has(Icons.MEASURES, m.id), "%s has its glyph" % m.id)
		assert_true(JournalTheme.MEASURE_PAINTS.has(m.id), "%s has its own paint" % m.id)
	var paints := JournalTheme.MEASURE_PAINTS.values()
	for i in paints.size():
		for j in range(i + 1, paints.size()):
			assert_ne(paints[i], paints[j], "no two measures share a paint")


func test_her_family_has_warmth_memories_and_since_and_no_ladder() -> void:
	assert_false(_measure(&"nesta", BondBook.CLOSENESS).applies, "no ladder: the measure does not apply")
	assert_false(_measure(&"nesta", BondBook.DEEDS).applies)
	assert_eq(_measure(&"nesta", BondBook.SINCE).filled, _measure(&"nesta", BondBook.SINCE).of, "always: the whole book")
	assert_eq(_measure(&"nesta", BondBook.WARMTH).word, "Cold")
	assert_eq(_measure(&"nesta", BondBook.SINCE).word, BondBook.ALWAYS)
	assert_eq([_measure(&"nesta", BondBook.MEMORIES).filled, _measure(&"nesta", BondBook.MEMORIES).of], [1, 2])
	_raise("nesta_truth_heard", 40)
	assert_eq(_measure(&"nesta", BondBook.WARMTH).word, "Civil", "a moment can change how she is with me")
	assert_eq(_measure(&"nesta", BondBook.MEMORIES).filled, 2)
	assert_eq(_measure(&"elain", BondBook.WARMTH).filled, BondBook.WARMTH_STEPS.size())


func test_a_ladder_bond_shows_its_stage_its_deeds_and_a_passing_mood() -> void:
	_raise("beast_claim_accepted", 2)
	Relationships.check(&"tamlin")
	var tamlin := Relationships.def(&"tamlin")
	assert_eq([_measure(&"tamlin", BondBook.CLOSENESS).filled, _measure(&"tamlin", BondBook.CLOSENESS).of], [1, tamlin.stages.size()])
	assert_eq(_measure(&"tamlin", BondBook.SINCE).word, "Day 2")
	assert_eq([_measure(&"tamlin", BondBook.DEEDS).filled, _measure(&"tamlin", BondBook.DEEDS).of], [0, tamlin.deeds.size()])
	_raise("first_dinner_eaten", 3)
	Relationships.check(&"tamlin")
	assert_true(Relationships.deed(&"tamlin", &"ate_at_table"))
	assert_eq(_measure(&"tamlin", BondBook.CLOSENESS).filled, 2, "the next stage is one more mark")
	assert_eq(_measure(&"tamlin", BondBook.DEEDS).filled, 1)
	assert_eq(_measure(&"tamlin", BondBook.WARMTH).word, "Civil")
	assert_true(Relationships.start_mood(&"tamlin", Relationships.COOL, Clock.day))
	assert_eq(_measure(&"tamlin", BondBook.WARMTH).word, BondBook.COOL_FOR_NOW, "a bad day, said as one")
	assert_eq(_measure(&"tamlin", BondBook.CLOSENESS).filled, 2, "and it costs no closeness")
	assert_false(_measure(&"mare", BondBook.WARMTH).applies, "the mare has no warmth to read")
	Clock.day = 10
	assert_eq([_measure(&"tamlin", BondBook.SINCE).filled, _measure(&"tamlin", BondBook.SINCE).of], [9, 10], "in her life since day 2 of 10")


func test_the_page_draws_every_measure_as_the_same_meter() -> void:
	_raise("beast_claim_accepted", 2)
	Relationships.check(&"tamlin")
	var tab := BondsTab.new()
	add_child_autofree(tab)
	await wait_process_frames(2)
	tab._shown()
	for id: StringName in [&"tamlin", &"father"]:
		tab.show_bond(id)
		assert_eq(tab._measures.get_child_count(), BondBook.MEASURES.size(), "%s: the same rows for everyone" % id)
		for m in BondBook.measures(BondBook.get_bond(id)):
			var meter := tab._measures.get_node(String(m.id)).get_node("Meter") as ProgressBar
			assert_eq(meter.custom_minimum_size, MeterRow.SIZE, "%s %s: one size of meter" % [id, m.id])
			assert_eq(meter.theme_type_variation, JournalTheme.measure_meter(m.id), "in the measure's own paint")
			assert_eq([meter.value, meter.max_value], [float(m.filled) if m.applies else 0.0, float(m.of)])
			assert_eq(tab._measures.get_node(String(m.id)).modulate.a < 1.0, not m.applies, "faint only when it is not ours")
