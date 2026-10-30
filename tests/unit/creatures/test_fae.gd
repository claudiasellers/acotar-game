extends GutTest

const NAGA := preload("res://creatures/fae/naga.tscn")
const SURIEL := preload("res://creatures/fae/suriel.tscn")
const ATTOR := preload("res://creatures/fae/attor.tscn")
const HORSE := preload("res://creatures/fae/white_horse.tscn")


func before_each() -> void:
	WorldState.clear()


func test_suriel_answers_its_cues_and_its_scream_carries() -> void:
	var s := SURIEL.instantiate() as Suriel
	add_child_autofree(s)
	var ear := CreatureSenses.new()
	add_child_autofree(ear)
	ear.global_position = Vector3(25, 0, 0)
	EventBus.story_actor_cue.emit(&"suriel", &"caught")
	assert_eq(s.state, Suriel.State.CAUGHT)
	watch_signals(s)
	EventBus.story_actor_cue.emit(&"suriel", &"naga_are_coming")
	assert_signal_emitted(s, "screamed")
	assert_gt(ear.awareness, 0.0, "the scream is heard 25 m away")


func test_naga_attacks_on_cue_and_dies_to_two_arrows() -> void:
	var n := NAGA.instantiate() as Naga
	n.creature_id = &"naga_2"
	add_child_autofree(n)
	assert_eq(n.state, Naga.State.LURK)
	EventBus.story_actor_cue.emit(&"naga_2", &"attack")
	assert_eq(n.state, Naga.State.CHARGE)
	var arrow := Node3D.new()
	add_child_autofree(arrow)
	watch_signals(EventBus)
	n.on_arrow_hit(arrow)
	assert_true(n.alive)
	n.on_arrow_hit(arrow)
	assert_false(n.alive)
	assert_signal_emitted_with_parameters(EventBus, "creature_killed", [&"naga_2", &"naga", &"arrow_wood", n.global_position])


func test_other_nagas_ignore_a_cue_for_naga_2() -> void:
	var n := NAGA.instantiate() as Naga
	n.creature_id = &"naga"
	add_child_autofree(n)
	EventBus.story_actor_cue.emit(&"naga_2", &"attack")
	assert_eq(n.state, Naga.State.LURK)


func test_bogge_is_always_behind_the_camera() -> void:
	for yaw in [0.0, 1.2, -2.5, PI]:
		var forward := Vector3.FORWARD.rotated(Vector3.UP, yaw)
		for t in [0.0, 0.5, 1.0]:
			var p := Bogge.behind(Vector3.ZERO, forward, t, 4.5, 1.6)
			assert_lt(forward.dot(p.normalized()), -0.6, "never in front of her")


func test_attor_is_unseen_until_the_glamour_lifts() -> void:
	var a := ATTOR.instantiate() as Attor
	add_child_autofree(a)
	await wait_frames(1)
	assert_false(a.true_form.visible)
	WorldState.raise_deed("glamour_lifted")
	await wait_frames(1)
	assert_true(a.true_form.visible)


func test_horse_has_a_mount_point_and_walks_on_cue() -> void:
	var h := HORSE.instantiate() as WhiteHorse
	add_child_autofree(h)
	assert_almost_eq(h.mount_point.position.y, 1.55, 0.01)
	EventBus.story_actor_cue.emit(&"white_horse", &"walk")
	assert_true(h.walking)


func test_spawner_maps_numbered_ids_and_answers() -> void:
	assert_eq(StorySpawner.base_kind(&"naga_3"), &"naga")
	assert_eq(StorySpawner.base_kind(&"white_horse"), &"white_horse")
	var spawner := StorySpawner.new()
	add_child_autofree(spawner)
	var naga := spawner.spawn(&"naga_3", Transform3D(Basis(), Vector3(5, 0, 0)))
	autofree(naga)
	assert_true(naga.is_in_group(&"story_actor_naga_3"))
	assert_eq(naga.creature_id, &"naga_3")
