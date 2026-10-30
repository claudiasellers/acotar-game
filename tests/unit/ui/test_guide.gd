extends GutTest

const BOOK := preload("res://data/guide/act1_guide.tres")
const SETTINGS_PATH := "user://test_guide_settings.cfg"
## Every Act I flag state in story order, up to the first evening past the wall.
const LADDER: Array[String] = ["wolf_killed", "fact.wolf_skinned", "pelt_sold",
	"beast_claim_accepted", "wall_crossed", "first_dinner_eaten"]
## The thread each prefix of LADDER should resolve to ("" = deliberate silence).
const EXPECTED: Array[String] = ["hunt", "skin", "sell", "home", "", "quiet", ""]

var _flags: Dictionary = {}


func before_each() -> void:
	_flags.clear()


func _has(flag: String) -> bool:
	return _flags.get(flag, false)


func _set_through(count: int) -> void:
	_flags.clear()
	for i in count:
		_flags[LADDER[i]] = true


func _director() -> GuideDirector:
	var d := GuideDirector.new(BOOK)
	d.refresh(_has)
	return d


func _run(d: GuideDirector, seconds: float, moved_per_s: float = 0.0, can_show: bool = true) -> Array:
	var shows: Array = []
	var t := 0.0
	while t < seconds:
		var r := d.tick(0.5, moved_per_s * 0.5, false, can_show)
		if not r.is_empty():
			shows.append([t + 0.5, r.tier])
		t += 0.5
	return shows


func test_every_act1_state_picks_one_need_or_silence() -> void:
	for i in EXPECTED.size():
		_set_through(i)
		var picked := BOOK.pick(_has)
		assert_eq(String(picked.id) if picked else "", EXPECTED[i], "after %d deeds" % i)


func test_every_need_has_three_tiers() -> void:
	for t in BOOK.threads:
		assert_eq(t.tier_count(), 3, String(t.id))


func test_no_line_names_what_she_has_not_met() -> void:
	for t in BOOK.threads:
		for line in t.lines:
			for word in t.forbidden_words:
				assert_false(line.to_lower().contains(word), "%s: '%s' in '%s'" % [t.id, word, line])


func test_no_line_reads_like_a_quest_log() -> void:
	var regex := RegEx.create_from_string("(?i)(\\d+\\s*m\\b|objective|quest|go to|[✓✔→]|\\n)")
	for t in BOOK.threads:
		for line in t.lines:
			assert_null(regex.search(line), "%s: '%s'" % [t.id, line])


func test_opening_thought_within_25_s() -> void:
	var shows := _run(_director(), 60.0)
	assert_eq(shows.size(), 1)
	assert_lt(shows[0][0], 25.0)
	assert_eq(shows[0][1], 0)


func test_nothing_during_scripted_moments_or_dread() -> void:
	assert_eq(_run(_director(), 600.0, 0.0, false).size(), 0)


func test_stall_nudges_wait_and_escalate() -> void:
	var d := _director()
	var shows := _run(d, 900.0)
	assert_eq(shows.size(), 3, str(shows))
	assert_gte(shows[1][0], GuideDirector.STALL)
	assert_gte(shows[2][0] - shows[1][0], GuideDirector.COOLDOWN)
	assert_eq([shows[1][1], shows[2][1]], [1, 2])


func test_progress_resets_the_stall_clock() -> void:
	var d := _director()
	_run(d, 230.0)
	d.note_progress()
	assert_eq(_run(d, 200.0).size(), 0)


func test_wandering_counts_like_idling() -> void:
	var d := _director()
	_run(d, 30.0)
	# Always moving (never idle), 2 m/s: the 400 m wander rule fires instead.
	var shows := _run(d, 300.0, 2.0)
	assert_eq(shows.size(), 1)


func test_new_need_announces_its_first_line() -> void:
	var d := _director()
	_run(d, 30.0)
	_flags["wolf_killed"] = true
	assert_true(d.refresh(_has))
	var shows := _run(d, 20.0)
	assert_eq(shows.size(), 1)
	assert_eq(d.thread.id, &"skin")
	assert_lt(shows[0][0], GuideDirector.NEW_DELAY + 1.0)


func test_on_demand_then_think_harder_then_close() -> void:
	var d := _director()
	assert_eq(d.on_demand().tier, 0)
	assert_eq(d.think_harder(0).tier, 1)
	assert_eq(d.think_harder(1).tier, 2)
	assert_true(d.think_harder(2).is_empty())
	assert_eq(d.on_demand().tier, 2, "recall keeps the plainest earned")


func test_settings_persist_three_modes() -> void:
	var saved := GuideSettings.settings_path
	GuideSettings.settings_path = SETTINGS_PATH
	for mode in [GuideSettings.Mode.ASK, GuideSettings.Mode.OFF, GuideSettings.Mode.AUTO]:
		GuideSettings.set_mode(mode)
		GuideSettings.load_settings()
		assert_eq(GuideSettings.get_mode(), mode)
	assert_eq(GuideSettings.LABELS.size(), 3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	GuideSettings.settings_path = saved
	GuideSettings.load_settings()


func test_card_shows_one_line_and_obeys_off() -> void:
	WorldState.clear()
	var journal := GuideJournal.new(BOOK)
	add_child_autofree(journal)
	journal.press()
	assert_true(journal.showing)
	assert_eq(journal._line.text, BOOK.threads[0].lines[0])
	assert_eq(journal._line.text.count("\n"), 0)
	journal.press()
	assert_eq(journal.shown_tier, 1)
	journal.on_mode_changed(GuideSettings.Mode.OFF)
	assert_false(journal.showing)
	journal.on_mode_changed(GuideSettings.get_mode())
