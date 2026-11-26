## Gloamers (bestiary §16): the common tier's wood-edge pack. L83's rigged
## body with every clip its brain names; 3 wood arrows or 1 to the throat, ash
## 1, 2 knife hits; Ember, Glimmer and Hush weak; out from 18:00 to 06:00 and
## lying up asleep by day; the first to see her calls; the rake, and every
## third blow the shove; half the pack down and the rest scatter (the fight
## ends driven off); a light arrow's glow pulls two off to grab at it and
## squabble, and a wound brings one back.
extends GutTest

const GLOAMER := preload("res://creatures/hostile/gloamer_roamer.tscn")
const DT := 1.0 / 30.0

var _time: float
var _ended: Array = []


func before_each() -> void:
	_time = Clock.time_of_day
	Clock.time_of_day = 22.0 / 24.0
	_ended.clear()
	EventBus.hostile_encounter_ended.connect(_on_ended)


func after_each() -> void:
	Clock.time_of_day = _time
	if EventBus.hostile_encounter_ended.is_connected(_on_ended):
		EventBus.hostile_encounter_ended.disconnect(_on_ended)
	WorldState.clear()


func _on_ended(source_id: StringName, family: StringName, outcome: StringName) -> void:
	_ended.append([source_id, family, outcome])


func _gloamer() -> GloamerRoamer:
	var g := GLOAMER.instantiate() as GloamerRoamer
	g.creature_id = &"gloamer_test"
	add_child_autofree(g)
	g.set_physics_process(false)
	g.senses.set_physics_process(false)
	g.collision_layer = 0
	g.collision_mask = 0
	return g


## A pack of `count` on flat ground at the origin, its members' bodies still.
func _pack(count: int = 4) -> HostileSite:
	var data := HostileSiteData.new()
	data.id = &"gloamer_test_pack"
	data.family = &"gloamer"
	data.member_scene = GLOAMER
	data.count = count
	data.territory_radius = 35.0
	var site := HostileSite.new()
	site.data = data
	site.snap_to_core = false
	site.height_func = func(_x: float, _z: float) -> float: return 0.0
	add_child_autofree(site)
	for m in site.members:
		m.set_physics_process(false)
		(m as HostileRoamer).senses.set_physics_process(false)
		m.collision_layer = 0
		m.collision_mask = 0
	return site


func _think(g: GloamerRoamer, seconds: float) -> void:
	for i in int(ceil(seconds / DT)):
		g._think(DT)


# --- the body -------------------------------------------------------------------

func test_its_body_is_the_rigged_gloamer_with_every_clip_its_brain_names() -> void:
	var g := _gloamer()
	assert_eq(g.data.kind, &"gloamer")
	assert_eq(g.data.model_scene.resource_path, "res://creatures/models/fae/gloamer.gltf")
	assert_not_null(g.animator, "rigged: its clips drive it")
	if g.animator == null:
		return
	for clip: StringName in [g.call_clip, g.glint_clip, g.squabble_clip, GloamerRoamer.SLEEP_CLIP,
			GloamerRoamer.WAKE_CLIP, &"telegraph_gloamer_rake", &"attack_gloamer_rake",
			&"telegraph_gloamer_shove", &"attack_gloamer_shove"]:
		assert_true(g.animator.anim.has_animation(clip), "it has its %s clip" % clip)


func test_its_rows_wind_up_on_the_bestiary_tells() -> void:
	var rake := AttackTable.resolve(GloamerRoamer.RAKE)
	var shove := AttackTable.resolve(GloamerRoamer.SHOVE)
	assert_eq(rake.family, &"gloamer")
	assert_eq(rake.damage, 8.0)
	assert_almost_eq(rake.windup_s, 0.45, 0.001)
	assert_eq(shove.damage, 12.0)
	assert_eq(shove.knockback_m, 1.0)
	assert_almost_eq(shove.windup_s, 0.6, 0.001)


