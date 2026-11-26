# gate: when:systems/weapons/*,systems/imbue/*,systems/strike/*,systems/chemistry/*,ui/chemistry/brew_menu.gd,data/stations/*
## Steeping a looted weapon (monster-gear §1.4; docs/contracts/monster_gear.md):
## at a hearth or a lit camp fire, a steeped arrow gives the weapon in her
## hand that element at Tier I until it breaks, the arrow is used up, and her
## hits carry it. Sleep arrows don't steep a blade (no Tier I Hush, §8b.4).
extends GutTest

const GLOAMER := preload("res://creatures/hostile/gloamer_roamer.tscn")
const HOOK := &"wpn_gloamer_hookknife"


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
	Gameplay.reset()
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


func _fire(data: String, lit: bool = true) -> CookingStation:
	var f := CookingStation.new()
	f.station = load("res://data/stations/%s.tres" % data)
	f.lit = lit
	add_child_autofree(f)
	return f


func test_a_steeped_arrow_at_a_hearth_steeps_the_held_weapon_until_it_breaks() -> void:
	rack.add(HOOK)
	Gameplay.inventory.add(&"arrow_fire", 2)
	Gameplay.inventory.add(&"arrow_sleep", 1)
	var hearth := _fire("hearth", false)
	assert_true(WeaponSteep.is_fire(hearth), "a hearth's fire is the node it brews on")
	assert_eq(WeaponSteep.offers(rack, Gameplay.inventory), [&"arrow_fire"] as Array[StringName],
			"the fire arrow is offered; the sleep arrow isn't")
	assert_eq(WeaponSteep.verb(rack, &"arrow_fire"), "Steep my hook-knife with a fire arrow")
	var r := WeaponSteep.steep(rack, hearth, &"arrow_fire")
	assert_true(r.ok, str(r))
	assert_eq(r.element, &"ember")
	assert_eq(Gameplay.inventory.arrow_count(&"arrow_fire"), 1, "the arrow is used up")
	var e := (rack.held_instance().imbue as ImbueSlots).entry(0)
	assert_eq(e.element, &"ember")
	assert_eq(int(e.tier), WeaponSteep.TIER)
	assert_eq(int(e.until_day), ImbueSlots.FOREVER, "it holds until the weapon breaks")
	assert_eq(WeaponSteep.offers(rack, Gameplay.inventory).size(), 0, "its one slot is full")
	assert_false(WeaponSteep.steep(rack, hearth, &"arrow_fire").ok)
	assert_eq(Gameplay.inventory.arrow_count(&"arrow_fire"), 1, "a refused steep keeps the arrow")


func test_it_wants_a_fire_a_weapon_and_a_steep_that_takes() -> void:
	Gameplay.inventory.add(&"arrow_frost", 1)
	Gameplay.inventory.add(&"arrow_sleep", 1)
	var hearth := _fire("hearth")
	assert_false(WeaponSteep.steep(rack, hearth, &"arrow_frost").ok, "not the boot knife")
	rack.add(HOOK)
	assert_false(WeaponSteep.is_fire(_fire("stillroom")), "a stillroom bench is no fire")
	assert_false(WeaponSteep.steep(rack, _fire("stillroom"), &"arrow_frost").ok)
	assert_false(WeaponSteep.is_fire(_fire("campfire", false)), "an unlit camp fire")
	assert_true(WeaponSteep.is_fire(_fire("campfire", true)), "a lit camp fire")
	assert_false(WeaponSteep.steep(rack, hearth, &"arrow_sleep").ok, "no Tier I Hush")
	assert_eq(Gameplay.inventory.arrow_count(&"arrow_sleep"), 1)
	assert_true(WeaponSteep.steep(rack, _fire("campfire", true), &"arrow_frost").ok)
	assert_eq(rack.held_instance().imbue.entry(0).element, &"rime")


func test_her_hits_carry_the_steep() -> void:
	rack.add(HOOK)
	Gameplay.inventory.add(&"arrow_fire", 1)
	assert_true(WeaponSteep.steep(rack, _fire("hearth"), &"arrow_fire").ok)
	var g := GLOAMER.instantiate() as GloamerRoamer
	g.creature_id = &"gloamer_steep"
	add_child_autofree(g)
	g.set_physics_process(false)
	g.senses.set_physics_process(false)
	g.collision_layer = 0
	g.collision_mask = 0
	g.global_position = Vector3(0, 0, -1.7)
	g.senses.awareness = 1.0
	HostileElements.show_fx = false
	k.strike()
	HostileElements.show_fx = true
	assert_almost_eq(g.burn_left, StrikeController.IMBUE_SECONDS * 0.1 * HostileElements.WEAK, 0.01,
			"Tier I Ember on a gloamer (weak) burns it")
