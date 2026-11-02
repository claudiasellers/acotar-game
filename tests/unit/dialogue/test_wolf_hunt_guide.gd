## WolfHuntGuide (lane L34-4): Feyre's thoughts through the ch1 wolf hunt.
## Every beat it says has Keeper lines in the data, beats come in the
## hunt's order and once each, the nudges stop for good once she draws, and
## ambient lines stay quiet while the guide holds the voice.
extends GutTest

const BEATS := [&"doe", &"eyes", &"size", &"wait", &"nudge_draw", &"nudge_loose", &"wood", &"miss", &"ash",
	&"kill"]


class FakeHunt:
	extends Node
	var running: bool = true
	var wolf: Node3D
	var doe: Node3D
	var ash_struck: bool = false
	var wolf_dead: bool = false


class FakeDoe:
	extends Node3D
	var alive: bool = true


var director: DialogueDirector
var hunt: FakeHunt
var guide: WolfHuntGuide
var shown: Array = []


func before_each() -> void:
	WorldState.clear()
	PhaseManager.current_phase = &"p0_winter"
	shown.clear()
	director = DialogueDirector.new()
	director.auto_tick = false
	director.show_fn = func(_who: String, text: String) -> float:
		shown.append(text)
		return 2.0
	add_child_autofree(director)
	hunt = FakeHunt.new()
	add_child_autofree(hunt)
	guide = WolfHuntGuide.new()
	guide.listen_to_bow = false
	guide.set_process(false)
	hunt.add_child(guide)


func _texts() -> Array:
	return shown.duplicate()