# --- numbers ----------------------------------------------------------------------

func test_three_wood_arrows_or_one_to_the_throat_or_one_ash() -> void:
	var g := _gloamer()
	for i in 2:
		g.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", g.global_position)
	assert_true(g.alive, "two wood arrows leave it standing")
	g.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", g.global_position)
	assert_false(g.alive, "the third drops it")
	var t := _gloamer()
	t.apply_hit(&"arrow_wood", &"wood", 1.0, &"weak", t.global_position)
	assert_false(t.alive, "one to the throat")
	var a := _gloamer()
	a.apply_hit(&"arrow_ash", &"ash", 1.0, &"body", a.global_position)
	assert_false(a.alive, "one ash")


## The owner's 2 knife hits: knife_scale 1.5 makes each cut 12 of its 24.
func test_two_knife_hits() -> void:
	var g := _gloamer()
	assert_eq(g.data.knife_scale, 1.5)
	g.apply_hit(&"knife", &"knife", StrikeController.KNIFE_MULT, &"body", g.global_position)
	assert_true(g.alive, "one cut leaves it standing")
	assert_almost_eq(g.health, 12.0, 0.01)
	g.apply_hit(&"knife", &"knife", StrikeController.KNIFE_MULT, &"body", g.global_position)
	assert_false(g.alive, "the second drops it")


## A wood arrow is still 8: the scale is the knife's only.
func test_the_knife_scale_leaves_arrows_alone() -> void:
	var g := _gloamer()
	g.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", g.global_position)
	assert_almost_eq(g.health, 16.0, 0.01)
	var naga := load("res://data/creatures/hostile/naga_roamer.tres") as CreatureData
	assert_eq(naga.knife_scale, 1.0, "every other family cuts as before")


## Its element row (plan §7): Ember, Glimmer and Hush work; frost is plain.
func test_its_element_row() -> void:
	var d := load("res://data/creatures/hostile/gloamer_roamer.tres") as CreatureData
	assert_eq(HostileElements.mult_of(d, &"fire"), HostileElements.WEAK)
	assert_eq(HostileElements.mult_of(d, &"light"), HostileElements.WEAK)
	assert_eq(HostileElements.mult_of(d, &"sleep"), HostileElements.WEAK)
	assert_eq(HostileElements.mult_of(d, &"frost"), HostileElements.NORMAL)


func test_out_from_dusk_to_dawn_and_lying_up_by_day() -> void:
	assert_eq(GloamerRoamer.routine_for(18.0), &"hunt")
	assert_eq(GloamerRoamer.routine_for(2.0), &"hunt")
	assert_eq(GloamerRoamer.routine_for(6.0), &"rest")
	assert_eq(GloamerRoamer.routine_for(12.0), &"rest")


func test_by_day_it_sleeps_at_home_and_wakes_when_it_moves() -> void:
	Clock.time_of_day = 12.0 / 24.0
	var g := _gloamer()
	g.home = g.global_position
	_think(g, DT)
	assert_true(g.is_lying_up(), "asleep in its pose at home")
	assert_lt(g.sight_scale(), 1.0, "and half seeing")
	_think(g, 3.0)
	assert_true(g.is_lying_up(), "it stays asleep")
	Clock.time_of_day = 19.0 / 24.0
	g.home = g.global_position + Vector3(10, 0, 0)
	_think(g, DT)
	assert_false(g.is_lying_up(), "night: it gets up")
	assert_eq(g.animator.action_clip(), GloamerRoamer.WAKE_CLIP)


# --- the fight --------------------------------------------------------------------

func test_the_first_to_see_her_calls() -> void:
	var g := _gloamer()
	var her := Node3D.new()
	add_child_autofree(her)
	g._on_ladder_changed(HostileLadder.State.SEARCHING, HostileLadder.State.ENGAGED, her)
	assert_eq(g.animator.action_clip(), &"call", "the chitter that becomes a shriek")


