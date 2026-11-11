# gate: needs:terrain
# gate: when:story/act1/act1_game.gd,world/shared/world/*,world/human_realm/cottage/*,core/streaming/*,characters/feyre/*
## T104 contract: New Game never lets Feyre's physics run before there is
## ground under her. Terrain3D builds its collision around her a few frames
## after she lands at the dawn anchor; released earlier, she now and then
## dropped through the cottage floor and fell forever.
extends GutTest

const GAME := "res://story/act1/act1_game.tscn"


func _reset() -> void:
	GameSettings.pending_load_slot = ""
	WorldStreamer.track(null)
	WorldStreamer.unload_all()
	WorldState.clear()
	Gameplay.reset()
	StoryControl.release()
	PhaseManager.phase_set = null
	PhaseManager.current_phase = &""


func after_each() -> void:
	_reset()


func test_she_is_let_go_only_over_ground_and_stays_on_it() -> void:
	_reset()
	var game := (load(GAME) as PackedScene).instantiate()
	add_child_autofree(game)
	var feyre := game.get(&"feyre") as Feyre
	assert_not_null(feyre, "act1_game made Feyre")
	var frames := 0
	while not feyre.is_physics_processing() and frames < 60 * 30:
		await get_tree().physics_frame
		frames += 1
	assert_true(feyre.is_physics_processing(), "she is let go")
	assert_true(game.has_ground_under(feyre), "there is ground under her on the frame she is let go")
	var start_y := feyre.global_position.y
	await wait_physics_frames(60)
	assert_gt(feyre.global_position.y, start_y - 1.0, "a second later she is still standing there")
