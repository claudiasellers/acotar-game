## Act I's chapter headings and the hush before the wolf clearing.
extends GutTest

var ms: Act1Milestones


func before_each() -> void:
	WorldState.clear()
	ChapterHeading.clear(get_tree())
	ms = Act1Milestones.new()
	add_child_autofree(ms)
	ms.set_process(false)
	ms._quiet_for = 0.0


func after_each() -> void:
	ChapterHeading.clear(get_tree())


func _headings() -> Array[String]:
	var out: Array[String] = []
	for card in get_tree().get_nodes_in_group(ChapterHeading.GROUP):
		if not card.is_queued_for_deletion() and card.has_node(^"Title"):
			out.append((card.get_node(^"Title") as Label).text)
	return out


func test_each_beat_has_a_heading_once() -> void:
	assert_true(ms.trigger(&"scene:wolf_kill"))
	assert_false(ms.trigger(&"scene:wolf_kill"), "once")
	assert_true(ms.trigger(&"wolf_killed"))
	assert_false(ms.trigger(&"fact.mother_bed_seen"), "minor facts have no heading")
	assert_eq(ChapterHeading.pending(), 2, "one showing, one waiting its turn")
	assert_eq(_headings(), ["The Wolf in the Snow"] as Array[String])


func test_a_loaded_save_replaying_flags_shows_nothing() -> void:
	ms._quiet_for = Act1Milestones.SETTLE
	assert_false(ms.trigger(&"pelt_sold"))
	assert_eq(ChapterHeading.pending(), 0)


func test_raised_deeds_show_their_headings() -> void:
	EventBus.flag_changed.emit("pelt_sold", true)
	EventBus.scene_space_started.emit(&"beast_door")
	assert_eq(ms.shown.keys(), [&"pelt_sold", &"scene:beast_door"])
	assert_eq(_headings(), ["Coin for the Winter"] as Array[String])


func test_a_heading_is_a_title_and_nothing_else() -> void:
	for id: StringName in Act1Milestones.HEADINGS:
		var title: String = Act1Milestones.HEADINGS[id]
		assert_false(title.contains(".") or title.contains("{"), "%s: a heading, not an instruction" % id)
		assert_lt(title.split(" ").size(), 7, "%s is short" % id)
	ms.trigger(&"wolf_killed")
	var card: Control = null
	for n in get_tree().get_nodes_in_group(ChapterHeading.GROUP):
		if not n.is_queued_for_deletion():
			card = n
	assert_eq(card.get_parent(), HudLayout.of(get_tree()).zone(HudLayout.Zone.NOTICE))
	assert_false(card.has_node(^"Line"), "no line under it saying what to do")


func test_a_heading_opens_a_staged_moment_while_finds_wait() -> void:
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	var log := PickupLog.of(get_tree())
	log.clear()
	log.note("A rabbit. Something, at least.")
	assert_eq(_headings().size(), 0)
	ms.trigger(&"scene:beast_door")
	assert_eq(_headings(), ["The Beast at the Door"] as Array[String])
	assert_eq(log.waiting(), 1, "the note is still waiting in the log")
	log.clear()
	StoryControl.set_mode(StoryControl.Mode.FULL)


func test_the_edges_draw_in_near_the_clearing() -> void:
	assert_eq(Act1Milestones.hush_at(500.0), 0.0)
	assert_gt(Act1Milestones.hush_at(80.0), 0.0)
	assert_almost_eq(Act1Milestones.hush_at(30.0), Act1Milestones.HUSH_MAX, 0.001)
