## Feyre's landmark thoughts on the way to the ch1 clearing.
extends GutTest

const STEP := 0.5


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()


func _walk(thoughts: Act1LandmarkThoughts, from: Vector2, to: Vector2, raised: Array) -> void:
	var n := maxi(1, ceili(from.distance_to(to) / 2.0))
	for i in n + 1:
		var line := thoughts.update(from.lerp(to, float(i) / n), STEP)
		if line != "":
			raised.append(line)


func test_the_route_raises_each_landmark_once_in_order() -> void:
	var thoughts := Act1LandmarkThoughts.new()
	var raised: Array = []
	var track := Act1Wayfinding.track_points()
	_walk(thoughts, HumanRealmLayout.COTTAGE, Act1Wayfinding.TRAIL_END, raised)
	for i in range(1, track.size()):
		_walk(thoughts, track[i - 1], track[i], raised)
	_walk(thoughts, HumanRealmLayout.DOE_CLEARING, HumanRealmLayout.DOE_CLEARING, raised)
	var expected: Array = []
	for spec: Array in Act1LandmarkThoughts.LANDMARKS:
		expected.append(spec[4])
	assert_eq(raised, expected, "bark, prints, slowing, ice, downwind")
	_walk(thoughts, HumanRealmLayout.DOE_CLEARING, Act1Wayfinding.TRAIL_END, raised)
	assert_eq(raised.size(), expected.size() + 1, "walking back raises only the wrong-way thought")
	assert_eq(raised[-1], Act1LandmarkThoughts.WRONG_WAY[4])
	thoughts.free()


func test_wandering_off_gets_a_gentle_wrong_way_at_most_twice() -> void:
	var thoughts := Act1LandmarkThoughts.new()
	var village := Vector2(380.0, 2250.0)
	var raised: Array = []
	_walk(thoughts, HumanRealmLayout.COTTAGE, village, raised)
	for i in 1000:
		var line := thoughts.update(village, STEP)
		if line != "":
			raised.append(line)
	assert_eq(raised, [Act1LandmarkThoughts.WRONG_WAY[4], Act1LandmarkThoughts.WRONG_WAY[4]])
	thoughts.free()


func test_lines_never_name_what_she_hasnt_met() -> void:
	var book := load(GuideJournal.BOOK_PATH) as GuideBook
	var forbidden := PackedStringArray()
	for thread: GuideThread in book.threads:
		if thread.id == &"hunt":
			forbidden = thread.forbidden_words
	assert_gt(forbidden.size(), 0)
	for spec: Array in Act1LandmarkThoughts.LANDMARKS + [Act1LandmarkThoughts.WRONG_WAY]:
		var thread := Act1LandmarkThoughts.thread_for(spec)
		assert_eq(thread.voice_id(0), spec[1])
		for word in forbidden:
			assert_false(thread.line(0).to_lower().contains(word), "%s says %s" % [spec[0], word])


func test_a_landmark_shows_on_the_thoughts_card() -> void:
	var journal := GuideJournal.new()
	add_child_autofree(journal)
	journal.mode = GuideSettings.Mode.AUTO
	var thoughts := Act1LandmarkThoughts.new()
	add_child_autofree(thoughts)
	thoughts.set_process(false)
	assert_eq(thoughts.update(Act1Wayfinding.TRAIL_END, STEP), Act1LandmarkThoughts.LANDMARKS[1][4],
			"standing at the prints raises the prints, not the bark before them")
	thoughts._try_show()
	assert_true(journal.showing)
	assert_eq(journal.shown_thread.line(0), Act1LandmarkThoughts.LANDMARKS[1][4])
