## The Hollow Hob (bestiary §10, plan §5.7): L83's rigged giant with every clip
## its brain names; 30 wood or 3 ash; asleep 09:00-22:00 at home, half seeing;
## a sneak blow while it sleeps cuts a charm from its necklace instead of
## wounding it, and eight cuts settle the hollow; at dusk it counts its charms
## and searches for one gone; the swat, the stomp at her feet, and a rock
## thrown at range that lands where she stood.
extends GutTest

const HOB := preload("res://creatures/hostile/hob_roamer.tscn")
const DT := 1.0 / 30.0


class FakeHer:
	extends CharacterBody3D
	var body_state: BodyState
	var is_aiming: bool = false
	var crouch := CrouchMotor.new()
	var stamina: float = 100.0
	var max_stamina: float = 100.0

	func drain_stamina(amount: float) -> void:
		stamina -= amount

	func is_winded() -> bool:
		return stamina <= 0.0


var _time: float


func before_each() -> void:
	_time = Clock.time_of_day
	Clock.time_of_day = 12.0 / 24.0
	StoryControl.release()
	WorldState.clear()


func after_each() -> void:
	Clock.time_of_day = _time
	StoryControl.release()
	WorldState.clear()


func _hob() -> HobRoamer:
	var h := HOB.instantiate() as HobRoamer
	h.creature_id = &"hob_test"
	add_child_autofree(h)
	h.set_physics_process(false)
	h.senses.set_physics_process(false)
	h.collision_layer = 0
	h.collision_mask = 0
	h.home = h.global_position
	return h


func _think(h: HobRoamer, seconds: float) -> void:
	for i in int(ceil(seconds / DT)):
		h._think(DT)


# --- the body -------------------------------------------------------------------

func test_its_body_is_the_rigged_hob_with_every_clip_its_brain_names() -> void:
	var h := _hob()
	assert_eq(h.data.kind, &"hob")
	assert_eq(h.data.model_scene.resource_path, "res://creatures/models/fae/hollow_hob.gltf")
	assert_not_null(h.animator, "rigged: its clips drive it")
	if h.animator == null:
		return
	for clip: StringName in [HobRoamer.SLEEP_CLIP, HobRoamer.EYE_CLIP, HobRoamer.SIT_UP_CLIP,
			HobRoamer.SNIFF_CLIP, HobRoamer.WAKE_CLIP, HobRoamer.COUNT_CLIP, HobRoamer.SEARCH_CLIP,
			HobRoamer.STIR_CLIP, h.call_clip, &"telegraph_hob_swat", &"attack_hob_swat",
			&"telegraph_hob_stomp", &"attack_hob_stomp", &"telegraph_hob_throw", &"attack_hob_throw"]:
		assert_true(h.animator.anim.has_animation(clip), "it has its %s clip" % clip)


func test_its_rows() -> void:
	var swat := AttackTable.resolve(HobRoamer.SWAT)
	var stomp := AttackTable.resolve(HobRoamer.STOMP)
	var throw := AttackTable.resolve(HobRoamer.THROW)
	assert_eq(swat.damage, 55.0)
	assert_almost_eq(swat.windup_s, 0.9, 0.001)
	assert_eq(stomp.damage, 35.0)
	assert_almost_eq(stomp.windup_s, 1.0, 0.001)
	assert_eq(throw.family, &"hob")
	assert_eq(throw.damage, 30.0)
	assert_almost_eq(throw.windup_s, 1.0, 0.001)


# --- numbers ----------------------------------------------------------------------

func test_thirty_wood_arrows_or_three_ash() -> void:
	var h := _hob()
	for i in 29:
		h.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", h.global_position)
	assert_true(h.alive, "29 wood arrows leave it standing")
	h.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", h.global_position)
	assert_false(h.alive, "the 30th drops it")
	var a := _hob()
	for i in 2:
		a.apply_hit(&"arrow_ash", &"ash", 1.0, &"body", a.global_position)
	assert_true(a.alive, "two ash leave it standing")
	a.apply_hit(&"arrow_ash", &"ash", 1.0, &"body", a.global_position)
	assert_false(a.alive, "the third drops it")


func test_its_element_row_fire_sends_it_off() -> void:
	var d := load("res://data/creatures/hostile/hob_roamer.tres") as CreatureData
	assert_eq(HostileElements.mult_of(d, &"fire"), HostileElements.WEAK)
	assert_eq(HostileElements.mult_of(d, &"frost"), HostileElements.NORMAL)
	assert_eq(HostileElements.mult_of(d, &"sleep"), HostileElements.NORMAL)


# --- its day ----------------------------------------------------------------------

func test_asleep_from_nine_to_ten_at_night() -> void:
	assert_eq(HobRoamer.routine_for(9.0), &"rest")
	assert_eq(HobRoamer.routine_for(12.0), &"rest")
	assert_eq(HobRoamer.routine_for(21.9), &"rest")
	assert_eq(HobRoamer.routine_for(22.0), &"awake")
	assert_eq(HobRoamer.routine_for(3.0), &"awake")


func test_by_day_it_sleeps_at_home_half_seeing() -> void:
	var h := _hob()
	_think(h, DT)
	assert_true(h.is_sleeping())
	assert_eq(h.animator.action_clip(), HobRoamer.SLEEP_CLIP, "sprawled on its stone")
	assert_eq(h.sight_scale(), HobRoamer.ASLEEP_SIGHT)
	Clock.time_of_day = 23.0 / 24.0
	_think(h, DT)
	assert_false(h.is_sleeping(), "night: it's up")
	assert_eq(h.sight_scale(), 1.0)


