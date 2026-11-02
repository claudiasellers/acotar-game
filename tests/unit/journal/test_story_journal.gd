## L54 contract: Feyre's sketchbook covers every story deed, never shows a step
## ahead of the current one, unlocks hints only by time or failed tries and
## reveals them only on request, and takes its whole look from SatchelTheme.
extends GutTest

const BOOK := "res://data/journal/story_journal.tres"
const PHASES := "res://data/phases/spring_court_phases.tres"
const PANEL_SCRIPTS := ["res://ui/journal/story_journal.gd", "res://ui/journal/journal_sketch.gd", "res://ui/journal/journal_spine.gd"]
## Names she can't know before the phase she meets or learns them in.
const NAMES := {
	"tamlin": 2, "lucien": 2, "alis": 2, "high lord": 2, "andras": 2,
	"suriel": 3, "naga": 3, "hybern": 3, "calanmai": 5, "rhysand": 99, "rhys": 99,
	"attor": 99, "bogge": 99, "puca": 99, "amarantha": 99, "clare": 7, "beddor": 7,
}

var _flags: Dictionary = {}


func _has(f: String) -> bool:
	return _flags.get(f, false)


func _book() -> JournalBook:
	return load(BOOK) as JournalBook


func before_each() -> void:
	_flags.clear()


func test_every_phase_has_a_chapter_and_every_deed_a_step() -> void:
	var book := _book()
	var set := load(PHASES) as PhaseSet
	var done := {}
	for e in book.all_entries():
		done[e.done_flag] = true
	var missing: Array = []
	for phase in set.phases:
		assert_not_null(book.chapter_for(phase.id), "chapter for %s" % phase.id)
		if phase.exit_condition:
			for f in phase.exit_condition.flags:
				if not done.has(f):
					missing.append(f)
	assert_eq(missing, [], "phase deeds with no sketchbook step")


func test_every_step_has_words_hints_and_a_known_sketch() -> void:
	for e in _book().all_entries():
		assert_ne(e.after, "", "%s after" % e.id)
		assert_ne(e.done_flag, "", "%s done flag" % e.id)
		assert_between(e.hints.size(), 1, 3, "%s hints" % e.id)
		assert_has(JournalSketch.MOTIFS, e.sketch, "%s sketch" % e.id)


func test_no_name_before_its_chapter() -> void:
	var book := _book()
	for ci in book.chapters.size():
		var c := book.chapters[ci]
		var texts := [c.title, c.opener]
		for e in c.entries:
			texts.append(e.after)
			texts.append_array(Array(e.hints))
		for t: String in texts:
			for n: String in NAMES:
				if ci < NAMES[n]:
					assert_false(t.to_lower().contains(n), "'%s' in ch%d: %s" % [n, ci, t])


func test_only_hints_name_a_key_and_only_the_last() -> void:
	for e in _book().all_entries():
		assert_false(e.after.contains("(E)") or e.after.contains("Press"), "%s after names a key" % e.id)
		for i in e.hints.size() - 1:
			assert_false(e.hints[i].contains("(E)") or e.hints[i].begins_with("Press"), "%s hint %d names a key" % [e.id, i])


func test_current_step_follows_the_flags_and_hides_the_future() -> void:
	var c := _book().chapter_for(&"p2_grounds")
	_flags["wall_crossed"] = true
	assert_eq(c.current(_has).id, &"arrive")
	_flags["fact.manor_arrived"] = true
	assert_eq(c.current(_has).id, &"bathe", "the manor bath step the user got stuck on")
	assert_eq(c.memories(_has).size(), 1, "only the arrival is behind her")
	_flags["fact.alis_bathed"] = true
	assert_eq(c.current(_has).id, &"dinner")


func test_act1_steps_borrow_the_g_thoughts() -> void:
	var c := _book().chapter_for(&"p0_winter")
	assert_eq(c.current(_has).id, &"hunt")
	assert_eq(c.current(_has).done_flag, "wolf_killed")
	_flags["fact.wolf_spotted"] = true
	assert_eq(c.current(_has).id, &"shoot", "once the wolf is seen, the shot is what she's after")
	var guide := load(JournalBook.GUIDE_PATH) as GuideBook
	for t in guide.threads:
		if t.id == &"shoot":
			assert_eq(c.current(_has).after, t.line(0))


func test_hints_unlock_by_time_or_fails_and_reveal_one_at_a_time() -> void:
	var l := HintLadder.new()
	assert_eq(l.reveal(&"x", 3), -1, "nothing before time or tries")
	l.tick(&"x", HintLadder.STUCK[0] - 1.0)
	assert_false(l.can_reveal(&"x", 3))
	l.tick(&"x", 1.0)
	assert_eq(l.unlocked(&"x", 3), 1)
	assert_eq(l.reveal(&"x", 3), 0)
	assert_eq(l.reveal(&"x", 3), -1, "the next waits")
	l.note_fail(&"x")
	l.note_fail(&"x")
	assert_eq(l.unlocked(&"x", 3), 2, "two failed tries unlock the second")
	assert_eq(l.reveal(&"x", 3), 1)
	var saved := l.to_dict()
	var back := HintLadder.new()
	back.from_dict(saved)
	assert_eq(back.shown(&"x"), 2)


func test_panel_opens_reveals_on_ask_and_closes() -> void:
	var j := StoryJournal.new(_book())
	j.phase_getter = func() -> StringName: return &"p2_grounds"
	j.has_flag = _has
	_flags["wall_crossed"] = true
	_flags["fact.manor_arrived"] = true
	add_child_autofree(j)
	assert_false(j.is_open(), "never on screen until asked for")
	j.open()
	assert_true(j.is_open())
	assert_eq(j.entry.id, &"bathe")
	assert_eq(j.think(), -1, "no hint before it unlocks")
	j.ladder.tick(&"bathe", HintLadder.STUCK[0])
	assert_eq(j.think(), 0)
	j.close()
	assert_false(j.is_open())
	assert_false(get_tree().paused)


func test_look_comes_only_from_satchel_theme() -> void:
	var colour := RegEx.create_from_string("Color\\(|Color8\\(|\\.ttf|\\.otf|PauseStyle\\.(PLUM|ROSE|GOLD|PEARL|BLUSH)")
	for path: String in PANEL_SCRIPTS:
		var src := FileAccess.get_file_as_string(path)
		var hits := []
		for line in src.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			if colour.search(line) and not line.contains("Color(ink") and not line.contains("Color(tint") \
					and not line.contains("Color(hole") and not line.contains("Color(shine") \
					and not line.contains("Color(SatchelTheme"):
				hits.append(line.strip_edges())
		assert_eq(hits, [], "%s names its own colour or font" % path)
