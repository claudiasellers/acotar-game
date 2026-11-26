extends GutTest
## GradeDirector is the one lighting authority (owner, 2026-11-26: one working
## version, no fallbacks). Rooms win indoors, a story grade lasts only as long
## as the scene that asked for it, fear is combined per source, ambient fear
## stays outdoors, and everyone else follows the mood it settles on.

var director: GradeDirector
var focus: Node3D
var changes: Array = []


func before_each() -> void:
	changes.clear()
	focus = Node3D.new()
	add_child_autofree(focus)
	director = GradeDirector.new()
	director.start_grade = &"manor"
	director.focus = focus
	add_child_autofree(director)
	EventBus.mood_changed.connect(_on_changed)


func after_each() -> void:
	EventBus.mood_changed.disconnect(_on_changed)


func _on_changed(mood: StringName, intensity: float, _seconds: float) -> void:
	changes.append([mood, intensity])


func _rooms() -> RegionGrade:
	var rooms := RegionGrade.new()
	rooms.grade = &"manor_interior"
	rooms.priority = 10
	rooms.indoor = true
	rooms.bounds = Rect2(-5.0, -5.0, 10.0, 10.0)
	add_child_autofree(rooms)
	return rooms


func _scene() -> Node:
	var n := Node.new()
	add_child(n)
	return n


func test_the_rooms_win_over_a_held_story_grade() -> void:
	_rooms()
	var ride := _scene()
	EventBus.grade_swap_requested.emit(ride, &"spring", 0.0)
	director._process(0.1)
	assert_eq(director.target_id(), &"manor_interior", "indoors the house's own look, whatever is held")
	focus.position = Vector3(30.0, 0.0, 0.0)
	director._process(0.1)
	assert_eq(director.target_id(), &"spring", "outside, the story's grade")
	ride.free()


func test_a_hold_ends_when_its_scene_leaves() -> void:
	var estate := RegionGrade.new()
	estate.grade = &"manor"
	estate.bounds = Rect2(-50.0, -50.0, 100.0, 100.0)
	add_child_autofree(estate)
	var farewell := _scene()
	EventBus.grade_swap_requested.emit(farewell, &"grade_solstice", 0.0)
	director._process(0.1)
	assert_eq(director.target_id(), &"grade_solstice")
	farewell.free()
	director._process(3.0)
	assert_eq(director.target_id(), &"manor", "the scene is gone, so is its grade")


func test_the_newest_hold_shows_and_the_older_one_returns() -> void:
	var a := _scene()
	var b := _scene()
	EventBus.grade_swap_requested.emit(a, &"spring", 0.0)
	EventBus.grade_swap_requested.emit(b, &"grade_rite_calanmai_night", 0.0)
	assert_eq(director.target_id(), &"grade_rite_calanmai_night")
	EventBus.grade_swap_requested.emit(b, &"", 0.0)
	assert_eq(director.target_id(), &"spring", "b let go; a still holds")
	a.free()
	b.free()


func test_a_null_release_ends_every_hold() -> void:
	var a := _scene()
	EventBus.grade_swap_requested.emit(a, &"spring", 0.0)
	EventBus.grade_swap_requested.emit(null, &"", 0.0)
	assert_eq(director._holds.size(), 0)
	a.free()


func test_fear_is_the_strongest_request_and_calm_ends_only_its_own() -> void:
	var a := _scene()
	var b := _scene()
	EventBus.mood_requested.emit(a, &"dread", 0.4, 0.0)
	EventBus.mood_requested.emit(b, &"dread", 0.9, 0.0)
	assert_almost_eq(director._mood_target, 0.9, 0.001)
	EventBus.mood_requested.emit(b, &"calm", 0.0, 0.0)
	assert_almost_eq(director._mood_target, 0.4, 0.001, "a's fear is still asked for")
	EventBus.mood_requested.emit(a, &"calm", 0.0, 0.0)
	assert_eq(director._mood_target, 0.0)
	assert_eq(changes.back(), [&"calm", 0.0], "the house, sound and HUD hear calm")
	a.free()
	b.free()