func test_at_dusk_it_counts_its_charms_and_searches_for_one_gone() -> void:
	var h := _hob()
	_think(h, DT)
	WorldState.set_flag(HobRoamer.CHARM_FLAG % 1, true)
	Clock.time_of_day = 22.5 / 24.0
	_think(h, DT)
	assert_true(h.is_searching_for_charm(), "a charm gone since its last count")
	assert_eq(int(WorldState.get_flag(HobRoamer.COUNTED_FLAG)), 1)
	# The next dusk, nothing new gone: it only counts.
	Clock.time_of_day = 12.0 / 24.0
	_think(h, HobRoamer.SEARCH_SECONDS + 1.0)
	Clock.time_of_day = 22.5 / 24.0
	_think(h, DT)
	assert_false(h.is_searching_for_charm())


# --- robbing it ---------------------------------------------------------------------

func test_a_sneak_blow_while_it_sleeps_cuts_a_charm_and_does_not_wound_it() -> void:
	var h := _hob()
	_think(h, DT)
	assert_eq(HobRoamer.next_charm(), 1)
	assert_true(h.take_strike(&"sneak", null), "the blow cuts a charm")
	assert_true(HobRoamer.charm_cut(1))
	assert_eq(HobRoamer.next_charm(), 2, "one at a time along the cord")
	assert_eq(h.health, h.data.max_health, "not a scratch on it")
	assert_lt(h.senses.awareness, HostileLadder.CURIOUS_AT, "it stirs and settles again")
	assert_false(h.take_strike(&"knife", null), "a plain blow is only a blow")


func test_a_cut_charm_is_gone_from_its_necklace() -> void:
	WorldState.set_flag(HobRoamer.CHARM_FLAG % 3, true)
	var h := _hob()
	var meshes := h.find_children("charm_*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), HobRoamer.CHARMS.size(), "a mesh for each charm")
	for node in meshes:
		var m := node as MeshInstance3D
		var n := HobRoamer.charm_of(String(m.name))
		assert_eq(m.visible, n != 3, "%s shows unless it was cut" % m.name)


func test_awake_or_roused_it_cannot_be_robbed() -> void:
	Clock.time_of_day = 23.0 / 24.0
	var h := _hob()
	_think(h, DT)
	assert_false(h.take_strike(&"sneak", null), "awake at night")
	assert_false(HobRoamer.charm_cut(1))


func test_a_sleep_arrow_buys_one_more_charm() -> void:
	Clock.time_of_day = 23.0 / 24.0
	var h := _hob()
	h.asleep_left = 5.0
	assert_true(h.is_sleeping())
	assert_true(h.take_strike(&"finisher", null))


func test_strike_takes_the_charm_through_the_controller() -> void:
	var h := _hob()
	_think(h, DT)
	h.senses.awareness = 0.0
	var her := FakeHer.new()
	her.add_to_group(&"player")
	add_child_autofree(her)
	her.global_position = Vector3(0, 0, 2.8)
	var k := StrikeController.new()
	her.add_child(k)
	k.set_physics_process(false)
	assert_eq(k.target(), h, "its body reaches past its middle")
	assert_true(k.strike())
	assert_true(HobRoamer.charm_cut(1), "behind it, asleep: a charm")
	assert_eq(h.health, h.data.max_health)


func test_eight_charms_cut_settle_the_hollow() -> void:
	var data := (load("res://data/creatures/hostile_sites/hob_silent_hollow.tres") as HostileSiteData).duplicate() as HostileSiteData
	var site := HostileSite.new()
	site.data = data
	site.snap_to_core = false
	site.height_func = func(_x: float, _z: float) -> float: return 0.0
	add_child_autofree(site)
	var h := site.members[0] as HobRoamer
	h.set_physics_process(false)
	h.senses.set_physics_process(false)
	h.home = h.global_position
	_think(h, DT)
	for i in range(1, 8):
		WorldState.set_flag(HobRoamer.CHARM_FLAG % i, true)
	assert_false(site.is_settled)
	assert_true(h.take_strike(&"sneak", null))
	assert_eq(HobRoamer.next_charm(), 0)
	assert_true(site.is_settled, "robbed asleep of every charm: the hollow settles")
	assert_true(h.alive)


# --- the fight ----------------------------------------------------------------------

func test_the_swat_and_under_it_the_stomp() -> void:
	var h := _hob()
	var near := Node3D.new()
	add_child_autofree(near)
	near.global_position = Vector3(0, 0, 2.0)
	assert_eq(h.pick_strike(near), HobRoamer.STOMP)
	near.global_position = Vector3(0, 0, 3.5)
	assert_eq(h.pick_strike(near), HobRoamer.SWAT)


func test_at_range_it_throws_a_rock_that_lands_where_she_stood() -> void:
	var h := _hob()
	var her := Node3D.new()
	add_child_autofree(her)
	her.global_position = Vector3(0, 0, 15.0)
	h._fight(her, DT)
	assert_eq(h.winding_up(), HobRoamer.THROW, "it lifts a boulder")
	assert_true(HobRoamer.throw_lands(Vector3(0, 0, 15), Vector3(1, 0, 15)), "she stayed: it hits")
	assert_false(HobRoamer.throw_lands(Vector3(0, 0, 15), Vector3(4, 0, 15)), "she ran: it misses")


func test_the_hollow_is_placed_from_p4() -> void:
	var d := load("res://data/creatures/hostile_sites/hob_silent_hollow.tres") as HostileSiteData
	assert_eq(d.family, &"hob")
	assert_eq(d.count, 1)
	assert_eq(d.core, Vector2(-1300, 900))
	assert_true("starlight_pool_found" in d.require_flags)
	var table: CreatureSpawnTable = load("res://data/creatures/spawn/western_fells.tres")
	var found := false
	for e in table.entries:
		found = found or e.id == &"site_hob_silent_hollow"
	assert_true(found, "the western fells carry it")
