## Contract test for the sound lane (L15): the bank covers every Act I space
## and deed, files stay small, and the director answers the events other lanes
## already emit (docs/contracts/audio.md).
extends GutTest

const ACT1_SPACES: Array[StringName] = [&"cottage", &"cottage_interior", &"hunting_forest",
	&"village", &"wall_seam", &"workshop", &"border_woods"]
## Every cue the director plays by name.
const DIRECTOR_CUES: Array[StringName] = [&"amb_dread", &"foot_snow", &"foot_wood", &"foot_grass",
	&"foot_jump", &"foot_land_snow", &"bow_draw", &"bow_release", &"bow_whoosh", &"bow_hit_flesh",
	&"bow_hit_wood", &"bow_hit_snow", &"bow_break", &"wolf_seize", &"wolf_bark_pain", &"wolf_growl_low",
	&"wolf_death", &"wolf_pack_growl", &"horror_wrong", &"beast_roar", &"beast_bellow_murderers",
	&"beast_bellow_who", &"beast_door_smash", &"beast_snarl", &"beast_claws", &"beast_cottage_rattle",
	&"beast_heartbeat", &"beast_footfall", &"beast_huff", &"beast_snap_arrow", &"ui_hover", &"ui_click",
	&"ui_open", &"ui_close", &"ui_celebrate"]
const MAX_FILE_BYTES := 2 * 1024 * 1024

var bank: SoundBank
var director: SoundDirector


func before_each() -> void:
	bank = load(SoundDirector.BANK_PATH) as SoundBank


func _director() -> SoundDirector:
	director = SoundDirector.new()
	add_child_autofree(director)
	return director


func test_every_cue_has_streams_that_load_and_stay_small() -> void:
	assert_gt(bank.cues.size(), 40)
	for c: SoundCue in bank.cues:
		assert_false(c.streams.is_empty(), "%s has no streams" % c.id)
		for s: AudioStream in c.streams:
			assert_not_null(s, "%s has a missing stream" % c.id)
			if s == null:
				continue
			assert_gt(s.get_length(), 0.05, s.resource_path)
			var f := FileAccess.open(s.resource_path, FileAccess.READ)
			assert_lt(f.get_length(), MAX_FILE_BYTES, s.resource_path)
			if c.loop:
				assert_true((c.pick() as AudioStreamOggVorbis).loop, "%s should loop" % c.id)


func test_director_cues_exist() -> void:
	for cue_id in DIRECTOR_CUES:
		assert_true(bank.has_cue(cue_id), "missing cue %s" % cue_id)


func test_every_act1_space_has_a_bed_and_the_arrival_has_no_music() -> void:
	for space in ACT1_SPACES:
		assert_true(bank.has_cue(StringName(bank.space_beds.get(space, &""))), "no bed for %s" % space)
	for space in [&"cottage", &"hunting_forest", &"village"]:
		assert_true(bank.has_cue(StringName(bank.space_music.get(space, &""))), "no music for %s" % space)
	assert_false(bank.space_music.has(&"border_woods"), "canon: the Spring Court arrival has no music")
	assert_false(bank.space_music.has(&"wall_seam"))
	assert_eq(bank.space_surfaces.get(&"cottage_interior"), &"wood")
	assert_eq(bank.space_surfaces.get(&"border_woods"), &"grass")


func test_footsteps_follow_distance_and_stop_in_the_air() -> void:
	var cadence := FootstepCadence.new()
	var steps := 0
	for i in 100:  # 10 m at walking pace
		steps += int(cadence.advance(0.1, 1.6, true))
	assert_between(steps, 11, 14)
	var air := 0
	for i in 100:
		air += int(cadence.advance(0.1, 1.6, false))
	assert_eq(air, 0)
	assert_lt(10.0 / FootstepCadence.stride_length(10.0), 10.0 / FootstepCadence.stride_length(1.6))


func test_space_falls_back_to_the_map_without_regions() -> void:
	var d := _director()
	assert_eq(d.space_at(Vector3(0, 0, 900)), &"border_woods")
	assert_eq(d.space_at(Vector3(0, 0, 2000)), &"hunting_forest")


