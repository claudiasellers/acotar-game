## H0: one damage rule for every creature (health-interactions §2.2, §2.4).
## damage = arrow_damage x arrow x bow x zone; ash counts toward ash_hits;
## fire burns whatever has burn_dps and frightens whatever has fire_fear_radius.
extends GutTest

const DEER := preload("res://creatures/prey/deer.tscn")
const ROAMER := preload("res://creatures/hostile/naga_roamer.tscn")
const ROAMER_DATA := preload("res://data/creatures/hostile/naga_roamer.tres")


func _three_ash_fae() -> CreatureData:
	var d := ROAMER_DATA.duplicate() as CreatureData
	d.ash_hits = 3
	d.lethal_delay = 0.0
	d.max_health = 400.0
	return d


func test_bow_mult_follows_launch_speed_and_caps() -> void:
	assert_almost_eq(Creature.bow_mult(48.0), 1.0, 0.001, "hunting bow")
	assert_almost_eq(Creature.bow_mult(30.0), 1.0, 0.001, "never below 1")
	assert_almost_eq(Creature.bow_mult(60.0), 1.0 + 12.0 / 72.0, 0.001, "yew longbow")
	assert_almost_eq(Creature.bow_mult(200.0), Creature.BOW_MULT_CAP, 0.001)


func test_bow_mult_of_reads_the_bow_data() -> void:
	assert_almost_eq(Creature.bow_mult_of(&""), 1.0, 0.001)
	assert_almost_eq(Creature.bow_mult_of(&"hunting_bow"), 1.0, 0.001)
	assert_gt(Creature.bow_mult_of(&"sentry_warbow"), Creature.bow_mult_of(&"hunting_bow"))
	assert_almost_eq(Creature.bow_mult_of(&"no_such_bow"), 1.0, 0.001)


func test_arrow_mult_reads_the_arrow_data() -> void:
	assert_almost_eq(Creature.arrow_mult(&"wood"), 1.0, 0.001)
	assert_almost_eq(Creature.arrow_mult(&"ash"), 1.5, 0.001)
	assert_almost_eq(Creature.arrow_mult(&"no_such_arrow"), 1.0, 0.001)


func test_ash_short_of_the_count_only_wounds() -> void:
	var d := _three_ash_fae()
	var r := Creature.resolve_hit(d, 10.0, &"ash", 5.0)
	assert_false(r.killed, "one ash of three can't kill even with the health gone")
	assert_false(r.mortal)
	assert_eq(r.health, 1.0)
	r = Creature.resolve_hit(d, r.health, &"ash", 1.0, r.ash_taken)
	assert_false(r.killed)
	r = Creature.resolve_hit(d, r.health, &"ash", 1.0, r.ash_taken)
	assert_true(r.killed, "the third ash kills")
	assert_eq(r.ash_taken, 3)


func test_body_and_weak_spot_on_a_naga_in_the_tree() -> void:
	var n := ROAMER.instantiate() as NagaRoamer
	add_child_autofree(n)
	var top := n.global_position + Vector3(0, n.data.body_height * 0.9, 0)
	var low := n.global_position + Vector3(0, n.data.body_height * 0.3, 0)
	assert_eq(n.hit_zone(top), &"weak")
	assert_eq(n.hit_zone(low), &"body")
	n.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", low)
	assert_almost_eq(n.health, 40.0, 0.001)
	assert_eq(n._hit_part(false), &"body")
	n.apply_hit(&"arrow_wood", &"wood", 1.0, &"weak", top)
	assert_almost_eq(n.health, 16.0, 0.001, "the throat takes three times")
	assert_eq(n._hit_part(false), &"throat")


