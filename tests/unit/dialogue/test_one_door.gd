## Every line said or thought in a scene goes through one door, the
## DialogueDirector (docs/contracts/dialogue.md): a line of the books by its
## id, or a row of a scene's own stage sheet with staged(). So each gets the
## voice, the ducking and the talking face the same way.
extends GutTest

## The only other scripts under story/ and systems/ that put a line on the
## presenter, and the voices each may use: a film runs on its own clock, and
## the two horror voices are not speech.
const ALSO_SPEAK := {
	"res://systems/dialogue/dialogue_director.gd": ["SAID", "THOUGHT", "READ"],
	"res://story/film/film_player.gd": ["TOLD"],
	"res://story/act2/bogge_hunt.gd": ["WHISPER"],
	"res://story/act3/suriel/suriel_snare.gd": ["DREAD"],
}

var lines: LinePresenter


func before_each() -> void:
	lines = LinePresenter.of(get_tree())
	lines.clear()


func after_each() -> void:
	lines.clear()


func _space(id: StringName) -> SceneSpace:
	var s := SceneSpace.new()
	s.space_id = id
	add_child_autofree(s)
	return s


func _director() -> DialogueDirector:
	var d := DialogueDirector.new()
	d.auto_tick = false
	add_child_autofree(d)
	return d


func test_a_staged_line_goes_the_way_a_line_of_the_books_goes() -> void:
	var s := _space(&"one_door_scene")
	var d := _director()
	var ducked := []
	d.line_spoken.connect(func(id: StringName, speaker: StringName, _t: String, _at: Vector3, inner: bool) -> void:
		ducked.append([id, speaker, inner]))
	var faces := []
	var on_face := func(actor: StringName, text: String, emotion: StringName, seconds: float) -> void:
		faces.append([actor, text, emotion, seconds])
	EventBus.line_spoken.connect(on_face)
	var secs := DialogueDirector.staged(s, &"dinner_sit", "Tamlin", "Sit. Eat.", 2.5, &"", &"stern")
	EventBus.line_spoken.disconnect(on_face)
	assert_almost_eq(secs, 2.5, 0.01)
	assert_eq(lines.showing, "Sit. Eat.")
	assert_eq(lines.voice, LinePresenter.Voice.SAID)
	assert_eq(lines.stand_of(LinePresenter.Voice.SAID).who_label.text, "Tamlin")
	assert_eq(ducked, [[&"dinner_sit", &"tamlin", false]], "the director's own signal, for the voice and the ducking")
	assert_eq(faces.size(), 1, "one face talks")
	assert_eq(faces[0].slice(0, 3), [&"tamlin", "Sit. Eat.", &"stern"])
	assert_true(d.busy(), "free-roam lines wait for it")
	assert_false(WorldState.has_flag("dlg.dinner_sit"), "a staged line is not a once-only line of the books")
	EventBus.scene_space_finished.emit(&"one_door_scene")
	assert_eq(lines.showing, "", "the line goes with its scene")


func test_a_staged_line_with_no_name_is_her_thought() -> void:
	var s := _space(&"one_door_thought")
	var d := _director()
	var ducked := []
	d.line_spoken.connect(func(id: StringName, speaker: StringName, _t: String, _at: Vector3, inner: bool) -> void:
		ducked.append([id, speaker, inner]))
	DialogueDirector.staged(s, &"bread", "", "Bread. Think of bread.")
	assert_eq(lines.voice, LinePresenter.Voice.THOUGHT)
	assert_eq(ducked, [[&"bread", &"feyre", true]])


func test_a_named_speaker_is_the_face_that_talks() -> void:
	var s := _space(&"one_door_stranger")
	_director()
	var faces := []
	var on_face := func(actor: StringName, _t: String, _e: StringName, _s: float) -> void: faces.append(actor)
	EventBus.line_spoken.connect(on_face)
	DialogueDirector.staged(s, &"stranger_hello", "The stranger", "There you are.", -1.0, &"rhysand")
	EventBus.line_spoken.disconnect(on_face)
	assert_eq(faces, [&"rhysand"])
	assert_eq(lines.stand_of(LinePresenter.Voice.SAID).who_label.text, "The stranger", "the name on screen is the sheet's")


func test_a_scene_run_bare_still_shows_its_words() -> void:
	var s := _space(&"one_door_bare")
	assert_null(DialogueDirector.of(get_tree()))
	assert_gt(DialogueDirector.staged(s, &"hold", "Alis", "Hold still."), 1.0)
	assert_eq(lines.showing, "Hold still.")
	assert_eq(DialogueDirector.staged(s, &"nothing", "Alis", ""), 0.0, "no words, no line")


func test_a_scene_space_says_through_the_door() -> void:
	var space := Act2Space.new()
	space.space_id = &"one_door_act2"
	space.stage = Act2Stage.new()
	space.stage.lines = {&"sit": {"who": "Tamlin", "text": "Sit. Eat."}, &"think": {"who": "", "text": "He means it."}}
	add_child_autofree(space)
	var d := _director()
	var beat := space.say(&"sit", &"stern")
	beat.enter(space)
	assert_eq(d.last_line.id, &"sit")
	assert_eq(d.last_line.emotion, &"stern")
	assert_eq(lines.showing, "Sit. Eat.")
	space.aside(&"think")
	assert_eq(d.last_line.id, &"think")
	assert_eq(lines.voice, LinePresenter.Voice.THOUGHT)


func test_nothing_else_puts_speech_on_the_presenter() -> void:
	assert_false(FileAccess.get_file_as_string("res://ui/lines/line_presenter.gd").contains("static func line("),
			"the presenter has no door of its own for a scene")
	var said := RegEx.create_from_string("\\.say\\(\\s*LinePresenter\\.Voice\\.([A-Z]+)")
	var hits: Array[String] = []
	var seen := {}
	for root in ["res://story", "res://systems"]:
		_search(root, said, hits, seen)
	assert_eq(hits, [] as Array[String], ("a said or thought line shown past the director. Fix: replace "
			+ "LinePresenter.say(...) with DialogueDirector.staged(self, &\"<line_id>\", who, text) (who = \"\" "
			+ "for her thought), or DialogueDirector.line(self, &\"<id>\") for a line of the books. Only a "
			+ "film, the Bogge's whisper and the Suriel's dread may call say() directly (ALSO_SPEAK here)."))
	for path: String in ALSO_SPEAK:
		assert_true(seen.has(path), "%s no longer calls LinePresenter.say: delete its row from ALSO_SPEAK in this test" % path)
	var direct := RegEx.create_from_string("LinePresenter\\.line\\(")
	var old: Array[String] = []
	for root in ["res://story", "res://systems", "res://ui"]:
		_search(root, direct, old, {}, false)
	assert_eq(old, [] as Array[String], "LinePresenter.line() was taken out: use DialogueDirector.line(self, &\"<id>\") or DialogueDirector.staged(...)")


func _search(dir: String, pattern: RegEx, hits: Array[String], seen: Dictionary, by_voice: bool = true) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_search(dir.path_join(sub), pattern, hits, seen, by_voice)
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd"):
			continue
		var path := dir.path_join(file)
		for m in pattern.search_all(FileAccess.get_file_as_string(path)):
			seen[path] = true
			if not by_voice or not (m.get_string(1) in (ALSO_SPEAK.get(path, []) as Array)):
				hits.append("%s: %s" % [path, m.get_string(0)])
