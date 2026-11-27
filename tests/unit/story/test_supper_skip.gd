## The supper talk offers the film's skip (T164): skipping the talk lands in
## the same story state as playing it through (flags, lines heard, the beat
## after it), the nudge "Rest, Feyre" still plays, and the offer shows only
## during the talk.
extends GutTest

var director: DialogueDirector


func before_each() -> void:
	WorldState.clear()
	PhaseManager.current_phase = &"p1_wolf_and_crossing"
	director = DialogueDirector.new()
	director.auto_tick = false
	director.books_dir = ""
	director.add_book(load("res://data/dialogue/lines/cottage_evening.tres") as DialogueBook)
	director.show_fn = func(_who: String, _text: String, _inner: bool) -> float:
		return 1.0
	add_child_autofree(director)


func _supper() -> CottageSupper:
	var s := CottageSupper.new()
	s.auto_tick = false
	add_child_autofree(s)
	WorldState.set_flag("pelt_sold", true)
	WorldState.set_flag(CottageEvening.SAT, true)
	assert_true(s.start())
	return s


func _finish(s: CottageSupper) -> void:
	for i in 400:
		if not s.running:
			return
		director._process(0.5)
		s.tick(0.5)


func _state() -> Dictionary:
	var log: Array = director.spoken_log.duplicate()
	log.sort()
	return {"flags": WorldState.all_flags().duplicate(), "heard": log}


func test_skipping_lands_where_playing_through_does() -> void:
	var played := _supper()
	_finish(played)
	assert_false(played.running)
	var want := _state()
	assert_true(WorldState.has_flag(CottageEvening.SUPPER))
	played.free()
	WorldState.clear()
	WorldState.set_flag("pelt_sold", true)
	director.spoken_log.clear()
	director._said_at.clear()
	var s := _supper()
	director._process(0.5)
	s.tick(0.5)
	assert_not_null(s.skip_control, "the offer is up during the talk")
	s.skip_talk()
	assert_true(s.skipped)
	assert_null(s.skip_control, "the offer goes once the talk is over")
	assert_true(s.running, "Rest, Feyre is still to come")
	_finish(s)
	assert_false(s.running)
	assert_eq(_state(), want, "the same flags and lines heard as played through")


func test_no_offer_before_or_after_the_talk() -> void:
	var s := CottageSupper.new()
	s.auto_tick = false
	add_child_autofree(s)
	assert_null(s.skip_control)
	s.skip_talk()
	assert_false(s.skipped, "nothing to skip before it starts")
	WorldState.set_flag("pelt_sold", true)
	WorldState.set_flag(CottageEvening.SAT, true)
	s.start()
	_finish(s)
	assert_null(s.skip_control)
	s.skip_talk()
	assert_false(s.skipped)