func test_a_stronger_bow_hits_harder_through_the_arrow() -> void:
	var n := ROAMER.instantiate() as NagaRoamer
	add_child_autofree(n)
	var a := Node3D.new()
	add_child_autofree(a)
	a.global_position = n.global_position + Vector3(0, 0.5, 0)
	a.set_meta(&"arrow_id", &"wood")
	a.set_meta(&"bow_id", &"sentry_warbow")
	n.on_arrow_hit(a)
	var dealt := ROAMER_DATA.max_health - n.health
	assert_almost_eq(dealt, ROAMER_DATA.arrow_damage * Creature.bow_mult(70.0), 0.01)


func test_ash_on_the_roamer_is_a_mortal_wound_that_kills_in_time() -> void:
	var n := ROAMER.instantiate() as NagaRoamer
	add_child_autofree(n)
	var a := Node3D.new()
	add_child_autofree(a)
	a.global_position = n.global_position + Vector3(0, 0.5, 0)
	a.set_meta(&"arrow_id", &"ash")
	n.on_arrow_hit(a)
	assert_true(n.alive)
	assert_true(n.mortally_wounded)
	n._physics_process(ROAMER_DATA.lethal_delay + 0.5)
	assert_false(n.alive)


func test_a_burning_naga_loses_health() -> void:
	var n := ROAMER.instantiate() as NagaRoamer
	add_child_autofree(n)
	n.ignite(2.0)
	assert_true(n._step_fire(1.0))
	assert_almost_eq(n.health, ROAMER_DATA.max_health - ROAMER_DATA.burn_dps, 0.01)


func test_a_deer_never_burns_but_flees_the_flame() -> void:
	var field := ElementField.new()
	field.follow_world_wind = false
	add_child_autofree(field)
	field.set_physics_process(false)
	field.add_patch(Vector3(2, 0, 0), 1.5, &"grass", 1.0)
	assert_gt(field.ignite_at(Vector3(2, 0, 0), 1.0), 0)
	var deer := DEER.instantiate() as Prey
	add_child_autofree(deer)
	var hp := deer.health
	deer.ignite(5.0)
	assert_eq(deer.burn_left, 0.0, "no burn_dps, no burning")
	deer._step_fire(0.1)
	assert_eq(deer.state, Prey.State.FLEE)
	assert_eq(deer.health, hp)


func test_feyre_catches_fire_in_burning_grass() -> void:
	var field := ElementField.new()
	field.follow_world_wind = false
	add_child_autofree(field)
	field.set_physics_process(false)
	field.add_patch(Vector3.ZERO, 1.5, &"grass", 1.0)
	field.ignite_at(Vector3.ZERO, 1.0)
	var her := Node3D.new()
	her.add_to_group(&"player")
	add_child_autofree(her)
	var e := ElementState.new()
	her.add_child(e)
	e.set_physics_process(false)
	e._catch_field_fire(0.1, her)
	assert_gt(e.fire, 0.0)


func test_only_the_player_catches_field_fire() -> void:
	var field := ElementField.new()
	field.follow_world_wind = false
	add_child_autofree(field)
	field.set_physics_process(false)
	field.add_patch(Vector3.ZERO, 1.5, &"grass", 1.0)
	field.ignite_at(Vector3.ZERO, 1.0)
	var post := Node3D.new()
	add_child_autofree(post)
	var e := ElementState.new()
	post.add_child(e)
	e.set_physics_process(false)
	e._catch_field_fire(0.1, post)
	assert_eq(e.fire, 0.0)


## R18: one damage rule and one vitals owner; the old ones are gone.
func test_the_old_systems_are_gone() -> void:
	assert_false(ResourceLoader.exists("res://creatures/hostile/hostile_vitals.gd"))
	assert_false(_has_method(&"resolve_arrow"), "resolve_hit is the one rule")
	var ash := load("res://data/arrows/ash.tres") as ArrowData
	assert_false(&"fae_lethal" in ash)


func _has_method(method: StringName) -> bool:
	var script := load("res://creatures/creature.gd") as Script
	for m in script.get_script_method_list():
		if m.name == method:
			return true
	return false
