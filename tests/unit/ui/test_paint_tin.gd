# gate: when:ui/satchel/paint_tin.gd,ui/satchel/satchel_hud.gd,ui/theme/*,ui/frame/*,systems/satchel/*
## The quick strap is her paint tin (plan step 8b): the book and four pans in
## HudLayout's STRAP zone. A pan shows what is pinned to its slot, its key and
## how many are left; it stands proud while LB is held and names what is in it
## when it is used or pinned.
extends GutTest

var satchel: SatchelHud


func before_each() -> void:
	SatchelHud.pad_active = false
	Gameplay.reset()
	Gameplay.inventory.add(&"ing_bilberry", 6)
	satchel = SatchelHud.new()
	add_child_autofree(satchel)
	await wait_process_frames(2)


func after_each() -> void:
	SatchelHud.pad_active = false


func test_the_tin_is_the_book_and_a_pan_a_slot_in_the_strap_zone() -> void:
	var tin := satchel._tin
	assert_eq(tin.pans.size(), QuickBar.SLOTS)
	assert_eq(tin.get_parent().get_parent(), HudLayout.of(get_tree()).zone(HudLayout.Zone.STRAP))
	assert_eq(tin.book_key.text, "I", "the book wears the key that opens it")
	assert_lte(SatchelHud.bar_size().x, 488.0, "no wider than the strap it replaces")
	for i in tin.pans.size():
		var pan := tin.pans[i]
		assert_eq((pan.get_node(^"Key") as Label).text, str(i + 1))
		assert_true(Rect2(Vector2.ZERO, tin.size).grow(12.0).encloses(Rect2(pan.position, pan.size)), "pan %d sits in the tin" % i)
		if i > 0:
			assert_gt(pan.position.x, tin.pans[i - 1].position.x + PaintTin.Pan.RADIUS * 2.0, "pans do not touch")


func test_a_pan_shows_what_is_pinned_and_how_many() -> void:
	var slot := satchel.bar.slot_of(&"ing_bilberry")
	if slot < 0:
		slot = 0
		satchel.bar.pin(slot, &"ing_bilberry")
	await wait_process_frames(2)
	var pan := satchel._tin.pans[slot]
	assert_eq(pan.count, 6)
	var count := pan.get_node(^"Count") as Label
	assert_true(count.visible)
	assert_eq(count.text, "6")
	assert_eq(count.theme_type_variation, &"SatchelCount")
	var empty := satchel._tin.pans[(slot + 1) % QuickBar.SLOTS]
	assert_false((empty.get_node(^"Count") as Label).visible, "an empty pan has no count")


func test_the_pad_changes_the_keys_and_the_chord_lifts_the_pans() -> void:
	SatchelHud.pad_active = true
	satchel._refresh()
	assert_eq(satchel._tin.book_key.text, "LB")
	assert_eq((satchel._tin.pans[0].get_node(^"Key") as Label).text, SatchelHud.SLOT_PAD_GLYPHS[0])
	var seat := satchel._tin.pans[0].position.y
	satchel._set_chord(true)
	assert_true(satchel._tin.pans[0].lit)
	await wait_seconds(0.5)
	assert_lt(satchel._tin.pans[0].position.y, seat - PaintTin.Pan.PROUD * 0.5, "a lit pan stands proud")
	satchel._set_chord(false)
	assert_false(satchel._tin.pans[0].lit)


func test_a_pinned_pan_is_named_for_a_moment() -> void:
	satchel.bar.pinned.emit(1, &"ing_bilberry")
	assert_eq(satchel._tin._name.text, ItemCatalog.get_item(&"ing_bilberry").display_name.to_upper())
	assert_eq(satchel._tin._name.theme_type_variation, &"TinName")
	await wait_seconds(0.4)
	assert_gt(satchel._tin._name.modulate.a, 0.9)
	await wait_seconds(PaintTin.NAME_SECONDS)
	assert_lt(satchel._tin._name.modulate.a, 0.1, "then the name goes")


