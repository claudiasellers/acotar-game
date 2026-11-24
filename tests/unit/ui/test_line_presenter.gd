## One presenter shows every line (plan step 7): a said line is the smear with
## the speaker's name, a thought is the slip of her page with her whorl, a
## film's narration is told in her hand, and the two horror voices keep their
## own palette. The lane hangs under Feyre's feet and the strap steps aside. A line never outlives its scene (L24-10): it clears when the
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
	var stand := lines.stand_of(LinePresenter.Voice.SAID)
	assert_eq(stand.theme_type_variation, &"LineBand")
	assert_eq(stand.text_label.theme_type_variation, &"LineSaid")
	assert_true(stand.who_label.visible)
	assert_eq(stand.who_label.text, "Lucien")
	assert_true(stand.who_label.uppercase, "the name is in capitals")
	assert_false(stand.whorl.visible)


func test_a_thought_is_her_page_slip_with_her_whorl_and_no_name() -> void:
	lines.say(LinePresenter.Voice.THOUGHT, "Feyre", "Someone should have held his hand.")
	var stand := lines.stand_of(LinePresenter.Voice.THOUGHT)
	assert_eq(stand.theme_type_variation, &"NotifyCard")
	assert_eq(stand.text_label.theme_type_variation, &"ThoughtText")
	assert_false(stand.who_label.visible, "a thought is never named")
	assert_true(stand.whorl.visible)


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


func test_lane_voices_hang_in_the_lane_and_keep_clear_of_the_corners() -> void:
	var view := get_viewport().get_visible_rect().size
	var long := "A long line that runs on and on, past where a short one would stop, so that it has to wrap onto a second row of the lane before it is done, and then some more of it."
	for v: LinePresenter.Voice in LinePresenter.Voice.values():
		if LinePresenter.VOICES[v].place != LinePresenter.Place.LANE:
			continue
		lines.say(v, "Tamlin", long)
		await wait_process_frames(2)
		var stand := lines.stand_of(v)
		var r := stand.get_global_rect()
		assert_gte(r.position.x, HudLayout.LANE_LEFT - 1.0, "voice %d starts in the lane" % v)
		assert_lte(r.end.x, view.x - HudLayout.LANE_LEFT + 1.0, "voice %d ends in the lane" % v)
		assert_almost_eq(r.position.y, view.y * LinePresenter.LANE_TOP, 1.0, "voice %d hangs from the lane's top" % v)
		assert_lte(r.end.y, view.y, "voice %d stays on the screen" % v)
		assert_gt(stand.text_label.get_line_count(), 1, "voice %d: a long line wraps (%s)" % [v, stand.text_label.size])
	lines.say(LinePresenter.Voice.THOUGHT, "", "Short.")
	await wait_process_frames(2)
	assert_lt(lines.stand_of(LinePresenter.Voice.THOUGHT).size.x, 300.0, "a short line's slip is as wide as its words")


