## Health-interactions §3.5 #14: soft aim on a pad. Friction inside 4 degrees
## of a hostile that is hunting her, a bend toward the body for a shot that
## would miss it, never toward the weak spot, and nothing at all on a mouse.
extends GutTest

const ROAMER := preload("res://creatures/hostile/naga_roamer.tscn")
const FROM := Vector3(0, 1.45, 0)
const AWAY := 25.0

var naga: NagaRoamer


func before_each() -> void:
	for stale in get_tree().get_nodes_in_group(Creature.GROUP):
		stale.remove_from_group(Creature.GROUP)
	naga = _naga(Vector3(0, 0, -AWAY), HostileLadder.State.ENGAGED)
	SatchelHud.pad_active = true


func after_each() -> void:
	SatchelHud.pad_active = false


func _naga(at: Vector3, state: HostileLadder.State) -> NagaRoamer:
	var n: NagaRoamer = ROAMER.instantiate()
	add_child_autofree(n)
	n.set_physics_process(false)
	n.global_position = at
	n.ladder.state = state
	return n


## A direction `yaw` and `pitch` degrees off the line to the naga's middle.
func _aim(yaw: float, pitch: float = 0.0) -> Vector3:
	var middle := naga.global_position + Vector3.UP * naga.data.body_height * 0.5
	var to := (middle - FROM).normalized()
	return to.rotated(Vector3.UP, deg_to_rad(yaw)).rotated(Vector3.RIGHT, deg_to_rad(pitch)).normalized()


func test_only_those_hunting_her_count() -> void:
	var calm := _naga(Vector3(5, 0, -10), HostileLadder.State.ROUTINE)
	var searching := _naga(Vector3(-5, 0, -10), HostileLadder.State.SEARCHING)
	var dead := _naga(Vector3(8, 0, -10), HostileLadder.State.ENGAGED)
	dead.alive = false
	var found := SoftAim.hunting(get_tree())
	assert_has(found, naga)
	assert_has(found, searching)
	assert_does_not_have(found, calm)
	assert_does_not_have(found, dead)


func test_her_aim_is_on_it_within_four_degrees_and_thirty_five_metres() -> void:
	assert_eq(SoftAim.target(get_tree(), FROM, _aim(3.0)), naga)
	assert_null(SoftAim.target(get_tree(), FROM, _aim(5.5)))
	naga.global_position = Vector3(0, 0, -40.0)
	assert_null(SoftAim.target(get_tree(), FROM, _aim(0.0)), "too far")


func test_the_stick_slows_across_it_by_mode() -> void:
	assert_eq(SoftAim.friction(get_tree(), FROM, _aim(2.0), &"light"), 0.6)
	assert_eq(SoftAim.friction(get_tree(), FROM, _aim(2.0), &"strong"), 0.45)
	assert_eq(SoftAim.friction(get_tree(), FROM, _aim(2.0), &"off"), 1.0)
	assert_eq(SoftAim.friction(get_tree(), FROM, _aim(8.0), &"light"), 1.0, "nothing to slow for")


func test_the_setting_picks_the_mode_on_a_pad() -> void:
	assert_eq(GameSettings.SOFT_AIM_LEVELS.size(), SoftAim.LEVELS.size())
	var saved: Variant = GameSettings.get_value(SoftAim.SETTING)
	for i in SoftAim.LEVELS.size():
		GameSettings.set_value(SoftAim.SETTING, i)
		assert_eq(SoftAim.mode(), SoftAim.LEVELS[i])
	GameSettings.set_value(SoftAim.SETTING, saved)
	assert_eq(SoftAim.LEVELS[int(GameSettings.DEFAULTS[SoftAim.SETTING])], &"light", "light unless she says otherwise")


func test_a_mouse_gets_none() -> void:
	SatchelHud.pad_active = false
	assert_eq(SoftAim.mode(), &"off")
	var shot := _aim(1.5)
	assert_eq(SoftAim.bend(get_tree(), FROM, shot, shot), shot)
	assert_eq(SoftAim.friction(get_tree(), FROM, shot), 1.0)


func test_a_near_miss_bends_onto_the_body() -> void:
	var shot := _aim(1.5)
	assert_false(SoftAim.on_creature(naga, FROM, shot), "it would miss")
	var bent := SoftAim.bend(get_tree(), FROM, shot, shot, &"light")
	assert_true(SoftAim.on_creature(naga, FROM, bent))


func test_the_bend_is_never_more_than_the_mode_allows() -> void:
	var shot := _aim(3.5)
	var bent := SoftAim.bend(get_tree(), FROM, shot, shot, &"light")
	assert_almost_eq(rad_to_deg(shot.angle_to(bent)), 1.5, 0.01)
	assert_false(SoftAim.on_creature(naga, FROM, bent), "a wide shot is still a miss")


func test_a_shot_already_on_it_is_hers_alone_throat_included() -> void:
	var body := _aim(0.2)
	assert_eq(SoftAim.bend(get_tree(), FROM, body, body, &"strong"), body)
	var throat_at := naga.global_position + Vector3.UP * naga.data.body_height * (naga.data.weak_zone_height + 0.03)
	var throat := (throat_at - FROM).normalized()
	assert_eq(naga.hit_zone(throat_at), &"weak")
	assert_eq(SoftAim.bend(get_tree(), FROM, throat, throat, &"strong"), throat, "the throat shot is not pulled down")


func test_the_bend_never_reaches_for_the_weak_spot() -> void:
	# Wide of it at throat height: the help goes to the body, below the throat.
	var throat_at := naga.global_position + Vector3.UP * naga.data.body_height * (naga.data.weak_zone_height + 0.03)
	var wide := (throat_at + Vector3.RIGHT * 0.7 - FROM).normalized()
	var bent := SoftAim.bend(get_tree(), FROM, wide, wide, &"strong")
	var lands := FROM + bent * FROM.distance_to(throat_at)
	assert_true(SoftAim.on_creature(naga, FROM, bent))
	assert_eq(naga.hit_zone(lands), &"body")


## The slice's measure: 50 seeded shots with the stick resting anywhere inside
## the cone, at a naga 25 m off. Off is the baseline.
func test_fifty_seeded_shots_at_twenty_five_metres() -> void:
	var rates := {}
	for mode: StringName in [&"off", &"light", &"strong"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 80
		var hits := 0
		for i in 50:
			var r := SoftAim.CONE_DEG * sqrt(rng.randf())
			var a := rng.randf() * TAU
			var shot := _aim(r * cos(a), r * sin(a) * 0.5)
			if SoftAim.on_creature(naga, FROM, SoftAim.bend(get_tree(), FROM, shot, shot, mode)):
				hits += 1
		rates[mode] = hits / 50.0
	gut.p("soft aim hit rates at 25 m: %s" % [rates])
	assert_gt(float(rates[&"light"]), float(rates[&"off"]) + 0.25, "light helps a good deal")
	assert_gte(float(rates[&"strong"]), 0.9, "strong lands nine in ten")
	assert_lt(float(rates[&"off"]), 0.4, "and without it the cone is mostly misses")


func test_one_close_and_after_her_pulls_the_camera_back() -> void:
	assert_false(SoftAim.engaged_near(get_tree(), FROM), "25 m is not close")
	naga.global_position = Vector3(0, 0, -8.0)
	assert_true(SoftAim.engaged_near(get_tree(), FROM))
	naga.ladder.state = HostileLadder.State.SEARCHING
	assert_false(SoftAim.engaged_near(get_tree(), FROM), "searching is not after her yet")
