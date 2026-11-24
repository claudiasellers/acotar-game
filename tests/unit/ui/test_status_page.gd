# gate: when:ui/dressing_room/*,ui/hud/vitals/status_row.gd,systems/vitals/*,ui/theme/*,ui/menu/wardrobe_tab.gd
## "How I am", the wardrobe's page on how Feyre is: her health and stamina in
## numbers, and every status on her with the HUD's own chip, name and words.
extends GutTest


func before_each() -> void:
	Gameplay.reset()


func after_each() -> void:
	if DressingRoom.is_open():
		DressingRoom.close_room(DressingRoom.view().feyre)


func test_meters_say_her_health_and_stamina_in_numbers() -> void:
	var vitals := VitalsState.new()
	autofree(vitals)
	vitals.health = 58.0
	var page := StatusPage.new()
	add_child_autofree(page)
	page.show_vitals(vitals, 40.0, 115.0)
	assert_eq(page.health.value, 58.0)
	assert_eq(page.health.max_value, VitalsState.MAX_HEALTH)
	assert_eq(page.health_count.text, "58 of 100")
	assert_eq(page.health.theme_type_variation, &"HealthMeter")
	assert_string_contains(page.heals_to.text, "up to %d" % roundi(vitals.regen_cap()))
	assert_eq(page.stamina.value, 40.0)
	assert_eq(page.stamina.theme_type_variation, &"StaminaMeter")
	assert_eq(page.stamina_count.text, "40 of 115")


func test_each_status_is_a_row_in_the_huds_words() -> void:
	var vitals := VitalsState.new()
	autofree(vitals)
	vitals.apply_status(&"test", &"venom", 0.6, 40.0)
	vitals.well_rested_left = 600.0
	var page := StatusPage.new()
	add_child_autofree(page)
	page.show_vitals(vitals, 100.0, 100.0)
	var tags: Array[String] = []
	for row in page.rows.get_children():
		tags.append(String(row.name))
	assert_eq(tags, ["venom", "well_rested"] as Array[String], "danger first, as the HUD's row")
	var venom := page.rows.get_node(^"venom")
	assert_eq((venom.find_child("Title", true, false) as Label).text, StatusRules.title(&"venom"))
	assert_eq((venom.find_child("Blurb", true, false) as Label).text, StatusRules.blurb(&"venom"))
	assert_eq((venom.find_child("State", true, false) as Label).text, "60%")
	assert_eq((page.rows.get_node(^"well_rested").find_child("State", true, false) as Label).text, "10 min left")
	page.show_vitals(vitals, 100.0, 100.0)
	assert_eq(page.rows.get_child_count(), 2, "shown again, not added to")


func test_a_gauge_names_its_stage_and_a_timer_its_time() -> void:
	for stage in 3:
		assert_eq(StatusPage.state_of({"tag": &"cold", "magnitude": 0.5, "stage": stage, "seconds_left": -1.0}),
				StatusPage.STAGE_WORDS[stage])
	assert_eq(StatusPage.state_of({"tag": &"steady", "magnitude": 1.0, "seconds_left": 45.2}), "46 s left")
	assert_eq(StatusPage.state_of({"tag": &"steady", "magnitude": 1.0, "seconds_left": 61.0}), "2 min left")
	assert_eq(StatusPage.state_of({"tag": &"at_ease", "magnitude": 0.5, "seconds_left": -1.0}), "", "a live state has no clock")
	for tag: StringName in StatusRules.ORDER:
		assert_ne(StatusRules.title(tag), "", "%s has a name" % tag)
		assert_ne(StatusRules.blurb(tag), "", "%s says what it does" % tag)
		assert_true(Icons.has(Icons.STATUS, tag), "%s has its chip's picture" % tag)


func test_the_satchels_wardrobe_opens_on_how_she_is() -> void:
	var feyre := Feyre.new()
	add_child_autofree(feyre)
	await wait_process_frames(2)
	DressingRoom.open(feyre, DressingRoom.SATCHEL)
	await wait_process_frames(2)
	var view := DressingRoom.view()
	var page := view.tabs.get_tab_control(0) as StatusPage
	assert_not_null(page, "the first page out in the world")
	assert_eq(view.tabs.current_tab, 0)
	assert_eq(String(page.name), StatusPage.TAB)
	assert_not_null(page.rows.get_node_or_null(^"cold"), "cold is always listed")
	assert_not_null(page.rows.get_node_or_null(^"hunger"), "and hunger")
	assert_eq(page.stamina.max_value, feyre.max_stamina)
	DressingRoom.close_room(feyre)
	DressingRoom.open(feyre, &"wardrobe")
	await wait_process_frames(2)
	view = DressingRoom.view()
	assert_true(view.tabs.get_tab_control(view.tabs.get_tab_count() - 1) is StatusPage, "last at the manor's wardrobe")
	assert_eq(view.tabs.current_tab, 0, "which still opens on its clothes")
	DressingRoom.close_room(feyre)
	DressingRoom.open(feyre, &"dressing_mirror")
	await wait_process_frames(2)
	assert_eq(DressingRoom.view().find_children("*", "StatusPage", true, false).size(), 0, "the vanity is for her face")
	DressingRoom.close_room(feyre)