## Lets the director say what it has queued, with `seconds` passing.
func _elapse(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		director._now += 0.25
		director._pump_scene()
		t += 0.25


func _start() -> void:
	EventBus.scene_space_started.emit(&"wolf_kill")


func _wolf_out() -> void:
	hunt.wolf = Node3D.new()
	hunt.add_child(hunt.wolf)
	hunt.doe = FakeDoe.new()
	hunt.add_child(hunt.doe)
	EventBus.story_actor_cue.emit(&"great_wolf", &"stalk")


func _quiet(seconds: float) -> void:
	_elapse(20.0)
	guide.idle = seconds
	guide.tick()


func test_every_beat_has_keeper_lines_in_the_data() -> void:
	var book := load("res://data/dialogue/lines/wolf_hunt.tres") as DialogueBook
	assert_not_null(book)
	var beats := {}
	for line in book.lines:
		assert_eq(line.trigger, DialogueLine.Trigger.SCENE, String(line.id))
		assert_true(line.inner, "%s is her thought" % line.id)
		assert_true(line.canon in ["V", "A"], "%s is from the book (Keeper)" % line.id)
		assert_true(String(line.where).begins_with("wolf_kill."), String(line.id))
		beats[String(line.where).trim_prefix("wolf_kill.")] = true
	for b in BEATS:
		assert_true(beats.has(String(b)), "no lines for beat %s" % b)


func test_the_hunt_in_order_and_once_each() -> void:
	_start()
	assert_true(director.held(), "the guide holds the voice")
	assert_eq(_texts().size(), 1, "the doe, first line")
	_elapse(10.0)
	assert_true(_texts()[1].begins_with("Her skin"), "the doe's two lines in order")
	_wolf_out()
	_elapse(10.0)
	assert_true(_texts()[2].begins_with("Golden eyes"))
	_quiet(1.5)
	_elapse(20.0)
	assert_true(_texts().has("The size of a pony. No animal that big should be so quiet."))
	var n := _texts().size()
	EventBus.story_actor_cue.emit(&"great_wolf", &"stalk")
	_elapse(5.0)
	assert_eq(_texts().size(), n, "a beat is said once a hunt")


func test_nudges_only_until_she_draws() -> void:
	_start()
	_wolf_out()
	_quiet(5.0)  # size
	_quiet(5.0)  # wait
	_quiet(8.0)  # nudge_draw
	_elapse(5.0)
	assert_true(guide.said.has(&"nudge_draw"))
	assert_true(_texts().has("The ash arrow. Three years in my quiver. Now."))
	_quiet(20.0)
	assert_false(guide.said.has(&"nudge_loose"), "the hide nudge waits until he has the doe")
	(hunt.doe as FakeDoe).alive = false
	guide.note_draw(true)
	guide.note_draw(false)
	_quiet(30.0)
	assert_false(guide.said.has(&"nudge_loose"), "she drew: no more nudges, ever")


func test_the_loose_nudge_comes_once_he_has_her() -> void:
	_start()
	_wolf_out()
	_quiet(5.0)
	_quiet(5.0)
	_quiet(8.0)
	(hunt.doe as FakeDoe).alive = false
	_quiet(10.0)
	_elapse(5.0)
	assert_true(_texts().has("Before he ruins the hide. His side."))


func test_what_her_shots_do() -> void:
	_start()
	_wolf_out()
	EventBus.creature_hit.emit(&"w", &"great_wolf", &"arrow_wood", &"side")
	_elapse(5.0)
	assert_true(_texts().has("Bee stings, to a wolf that size. It has to be the ash."))
	guide.note_landing(null)
	_elapse(5.0)
	assert_true(_texts().has("Missed. I can't afford to miss."))
	var n := _texts().size()
	guide.note_landing(hunt.wolf)
	guide.note_landing(null)
	_elapse(5.0)
	assert_eq(_texts().size(), n, "a hit on him isn't a miss, and a miss is said once")
	hunt.ash_struck = true
	EventBus.creature_hit.emit(&"w", &"great_wolf", &"arrow_ash", &"side")
	_elapse(5.0)
	assert_true(_texts().has("He's looking at me. Like he knows. Just in case... the eye."))
	_quiet(30.0)
	assert_false(guide.said.has(&"wait"), "no waiting thoughts once the ash is in him")
	EventBus.creature_killed.emit(&"w", &"great_wolf", &"arrow_wood", Vector3.ZERO)
	# The scene ends while he still breathes: the last thought still comes.
	EventBus.scene_space_finished.emit(&"wolf_kill")
	_elapse(10.0)
	assert_true(_texts().has("He should be dead, not dying."))
	assert_true(_texts().has("Wolf. Definitely just a wolf."))


func test_a_new_beat_cuts_off_the_last() -> void:
	_start()
	_wolf_out()
	assert_eq(director._scene_queue.size(), 1, "the downwind line is waiting")
	hunt.ash_struck = true
	EventBus.creature_hit.emit(&"w", &"great_wolf", &"arrow_ash", &"side")
	assert_true(_texts().back().begins_with("He's looking at me"), "the ash cuts straight in")
	_elapse(10.0)
	assert_false(_texts().has("He's downwind of her. She can't see or smell him."))


func test_ambient_lines_wait_while_the_guide_holds() -> void:
	var line := DialogueLine.new()
	line.id = &"t_ambient"
	line.trigger = DialogueLine.Trigger.DEED
	line.deed = &"wolf_killed"
	line.inner = true
	line.text = "Ambient."
	var book := DialogueBook.new()
	book.lines.append(line)
	director.add_book(book)
	_start()
	WorldState.set_flag("wolf_killed", true)
	director._now += 30.0
	assert_null(director.step(Vector3.ZERO), "quiet while the hunt holds the voice")
	EventBus.scene_space_finished.emit(&"wolf_kill")
	assert_false(director.held())
	director._now += DialogueDirector.SCENE_HUSH + DialogueDirector.GAP + 1.0
	assert_not_null(director.step(Vector3.ZERO), "lines come back once the hunt is over")


func test_the_heart_beats_only_under_a_draw_with_him_out() -> void:
	_start()
	guide.note_draw(true)
	assert_false(guide.heart, "nothing to fear before he shows himself")
	_wolf_out()
	guide.note_draw(true)
	assert_true(guide.heart and guide.drawn)
	guide.note_draw(false)
	assert_false(guide.heart)