## The director's look pass on 7a: a line never sits on Feyre. Her whole body,
## as the follow camera frames it standing and after a few steps, ends above
## the lane.
func test_the_lane_hangs_under_feyres_feet() -> void:
	var floor := CSGBox3D.new()
	floor.size = Vector3(80, 1, 80)
	floor.position.y = -0.5
	floor.use_collision = true
	add_child_autofree(floor)
	var feyre := (load("res://characters/feyre/feyre.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(feyre)
	await wait_physics_frames(60)
	var lane_top := get_viewport().get_visible_rect().size.y * LinePresenter.LANE_TOP
	assert_lt(_on_screen(feyre).end.y, lane_top, "standing")
	Input.action_press(&"move_forward")
	await wait_physics_frames(90)
	var walking := _on_screen(feyre).end.y
	Input.action_release(&"move_forward")
	assert_lt(walking, lane_top, "walking")


func _on_screen(body: Node3D) -> Rect2:
	var cam := get_viewport().get_camera_3d()
	var r := Rect2()
	var first := true
	for v in body.find_children("*", "GeometryInstance3D", true, false):
		var g := v as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		for i in 8:
			var p := cam.unproject_position(g.global_transform * g.get_aabb().get_endpoint(i))
			r = Rect2(p, Vector2.ZERO) if first else r.expand(p)
			first = false
	return r


## The strap sits where the lane hangs, so it steps aside for a line and comes
## back after it.
func test_the_strap_steps_aside_for_a_line() -> void:
	var strap := HudLayout.of(get_tree()).zone(HudLayout.Zone.STRAP)
	await wait_seconds(HudLayout.STRAP_FADE + 0.2)
	assert_eq(strap.modulate.a, 1.0, "no line, the strap is there")
	lines.say(LinePresenter.Voice.SAID, "Alis", "Hold still.", null, 30.0)
	await wait_seconds(HudLayout.STRAP_FADE + 0.2)
	assert_eq(strap.modulate.a, 0.0, "a line in the lane")
	assert_true(strap.visible and strap.is_visible_in_tree(), "only faded: the strap and its keys stay live mid-line")
	assert_eq(strap.process_mode, Node.PROCESS_MODE_PAUSABLE, "and it goes on running")
	lines.clear()
	lines.say(LinePresenter.Voice.WHISPER, "", "Look at me.", null, 30.0)
	await wait_seconds(HudLayout.STRAP_FADE + 0.2)
	assert_eq(strap.modulate.a, 1.0, "a whisper is not in the lane")


## Said type reads on the brightest ground there is (noon snow): the smear
## under the words leaves white body type 4.5 to 1 and the gold name 3 to 1
## even over pure white, in both acts. The name's capitals are 16 px tall.
func test_said_type_reads_on_bright_ground() -> void:
	for act: JournalTheme.Act in [JournalTheme.Act.HUMAN, JournalTheme.Act.SPRING]:
		var c := JournalTheme.colors(act)
		var under := Color.WHITE.lerp(Color(c[&"ink"], 1.0), JournalTheme.BAND_DEPTH)
		assert_gte(_contrast(c[&"paper"], under), 4.5, "act %d: said type on snow" % act)
		assert_gte(_contrast(c[&"glow"], under), 3.0, "act %d: the name on snow" % act)
		var t := JournalTheme.build(act)
		# Marcellus capitals stand 0.7 of the size tall.
		assert_gte(t.get_font_size(&"font_size", &"LineName") * 0.7, 16.0, "act %d: the name's capitals" % act)
		assert_gte(t.get_font_size(&"font_size", &"LineSaid"), 24)


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)


## A film's words go through the same presenter: narration is told, a
## speaker's line is said under their name, standing on the letterbox.
func test_a_film_tells_and_says_on_the_letterbox() -> void:
	var f := FilmScript.new()
	f.id = &"line_probe"
	f.length = 6.0
	f.bars = 0.0
	for spec: Array in [[&"n", 0.5, &"", "The forest had become a labyrinth."], [&"s", 2.0, &"alis", "Hold still."]]:
		var l := FilmLine.new()
		l.id = spec[0]
		l.at = spec[1]
		l.hold = 3.0
		l.speaker = spec[2]
		l.text = spec[3]
		f.lines.append(l)
	FilmPlayer.headless_opt_in = true
	var p := FilmPlayer.start(get_tree(), f)
	p.seek(0.6)
	assert_eq(lines.voice, LinePresenter.Voice.TOLD)
	assert_eq(lines.showing, "The forest had become a labyrinth.")
	await wait_process_frames(2)
	var view := get_viewport().get_visible_rect().size
	var bar := maxf(0.0, (view.y - view.x / Cine.BAR_ASPECT) * 0.5)
	var stand := lines.stand_of(LinePresenter.Voice.TOLD)
	assert_almost_eq(stand.get_global_rect().end.y, view.y - bar - LinePresenter.FILM_LIFT, 1.0, "stands on the bar")
	p.seek(2.1)
	assert_eq(lines.voice, LinePresenter.Voice.SAID)
	assert_eq(stand.who_label.text, "Alis")
	p.free()
	FilmPlayer.headless_opt_in = false
	StoryControl.release()
	WorldState.clear()


func test_a_whisper_stands_apart_and_does_not_take_the_lane() -> void:
	lines.say(LinePresenter.Voice.THOUGHT, "", "Bread. Think of bread.", null, 30.0)
	lines.say(LinePresenter.Voice.WHISPER, "", "Look at me.", null, 30.0)
	await wait_process_frames(2)
	var whisper := lines.stand_of(LinePresenter.Voice.WHISPER)
	assert_eq(lines.showing, "Bread. Think of bread.", "her thought stays in the lane")
	assert_eq(whisper.showing, "Look at me.")
	assert_eq(whisper.theme_type_variation, &"LineBare", "no sheet at all")
	var view := get_viewport().get_visible_rect().size
	var mid := whisper.get_global_rect().get_center().y / view.y
	assert_between(mid, LinePresenter.MIDDLE.x, LinePresenter.MIDDLE.y, "in the middle of her view")
	var at := whisper.text_label.position
	await wait_process_frames(3)
	assert_ne(whisper.text_label.position, at, "it trembles")
	# Horror is never the pretty UI (R3): bone in a thin hand, red only as a bleed.
	var t := JournalTheme.build(JournalTheme.Act.SPRING)
	assert_eq(t.get_color(&"font_color", &"LineWhisper"), JournalTheme.HORROR[&"bone"])
	assert_string_contains((t.get_font(&"font", &"LineWhisper") as FontVariation).base_font.resource_path, "Cormorant")
	assert_string_contains(t.get_font(&"font", &"LineDread").resource_path, "Marcellus")
	assert_true(t.get_stylebox(&"panel", &"LineFlood") is StyleBoxTexture, "the Suriel's black is a flood, not a box")
	assert_gte((t.get_stylebox(&"panel", &"LineFlood") as StyleBoxTexture).get_expand_margin(SIDE_LEFT), 2000.0, "edge to edge")


func test_dread_writes_itself_out_and_goes_when_told() -> void:
	var text := "Stay with the High Lord, human."
	lines.say(LinePresenter.Voice.DREAD, "", text, null, 600.0)
	var stand := lines.stand_of(LinePresenter.Voice.DREAD)
	assert_eq(stand.theme_type_variation, &"LineFlood")
	await wait_process_frames(2)
	assert_lt(stand.text_label.visible_characters, text.length(), "not all at once")
	await wait_seconds(LinePresenter.writing_time(LinePresenter.Voice.DREAD, text) + 0.3)
	assert_eq(stand.text_label.visible_characters, text.length(), "written out")
	lines.clear_voice(LinePresenter.Voice.SAID)
	assert_eq(lines.showing, text, "clearing another voice leaves it")
	lines.clear_voice(LinePresenter.Voice.DREAD)
	assert_eq(lines.showing, "")


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


## Her guide thoughts are Thought lines like any other, and her bookmark (the
## whorl and the G key) rests in the THOUGHT zone. G brings the thought back.
## The guide never takes down a line that isn't its own.
func test_guide_thoughts_are_slips_and_the_bookmark_brings_them_back() -> void:
	WorldState.clear()
	var journal := GuideJournal.new(load("res://data/guide/act1_guide.tres") as GuideBook)
	add_child_autofree(journal)
	var mark := HudLayout.of(get_tree()).zone(HudLayout.Zone.THOUGHT).find_child("ThoughtBookmark", true, false)
	assert_not_null(mark, "the bookmark is a piece of the THOUGHT zone")
	assert_not_null(mark.find_child("Whorl", true, false))
	journal.press()
	assert_true(journal.showing)
	assert_eq(lines.voice, LinePresenter.Voice.THOUGHT)
	assert_eq(lines.showing, journal.line)
	var first := journal.line
	journal.hide_thought()
	assert_eq(lines.showing, "", "put away")
	journal.press()
	assert_eq(lines.showing, first, "G brings it back")
	lines.say(LinePresenter.Voice.SAID, "Nesta", "You're late.", null, 30.0)
	assert_false(journal.can_show(), "someone is speaking: her thought waits")
	journal.hide_thought()
	assert_eq(lines.showing, "You're late.", "the guide leaves another's line alone")
	var hits: Array[String] = []
	for old in ["GuideVignette", "CartoucheStyleBox"]:
		_grep("res://", old, hits)
	assert_eq(hits, [], "the old card's parts are gone")


## The director sends her thoughts to the slip and speech to the band.
func test_the_director_picks_the_voice_from_the_line() -> void:
	var d := DialogueDirector.new()
	d.auto_tick = false
	add_child_autofree(d)
	d._show_line("", "The snow is deep.", true)
	assert_eq(lines.voice, LinePresenter.Voice.THOUGHT)
	d._show_line("Nesta", "You're late.", false)
	assert_eq(lines.voice, LinePresenter.Voice.SAID)


## No script but the presenter shows a line: the four it replaced are gone.
func test_the_old_presenters_are_gone() -> void:
	var hits: Array[String] = []
	for old in ["Act2Caption", "Act2Whisper", "SurielVoice", "FilmCaptions"]:
		_grep("res://", old, hits)
	assert_eq(hits, [], "still names an old presenter")


func _grep(dir: String, word: String, hits: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and sub != "addons":
			_grep(dir.path_join(sub), word, hits)
	for file in DirAccess.get_files_at(dir):
		var path := dir.path_join(file)
		if file.ends_with(".gd") and path != "res://tests/unit/ui/test_line_presenter.gd" \
				and FileAccess.get_file_as_string(path).contains(word):
			hits.append(path)
