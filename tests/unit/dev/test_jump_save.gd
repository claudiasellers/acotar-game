## Contract for the dev jump (tools/dev/jump_save.gd, T163): a jump to the
## beast at the door sets everything BeastDoor waits on and nothing that ends
## it, and its beats are act1_playtest's, in play order.
# gate: when:tools/dev/*,story/act1/*,tools/playtest/act1_playtest.gd
extends GutTest

const JUMP := preload("res://tools/dev/jump_save.gd")


func test_beast_door_jump_meets_what_the_door_waits_on() -> void:
	var door := BeastDoor.new()
	var flags := JUMP.flags_before("beast_door")
	for flag in door.require_flags:
		assert_true(flags.has(flag), "the jump sets %s, which BeastDoor needs" % flag)
	for flag in door.done_flags:
		assert_false(flags.has(flag), "the jump leaves %s unset, or the door never starts" % flag)
	assert_true(JUMP.jumpable().has("beast_door"))
	door.free()


func test_beats_are_the_playtests_in_order() -> void:
	var playtest: Array = load("res://tools/playtest/act1_playtest.gd").ACCEPTANCE_BEATS
	var last := -1
	for beat: Dictionary in JUMP.BEATS:
		var at := playtest.find(beat.id)
		assert_gt(at, last, "%s is an act1_playtest beat, after the one before it" % beat.id)
		last = at
