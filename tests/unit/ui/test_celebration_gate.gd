## Celebratory cards wait out dread and staged moments, then show (R3).
extends GutTest


func before_each() -> void:
	CelebrationGate.watch()
	CelebrationGate.reset()
	StoryControl.set_mode(StoryControl.Mode.FULL)
	FindCard.clear(get_tree())


func after_each() -> void:
	CelebrationGate.reset()
	StoryControl.set_mode(StoryControl.Mode.FULL)
	FindCard.clear(get_tree())


func _cards_on_screen() -> int:
	return get_tree().get_nodes_in_group(FindCard.GROUP).size()


func test_truth_card_held_during_dread_and_shown_after() -> void:
	EventBus.mood_requested.emit(&"dread", 0.6, 2.0)
	assert_true(CelebrationGate.hushed())
	FindCard.show_find(get_tree(), &"fact.suriel_home", &"truths")
	await wait_seconds(1.2)
	assert_eq(_cards_on_screen(), 0, "no card while the Suriel is frightening")
	assert_eq(FindCard.pending(), 1, "the card is queued, not dropped")
	EventBus.mood_requested.emit(&"calm", 0.0, 2.0)
	assert_false(CelebrationGate.hushed())
	await wait_seconds(CelebrationGate.RECHECK + 0.2)
	assert_eq(_cards_on_screen(), 1, "the card shows once the dread clears")


func test_staged_moment_holds_cards() -> void:
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	FindCard.note(get_tree(), "Something true.")
	await wait_seconds(0.8)
	assert_eq(_cards_on_screen(), 0)
	StoryControl.set_mode(StoryControl.Mode.FULL)
	await wait_seconds(CelebrationGate.RECHECK + 0.2)
	assert_eq(_cards_on_screen(), 1)


func test_held_queue_shows_one_card_at_a_time() -> void:
	EventBus.mood_requested.emit(&"dread", 1.0, 0.5)
	FindCard.note(get_tree(), "one")
	FindCard.note(get_tree(), "two")
	await wait_seconds(1.1)
	EventBus.mood_requested.emit(&"calm", 0.0, 1.0)
	await wait_seconds(CelebrationGate.RECHECK + 0.2)
	assert_eq(_cards_on_screen(), 1, "never two cards stacked after the hold")
	assert_eq(FindCard.pending(), 2)


func test_calm_play_shows_immediately() -> void:
	FindCard.note(get_tree(), "A rabbit. Something, at least.")
	await wait_frames(2)
	assert_eq(_cards_on_screen(), 1)
