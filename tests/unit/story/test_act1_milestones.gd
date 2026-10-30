## Act I's milestone cards and the hush before the wolf clearing.
extends GutTest

var ms: Act1Milestones


func before_each() -> void:
	WorldState.clear()
	ms = Act1Milestones.new()
	add_child_autofree(ms)
	ms.set_process(false)
	ms._quiet_for = 0.0


func test_each_beat_has_a_card_once() -> void:
	assert_true(ms.trigger(&"scene:wolf_kill"))
	assert_false(ms.trigger(&"scene:wolf_kill"), "once")
	assert_true(ms.trigger(&"wolf_killed"))
	assert_false(ms.trigger(&"fact.mother_bed_seen"), "minor facts have no card")
	assert_eq(ms.queue, [&"scene:wolf_kill", &"wolf_killed"])


func test_a_loaded_save_replaying_flags_shows_nothing() -> void:
	ms._quiet_for = 1.0
	assert_false(ms.trigger(&"pelt_sold"))
	assert_true(ms.queue.is_empty())


func test_raised_deeds_queue_their_cards() -> void:
	EventBus.flag_changed.emit("pelt_sold", true)
	EventBus.scene_space_started.emit(&"beast_door")
	assert_eq(ms.queue, [&"pelt_sold", &"scene:beast_door"])


func test_lines_name_the_keys_as_bound() -> void:
	var line := Act1Milestones.expand(Act1Milestones.CARDS[&"wolf_killed"][1])
	assert_false(line.contains("{key:"), line)
	assert_true(line.contains("]E[/color]"), line)
	var hunt := Act1Milestones.expand(Act1Milestones.CARDS[&"fact.wolf_spotted"][1])
	assert_true(hunt.contains("Right mouse") and hunt.contains("Left mouse"), hunt)
	for id: StringName in Act1Milestones.CARDS:
		assert_false(Act1Milestones.expand(Act1Milestones.CARDS[id][1]).contains("?"), "%s: unbound key" % id)


func test_the_card_shows_title_and_line() -> void:
	ms.show_card(&"wolf_killed")
	assert_true(ms._card.visible)
	assert_eq(ms._title.text, "He's Down")
	assert_true(ms._line.text.contains("Skin him"))


func test_the_edges_draw_in_near_the_clearing() -> void:
	assert_eq(Act1Milestones.hush_at(500.0), 0.0)
	assert_gt(Act1Milestones.hush_at(80.0), 0.0)
	assert_almost_eq(Act1Milestones.hush_at(30.0), Act1Milestones.HUSH_MAX, 0.001)
