extends GutTest
## Lane L33: FilmPlayer and the opening film's wiring. Contract:
## docs/contracts/film.md.

var _started: Array[StringName] = []
var _finished: Array[StringName] = []


func _film() -> FilmScript:
	var f := FilmScript.new()
	f.id = &"probe"
	f.length = 3.0
	f.seen_flag = "fact.film_probe_seen"
	f.bars = 0.0
	for spec: Array in [[&"a", 0.5, "one"], [&"b", 1.5, "two"]]:
		var l := FilmLine.new()
		l.id = spec[0]
		l.at = spec[1]
		l.hold = 2.0
		l.text = spec[2]
		f.lines.append(l)
	for spec: Array in [[&"first", 0.2], [&"second", 1.0], [&"third", 2.5]]:
		var b := FilmBeat.new()
		b.name = spec[0]
		b.at = spec[1]
		f.beats.append(b)
	return f


func _on_start(id: StringName) -> void:
	_started.append(id)


func _on_finish(id: StringName) -> void:
	_finished.append(id)


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	_started.clear()
	_finished.clear()
	EventBus.scene_space_started.connect(_on_start)
	EventBus.scene_space_finished.connect(_on_finish)


func after_each() -> void:
	EventBus.scene_space_started.disconnect(_on_start)
	EventBus.scene_space_finished.disconnect(_on_finish)
	var p := FilmPlayer.current(get_tree())
	if p:
		p.free()
	FilmPlayer.headless_opt_in = false
	OpeningFilmWorld.disarm()
	WorldState.clear()
	StoryControl.release()


func test_films_never_play_headless_unless_a_test_opts_in() -> void:
	assert_false(FilmPlayer.can_play(), "headless run")
	assert_null(FilmPlayer.start(get_tree(), _film()))
	FilmPlayer.headless_opt_in = true
	assert_not_null(FilmPlayer.start(get_tree(), _film()))


func test_beats_and_lines_fire_in_order_and_control_is_held() -> void:
	FilmPlayer.headless_opt_in = true
	var p := FilmPlayer.start(get_tree(), _film())
	var beats: Array[StringName] = []
	p.beat.connect(func(b: StringName) -> void: beats.append(b))
	assert_eq(StoryControl.mode, StoryControl.Mode.NONE, "held for the film")
	assert_eq(_started, [&"film_probe"] as Array[StringName], "scene space bracket opens")
	p.seek(1.6)
	assert_eq(beats, [&"first", &"second"] as Array[StringName])
	assert_eq(p.captions.current.id, &"b", "the latest line is on screen")
	assert_false(WorldState.has_flag("fact.film_probe_seen"))


func test_skip_writes_the_seen_fact_and_hands_back() -> void:
	FilmPlayer.headless_opt_in = true
	var p := FilmPlayer.start(get_tree(), _film())
	var ended := []
	p.finished.connect(func(s: bool) -> void: ended.append(s))
	p.skip()
	assert_true(WorldState.has_flag("fact.film_probe_seen"))
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL)
	assert_eq(_finished, [&"film_probe"] as Array[StringName])
	assert_eq(ended, [true])


func test_finishing_writes_the_fact_once() -> void:
	FilmPlayer.headless_opt_in = true
	var p := FilmPlayer.start(get_tree(), _film())
	p.seek(3.1)
	p._process(0.0)
	assert_true(p.ended)
	assert_true(WorldState.has_flag("fact.film_probe_seen"))
	assert_eq(_finished.size(), 1)


func test_freed_early_still_never_leaves_the_story_waiting() -> void:
	FilmPlayer.headless_opt_in = true
	var p := FilmPlayer.start(get_tree(), _film())
	p.free()
	assert_true(WorldState.has_flag("fact.film_probe_seen"))
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL)
	assert_eq(_finished, [&"film_probe"] as Array[StringName])


func test_film_hides_the_game_hud_and_brings_it_back() -> void:
	FilmPlayer.headless_opt_in = true
	var scene := Node.new()
	var hud := CanvasLayer.new()
	scene.add_child(hud)
	add_child_autofree(scene)
	var p := FilmPlayer.start(get_tree(), _film())
	p.hide_ui_of(scene)
	assert_false(hud.visible)
	p.skip()
	assert_true(hud.visible)


func test_a_skip_press_is_any_confirm_or_escape() -> void:
	for a: StringName in [&"interact", &"pause"]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = true
		assert_true(FilmSkip.is_skip_press(e), String(a))


func test_take_is_false_unless_the_opening_film_just_ran() -> void:
	# Tests, Continue and the playtests start act1_game directly: unchanged.
	assert_false(OpeningFilmWorld.take(Node.new(), null, Callable()))


func test_new_game_routes_through_the_film_to_the_game() -> void:
	assert_eq(OpeningFilm.route(""), OpeningFilm.SCENE, "New Game plays the film")
	assert_eq(OpeningFilm.route("slot_0"), OpeningFilm.GAME_SCENE, "Continue goes straight in")
	assert_eq(OpeningFilm.GAME_SCENE, String(load("res://ui/title/title_screen.gd").GAME_SCENE))
	# Headless, the film scene goes straight on to the game, as New Game did.
	var film := (load(OpeningFilm.SCENE) as PackedScene).instantiate() as OpeningFilm
	var went := []
	film.change_scene = func(path: String) -> void: went.append(path)
	add_child_autofree(film)
	await wait_process_frames(2)
	assert_eq(went, [OpeningFilm.GAME_SCENE])


func test_opening_film_data_matches_the_script() -> void:
	var f := load("res://data/film/opening_film.tres") as FilmScript
	assert_eq(f.id, &"opening")
	assert_eq(f.length, 185.0, "cut to the 3:05 score")
	assert_eq(f.music_cue, &"music_opening_film")
	assert_eq(f.seen_flag, "", "a new game's flags stay empty for its first thought")
	assert_eq(f.lines.size(), 16)
	var last := -1.0
	for i in f.lines.size():
		assert_eq(f.lines[i].id, StringName("op_%02d" % (i + 1)))
		assert_gt(f.lines[i].at, last)
		assert_ne(f.lines[i].text, "")
		last = f.lines[i].at
	last = -1.0
	for b in f.beats:
		assert_gt(b.at, last, String(b.name))
		last = b.at
	assert_lt(f.beat_time(&"change_scene"), f.beat_time(&"cottage_ext"))
	assert_lt(f.beat_time(&"wolf_eye"), f.beat_time(&"title"))
