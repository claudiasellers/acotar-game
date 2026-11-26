# gate: when:ui/hud/use_prompt.gd,ui/hud/key_prompt.gd,ui/frame/*,systems/mount/mount_director.gd,systems/fast_travel/*,systems/wayside/*
## What the interact keys do to the things in reach is said by one prompt
## with a verb, E first and T second; the mare, the whorl stones and the
## wayside spots draw no "E" of their own (the UX review, 2026-11-24) and
## offer through Interactor (owner, 2026-11-26).
extends GutTest

var prompt: UsePrompt


func before_each() -> void:
	SatchelHud.pad_active = false
	StoryControl.set_mode(StoryControl.Mode.FULL)
	prompt = UsePrompt.of(get_tree())


func after_each() -> void:
	StoryControl.set_mode(StoryControl.Mode.FULL)
	SatchelHud.pad_active = false


func test_one_prompt_says_the_newest_offer_and_takes_it_back() -> void:
	assert_same(UsePrompt.of(get_tree()), prompt, "one in the scene")
	var mare := Node3D.new()
	var stone := Node3D.new()
	add_child_autofree(mare)
	add_child_autofree(stone)
	prompt.offer(mare, "ride")
	await wait_process_frames(2)
	assert_eq(prompt.text(), "E   ride")
	prompt.offer(stone, "trace the whorl")
	await wait_process_frames(2)
	assert_eq(prompt.text(), "E   trace the whorl", "the newest speaks")
	prompt.offer(stone, "")
	await wait_process_frames(2)
	assert_eq(prompt.text(), "E   ride", "and the other is still in reach")
	SatchelHud.pad_active = true
	await wait_process_frames(2)
	assert_eq(prompt.text(), "X   ride", "named for the pad")
	prompt.offer(mare, "")
	await wait_process_frames(2)
	assert_eq(prompt.text(), "")


func test_two_slots_are_named_together_slot_one_first() -> void:
	var mare := Node3D.new()
	add_child_autofree(mare)
	prompt.offer(mare, "tend", &"interact_alt")
	prompt.offer(mare, "ride")
	assert_eq(prompt.offered(), [["ride", &"interact"], ["tend", &"interact_alt"]], "slot 1 first, whatever came first")
	await wait_process_frames(2)
	assert_eq(prompt.text(), "E   ride  ·  T   tend")
	SatchelHud.pad_active = true
	await wait_process_frames(2)
	assert_eq(prompt.text(), "X   ride  ·  Hold X   tend", "the pad's second is a hold of X")
	prompt.offer(mare, "", &"interact_alt")
	prompt.offer(mare, "")


func test_it_is_silent_in_a_scene_and_forgets_what_has_gone() -> void:
	var spot := Node3D.new()
	add_child(spot)
	prompt.offer(spot, "take it")
	StoryControl.set_mode(StoryControl.Mode.NONE)
	assert_eq(prompt.offered(), [], "a scene holds her hands")
	StoryControl.set_mode(StoryControl.Mode.FULL)
	assert_eq(prompt.offered(), [["take it", &"interact"]])
	spot.free()
	assert_eq(prompt.offered(), [], "a freed thing offers nothing")


func test_nothing_in_the_world_draws_its_own_key() -> void:
	for path: String in ["res://systems/mount/mount_director.gd", "res://systems/fast_travel/whorl_stone.gd",
			"res://systems/wayside/wayside_spot_node.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_gt(src.length(), 100, "%s exists" % path)
		assert_false(src.contains("Label3D"), "%s floats no label" % path)
		assert_true(src.contains("use_verb"), "%s offers its verb to the one prompt, through Interactor" % path)
	for kind: Script in [WaysideSnare, WaysideRest, WaysideNook]:
		assert_true(kind.get_script_method_list().any(func(m: Dictionary) -> bool: return m.name == "prompt_verb"),
				"%s says its own verb" % kind.resource_path)
