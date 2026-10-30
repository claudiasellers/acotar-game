extends GutTest


func test_starts_in_hunting_clothes() -> void:
	var w := Wardrobe.new()
	assert_eq(w.equipped_in(&"top"), &"hunter_tunic")
	assert_eq(w.equipped_in(&"outer"), &"hunter_cloak")
	assert_gt(w.warmth(), 0.5)


func test_gown_replaces_top_and_bottom() -> void:
	var w := Wardrobe.new()
	assert_false(w.equip(&"ball_gown_rose"), "must own it first")
	assert_true(w.grant(&"ball_gown_rose"))
	assert_true(w.equip(&"ball_gown_rose"))
	assert_eq(w.equipped_in(&"top"), &"ball_gown_rose")
	assert_eq(w.equipped_in(&"bottom"), &"ball_gown_rose")
	w.grant(&"spring_tunic_sage")
	w.equip(&"spring_tunic_sage")
	assert_eq(w.equipped_in(&"bottom"), &"", "putting on a tunic takes the gown off")


func test_makeup_and_hair_round_trip() -> void:
	var w := Wardrobe.new()
	assert_true(w.apply_makeup(&"lips_rosebud"))
	assert_true(w.apply_makeup(&"eyes_gold"))
	assert_true(w.set_hair(&"crown_braid"))
	w.grant(&"tiara_gold")
	w.equip(&"tiara_gold")
	var copy := Wardrobe.new()
	copy.load_state(JSON.parse_string(JSON.stringify(w.save_state())))
	assert_eq(copy.hair, &"crown_braid")
	assert_eq(String(copy.makeup()[&"lips"]["id"]), "lips_rosebud")
	assert_eq(copy.equipped_in(&"head"), &"tiara_gold")


func test_notice_angle_and_drift() -> void:
	var cam := Transform3D(Basis(), Vector3.ZERO)
	assert_almost_eq(NoticeDirector.angle_to(cam, Vector3(0, 0, -10)), 0.0, 0.01)
	assert_almost_eq(NoticeDirector.angle_to(cam, Vector3(10, 0, -10)), 45.0, 0.01)
	var drift := NoticeDirector.drift_toward(cam, Vector3(10, 0, -10), 0.01)
	assert_lt(drift.x, 0.0, "turns right (negative yaw) toward +X")
	assert_almost_eq(absf(drift.x), 0.01, 0.0001, "never faster than the cap")


func test_holding_the_look_adds_one_sketch() -> void:
	Gameplay.reset()
	var director := NoticeDirector.new()
	autofree(director)
	var point := NoticePoint.new()
	point.sketch_id = &"sketch_snowdrop"
	point.title = "Snowdrop"
	point.look_seconds = 1.0
	add_child_autofree(point)
	point.global_position = Vector3(0, 0, -5)
	var cam := Transform3D(Basis(), Vector3.ZERO)
	for i in 12:
		director.update(0.1, cam, [point], true)
	assert_true(Gameplay.sketchbook.has(&"sketch_snowdrop"))
	assert_eq(Gameplay.sketchbook.count(), 1)
	for i in 12:
		director.update(0.1, cam, [point], true)
	assert_eq(Gameplay.sketchbook.count(), 1)


func test_moving_resets_the_hold() -> void:
	Gameplay.reset()
	var director := NoticeDirector.new()
	autofree(director)
	var point := NoticePoint.new()
	point.sketch_id = &"sketch_hands"
	point.look_seconds = 1.0
	add_child_autofree(point)
	point.global_position = Vector3(0, 0, -5)
	var cam := Transform3D(Basis(), Vector3.ZERO)
	for i in 8:
		director.update(0.1, cam, [point], true)
	director.update(0.1, cam, [point], false)
	for i in 8:
		director.update(0.1, cam, [point], true)
	assert_false(Gameplay.sketchbook.has(&"sketch_hands"))


func test_story_gift_ids_exist() -> void:
	for id in [&"outfit_solstice_blue_gown", &"outfit_mortal_travel_dress"]:
		assert_not_null(WardrobeCatalog.piece(id), String(id))
	assert_not_null(WardrobeCatalog.hair(&"hair_loose_with_flowers"))
	assert_true(ItemCatalog.has(&"obj_lucien_knife"))
	assert_true(ItemCatalog.has(&"obj_white_roses"))


func test_journal_truths_once_and_saved() -> void:
	var j := ProofJournal.new()
	assert_true(j.add_truth(&"treaty_no_loophole"))
	assert_false(j.add_truth(&"treaty_no_loophole"))
	var copy := ProofJournal.new()
	copy.load_state(JSON.parse_string(JSON.stringify(j.save_state())))
	assert_eq(copy.truths, [&"treaty_no_loophole"] as Array[StringName])
