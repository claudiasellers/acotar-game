## One presenter shows every line (plan step 7): a said line is the band with
## the speaker's name, a thought is the slip of her page with her whorl, both
## in one lane. A line never outlives its scene (L24-10): it clears when the
## scene that spoke it finishes or leaves the tree, on a phase change and on a
## load, and it steps aside while a screen pauses the tree.
extends GutTest

var lines: LinePresenter


func before_each() -> void:
	lines = LinePresenter.of(get_tree())
	lines.clear()
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false
	lines.clear()


func _space(id: StringName) -> SceneSpace:
	var s := SceneSpace.new()
	s.space_id = id
	add_child_autofree(s)
	return s


func test_a_said_line_is_the_band_with_the_name() -> void:
	lines.say(LinePresenter.Voice.SAID, "Lucien", "You'll want to keep to the path, human.")
	assert_eq(lines.voice, LinePresenter.Voice.SAID)
	assert_eq(lines.sheet.theme_type_variation, &"LineBand")
	assert_eq(lines.text_label.theme_type_variation, &"LineSaid")
	assert_true(lines.who_label.visible)
	assert_eq(lines.who_label.text, "Lucien")
	assert_true(lines.who_label.uppercase, "the name is in capitals")
	assert_false(lines.whorl.visible)


func test_a_thought_is_her_page_slip_with_her_whorl_and_no_name() -> void:
	lines.say(LinePresenter.Voice.THOUGHT, "Feyre", "Someone should have held his hand.")
	assert_eq(lines.sheet.theme_type_variation, &"NotifyCard")
	assert_eq(lines.text_label.theme_type_variation, &"ThoughtText")
	assert_false(lines.who_label.visible, "a thought is never named")
	assert_true(lines.whorl.visible)


func test_a_scene_line_with_no_name_is_a_thought() -> void:
	var s := _space(&"line_test_voice")
	LinePresenter.line(s, "", "A thought.")
	assert_eq(lines.voice, LinePresenter.Voice.THOUGHT)
	LinePresenter.line(s, "Alis", "Hold still.")
	assert_eq(lines.voice, LinePresenter.Voice.SAID)
	assert_eq(lines.showing, "Hold still.", "one line at a time: the newer takes the lane")


func test_every_voice_has_a_whole_row_the_theme_knows() -> void:
	for v: LinePresenter.Voice in LinePresenter.Voice.values():
		assert_true(LinePresenter.VOICES.has(v), "voice %d has no row" % v)
		var row: Dictionary = LinePresenter.VOICES[v]
		assert_has(JournalTheme.PANELS, row.sheet)
		assert_true(JournalTheme.LABELS.has(row.type), "%s is not a label of the theme" % row.type)


func test_both_voices_share_the_lane_and_keep_clear_of_the_corners() -> void:
	var view := get_viewport().get_visible_rect().size
	for v: LinePresenter.Voice in LinePresenter.Voice.values():
		lines.say(v, "Tamlin", "A long line that runs on and on, past where a short one would stop, so that it has to wrap onto a second row of the lane before it is done, and then some more of it.")
		await wait_process_frames(2)
		var r := lines.sheet.get_global_rect()
		assert_gte(r.position.x, HudLayout.LANE_LEFT - 1.0, "voice %d starts in the lane" % v)
		assert_lte(r.end.x, view.x - HudLayout.LANE_LEFT + 1.0, "voice %d ends in the lane" % v)
		assert_almost_eq(r.end.y, view.y * LinePresenter.LANE_FOOT, 1.0, "voice %d stands on the lane's foot" % v)
		assert_gt(lines.text_label.get_line_count(), 1, "a long line wraps")
	lines.say(LinePresenter.Voice.THOUGHT, "", "Short.")
	await wait_process_frames(2)
	assert_lt(lines.sheet.size.x, 300.0, "a short line's slip is as wide as its words")


func test_line_clears_when_its_scene_finishes() -> void:
	var s := _space(&"line_test_a")
	LinePresenter.line(s, "Tamlin", "The table. Clear it off!", 30.0)
	assert_eq(lines.showing, "The table. Clear it off!")
	EventBus.scene_space_finished.emit(&"some_other_scene")
	assert_ne(lines.showing, "", "another scene ending leaves it")
	EventBus.scene_space_finished.emit(&"line_test_a")
	assert_eq(lines.showing, "", "its own scene ending clears it")


func test_line_clears_when_its_scene_leaves_the_tree() -> void:
	var s := _space(&"line_test_b")
	LinePresenter.line(s, "", "A thought.", 30.0)
	remove_child(s)
	assert_eq(lines.showing, "")
	s.free()


func test_child_node_speaks_for_its_scene() -> void:
	var s := _space(&"line_test_c")
	var prop := Node3D.new()
	s.add_child(prop)
	LinePresenter.line(prop, "Lucien", "Polite.", 30.0)
	EventBus.scene_space_finished.emit(&"line_test_c")
	assert_eq(lines.showing, "")


func test_phase_change_and_load_clear_it() -> void:
	LinePresenter.line(self, "Tamlin", "One.", 30.0)
	EventBus.phase_changed.emit(&"p3_house", &"p4_studio")
	assert_eq(lines.showing, "", "phase change")
	LinePresenter.line(self, "Tamlin", "Two.", 30.0)
	EventBus.game_loaded.emit("test")
	assert_eq(lines.showing, "", "load")


func test_line_still_times_out_and_hides_under_a_paused_screen() -> void:
	LinePresenter.line(self, "", "Short.", 0.2)
	get_tree().paused = true
	lines._process(1.0)
	assert_false(lines.visible, "hidden while a screen pauses the tree")
	assert_eq(lines.showing, "Short.", "its clock waits under the screen")
	get_tree().paused = false
	lines._process(0.0)
	assert_true(lines.visible)
	await wait_seconds(0.5)
	assert_eq(lines.showing, "", "times out once play resumes")


## The director sends her thoughts to the slip and speech to the band.
func test_the_director_picks_the_voice_from_the_line() -> void:
	var d := DialogueDirector.new()
	d.auto_tick = false
	add_child_autofree(d)
	d._show_line("", "The snow is deep.", true)
	assert_eq(lines.voice, LinePresenter.Voice.THOUGHT)
	d._show_line("Nesta", "You're late.", false)
	assert_eq(lines.voice, LinePresenter.Voice.SAID)


## No script but the presenter shows a scene's or the director's line.
func test_the_old_caption_is_gone() -> void:
	assert_false(ResourceLoader.exists("res://story/act2/act2_caption.gd"))
	var hits: Array[String] = []
	_grep("res://", "Act2Caption", hits)
	assert_eq(hits, [], "still names the old caption")


func _grep(dir: String, word: String, hits: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and sub != "addons":
			_grep(dir.path_join(sub), word, hits)
	for file in DirAccess.get_files_at(dir):
		var path := dir.path_join(file)
		if file.ends_with(".gd") and path != "res://tests/unit/ui/test_line_presenter.gd" \
				and FileAccess.get_file_as_string(path).contains(word):
			hits.append(path)
