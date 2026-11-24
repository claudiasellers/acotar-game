# gate: when:ui/dressing_room/*,systems/crafting/*,systems/interaction/interactor.gd,ui/guide/*,ui/hud/key_prompt.gd,ui/menu/wardrobe_tab.gd
## Crown weaving is an action on the wardrobe's Crowns page, with no key in
## the world (the owner, 2026-11-24: pad Y is her knife, so the thought
## bookmark took d-pad down and the crown left it).
extends GutTest


func before_each() -> void:
	Gameplay.reset()


func after_each() -> void:
	if DressingRoom.is_open():
		DressingRoom.close_room(DressingRoom.view().feyre)
	SatchelHud.pad_active = false


func _open() -> DressingRoomView:
	var feyre := Feyre.new()
	add_child_autofree(feyre)
	await wait_process_frames(2)
	DressingRoom.open(feyre, DressingRoom.SATCHEL)
	await wait_process_frames(2)
	return DressingRoom.view()


func _crowns(view: DressingRoomView) -> Control:
	for i in view.tabs.get_tab_count():
		if String(view.tabs.get_tab_control(i).name) == DressingRoomView.WEAVE_TAB:
			return view.tabs.get_tab_control(i)
	return null


func test_without_blooms_the_page_says_so() -> void:
	var view: DressingRoomView = await _open()
	var crowns := _crowns(view)
	assert_not_null(crowns, "the Crowns page is there before she owns one")
	assert_true((crowns.find_child("WeaveChip", true, false) as Button).disabled)
	assert_eq((crowns.find_child("WeaveLine", true, false) as Label).text, DressingRoomView.WEAVE_NEEDS)
	assert_eq(view.weave_crown(), &"")


func test_with_blooms_she_weaves_one_and_wears_it() -> void:
	Gameplay.inventory.add(&"ing_rose_red", 3)
	Gameplay.inventory.add(&"ing_primrose", 2)
	assert_not_null(CrownWeaver.best_recipe(Gameplay.inventory))
	var view: DressingRoomView = await _open()
	var chip := _crowns(view).find_child("WeaveChip", true, false) as Button
	assert_false(chip.disabled)
	var tab_count := view.tabs.get_tab_count()
	chip.pressed.emit()
	var worn := Gameplay.wardrobe.equipped_in(&"head")
	assert_eq(worn, &"woven_crown_rose", "woven and on her head")
	assert_eq(view.tabs.get_tab_count(), tab_count, "the page is hung again in place")
	assert_eq(String(view.tabs.get_current_tab_control().name), DressingRoomView.WEAVE_TAB)
	var cards := _crowns(view).find_children("*", "PanelContainer", true, false).filter(func(c: Node) -> bool:
		return c.has_meta(&"pieces") and (c.get_meta(&"pieces") as Array).has(worn))
	assert_eq(cards.size(), 1, "the new crown has its card")


func test_no_key_in_the_world_weaves_and_the_bookmark_has_the_dpad() -> void:
	var feyre := Feyre.new()
	add_child_autofree(feyre)
	var guide := GuideJournal.new()
	add_child_autofree(guide)
	await wait_process_frames(2)
	assert_false(InputMap.has_action(&"weave_crown"), "the world shortcut is gone")
	var pads: Array = InputMap.action_get_events(GuideJournal.ACTION).filter(func(e: InputEvent) -> bool:
		return e is InputEventJoypadButton)
	assert_eq(pads.size(), 1)
	assert_eq((pads[0] as InputEventJoypadButton).button_index, JOY_BUTTON_DPAD_DOWN, "pad Y is free for her knife")
	assert_eq(KeyPrompt.key(GuideJournal.ACTION), "G")
	SatchelHud.pad_active = true
	assert_eq(KeyPrompt.key(GuideJournal.ACTION), "↓", "named from the input map on the pad")
