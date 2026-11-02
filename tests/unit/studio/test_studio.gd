## Contract test for the studio (L30): canvas, brushes, mixing, supply,
## deeds and the room. One file per R6.
extends GutTest

const BLUE := Color(0.184, 0.310, 0.561)
const YELLOW := Color(0.957, 0.769, 0.188)


func before_each() -> void:
	Gameplay.reset()
	WorldState.clear()
	StudioSupply.charges.clear()


func _lum_stddev(img: Image, rect: Rect2i) -> float:
	var sum := 0.0
	var sq := 0.0
	var n := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var l := img.get_pixel(x, y).get_luminance()
			sum += l
			sq += l * l
			n += 1
	var mean := sum / n
	return sqrt(maxf(sq / n - mean * mean, 0.0))


func test_canvas_is_linen_with_a_weave() -> void:
	var c := StudioCanvas.new()
	assert_eq(c.image.get_size(), Vector2i(1024, 768))
	var sd := _lum_stddev(c.image, Rect2i(100, 100, 64, 64))
	assert_between(sd, 0.008, 0.06, "weave shows but stays quiet (sd %.4f)" % sd)


func test_every_brush_lays_paint() -> void:
	var brushes := StudioCanvas.brushes()
	assert_eq(brushes.size(), 5)
	for b in brushes:
		var c := StudioCanvas.new()
		c.brush = b
		c.size_index = 2
		var before := c.image.duplicate()
		c.begin(Vector2(200, 300), Color(0.8, 0.2, 0.4))
		c.drag(Vector2(500, 320))
		c.end()
		var changed := 0
		for x in range(200, 500, 6):
			for dy in range(-20, 21, 4):
				if not c.image.get_pixel(x, 310 + dy).is_equal_approx(before.get_pixel(x, 310 + dy)):
					changed += 1
		assert_gt(changed, 8, "%s changed %d samples" % [b.id, changed])
		assert_eq(c.strokes, 1)


func test_blue_and_yellow_mix_green() -> void:
	var g := PigmentMix.mix(BLUE, YELLOW, 0.5)
	var hue := g.h * 360.0
	assert_between(hue, 75.0, 170.0, "hue %.0f" % hue)
	assert_gt(g.s, 0.3, "still a vivid green")
	var pink := PigmentMix.mix(Color(0.85, 0.25, 0.3), Color(0.97, 0.95, 0.92), 0.6)
	assert_gt(pink.v, 0.8, "red and white make a light tint")


func test_wet_yellow_over_blue_reads_green() -> void:
	var c := StudioCanvas.new()
	c.brush = StudioCanvas.brushes()[2]  # bristle picks up the most
	c.size_index = 3
	c.begin(Vector2(100, 400), BLUE)
	c.drag(Vector2(900, 400))
	c.end()
	c.begin(Vector2(100, 400), YELLOW)
	c.drag(Vector2(900, 400))
	c.end()
	var p := c.image.get_pixel(800, 400)
	assert_gt(p.g, p.b, "green over blue (%s)" % p)
	assert_between(p.h * 360.0, 60.0, 180.0, "hue %.0f" % (p.h * 360.0))


func test_undo_twelve_deep() -> void:
	var c := StudioCanvas.new()
	var blank := c.image.duplicate()
	for i in 14:
		c.begin(Vector2(50 + i * 40, 100), Color(0.5, 0.1, 0.6))
		c.drag(Vector2(60 + i * 40, 300))
		c.end()
	var undone := 0
	while c.undo():
		undone += 1
	assert_eq(undone, StudioCanvas.UNDO_DEPTH)
	assert_false(c.image.get_pixel(60, 200).is_equal_approx(blank.get_pixel(60, 200)), "the oldest strokes stay")


func test_palette_mixes_and_finds_colours() -> void:
	assert_gte(StudioPalette.book_size(), 24)
	var pal := StudioPalette.new()
	var found: Array[String] = []
	pal.colour_found.connect(func(n: String, _c: Color) -> void: found.append(n))
	pal.drop(0, BLUE)
	var green := pal.drop(0, YELLOW)
	assert_between(green.h * 360.0, 75.0, 170.0)
	assert_eq(int(pal.wells[0].amount), StudioPalette.STROKES_PER_DROP * 2)
	# Lead white into rose madder is close to the book's Rose.
	pal.drop(1, Color(0.878, 0.376, 0.494))
	pal.drop(1, Color(0.965, 0.949, 0.918))
	pal.drop(1, Color(0.878, 0.376, 0.494))
	assert_gt(found.size(), 0, "a mix matched the colour book (well 1: %s)" % pal.wells[1].color)
	assert_eq(StudioPalette.found_names().size(), found.size(), "finds are kept as facts")
	for i in StudioPalette.STROKES_PER_DROP * 2:
		assert_true(pal.use(0))
	assert_false(pal.use(0), "a well runs dry")


func test_supply_charcoal_forage_and_manor_stock() -> void:
	var s := StudioSupply.new(Gameplay.inventory)
	assert_eq(s.paints().size(), 1, "only charcoal before anything else")
	Gameplay.inventory.add(&"pig_blue")
	assert_eq(s.left(&"pig_blue"), StudioSupply.STROKES_PER_CAKE)
	for i in StudioSupply.STROKES_PER_CAKE:
		assert_true(s.spend(&"pig_blue"))
	assert_false(s.spend(&"pig_blue"), "a cake gives 40 strokes")
	assert_true(s.spend(StudioSupply.CHARCOAL))
	WorldState.set_flag("gallery_opened")
	assert_gte(s.paints().size(), 1 + 20, "the stocked room")
	assert_eq(s.left(&"manor:0"), -1, "manor paint never runs out")


