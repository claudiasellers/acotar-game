## Monster gear (plans/hostile-fae/monster-gear.md; docs/contracts/monster_gear.md):
## the looted weapons' rows and loot tables, the imbue slots (progression §8b's
## first slice), the rack (wear, breaking, saving), Strike with a held weapon
## (power, reach, swing, traits, imbues through the family rows), what bodies
## leave and what camp containers hold.
extends GutTest

const GLOAMER := preload("res://creatures/hostile/gloamer_roamer.tscn")
const NAGA := preload("res://creatures/hostile/naga_roamer.tscn")
const HOOK := &"wpn_gloamer_hookknife"
const CLUB := &"wpn_gloamer_knuckleclub"


class FakeHer:
	extends CharacterBody3D
	var is_aiming: bool = false
	var crouch := CrouchMotor.new()


var her: FakeHer
var k: StrikeController
var rack: WeaponRack


func before_each() -> void:
	StoryControl.release()
	WorldState.clear()
	her = FakeHer.new()
	her.add_to_group(&"player")
	add_child_autofree(her)
	k = StrikeController.new()
	her.add_child(k)
	k.set_physics_process(false)
	rack = WeaponRack.of(her)


func after_each() -> void:
	StoryControl.release()
	WorldState.clear()
	# What bodies dropped lies under this script's node: clear it between tests.
	for n in get_tree().get_nodes_in_group(WeaponDrop.GROUP):
		if n is WeaponDrop:
			n.free()


func _gloamer(at: Vector3 = Vector3.ZERO, id: StringName = &"gloamer_gear") -> GloamerRoamer:
	var g := GLOAMER.instantiate() as GloamerRoamer
	g.creature_id = id
	add_child_autofree(g)
	g.set_physics_process(false)
	g.senses.set_physics_process(false)
	g.collision_layer = 0
	g.collision_mask = 0
	g.global_position = at
	g.senses.awareness = 1.0
	return g


# --- the rows ---------------------------------------------------------------------

func test_every_row_is_whole() -> void:
	var ids := WeaponTable.ids()
	assert_gte(ids.size(), 19, "the catalogue's weapons")
	for id in ids:
		var w := WeaponTable.get_weapon(id)
		assert_eq(w.id, id)
		assert_ne(w.display_name, "", "%s has a name" % id)
		assert_between(w.power, 0.5, 3.0, "%s power" % id)
		assert_between(w.swing_s, 0.3, 1.5, "%s swing" % id)
		assert_between(w.reach_m, 1.4, 3.2, "%s reach" % id)
		assert_gt(w.durability, 0, "%s breaks in time" % id)
		assert_between(w.imbue_slots, 0, 2, "%s slots" % id)
		assert_true(w.trait_id in [&"", &"bleed", &"hamstring", &"sweep", &"stun", &"weakspot", &"glint"], "%s trait" % id)
		assert_lt(w.power, StrikeController.SNEAK_MULT, "%s never reaches a sneak" % id)
		assert_eq(w.model_path(), "res://art/monster_gear/%s.glb" % id, "L88's model id is the item id")


func test_every_loot_table_names_real_weapons() -> void:
	for family in [&"gloamer", &"naga", &"briarling", &"hob", &"blackvein", &"martax", &"crow"]:
		var t := LootTable.for_family(family)
		assert_not_null(t, String(family))
		if t == null:
			continue
		for id in t.carried + t.trophies + [t.leader_weapon, t.camp_weapon]:
			if id != &"":
				assert_true(WeaponTable.has(id), "%s names %s" % [family, id])
		assert_eq(t.trophies.size(), t.trophy_chances.size(), "%s: a chance per trophy" % family)


func test_the_naga_carry_nothing() -> void:
	assert_true(LootTable.for_family(&"naga").carried.is_empty(), "no clothes, gear or weapons [C]")


func test_a_gloamer_pack_carries_its_mix_and_a_big_pack_its_glaive() -> void:
	var t := LootTable.for_family(&"gloamer")
	assert_eq(t.carried_by(0, 4), HOOK)
	assert_eq(t.carried_by(1, 4), CLUB)
	assert_eq(t.carried_by(3, 4), &"wpn_gloamer_trinket_flail")
	assert_eq(t.carried_by(4, 5), &"wpn_gloamer_scythe_glaive", "the fifth of five")
	assert_eq(t.carried_by(3, 5), &"wpn_gloamer_trinket_flail")


# --- imbue slots ------------------------------------------------------------------

func test_imbue_slots_hold_an_element_at_a_tier() -> void:
	var s := ImbueSlots.new(2)
	assert_true(s.apply(0, &"ember", 3))
	assert_almost_eq(s.share(&"ember", 0), 0.3, 0.001)
	assert_true(s.apply(1, &"ember", 3))
	assert_almost_eq(s.share(&"ember", 0), 0.5, 0.001, "capped at 50%")
	assert_false(s.apply(2, &"ember", 1), "no third slot")
	assert_false(s.apply(0, &"hush", 1), "Hush has no Tier I")
	assert_false(s.apply(0, &"nonsense", 2))