func test_space_change_swaps_bed_and_music() -> void:
	var d := _director()
	d._set_space(&"village")
	assert_eq(d._bed_cue, &"amb_village")
	assert_eq(d._music_cue, &"music_village")
	d._set_space(&"border_woods")
	assert_eq(d._bed_cue, &"amb_spring_arrival")
	assert_eq(d._music_cue, &"")
	assert_eq(d.surface, &"grass")


func test_dread_silences_the_world_and_calm_brings_it_back() -> void:
	var d := _director()
	d._set_space(&"hunting_forest")
	EventBus.scene_space_started.emit(&"test_space")
	EventBus.mood_requested.emit(&"dread", 1.0, 0.05)
	await wait_seconds(0.2)
	assert_almost_eq(d.dread, 1.0, 0.01)
	assert_false(d.played.has(&"horror_wrong"), "story scenes bring their own horror")
	EventBus.mood_requested.emit(&"calm", 0.0, 0.05)
	await wait_seconds(0.2)
	assert_almost_eq(d.dread, 0.0, 0.01)
	EventBus.scene_space_finished.emit(&"test_space")


func test_roaming_dread_ends_on_the_wrong_sound() -> void:
	var d := _director()
	EventBus.mood_requested.emit(&"dread", 0.8, 0.05)
	assert_eq(int(d.played.get(&"horror_wrong", 0)), 1)


func test_the_beast_and_the_wolf_answer_story_cues() -> void:
	var d := _director()
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"enter")
	assert_eq(int(d.played.get(&"beast_door_smash", 0)), 1, "one door, however many announce it")
	EventBus.story_actor_cue.emit(&"tamlin_beast", &"accuse")
	assert_eq(int(d.played.get(&"beast_bellow_murderers", 0)), 1)
	EventBus.story_actor_cue.emit(&"great_wolf", &"seize_doe")
	EventBus.creature_hit.emit(&"w1", &"great_wolf", &"arrow_ash", &"side")
	EventBus.creature_killed.emit(&"w1", &"great_wolf", &"arrow", Vector3.ZERO)
	for cue_id in [&"wolf_seize", &"wolf_bark_pain", &"wolf_death"]:
		assert_eq(int(d.played.get(cue_id, 0)), 1, cue_id)
	assert_lt(d.dread, 0.5, "canon: the snow falls again after the first arrow")


func test_celebrations_chime_once() -> void:
	var d := _director()
	EventBus.celebration_requested.emit(&"deed", Vector3.ZERO)
	EventBus.celebration_requested.emit(&"deed", Vector3.ZERO)
	assert_eq(int(d.played.get(&"ui_celebrate", 0)), 1)


func test_buttons_sound_without_knowing_about_sound() -> void:
	var d := _director()
	var button := Button.new()
	add_child_autofree(button)
	button.pressed.emit()
	assert_eq(int(d.played.get(&"ui_click", 0)), 1)
	var quiet := Button.new()
	quiet.set_meta(&"silent", true)
	add_child_autofree(quiet)
	quiet.pressed.emit()
	assert_eq(int(d.played.get(&"ui_click", 0)), 1)


func test_arrow_impacts_by_what_they_hit() -> void:
	var tree := StaticBody3D.new()
	var beast := Node3D.new()
	beast.add_to_group(&"creature")
	var ground := Node3D.new()
	assert_eq(SoundDirector.arrow_hit_cue(tree, &"snow"), &"bow_hit_wood")
	assert_eq(SoundDirector.arrow_hit_cue(beast, &"snow"), &"bow_hit_flesh")
	assert_eq(SoundDirector.arrow_hit_cue(ground, &"snow"), &"bow_hit_snow")
	for n in [tree, beast, ground]:
		n.free()


func test_feyre_gets_feet_and_a_bow_voice_when_she_enters() -> void:
	var d := _director()
	var feyre := (load("res://characters/feyre/feyre.tscn") as PackedScene).instantiate() as Feyre
	add_child_autofree(feyre)
	await wait_physics_frames(3)
	assert_eq(d._feyre, feyre)
	assert_not_null(d._feet)
	assert_true(feyre.arrow_fired.is_connected(d._on_arrow_fired))
	assert_true(feyre.jump_motor.landed.is_connected(d._on_landed))