func test_the_old_strap_and_rings_are_gone() -> void:
	for path: String in ["res://ui/satchel/quick_strap.gd", "res://ui/satchel/quick_ring.gd"]:
		assert_false(FileAccess.file_exists(path), path)
	var src := FileAccess.get_file_as_string("res://ui/satchel/satchel_hud.gd") + FileAccess.get_file_as_string("res://ui/satchel/paint_tin.gd")
	assert_null(RegEx.create_from_string("QuickRing|QuickStrap|Color\\(\\s*[0-9]|Color\\(\"#").search(src), "no ring, strap or colour of its own")


## The pickup log names what went into her bags: one row a thing, more of the
## same adds to its row, and a row goes after a few seconds.
func test_the_pickup_log_names_what_she_picked() -> void:
	var log := satchel.pickups
	assert_eq(log.get_parent(), HudLayout.of(get_tree()).zone(HudLayout.Zone.PICKUPS))
	for row in log.get_children():
		row.free()
	Gameplay.inventory.add(&"ing_rose_hip", 2)
	Gameplay.inventory.add(&"ing_bilberry", 3)
	Gameplay.inventory.add(&"ing_rose_hip", 1)
	var rose := ItemCatalog.get_item(&"ing_rose_hip").display_name
	var bil := ItemCatalog.get_item(&"ing_bilberry").display_name
	assert_eq(log.lines(), PackedStringArray(["%s  ×3" % rose, "%s  ×3" % bil]))
	assert_eq((log.get_child(0) as Control).theme_type_variation, &"PickupRow")
	for id: StringName in [&"ing_primrose", &"ing_lavender", &"ing_hazelnut"]:
		Gameplay.inventory.add(id, 1)
	assert_eq(log.get_child_count(), PickupLog.MAX_ROWS, "the oldest row makes room")
	await wait_seconds(PickupLog.HOLD + PickupLog.FADE + 0.4)
	assert_eq(log.lines().size(), 0, "rows go after a few seconds")
	var right := HudLayout.CORNERS[HudLayout.Zone.PICKUPS][1].x + PickupLog.WIDTH as float
	assert_lte(right, HudLayout.LANE_LEFT, "the log keeps left of the lane lines stand in")


## A pan's name sits wholly inside the tin's own rect in every state: at
## rest, with the pans standing proud under LB, and over the end pans.
func test_a_pans_name_stays_inside_the_tin() -> void:
	var tin := satchel._tin
	for chord: bool in [false, true]:
		satchel._set_chord(chord)
		await wait_seconds(0.4)
		for i in tin.pans.size():
			tin.name_pan(i, "Wild strawberries and cream")
			await wait_process_frames(2)
			var tag := Rect2(tin._name.position, tin._name.size)
			assert_true(Rect2(Vector2.ZERO, tin.size).encloses(tag), "pan %d, chord %s: %s in %s" % [i, chord, tag, tin.size])
			var pan := tin.pans[i]
			assert_lte(tag.end.y, pan.position.y, "the name clears pan %d's rim" % i)
	satchel._set_chord(false)
	assert_lte(SatchelHud.bar_size().y, 132.0, "the bar is no taller than its zone allows")


## A landmark seen is a note at most once every 20 s; the rest are dropped.
func test_landmark_notes_are_rare_and_dropped_not_queued() -> void:
	var map := WorldMapHud.new()
	FindCard.clear(get_tree())
	map.notice(get_tree(), "The old mill", false)
	map.notice(get_tree(), "A cairn", false)
	map.notice(get_tree(), "The split oak", false)
	assert_eq(FindCard.pending(), 1, "one note, the other two dropped")
	assert_false(map.landmark_note_due())
	map._landmark_noted_at -= int(WorldMapHud.LANDMARK_NOTE_GAP * 1000.0)
	assert_true(map.landmark_note_due(), "due again after the gap")
	map.notice(get_tree(), "Elmhollow", true)
	assert_eq(FindCard.pending(), 2, "a place found is still a heading")
	FindCard.clear(get_tree())
	map.free()