func test_a_scene_that_leaves_takes_its_fear_with_it() -> void:
	var a := _scene()
	EventBus.mood_requested.emit(a, &"dread", 0.8, 0.0)
	a.free()
	assert_eq(director._mood_target, 0.0)


func test_ambient_dread_stays_outdoors_and_a_scene_reaches_in() -> void:
	_rooms()
	director._process(0.1)
	assert_true(director.indoors)
	EventBus.mood_requested.emit(DreadField, &"dread", 1.0, 0.0)
	assert_eq(director._mood_target, 0.0, "a wolf outside never darkens the rooms")
	var bite := _scene()
	EventBus.mood_requested.emit(bite, &"dread", 0.7, 0.0)
	assert_almost_eq(director._mood_target, 0.7, 0.001, "a staged scene's fear reaches indoors")
	EventBus.mood_requested.emit(bite, &"calm", 0.0, 0.0)
	director._process(5.0)   # the blend into the rooms finishes
	focus.position = Vector3(30.0, 0.0, 0.0)
	director._process(0.1)
	assert_false(director.indoors)
	assert_almost_eq(director._mood_target, 1.0, 0.001, "out on the grounds the wolf's dread lands")
	EventBus.mood_requested.emit(DreadField, &"calm", 0.0, 0.0)
	bite.free()


func test_a_null_calm_ends_every_request() -> void:
	var a := _scene()
	EventBus.mood_requested.emit(a, &"dread", 0.8, 0.0)
	EventBus.mood_requested.emit(DreadField, &"dread", 0.5, 0.0)
	EventBus.mood_requested.emit(null, &"calm", 0.0, 0.0)
	assert_eq(director._mood_target, 0.0)
	a.free()


func test_the_house_lights_follow_the_settled_mood() -> void:
	var house := Node3D.new()
	add_child_autofree(house)
	var candle := OmniLight3D.new()
	candle.light_energy = 2.0
	house.add_child(candle)
	var lights := ManorMoodLights.new()
	house.add_child(lights)
	lights.collect()
	_rooms()
	director._process(0.1)
	EventBus.mood_requested.emit(DreadField, &"dread", 1.0, 0.0)
	lights._process(1.0)
	assert_almost_eq(candle.light_energy, 2.0, 0.001, "ambient dread outside leaves the candles alone")
	var scene := _scene()
	EventBus.mood_requested.emit(scene, &"dread", 1.0, 0.1)
	lights._process(1.0)
	assert_lt(candle.light_energy, 2.0, "a scene's dread gutters them")
	EventBus.mood_requested.emit(DreadField, &"calm", 0.0, 0.0)
	scene.free()


## Only GradeDirector lights the game: no other game script builds an
## environment or writes the World's. The title screen and the films are
## their own stages, not the game world.
const GAME_DIRS := ["res://core", "res://systems", "res://story", "res://world",
		"res://creatures", "res://characters", "res://ui"]
const OWN_STAGES := ["res://story/film/", "res://ui/title/"]


func _scripts(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scripts(dir.path_join(d), out)


func test_nothing_else_builds_or_writes_the_game_environment() -> void:
	var files: Array[String] = []
	for dir: String in GAME_DIRS:
		_scripts(dir, files)
	assert_gt(files.size(), 100, "the game's scripts were read")
	var writes := RegEx.create_from_string(
			"\\.environment\\.(ssao|ssil|sdfgi|glow|fog|volumetric|tonemap|ambient|adjustment|sky)\\w*\\s*=[^=]")
	var offenders: Array[String] = []
	for path in files:
		if path == "res://world/shared/grades/grade_director.gd":
			continue
		var own_stage := false
		for stage: String in OWN_STAGES:
			own_stage = own_stage or path.begins_with(stage)
		if own_stage:
			continue
		var code := FileAccess.get_file_as_string(path)
		if code.contains("Environment.new()") or writes.search(code) != null:
			offenders.append(path)
	assert_eq(offenders, [] as Array[String], "GradeDirector is the one lighting authority")
