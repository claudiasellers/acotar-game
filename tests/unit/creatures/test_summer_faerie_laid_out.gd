## The Summer faerie laid out on the hall table dies where he lies (lane L22,
## for L29's ch17 staging): no turn of the body, he only goes slack.
extends GutTest


func _laid_face_down(f: Node3D) -> void:
	# As story lays him: head toward -X, face down.
	f.global_transform = Transform3D(Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)), Vector3(0, 1, 0))


func test_laid_out_cue_sets_it() -> void:
	var f := SummerFaerie.new()
	add_child_autofree(f)
	assert_false(f.laid_out)
	EventBus.story_actor_cue.emit(&"summer_faerie", &"laid_out")
	assert_true(f.laid_out)


func test_laid_out_death_goes_slack_in_place() -> void:
	var f := SummerFaerie.new()
	f.death_time = 0.4
	add_child_autofree(f)
	_laid_face_down(f)
	EventBus.story_actor_cue.emit(&"summer_faerie", &"laid_out")
	var figure := f.get_child(0) as Node3D
	var before := figure.global_transform
	watch_signals(f)
	EventBus.story_actor_cue.emit(&"summer_faerie", &"dies")
	assert_false(f.alive)
	assert_signal_emitted(f, "died")
	await wait_seconds(0.6)
	assert_eq(figure.rotation, Vector3.ZERO, "no turn of the body")
	assert_almost_eq(figure.global_basis.y.normalized().dot(before.basis.y.normalized()), 1.0, 0.001, "still lying head toward -X")
	assert_lt(figure.global_position.y, before.origin.y, "sinks onto the table, not up")
	assert_lt(figure.scale.x, 1.0, "the chest settles flatter")


func test_standing_death_still_falls() -> void:
	var f := SummerFaerie.new()
	f.death_time = 0.4
	add_child_autofree(f)
	EventBus.story_actor_cue.emit(&"summer_faerie", &"dies")
	await wait_seconds(0.3)
	assert_gt((f.get_child(0) as Node3D).rotation.x, 0.5)
