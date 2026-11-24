## Contract test for the tracking rules (plans/hostile-fae/health-interactions.md
## §3.6, slice HT): the leash keeps a followed creature within reach of Feyre
## without her seeing it turn back, a wounded animal beds down inside it with
## its blood trail unbroken, and a creature she has lost gives itself away at
## most three times. The fresh trail itself: test_tracks.gd.
extends GutTest

const GREAT_WOLF := preload("res://creatures/wolves/great_wolf.tscn")
const DEER := preload("res://creatures/prey/deer.tscn")
const STEP := 1.0 / 60.0

var her: Node3D
var camera: Camera3D
var layer: TrackLayer
var _gentle: bool


func before_each() -> void:
	WorldState.clear()
	_gentle = GameSettings.gentle_mode
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600.0, 1.0, 600.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	add_child_autofree(ground)
	layer = TrackLayer.new()
	add_child_autofree(layer)
	her = Node3D.new()
	her.add_to_group(&"player")
	camera = Camera3D.new()
	camera.position.y = 1.6
	her.add_child(camera)
	add_child_autofree(her)
	camera.make_current()


func after_each() -> void:
	GameSettings.set_value(&"gentle_mode", _gentle)


func _wolf_at(at: Vector3) -> GreatWolf:
	var wolf := GREAT_WOLF.instantiate() as GreatWolf
	wolf.position = at
	add_child_autofree(wolf)
	return wolf


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Walks her `metres` along +Z at `speed` with her back to the wolf, and
## returns {far: the farthest he got, seen_closing: frames he came nearer
## while she could see him}.
func _drive_away(wolf: GreatWolf, metres: float, speed: float, facing_him: bool = false) -> Dictionary:
	her.rotation.y = 0.0 if facing_him else PI
	var far := 0.0
	var seen_closing := 0
	var gone := 0.0
	while gone < metres:
		var before := _flat(wolf.global_position, her.global_position)
		her.global_position.z += speed * STEP
		gone += speed * STEP
		var was := wolf.global_position
		await get_tree().physics_frame
		var d := _flat(wolf.global_position, her.global_position)
		far = maxf(far, d)
		if FollowLeash.sees(wolf) and _flat(was, wolf.global_position) > 0.005 and d < before:
			seen_closing += 1
	return {"far": far, "seen_closing": seen_closing}


func test_the_great_wolf_is_leashed_at_45_m_and_cues_with_his_growl() -> void:
	var wolf := _wolf_at(Vector3.ZERO)
	assert_not_null(wolf.leash, "his data asks for a leash")
	assert_eq(wolf.leash.metres, 45.0)
	assert_false(wolf.leash.wounded_only)
	assert_eq(wolf.nudge.cue, &"wolf_growl_low")


func test_she_walks_80_m_away_and_he_is_never_more_than_45_m_from_her() -> void:
	var wolf := _wolf_at(Vector3.ZERO)
	her.global_position = Vector3(0, 0, 20)
	await wait_physics_frames(5)
	assert_true(wolf.leash.armed, "she has been close: the leash is armed")
	var out: Dictionary = await _drive_away(wolf, 80.0, 6.0)
	assert_lt(float(out.far), 45.0, "farthest he got from her: %.1f m" % out.far)
	assert_eq(int(out.seen_closing), 0, "she never sees him come back")
	assert_gt(wolf.global_position.z, 50.0, "he came with her")


func test_she_sprints_away_and_he_is_still_within_45_m() -> void:
	var wolf := _wolf_at(Vector3.ZERO)
	her.global_position = Vector3(0, 0, 20)
	await wait_physics_frames(5)
	var out: Dictionary = await _drive_away(wolf, 80.0, 17.0)
	assert_lt(float(out.far), 45.0, "farthest he got from her: %.1f m" % out.far)
	assert_eq(int(out.seen_closing), 0)


func test_watched_at_the_edge_he_stands_rather_than_walk_back_in_view() -> void:
	var wolf := _wolf_at(Vector3.ZERO)
	her.global_position = Vector3(0, 0, 20)
	await wait_physics_frames(5)
	# She backs off watching him, to 42 m: past where he should start back.
	var out: Dictionary = await _drive_away(wolf, 22.0, 4.0, true)
	assert_true(wolf.leash.engaged, "he is past the soft edge")
	assert_eq(int(out.seen_closing), 0, "but she is looking, so he stands")
	assert_lt(_flat(wolf.global_position, Vector3.ZERO), 0.5)


func test_a_creature_she_has_not_reached_yet_is_left_alone() -> void:
	var wolf := _wolf_at(Vector3.ZERO)
	her.global_position = Vector3(0, 0, 60)
	her.rotation.y = PI
	await wait_physics_frames(30)
	assert_false(wolf.leash.armed, "58 m out at the hunt's start: not armed")
	assert_lt(_flat(wolf.global_position, Vector3.ZERO), 0.5, "he carries on with his own business")


func test_drawn_off_his_kill_he_goes_back_to_it_when_she_does() -> void:
	var wolf := _wolf_at(Vector3.ZERO)
	var kill := Node3D.new()
	add_child_autofree(kill)
	wolf.prey = kill
	her.global_position = Vector3(0, 0, 20)
	await wait_physics_frames(5)
	wolf.state = GreatWolf.State.HOLD_PREY
	var out: Dictionary = await _drive_away(wolf, 40.0, 17.0)
	assert_lt(float(out.far), 45.0, "he leaves the doe rather than lose her: %.1f m" % out.far)
	assert_gt(_flat(wolf.global_position, Vector3.ZERO), 10.0)
	her.global_position = Vector3(0, 0, 20)
	await wait_until(func() -> bool: return _flat(wolf.global_position, Vector3.ZERO) < 3.0, 40.0)
	assert_lt(_flat(wolf.global_position, Vector3.ZERO), 3.0, "she is back at the clearing and so is he, over the doe")
	assert_eq(wolf.state, GreatWolf.State.HOLD_PREY)