func test_the_rake_and_every_third_blow_the_shove() -> void:
	var g := _gloamer()
	var picks: Array[StringName] = []
	for i in 6:
		picks.append(g.pick_strike(null))
	var want: Array[StringName] = [GloamerRoamer.RAKE, GloamerRoamer.RAKE, GloamerRoamer.SHOVE,
			GloamerRoamer.RAKE, GloamerRoamer.RAKE, GloamerRoamer.SHOVE]
	assert_eq(picks, want)


func test_half_the_pack_down_and_the_rest_scatter() -> void:
	var site := _pack(4)
	site.report(site.members[0], Vector3(0, 0, 10))
	site.members[0].die(&"arrow_wood")
	assert_true(site.engaged, "one down of four: they fight on")
	for m in site.members.slice(1):
		assert_false((m as HostileRoamer).is_fleeing(), "not yet")
	site.members[1].die(&"arrow_wood")
	for m in site.members.slice(2):
		var r := m as HostileRoamer
		assert_true(r.is_fleeing(), "two of four down: the rest run")
		assert_false(r.ladder.is_hostile(), "having given her up")
	assert_false(site.engaged)
	assert_eq(_ended, [[&"gloamer_test_pack", &"gloamer", HostileEncounters.DRIVEN_OFF]],
			"the fight ends driven off, once")
	assert_false(site.is_settled, "the camp isn't cleared")
	# G25: the rout has an ending: the day is kept, a small swell comes back.
	assert_eq(WorldState.get_flag(HostileSite.ROUTED_FLAG % &"gloamer_test_pack"), Clock.day)
	assert_not_null(site.swell, "the place comes back for the night")
	if site.swell:
		assert_null(site.swell.sparkle, "the quiet swell, not the settle's")
	var r2 := site.members[2] as HostileRoamer
	assert_not_null(r2._dread)
	if r2._dread:
		assert_eq(r2._dread.max_intensity, HostileRoamer.ROUT_DREAD, "the dread eases")


func test_a_naga_camp_fights_to_the_last() -> void:
	var naga := load("res://creatures/hostile/naga_roamer.tscn").instantiate() as HostileRoamer
	assert_eq(naga.rout_share, 0.0)
	assert_eq(naga.glint_drawn, 0)
	naga.free()


func test_a_light_arrow_glow_pulls_the_two_nearest_off_to_squabble() -> void:
	var site := _pack(4)
	var at := Vector3(20, 0, 0)
	EventBus.arrow_light_landed.emit(at)
	var drawn: Array[HostileRoamer] = []
	for m in site.members:
		if (m as HostileRoamer).is_distracted():
			drawn.append(m)
	assert_eq(drawn.size(), 2, "two go for it, not the pack")
	var near := site.members.duplicate()
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(at) < b.global_position.distance_to(at))
	assert_true(drawn.has(near[0]) and drawn.has(near[1]), "the two nearest")
	var g := drawn[0] as GloamerRoamer
	g.global_position = at
	g._think(DT)
	assert_eq(g.animator.action_clip(), &"grab_shiny", "it grabs at it")
	for i in int(ceil(2.1 / DT)):
		g.animator._drive_action(DT)
	g._think(DT)
	assert_eq(g.animator.action_clip(), &"squabble", "then fights over it")


func test_a_wound_brings_it_back_to_her() -> void:
	var site := _pack(3)
	site.glint(Vector3(10, 0, 0))
	var g: HostileRoamer = null
	for m in site.members:
		if (m as HostileRoamer).is_distracted():
			g = m
	assert_not_null(g)
	g.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", g.global_position)
	assert_false(g.is_distracted(), "she is the thing that matters again")


func test_a_glint_far_off_draws_nobody() -> void:
	var site := _pack(3)
	EventBus.arrow_light_landed.emit(Vector3(500, 0, 0))
	for m in site.members:
		assert_false((m as HostileRoamer).is_distracted())
