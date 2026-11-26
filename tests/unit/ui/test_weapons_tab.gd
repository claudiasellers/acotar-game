# gate: when:ui/weapons/*,systems/weapons/*,systems/imbue/*,data/combat/weapons/*,ui/menu/menu_tab.gd
## The Weapons page (UX review G28): what Feyre carries, said in her words,
## and the choice of what she holds, which the game used to make for her.
extends GutTest

const HOOK := &"wpn_gloamer_hookknife"
const SHEARS := &"wpn_blackvein_jaw_shears"
const GAFF := &"wpn_fishers_gaff"

var her: Node3D
var rack: WeaponRack
var tab: WeaponsTab


func before_each() -> void:
	WorldState.clear()
	her = Node3D.new()
	her.add_to_group(&"player")
	add_child_autofree(her)
	rack = WeaponRack.of(her)
	tab = WeaponsTab.new()
	add_child_autofree(tab)


func after_each() -> void:
	WorldState.clear()
	for c in get_children():
		if c is WeaponDrop:
			c.queue_free()


func test_the_list_is_the_knife_and_what_she_carries() -> void:
	rack.add(HOOK)
	rack.add(SHEARS)
	tab._shown()
	assert_eq(tab._rows.size(), 3, "the boot knife, then each weapon")
	assert_eq(tab.showing, 0, "it opens on the one in her hand")
	assert_eq(tab._name.text, WeaponWords.name_of(HOOK))
	assert_eq(tab._count.text, "2 of %d carried" % rack.capacity)


func test_she_chooses_what_she_holds() -> void:
	rack.add(HOOK)
	rack.add(SHEARS)
	tab._shown()
	tab.show_weapon(1)
	assert_eq(tab._hold.text, "Take it in hand")
	tab.hold_or_put_away()
	assert_eq(rack.held, 1)
	assert_eq(tab._hold.text, "Put it away")
	tab.hold_or_put_away()
	assert_eq(rack.held, WeaponsTab.KNIFE, "put away, the knife is in her hand")
	tab.show_weapon(WeaponsTab.KNIFE)
	assert_false(tab._hold.visible, "nothing to choose on the knife while she holds it")
	assert_false(tab._leave.visible, "the knife is never left behind")


func test_leaving_one_lays_it_at_her_feet_with_its_wear() -> void:
	rack.add(HOOK)
	rack.add(SHEARS, 0.5)
	tab._shown()
	tab.show_weapon(1)
	tab.leave_here()
	assert_eq(rack.carried.size(), 1)
	assert_eq(rack.held, 0, "the one she held stays in her hand")
	var drops := get_children().filter(func(c: Node) -> bool: return c is WeaponDrop)
	assert_eq(drops.size(), 1)
	assert_eq((drops[0] as WeaponDrop).weapon_id, SHEARS)
	assert_almost_eq((drops[0] as WeaponDrop).wear, 0.5, 0.05)
	assert_eq(tab._rows.size(), 2)


func test_every_weapon_is_said_in_words_and_never_a_figure() -> void:
	var digits := RegEx.create_from_string("[0-9]")
	for id: StringName in WeaponTable.ids():
		var w := WeaponTable.get_weapon(id)
		var lines := WeaponWords.does(w)
		assert_gt(lines.size(), 0, "%s says something" % id)
		assert_null(digits.search("\n".join(lines)), "%s: no numbers on her page" % id)
		if w.trait_id != &"":
			assert_true(WeaponWords.TRAITS.has(w.trait_id), "%s: the trait %s has words" % [id, w.trait_id])


func test_wear_reads_sound_then_scuffed_then_cracking() -> void:
	rack.add(HOOK, 1.0)
	rack.add(HOOK, 0.5)
	rack.add(HOOK, 0.2)
	assert_eq(WeaponWords.wear(rack, 0), "Sound.")
	assert_eq(WeaponWords.wear(rack, 1), "Scuffed, but it holds.")
	assert_eq(WeaponWords.wear(rack, 2), "Cracking. It won't last.")
	rack.carried[2].left = 1
	assert_eq(WeaponWords.wear(rack, 2), "One blow left in it.")


func test_a_steep_shows_in_its_slot() -> void:
	rack.add(SHEARS)
	assert_eq(Array(WeaponWords.steeps(rack.carried[0].imbue)), [WeaponWords.EMPTY_SLOT, WeaponWords.EMPTY_SLOT])
	assert_true(rack.imbue(0, &"ember", 1))
	assert_eq(Array(WeaponWords.steeps(rack.carried[0].imbue)), [WeaponWords.ELEMENTS[&"ember"], WeaponWords.EMPTY_SLOT])
	assert_eq(Array(WeaponWords.steeps(ImbueSlots.new(0))), [WeaponWords.NO_SLOTS])


func test_a_full_rack_with_only_the_knife_in_hand_says_there_is_no_room() -> void:
	for i in rack.capacity:
		rack.add(HOOK)
	rack.put_away()
	var d := WeaponDrop.spawn(self, Vector3.ZERO, GAFF)
	assert_eq(d.use_verb, "no room for %s" % WeaponWords.name_of(GAFF).to_lower())
	assert_false(d.use(her))