func test_looking_at_her_or_dying_he_stays_put() -> void:
	var wolf := _wolf_at(Vector3.ZERO)
	her.global_position = Vector3(0, 0, 20)
	await wait_physics_frames(5)
	wolf.state = GreatWolf.State.DYING
	await _drive_away(wolf, 40.0, 17.0)
	assert_lt(_flat(wolf.global_position, Vector3.ZERO), 0.5)


func test_an_unhurt_deer_that_bolts_is_gone_and_a_wounded_one_beds_down() -> void:
	var deer := DEER.instantiate() as Prey
	deer.position = Vector3(0, 0, -20)
	add_child_autofree(deer)
	await wait_physics_frames(3)
	assert_true(deer.leash.wounded_only)
	assert_false(deer.leash.applies(), "unhurt: no leash")
	# One barbed arrow from where she stands.
	var arrow := Node3D.new()
	arrow.set_meta(&"arrow_id", &"barbed")
	arrow.position = Vector3(0, 0, -19)
	add_child_autofree(arrow)
	var hit_at := deer.global_position
	deer.on_arrow_hit(arrow)
	deer.on_arrow_effect(&"barbed", arrow)
	assert_true(deer.alive, "one arrow wounds a deer")
	assert_eq(deer.state, Prey.State.FLEE)
	await wait_until(func() -> bool: return deer.state == Prey.State.BED, 20.0)
	assert_eq(deer.state, Prey.State.BED, "it lies up at the edge of the leash")
	await wait_physics_frames(30)
	var d := _flat(deer.global_position, her.global_position)
	assert_between(d, 30.0, 60.0, "bedded %.1f m from her" % d)
	# The blood leads from the hit to the bed with no gap.
	var blood: Array = layer.head_of(deer.get_instance_id(), true)
	assert_gt(blood.size(), 8)
	var at := hit_at
	var widest := 0.0
	for mark in blood:
		widest = maxf(widest, _flat(at, mark.position))
		at = mark.position
	widest = maxf(widest, _flat(at, deer.global_position))
	assert_lt(widest, 2.5, "widest gap in the blood trail: %.1f m" % widest)
	# Close enough to startle it and it is up and running again.
	CreatureSenses.emit_noise(get_tree(), deer.global_position + Vector3(0, 0, 3), 1.0)
	assert_eq(deer.state, Prey.State.FLEE)


func test_lost_for_20_s_he_cues_at_most_three_times() -> void:
	var wolf := _wolf_at(Vector3.ZERO)
	var nudge := wolf.nudge
	nudge.set_physics_process(false)
	GameSettings.set_value(&"gentle_mode", false)
	watch_signals(nudge)
	nudge.tick(19.0, false, 30.0)
	assert_eq(nudge.count, 0, "19 s: not yet")
	nudge.tick(1.5, false, 30.0)
	assert_eq(nudge.count, 1, "20 s out of sight at 30 m: the first cue")
	assert_not_null(wolf.get_node_or_null(^"SnowShake"), "snow shaken loose above him")
	nudge.tick(24.0, false, 30.0)
	assert_eq(nudge.count, 1)
	nudge.tick(1.5, false, 30.0)
	assert_eq(nudge.count, 2, "25 s later, the second")
	nudge.tick(26.0, false, 30.0)
	assert_eq(nudge.count, 3)
	nudge.tick(200.0, false, 30.0)
	assert_eq(nudge.count, 3, "never a fourth")
	assert_signal_emit_count(nudge, "cued", 3)
	nudge.tick(0.1, true, 30.0)
	assert_eq(nudge.count, 0, "seeing him starts it over")
	nudge.tick(30.0, false, 10.0)
	assert_eq(nudge.count, 0, "within 15 m he isn't lost")


func test_gentle_mode_cues_after_12_s() -> void:
	var wolf := _wolf_at(Vector3.ZERO)
	wolf.nudge.set_physics_process(false)
	GameSettings.set_value(&"gentle_mode", true)
	wolf.nudge.tick(12.5, false, 30.0)
	assert_eq(wolf.nudge.count, 1)


func test_the_nudge_reads_her_camera() -> void:
	var wolf := _wolf_at(Vector3.ZERO)
	GameSettings.set_value(&"gentle_mode", false)
	her.global_position = Vector3(0, 0, 30)
	her.rotation.y = PI
	await wait_physics_frames(3)
	assert_false(FollowLeash.sees(wolf), "her back is to him")
	wolf.nudge._physics_process(21.0)
	assert_eq(wolf.nudge.count, 1)
	her.rotation.y = 0.0
	await wait_physics_frames(3)
	assert_true(FollowLeash.sees(wolf), "she turns and there he is")
	assert_eq(wolf.nudge.count, 0)
	# A wall between them hides him again.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 10.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 5, 15)
	add_child_autofree(wall)
	await wait_physics_frames(3)
	assert_false(FollowLeash.sees(wolf), "behind cover counts as out of view")
