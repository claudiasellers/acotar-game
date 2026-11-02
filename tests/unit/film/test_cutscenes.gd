## The three cutscenes (lane L33): each story moment plays its film and waits
## on the facts it writes, so the story moves on whether the film plays to
## the end, is skipped on its first frame, or can't play at all (headless).
## Each director is staged for real (opted in), run through every beat, then
## skipped: nothing it does may break, and it takes its props away.
extends GutTest

const FILMS := {
	&"eyes_open": [&"glamour_lift", ["fact.film_eyes_open_lift", "fact.film_eyes_open_seen"]],
	&"night_court": [&"rhysand_visit", ["fact.false_name_clare_beddor", "fact.film_night_court_seen"]],
	&"silent_manor": [&"alis_truth", ["fact.film_silent_manor_seen"]],
}

var root: Node3D
var feyre: Node3D


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	root = Node3D.new()
	add_child_autofree(root)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)


func after_each() -> void:
	var p := FilmPlayer.current(get_tree())
	if p:
		p.free()
	FilmPlayer.headless_opt_in = false
	WorldState.clear()
	StoryControl.release()


func _moment(id: StringName) -> StoryMoment:
	return load("res://data/story/moments/%s.tres" % id) as StoryMoment


func _space() -> Node3D:
	var space := Node3D.new()
	space.position = Vector3(40, 0, 40)
	root.add_child(space)
	return space


func test_each_moment_plays_its_film_then_waits_on_its_facts() -> void:
	for id: StringName in FILMS:
		var m := _moment(FILMS[id][0])
		var film_at := -1
		var waits: Array[String] = []
		for i in m.steps.size():
			var step: Dictionary = m.steps[i]
			if step.get("do") == "film":
				assert_eq(StringName(step.get("id")), id, "%s plays %s" % [m.id, id])
				film_at = i
			elif step.get("do") == "until_flag" and film_at >= 0:
				waits.append(String(step.get("flag")))
			elif step.get("do") == "raise":
				assert_gt(film_at, -1, "%s raises its deed after the film starts" % m.id)
		assert_has(waits, "fact.film_%s_seen" % id, "%s waits for the film to end" % m.id)


func test_films_write_only_facts() -> void:
	for id: StringName in FILMS:
		var film := Films.data_of(id)
		assert_not_null(film, "%s has data" % id)
		for f in FilmPlayer.facts_of(film):
			assert_true(f.begins_with("fact."), "%s writes %s, a fact (R2)" % [id, f])
		assert_true(ResourceLoader.exists(Films.DIRECTOR % id), "%s has a director" % id)


func test_headless_a_film_cannot_play_and_writes_every_fact_at_once() -> void:
	for id: StringName in FILMS:
		WorldState.clear()
		assert_null(Films.play(_space(), id), "%s does not play headless" % id)
		for f: String in FILMS[id][1]:
			assert_true(WorldState.has_flag(f), "%s wrote %s" % [id, f])


func test_skipped_on_the_first_frame_the_story_moves_on() -> void:
	FilmPlayer.headless_opt_in = true
	for id: StringName in FILMS:
		WorldState.clear()
		var p := Films.play(_space(), id)
		assert_not_null(p, "%s plays when opted in" % id)
		assert_not_null(p.get_node_or_null("Director"), "%s is staged by its director" % id)
		p.skip()
		for f: String in FILMS[id][1]:
			assert_true(WorldState.has_flag(f), "%s skipped still wrote %s" % [id, f])
		assert_eq(StoryControl.mode, StoryControl.Mode.FULL, "%s hands control back" % id)
		p.free()


func test_every_beat_of_every_director_runs_and_the_props_go() -> void:
	FilmPlayer.headless_opt_in = true
	for id: StringName in FILMS:
		WorldState.clear()
		var p := Films.play(_space(), id)
		var director := p.get_node("Director") as CutsceneDirector
		var props := director.props.duplicate()
		var fired: Array[StringName] = []
		p.beat.connect(func(b: StringName) -> void: fired.append(b))
		p.seek(p.data.length - 0.05)
		assert_eq(fired.size(), p.data.beats.size(), "%s fired every beat" % id)
		p.skip()
		await get_tree().process_frame
		for n in props:
			assert_false(is_instance_valid(n) and (n as Node).is_inside_tree() and not (n as Node).is_queued_for_deletion(),
					"%s took its prop %s away" % [id, n])
		p.free()


## The house builds its floors at their world height: a film staged in its
## layout frame stands on the ground floor, not under it (the Mac run had
## the dining hall played on the terrain below the house).
func test_the_house_frame_stands_on_the_ground_floor() -> void:
	var house := Node3D.new()
	house.position = Vector3(5.0, 0.0, -3.0)
	root.add_child(house)
	var anchor := Marker3D.new()
	anchor.add_to_group(&"story_anchor")
	house.add_child(anchor)
	var space := Node3D.new()
	anchor.add_child(space)
	var d := CutsceneDirector.new()
	d.space = space
	assert_true(d.use_house(), "the anchor's parent is the house")
	var p := d.at(Vector3(7.0, 0.0, -30.5))
	assert_almost_eq(p.y, ManorHouseBuilder.floor_y(0), 0.001, "on the ground floor")
	assert_almost_eq(p.x, 12.0, 0.001)
	d.free()


## Shots frame a head where the pose draws it: sat in the grass, a head is
## low, not where the walking animation would have it.
func test_a_posed_head_is_where_the_pose_draws_it() -> void:
	var who := (load("res://characters/tamlin/tamlin_model.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(who)
	await wait_process_frames(3)
	var standing := CutsceneDirector.head_of(who).y
	FilmPose.on(who).to(&"sit_ground", 0.0)
	await wait_process_frames(3)
	var sitting := CutsceneDirector.head_of(who).y
	assert_gt(standing, 1.5, "standing head")
	assert_lt(sitting, standing - 0.5, "sat in the grass, the head is low (%.2f)" % sitting)