func test_a_brew_imbue_runs_out_and_a_folk_one_never_does() -> void:
	var s := ImbueSlots.new(2)
	s.apply(0, &"rime", 1, 4)
	s.apply(1, &"glimmer", 3)
	assert_almost_eq(s.share(&"rime", 4), 0.1, 0.001, "still running on its last day")
	assert_eq(s.share(&"rime", 5), 0.0, "gone the next")
	assert_almost_eq(s.share(&"glimmer", 500), 0.3, 0.001, "Tier III never runs out")
	assert_eq(s.free_slot(5), 0, "the spent slot is free again")


func test_imbue_slots_survive_a_save() -> void:
	var s := ImbueSlots.new(2)
	s.apply(1, &"hush", 2, 9)
	var back := ImbueSlots.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.count, 2)
	assert_almost_eq(back.share(&"hush", 9), 0.15, 0.001)


# --- the rack ---------------------------------------------------------------------

func test_a_pickup_is_held_at_once_and_wears_and_breaks() -> void:
	assert_eq(rack.add(HOOK), 0)
	assert_eq(rack.held_weapon().id, HOOK, "empty-handed, she takes it up")
	assert_eq(rack.left_of(0), 18)
	for i in 17:
		assert_false(rack.wear_held())
	assert_true(rack.is_worn(0), "it shows worn near the end")
	assert_true(rack.last_hit())
	watch_signals(rack)
	assert_true(rack.wear_held(), "the eighteenth hit breaks it")
	assert_signal_emitted_with_parameters(rack, "broke", [HOOK])
	assert_null(rack.held_weapon(), "back to the boot knife")


func test_when_one_breaks_she_takes_up_the_next() -> void:
	rack.add(HOOK, 1.0 / 18.0)
	rack.add(CLUB)
	assert_true(rack.wear_held())
	assert_eq(rack.held_weapon().id, CLUB)


func test_a_resisted_hit_wears_it_twice() -> void:
	rack.add(HOOK)
	rack.wear_held(true)
	assert_eq(rack.left_of(0), 16)


func test_the_rack_holds_five() -> void:
	for i in WeaponRack.CAPACITY:
		assert_gte(rack.add(HOOK), 0)
	assert_eq(rack.add(HOOK), -1, "full")
	assert_eq(rack.add(&"not_a_weapon"), -1)


func test_the_rack_survives_a_save() -> void:
	rack.add(HOOK, 0.5)
	rack.add(CLUB)
	rack.imbue(1, &"ember", 3)
	rack.hold(1)
	var data: Dictionary = JSON.parse_string(JSON.stringify(rack.save_state()))
	rack.load_state({})
	assert_true(rack.carried.is_empty())
	rack.load_state(data)
	assert_eq(rack.carried.size(), 2)
	assert_eq(rack.left_of(0), 9)
	assert_eq(rack.held_weapon().id, CLUB)
	assert_almost_eq(float(rack.held_shares().get(&"ember", 0.0)), 0.3, 0.001)


# --- Strike with a held weapon ----------------------------------------------------

func test_a_held_weapon_strikes_with_its_power_and_reach_and_wears() -> void:
	var g := _gloamer(Vector3(0, 0, -1.85))
	assert_null(k.target(), "1.85 m is past the boot knife's reach")
	rack.add(HOOK)
	assert_eq(k.target(), g, "the hook-knife reaches it")
	assert_true(k.strike())
	assert_almost_eq(g.health, 24.0 - 8.0 * 1.25, 0.01, "power 1.25 of its arrow damage")
	assert_eq(rack.left_of(0), 17, "one hit's wear")
	assert_gt(g.bleeding, 0.0, "the hook bleeds it")
	assert_almost_eq(k._cooldown, 0.6, 0.001, "its swing")


func test_the_knife_scale_is_the_boot_knifes_alone() -> void:
	var g := _gloamer(Vector3(0, 0, -1.7))
	rack.add(CLUB)
	k.strike()
	assert_almost_eq(g.health, 24.0 - 8.0 * 1.8, 0.01, "the club's power, not x knife_scale")


func test_the_last_hit_lands_double_and_breaks_it() -> void:
	var g := _gloamer(Vector3(0, 0, -1.7))
	rack.add(CLUB, 1.0 / 22.0)
	k.strike()
	assert_false(g.alive, "1.8 x 2 x 8 = 28.8 of its 24")
	assert_null(rack.held_weapon())


func test_an_imbued_weapon_reacts_through_the_family_row() -> void:
	var g := _gloamer(Vector3(0, 0, -1.7))
	HostileElements.show_fx = false
	rack.add(HOOK)
	rack.imbue(0, &"ember", 3)
	k.strike()
	HostileElements.show_fx = true
	assert_gt(g.burn_left, 0.0, "Ember on a gloamer (weak) sets it burning")
	assert_almost_eq(g.burn_left, StrikeController.IMBUE_SECONDS * 0.3 * HostileElements.WEAK, 0.01)


