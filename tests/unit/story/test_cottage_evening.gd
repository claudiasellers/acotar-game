## The evening at home after the sale (CottageEvening, lane L86): the four
## deeds open only on that evening and each once, supper waits on the other
## three, each fact brings the family's words (R2: the lines follow the fact),
## supper speaks in the Keeper's order and ends on "Rest, Feyre", the bed
## sleeps her only after supper, and the beast comes only once she has slept.
extends GutTest

var director: DialogueDirector
var shown: Array = []


func before_each() -> void:
	WorldState.clear()
	PhaseManager.current_phase = &"p1_wolf_and_crossing"
	shown.clear()
	director = DialogueDirector.new()
	director.auto_tick = false
	director.books_dir = ""
	director.add_book(load("res://data/dialogue/lines/cottage_evening.tres") as DialogueBook)
	director.show_fn = func(_who: String, text: String, _inner: bool) -> float:
		shown.append(text)
		return 1.0
	add_child_autofree(director)


func _station(fact: String) -> EveningStation:
	var s := EveningStation.new()
	s.fact = fact
	s.use_verb = "do it"
	add_child_autofree(s)
	return s


func _chair() -> EveningStation:
	var s := _station(CottageEvening.SAT)
	s.needs = PackedStringArray([CottageEvening.TABLE, CottageEvening.FIRE, CottageEvening.CHANGED])
	s.wait_beats = PackedStringArray(["wait_table", "wait_fire", "wait_clothes"])
	return s


func test_every_beat_has_lines() -> void:
	for beat in ["table", "fire", "changed", "supper", "father", "rest", "wait_table", "wait_fire", "wait_clothes", "wait_bed"]:
		var key := StringName("%s.%s" % [CottageEvening.SCENE, beat])
		assert_false(director._of(DialogueLine.Trigger.SCENE, key).is_empty(), "lines for %s" % beat)
	var rest := director._of(DialogueLine.Trigger.SCENE, &"cottage_evening.rest")
	assert_string_starts_with((rest[-1] as DialogueLine).text, "Rest, Feyre.")


func test_a_deed_is_open_only_on_the_evening_and_only_once() -> void:
	var table := _station(CottageEvening.TABLE)
	assert_false(table.open_now(), "not before the pelt is sold")
	WorldState.set_flag("pelt_sold", true)
	assert_true(table.open_now())
	table.use(null)
	assert_true(WorldState.has_flag(CottageEvening.TABLE), "E raises the deed's fact")
	assert_false(table.open_now(), "done once")
	WorldState.set_flag(CottageEvening.FIRE, true)
	assert_false(WorldState.has_flag("beast_claim_accepted"))
	WorldState.set_flag("beast_claim_accepted", true)
	assert_false(_station(CottageEvening.CHANGED).open_now(), "closed once the beast has come")


func test_supper_waits_on_the_other_three_and_says_which() -> void:
	WorldState.set_flag("pelt_sold", true)
	var chair := _chair()
	assert_eq(chair.missing(), 0)
	chair.use(null)
	assert_false(WorldState.has_flag(CottageEvening.SAT), "she can't sit yet")
	assert_false(shown.is_empty(), "her thought about the table")
	WorldState.set_flag(CottageEvening.TABLE, true)
	WorldState.set_flag(CottageEvening.FIRE, true)
	assert_eq(chair.missing(), 2, "the clothes are left")
	WorldState.set_flag(CottageEvening.CHANGED, true)
	assert_eq(chair.missing(), -1)
	chair.use(null)
	assert_true(WorldState.has_flag(CottageEvening.SAT))


func test_the_family_speak_when_a_deed_is_done() -> void:
	var evening := CottageEvening.new()
	add_child_autofree(evening)
	WorldState.set_flag("pelt_sold", true)
	WorldState.set_flag(CottageEvening.TABLE, true)
	assert_true(director.beat_speaking(), "the table brings the family's words")


func test_supper_speaks_in_order_and_ends_on_rest() -> void:
	var supper := CottageSupper.new()
	supper.auto_tick = false
	add_child_autofree(supper)
	assert_false(supper.can_start(), "not before she sits")
	WorldState.set_flag("pelt_sold", true)
	WorldState.set_flag(CottageEvening.SAT, true)
	assert_true(supper.can_start())
	var labels: Array = supper._build_beats().map(func(b: SceneBeat) -> String: return b.label)
	var at := func(label: String) -> int: return labels.find(label)
	for pair in [["say supper", "say father"], ["say father", "say rest"], ["say rest", "raise %s" % CottageEvening.SUPPER]]:
		assert_lt(at.call(pair[0]), at.call(pair[1]), "%s before %s" % pair)
		assert_eq(labels[at.call(pair[0]) + 1], "until %s is said" % String(pair[0]).trim_prefix("say "))


func test_the_bed_sleeps_her_only_after_supper() -> void:
	var bed := CottageBed.new()
	bed.fact = "fact.mother_bed_seen"
	add_child_autofree(bed)
	WorldState.set_flag("pelt_sold", true)
	assert_true(bed.evening())
	assert_false(bed.can_sleep(), "supper first")
	WorldState.set_flag(CottageEvening.SUPPER, true)
	assert_true(bed.can_sleep())
	WorldState.set_flag(CottageEvening.SLEPT, true)
	assert_false(bed.evening(), "one sleep")


func test_the_beast_comes_only_after_she_has_slept() -> void:
	var door := BeastDoor.new()
	door.auto_tick = false
	add_child_autofree(door)
	assert_true(door.require_flags.has(CottageEvening.SLEPT))
	assert_true(door.require_flags.has("pelt_sold"))
