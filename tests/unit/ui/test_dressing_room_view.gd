## The dressing room screen: every piece filed in one tab and one garment card,
## colour variants as swatches, wearing twirls and keeps the game paused.
extends GutTest



func before_each() -> void:
	Gameplay.reset()


func test_every_piece_has_a_tab_and_variants_share_a_card() -> void:
	var all := WardrobeCatalog.all_pieces()
	var names: Array[String] = ["Gowns"]
	for c in DressingRoomView.CATEGORIES:
		names.append(c["name"])
	var counted := 0
	for n in names:
		var here: Array[WardrobePiece] = all.filter(func(p: WardrobePiece) -> bool: return DressingRoomView.category_of(p) == n)
		for fam in DressingRoomView.families(here):
			counted += (fam["pieces"] as Array).size()
	# "Gowns" is listed in CATEGORIES too; count each tab once.
	var gowns := all.filter(func(p: WardrobePiece) -> bool: return DressingRoomView.category_of(p) == "Gowns").size()
	assert_eq(counted - gowns, all.size(), "each piece sits in exactly one tab")
	var gowns_only: Array[WardrobePiece] = all.filter(func(p: WardrobePiece) -> bool: return p.mesh_path.ends_with("gown_ball.glb"))
	var fams := DressingRoomView.families(gowns_only)
	assert_eq(fams.size(), 1, "the ball gown's colours are one card")
	assert_gt((fams[0]["pieces"] as Array).size(), 3, "with a swatch per colour")


func test_names_split_garment_and_colour() -> void:
	var p := WardrobeCatalog.piece(&"ball_gown_rose")
	assert_eq(DressingRoomView.family_name(p), "Ball gown")
	assert_eq(DressingRoomView.variant_name(p), "Rose")
	assert_eq(DressingRoomView.category_of(p), "Gowns")
	assert_eq(DressingRoomView.category_of(WardrobeCatalog.piece(&"flower_crown_rose")), "Crowns")


func test_open_wear_twirl_close() -> void:
	var feyre := Feyre.new()
	add_child_autofree(feyre)
	await wait_process_frames(2)
	var yaw := feyre.model.rotation.y
	DressingRoom.open(feyre, &"wardrobe")
	assert_true(DressingRoom.is_open())
	assert_true(get_tree().paused)
	var view := get_tree().root.get_node("DressingRoom/DressingRoomView") as DressingRoomView
	assert_not_null(view)
	assert_eq(feyre.model.process_mode, Node.PROCESS_MODE_ALWAYS, "she keeps moving under the pause")
	assert_true((view.camera as Camera3D).current, "the mirror's camera is live")
	assert_gt(view.tabs.get_tab_count(), 4)
	view.wear(&"ball_gown_rose")
	assert_eq(Gameplay.wardrobe.equipped_in(&"top"), &"ball_gown_rose")
	assert_eq(Gameplay.wardrobe.equipped_in(&"outer"), &"", "the patched cloak comes off for a gown")
	assert_eq(Gameplay.wardrobe.equipped_in(&"feet"), &"satin_slippers_blush", "old boots become matching slippers")
	await _real_seconds(0.3)
	assert_ne(feyre.model.rotation.y, view.get(&"_yaw"), "she is mid-twirl while paused")
	await _real_seconds(0.6)
	assert_almost_eq(feyre.model.rotation.y, float(view.get(&"_yaw")), 0.01, "and lands facing the mirror")
	assert_true(view.wearing.text.contains("Ball gown (rose)"))
	Gameplay.wardrobe.grant(&"flower_crown_rose")
	Gameplay.wardrobe.equip(&"flower_crown_rose")
	view.take_off([&"head"])
	assert_eq(Gameplay.wardrobe.equipped_in(&"head"), &"")
	DressingRoom.close_room(feyre)
	assert_false(get_tree().paused)
	assert_false(DressingRoom.is_open())
	assert_almost_eq(feyre.model.rotation.y, yaw, 0.001, "she faces the way she came in")
	assert_eq(feyre.model.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_true(feyre.camera == null or feyre.camera.current)


## GUT's timers stop under the pause; frames keep coming.
func _real_seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