func test_hush_builds_to_sleep() -> void:
	var g := _gloamer(Vector3(0, 0, -1.7))
	HostileElements.show_fx = false
	for i in 2:
		StrikeController.imbue_effect(g, &"sleep", 0.25 * HostileElements.WEAK)
	assert_eq(g.asleep_left, 0.0, "not yet")
	StrikeController.imbue_effect(g, &"sleep", 0.25 * HostileElements.WEAK)
	HostileElements.show_fx = true
	assert_gt(g.asleep_left, 0.0, "the third Tier III hit on a Hush-weak gloamer drops it")


func test_a_sweep_catches_the_next_one_in_front() -> void:
	var a := _gloamer(Vector3(0, 0, -1.6), &"gear_a")
	var b := _gloamer(Vector3(0.8, 0, -1.8), &"gear_b")
	var behind := _gloamer(Vector3(0, 0, 1.5), &"gear_behind")
	rack.add(&"wpn_gloamer_scythe_glaive")
	k.strike()
	assert_lt(a.health, 24.0)
	assert_lt(b.health, 24.0, "the sweep's second")
	assert_eq(behind.health, 24.0, "not the one behind her")
	assert_eq(rack.left_of(0), 15, "one swing, one wear")


# --- what bodies and camps leave ----------------------------------------------------

func _drops() -> Array[WeaponDrop]:
	var out: Array[WeaponDrop] = []
	for n in get_tree().get_nodes_in_group(WeaponDrop.GROUP):
		if n is WeaponDrop and not (n as WeaponDrop).taken:
			out.append(n)
	return out


func test_a_dead_gloamer_drops_the_weapon_in_its_hand_used() -> void:
	var g := _gloamer()
	assert_eq(g.carried_weapon, HOOK, "the first of a pack carries the hook-knife")
	var before := _drops().size()
	g.die(&"arrow_wood")
	var drops := _drops()
	assert_eq(drops.size(), before + 1)
	var d := drops.back() as WeaponDrop
	assert_eq(d.weapon_id, HOOK)
	assert_between(d.wear, 0.5, 0.9, "it's been used")
	for x in drops:
		x.queue_free()


func test_taking_a_drop_and_swapping_when_full() -> void:
	var d := WeaponDrop.spawn(self, Vector3.ZERO, CLUB, 0.5)
	assert_true(d.open_now())
	assert_true(d.use(her))
	assert_eq(rack.held_weapon().id, CLUB)
	for i in WeaponRack.CAPACITY - 1:
		rack.add(HOOK)
	var e := WeaponDrop.spawn(self, Vector3.ZERO, &"wpn_pruning_hook")
	assert_eq(e.use_verb, "swap for pruning hook")
	assert_true(e.use(her))
	assert_eq(rack.carried.size(), WeaponRack.CAPACITY)
	var left := _drops()
	assert_eq(left.size(), 1, "the club is left lying where the hook was")
	assert_eq(left[0].weapon_id, CLUB)
	assert_almost_eq(left[0].wear, 11.0 / 22.0, 0.01, "with its wear")
	left[0].queue_free()


func test_a_unique_trophy_drops_once() -> void:
	assert_false(WeaponRack.unique_dropped(&"wpn_hob_tooth_cleaver"))
	WeaponRack.mark_unique_dropped(&"wpn_hob_tooth_cleaver")
	assert_true(WeaponRack.unique_dropped(&"wpn_hob_tooth_cleaver"))


func test_a_camp_container_gives_coins_and_its_weapon_once() -> void:
	var data := HostileSiteData.new()
	data.id = &"gear_test_camp"
	data.family = &"gloamer"
	data.count = 0
	var site := HostileSite.new()
	site.data = data
	site.snap_to_core = false
	site.height_func = func(_x: float, _z: float) -> float: return 0.0
	add_child_autofree(site)
	var c := site.camp_loot
	assert_not_null(c, "a gloamer camp has its hoard")
	var coins := Gameplay.inventory.coin
	assert_true(c.open_now())
	var got: Dictionary = c.use(her)
	assert_between(int(got.coins), 3, 8)
	assert_eq(Gameplay.inventory.coin, coins + int(got.coins))
	assert_eq(got.weapon, HOOK)
	assert_false(c.open_now(), "emptied")
	Gameplay.inventory.coin = coins
	for x in _drops():
		x.queue_free()


func test_a_camp_refills_only_after_the_blight() -> void:
	assert_true(CampContainer.is_full(null, 3, 7, false))
	assert_false(CampContainer.is_full(3, 40, 7, false), "before the blight, empty for good")
	assert_false(CampContainer.is_full(3, 8, 7, true))
	assert_true(CampContainer.is_full(3, 10, 7, true), "after it, full again a week on")