func test_easel_sheeted_until_p4_and_first_stroke_opens_gallery() -> void:
	assert_false(StudioDeeds.easel_open())
	WorldState.set_flag("starlight_pool_found")
	assert_true(StudioDeeds.easel_open())
	var feyre := Node3D.new()
	add_child_autofree(feyre)
	var session := StudioSession.new(Gameplay.inventory, null, feyre)
	assert_eq(session.paint_line([Vector2(10, 10), Vector2(200, 150)] as Array[Vector2]), "")
	assert_true(WorldState.has_flag("gallery_opened"), "the first stroke asked for paint")
	assert_true(session.opened_gallery)
	session.opened_gallery = false
	session.paint_line([Vector2(30, 10), Vector2(220, 150)] as Array[Vector2])
	assert_false(session.opened_gallery, "only once")


func test_finish_leans_it_in_the_room_and_raises_first_painting() -> void:
	WorldState.set_flag("starlight_pool_found")
	var house := Node3D.new()
	add_child_autofree(house)
	var easel := Node3D.new()
	easel.name = "Station_easel"
	easel.position = Vector3(16, 4.0, -32.5)
	house.add_child(easel)
	var feyre := Node3D.new()
	house.add_child(feyre)
	feyre.position = Vector3(16, 4.0, -30.3)
	var session := StudioSession.new(Gameplay.inventory, easel, feyre)
	session.paint_line([Vector2(100, 100), Vector2(600, 500)] as Array[Vector2])
	session.close()
	assert_true(FileAccess.file_exists(StudioCanvas.wip_path(session.key())), "work in progress kept")
	var again := StudioSession.new(Gameplay.inventory, easel, feyre)
	assert_eq(again.canvas.strokes, 1, "and picked up again")
	var view := easel.get_node_or_null(StudioRoom.VIEW_NAME)
	assert_not_null(view, "the canvas shows on the easel")
	var record := again.finish("Roses")
	assert_true(WorldState.has_flag("first_painting"))
	assert_true(FileAccess.file_exists(String(record.path)))
	assert_false(FileAccess.file_exists(StudioCanvas.wip_path(session.key())), "a fresh canvas after")
	var spots := house.get_node(StudioRoom.SPOTS_NAME)
	assert_gte(spots.get_child_count(), 10)
	var hung := 0
	for spot in spots.get_children():
		hung += spot.get_child_count()
	assert_eq(hung, 1, "leaned against the wall")
	assert_almost_eq(easel.get_node(StudioRoom.VIEW_NAME).global_position.y, 5.3, 0.01)
	DirAccess.remove_absolute(String(record.path))


func test_studio_ui_opens_paints_and_closes() -> void:
	var feyre := Node3D.new()
	add_child_autofree(feyre)
	StudioUi.open(feyre, null)
	assert_false(StudioUi.is_open(), "sheeted before P4")
	WorldState.set_flag("starlight_pool_found")
	var easel := Node3D.new()
	easel.name = "UiEasel"
	add_child_autofree(easel)
	StudioUi.open(feyre, easel)
	assert_true(StudioUi.is_open())
	assert_true(get_tree().paused)
	var s := StudioUi.session()
	assert_eq(s.paint_line([Vector2(10, 10), Vector2(300, 200)] as Array[Vector2]), "")
	s.tick()
	assert_true(WorldState.has_flag("gallery_opened"))
	s.refresh.call()
	StudioUi.close()
	assert_false(StudioUi.is_open())
	assert_false(get_tree().paused)
	assert_not_null(easel.get_node_or_null(StudioRoom.VIEW_NAME))
	StudioCanvas.clear_wip("UiEasel")


func test_easel_nook_dresses_once_as_an_indoor_painting_corner() -> void:
	var easel := Node3D.new()
	add_child_autofree(easel)
	var nook := StudioNook.dress(easel)
	assert_eq(StudioNook.dress(easel), nook, "dressed once")
	for id in [&"floor_candlestand", &"rug_round", &"paint_table", &"canvas_stack", &"stool", &"bookcase_low", &"painting_medium"]:
		assert_not_null(nook.get_node_or_null(String(id)), "has %s" % id)
	assert_not_null(nook.get_node_or_null("DropCloth"))
	# Indoors: no garden arbor, garland, potted roses, falling petals or chimes.
	for gone in ["arch_trellis", "flower_garland", "potted_roses", "Petals", "NookChime"]:
		assert_null(nook.get_node_or_null(gone), "no %s indoors" % gone)
	assert_not_null(nook.get_node_or_null("CurtainL"))
	assert_not_null(nook.get_node_or_null("CurtainR"))
	assert_true(nook.get_node("NookLight") is OmniLight3D)
	assert_true(nook.get_node("WindowLight") is SpotLight3D)
	Clock.time_of_day = 0.5
	assert_almost_eq(StudioNook.day_factor(), 1.0, 0.01, "full daylight at noon")
	Clock.time_of_day = 0.0
	assert_eq(StudioNook.day_factor(), 0.0, "dark at midnight")
	Clock.time_of_day = 0.3
	# Her standing spot stays clear of anything she'd bump into.
	for c in nook.get_children():
		if c is StaticBody3D:
			var d := Vector2((c as Node3D).position.x, (c as Node3D).position.z).distance_to(
				Vector2(StudioNook.STAND.x, StudioNook.STAND.z))
			assert_gt(d, 1.2, "%s clear of where she stands (%.2f m)" % [c.name, d])
