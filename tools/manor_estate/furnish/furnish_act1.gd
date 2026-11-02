## L38-1, the refurnish of the rooms Feyre walks through in Act I: the
## entrance hall, the dining hall, her bedroom and bath, the library with the
## mural, Tamlin's study, the gallery, the main corridors, the painting room,
## the kitchen, the infirmary, Alis's room and Tamlin's bedchamber.
##
## Each room is laid out by hand like an interior designer would: pieces back
## onto walls or gather round a focal point (a hearth, a table, a window),
## surfaces are dressed from the room's style deck so no small thing repeats
## inside a room, and every story mark, book-moment spawn and playtest walk
## stays clear (ManorFurnisher.fits). Canon comes from the Keeper's answers of
## 2026-11-02 (docs/plans in /mnt/project-files/plans/manor-refurnish/plan.md);
## lines marked [C] are the book's, [X] ours.
##
## Called by gen_ground, gen_upper and gen_service after their rooms, doors,
## stairs, stations and secrets exist, so the furnisher can see them all.
class_name ManorFurnishAct1
extends RefCounted

## Which part each room is generated in: [room id, level].
const ROOMS := {
	&"ground": [[&"entrance_hall", 0], [&"dining_hall", 0], [&"library", 0], [&"tamlin_study", 0],
		[&"gallery", 0], [&"east_corridor", 0], [&"west_corridor", 0]],
	&"upper": [[&"upper_hall", 1], [&"east_corridor", 1], [&"west_corridor", 1], [&"feyre_bedroom", 1],
		[&"feyre_bath", 1], [&"painting_room", 1], [&"tamlin_bedchamber", 1]],
	&"service": [[&"svc_kitchen", 0], [&"svc_infirmary", 0], [&"svc_passage_0", 0], [&"svc_alis_room", 1],
		[&"svc_servants_hall", 0]],
}

## Where the mural hangs in the library (east wall, `t` along it): the frame is
## 3.9 m wide (StudyMural.FRAME_SIZE), centred on the manor_study_mural anchor's z.
const MURAL_T := 3.0
const MURAL_HALF := 2.1
## The Calanmai painting's place in Tamlin's bedchamber (west wall, along z),
## from the tamlin_bedchamber_painting_wall anchor: 1.3 m of wall kept clear.
const TAMLIN_PAINTING_T := 6.0


static func furnish(dsl: ManorLayoutDSL) -> void:
	var ctx := ManorFurnishContext.new(dsl.layout)
	var log: Array[String] = []
	var me := ManorFurnishAct1.new()
	for row: Array in ROOMS.get(dsl.layout.part_id, []):
		var room := _room(dsl, row[0], row[1])
		if room == null:
			push_error("furnish_act1: no room %s on level %d" % row)
			continue
		var f := ManorFurnisher.new(dsl, room, ctx)
		var fn := "_%s_l%d" % [room.id, room.level]
		if not me.has_method(fn):
			fn = "_" + String(room.id)
		me.call(fn, f)
		if not f.misses.is_empty():
			log.append("%s L%d skipped: %s" % [room.id, room.level, ", ".join(f.misses)])
	for line in log:
		print("[furnish] ", line)


static func _room(dsl: ManorLayoutDSL, id: StringName, level: int) -> ManorRoomDef:
	for r in dsl.layout.rooms:
		if r.id == id and r.level == level:
			return r
	return null


## Dresses these surfaces from `style`, `extra` more things than their usual.
static func _dress(f: ManorFurnisher, list: Array, style: StringName, extra: int = 1) -> void:
	for s in list:
		if s != null and not (s as ManorPropPlacement).has_meta(&"dressed"):
			s.set_meta(&"dressed", true)
			f.dress(s, style, (ManorDecorDecks.SURFACE.get(s.prop_id, [0, 0, 1]) as Array)[2] + extra)


# --- ground floor ------------------------------------------------------------------

## [C] Black-and-white checkered marble, countless doors, the sweeping stair,
## hall tables scattered with vases of fat hydrangeas. The south half is the
## Summer faerie's triage floor and the front-door walk: kept open.
static func _entrance_hall(f: ManorFurnisher) -> void:
	f.light(&"chandelier_crystal", 10, 4)
	f.light(&"chandelier_crystal", 10, 26)
	f.light(&"chandelier_small", 2.4, 15)
	f.light(&"chandelier_small", 17.6, 15)
	f.put(&"rug_round", 4.6, 2.9)
	f.put(&"rug_runner", 10, 27.5)
	# the stair's foot, flanked by columns
	f.at(&"column_marble", 4.0, 20.7)
	f.at(&"column_marble", 16.0, 20.7)
	# scattered hall tables, each with its fat hydrangeas
	f.set_on(f.at(&"hall_table_round", 4.6, 2.9), [&"urn_hydrangea_white", &"candlestick_brass", &"shell_dish"])
	f.set_on(f.at(&"hall_table_round", 3.6, 27.6), [&"vase_hydrangea_blue", &"trinket_box_enamel", &"music_box"])
	f.set_on(f.at(&"hall_table_round", 3.4, 22.2), [&"vase_hydrangea_pink", &"letter_rack", &"bonbon_dish"])
	f.set_on(f.at(&"hall_table_round", 13.6, 23.4), [&"vase_peonies", &"figurine_deer", &"posy_teacup"])
	# north band: consoles either side of the saloon door
	var c1 := f.fit_wall("n", 16.6, &"console_gilt")
	f.hang("n", 16.6, &"wall_mirror_oval", 1.95)
	var c4 := f.fit_wall("n", 6.6, &"sideboard")
	f.hang("n", 6.6, &"barometer_wall", 1.9)
	f.fit_wall("n", 13.3, &"plant_stand_fern")
	f.hang("n", 13.3, &"wall_shelf_curios", 2.2)
	f.fit_wall("n", 19.2, &"umbrella_stand")
	# west wall: console and pier glass, the bench under the hall's long painting, the clock
	var c2 := f.fit_wall("w", 4.4, &"console_gilt")
	f.hang("w", 4.4, &"mirror_gilt", 2.0)
	f.set_on(f.fit_wall("w", 15.6, &"hall_bench_cushioned"), [&"fan_lace"])
	f.art("w", 15.6, &"painting_large", 2.3, 0.85)
	f.fit_wall("w", 13.0, &"bust_pedestal")
	f.fit_wall("w", 18.3, &"plant_stand_fern")
	f.fit_wall("w", 25.6, &"clock_grandfather")
	f.fit_wall("w", 30.2, &"coat_rack")
	# east wall: commode by mark 3, the matching bench, an étagère of curios by the front windows
	var c3 := f.fit_wall("e", 4.4, &"commode_serpentine")
	f.hang("e", 4.4, &"wall_clock_sunburst", 2.1)
	f.set_on(f.fit_wall("e", 15.6, &"hall_bench_cushioned"), [&"book_pile_ribbon"])
	f.art("e", 15.6, &"painting_large", 2.3, 0.85)
	f.fit_wall("e", 13.0, &"candle_tree")
	f.fit_wall("e", 18.3, &"bust_pedestal")
	_shelves(f, f.fit_wall("e", 26.2, &"etagere_gilt"), &"hall")
	# front wall: orange trees flank the doors, maidens between the windows
	f.fit_wall("s", 7.4, &"orange_tree_tub")
	f.fit_wall("s", 12.6, &"orange_tree_tub")
	f.fit_wall("s", 5.2, &"statue_maiden")
	f.fit_wall("s", 14.8, &"statue_maiden")
	f.at(&"vase_tall", 0.75, 31.2)
	f.at(&"potted_palm", 19.2, 31.2)
	f.at(&"swan_planter", 19.0, 1.0, 180)
	_dress(f, [c1, c2, c3, c4], &"hall", 3)
	_wall_accents(f, &"grand", ["w", "e"])
	_wall_accents(f, &"cosy", ["n", "w", "e"])
	f.art("w", 6.8, &"painting_medium", 1.9)
	f.art("w", 27.9, &"painting_medium", 2.0, 0.8)
	f.art("e", 28.4, &"portrait_masked", 2.1, 0.9)
	f.art("n", 3.0, &"painting_medium", 2.2, 1.2)
	f.art("e", 6.8, &"painting_small", 1.9)
	f.sconces(3.0)


## Small wall pieces from `wall_style` on the bare stretches of each wall.
static func _wall_accents(f: ManorFurnisher, wall_style: StringName, sides: Array = ManorFurnisher.SIDES) -> void:
	for side: String in sides:
		f.wall_accent(side, wall_style, 1.9)
		f.wall_accent(side, wall_style, 1.9)


## Sets curios on an étagère's three open shelves (not a SURFACE: shelves, not a top).
static func _shelves(f: ManorFurnisher, et: ManorPropPlacement, style: StringName) -> void:
	if et == null:
		return
	var b := Basis(Vector3.UP, deg_to_rad(et.yaw_deg))
	var i := 0
	for y in [0.42, 0.86, 1.28]:
		var id := f.deal(ManorDecorDecks.DETAIL, style, func(x: StringName) -> bool:
			var sz := PropLib.size_of(x)
			return sz.x <= 0.6 and sz.z <= 0.36 and sz.y <= 0.38)
		if id == &"":
			return
		var off := b * Vector3(-0.15 + 0.3 * (i % 2), 0.0, 0.0)
		f.dsl.prop(f.room, id, et.position.x + off.x, et.position.z + off.z, et.yaw_deg, y)
		i += 1
	et.set_meta(&"dressed", true)


## [C] A long table filling the room (L29's table and chairs stay exactly), Tamlin's
## oversized chair at its head (west), Feyre at the far end, a fireplace whose
## mantel carries candelabras, velvet drapes, a chandelier. [X] the rest: window
## seats, pier pieces, sideboards, a breakfast table, a fireside pair.
static func _dining_hall(f: ManorFurnisher) -> void:
	f.light(&"chandelier_crystal", 8.4, 10)
	f.light(&"chandelier_crystal", 13.6, 10)
	f.put(&"rug_large", 8.0, 10, 90)
	f.put(&"rug_large", 14.0, 10, 90)
	f.put(&"rug_runner", 1.9, 10)
	var table := f.put(&"table_dining_long", 11, 10)
	for i in 7:
		var x := 7.6 + i * 1.13
		f.put(&"chair_dining", x, 8.9, 0)
		f.put(&"chair_dining", x, 11.1, 180)
	f.put(&"chair_head_dining", 6.6, 10, 90)
	f.put(&"chair_dining", 15.4, 10, -90)
	# the table's middle only: the first dinner lays its own places at the ends
	f.set_on(table, [&"candelabra", &"bowl_floating_blossoms", &"vase_peonies", &"candle_cluster"])
	# north wall: matched sideboards either side of the corridor door, paintings over them
	var sb1 := f.fit_wall("n", 5.0, &"sideboard")
	var sb2 := f.fit_wall("n", 17.0, &"sideboard")
	f.art("n", 5.0, &"painting_large", 2.45, 0.8)
	f.art("n", 17.0, &"painting_large", 2.45, 0.8)
	f.fit_wall("n", 8.4, &"candle_tree")
	f.fit_wall("n", 13.6, &"floor_candlestand")
	f.at(&"orange_tree_tub", 1.0, 1.0)
	f.at(&"orange_tree_tub", 21.0, 1.0)
	# a little breakfast table by the hall door, a settee and tea table by the pantry doors
	var bt := f.at(&"table_round", 4.0, 4.4)
	f.at(&"chair_simple", 2.9, 4.4)
	f.at(&"chair_simple", 5.1, 4.4)
	f.at(&"settee_rose", 16.6, 3.0, 180)
	var tt := f.at(&"table_tea", 16.6, 4.5)
	# west wall: china cabinets either side of the hall door
	f.fit_wall("w", 4.6, &"cabinet_curio")
	f.fit_wall("w", 15.6, &"cabinet_curio")
	f.art("w", 4.6, &"painting_medium", 3.0, 0.9)
	f.art("w", 15.6, &"painting_medium", 3.0, 0.9)
	var cart := f.at(&"tea_cart", 2.6, 7.4, -90)
	# south wall: a seat in each tall window, pier pieces between under the velvet drapes
	for p in f.under_windows("s", &"window_seat", 0.0, 0.8):
		f.set_on(p, [&"cushion_pile"])
	f.fit_wall("s", 4.4, &"candle_tree")
	_shelves(f, f.fit_wall("s", 8.75, &"etagere_gilt"), &"dining")
	f.fit_wall("s", 13.25, &"clock_grandfather")
	var pier := f.fit_wall("s", 17.6, &"commode_serpentine")
	f.hang("s", 17.6, &"mirror_gilt", 2.2)
	f.at(&"potted_roses", 0.8, 19.0)
	# the hearth (station on the east wall): screen, tools, logs and a fireside pair
	f.at(&"fire_screen", 20.3, 10, 90)
	f.fit_wall("e", 12.3, &"fire_tools")
	f.fit_wall("e", 7.7, &"log_basket")
	f.at(&"chair_bergere", 19.2, 7.4, 180)
	f.at(&"chair_bergere", 19.2, 12.6, 0)
	f.fit_wall("e", 2.0, &"bust_pedestal")
	f.fit_wall("e", 18.2, &"plant_stand_fern")
	f.hang("e", 18.2, &"wall_shelf_curios", 2.0)
	_dress(f, [sb1, sb2, pier, cart, bt, tt], &"dining", 3)
	f.dress_all(&"dining", 2)
	f.mantel(&"dining")
	f.hang("e", 2.0, &"wall_clock_sunburst", 2.3)
	_wall_accents(f, &"grand")
	_wall_accents(f, &"cosy", ["n", "w"])
	f.sconces(3.0)


## [C] The book's "study": a hundred candles, tomes on every wall, a mezzanine
## wall to wall in books, small labyrinths of stacks, couches, desks and rich
## rugs scattered, a bank of windows over the rose garden with the mural on the
## wall beside them, a small writing desk, children's books.
static func _library(f: ManorFurnisher) -> void:
	f.light(&"chandelier_crystal", 11, 12.5)
	f.light(&"chandelier_crystal", 11, 4.5)
	f.light(&"chandelier_small", 4.8, 11.0)
	# the mural's wall stays bare (StudyMural hangs it); its viewing floor stays open
	f.reserve("e", MURAL_T - MURAL_HALF, MURAL_T + MURAL_HALF)
	f.claim("e", MURAL_T - MURAL_HALF, MURAL_T + MURAL_HALF, 0.0)
	f.put(&"rug_round", 18.6, 5.2)
	# the mezzanine wall to wall in books (west and south), the spiral stair where they meet
	for t in [6.0, 10.0, 14.0]:
		f.wall("w", t, &"library_mezzanine")
	for t in [3.45, 7.5, 14.4, 18.45]:
		f.wall("s", t, &"library_mezzanine")
	f.put(&"spiral_stair", 1.2, 17.5, 90)
	# north: the bank of windows, a seat in each, low shelves between
	var seats := f.under_windows("n", &"window_seat", 0.0, 0.8)
	var kids := [[&"books_childrens", &"cushion_pile"], [&"cushion_pile", &"book_pile_ribbon"], [&"cushion_pile", &"hourglass"]]
	for i in seats.size():
		f.set_on(seats[i], kids[i % kids.size()])
	var ws := f.under_windows("w", &"window_seat", 0.0, 0.8)
	var lb1 := f.fit_wall("n", 4.4, &"bookcase_low", 0.0, 0.75)
	var lb2 := f.fit_wall("n", 8.75, &"bookcase_low", 0.0, 0.75)
	f.fit_wall("n", 13.6, &"bookcase_tall")
	f.fit_wall("n", 15.65, &"bookcase_tall")
	_shelves(f, f.fit_wall("n", 20.6, &"etagere_gilt"), &"library")
	# east: the hidden-nook bookcase with the rose-red book, the hearth's reading group
	f.fit_wall("e", 14.65, &"bookcase_tall")
	f.fit_wall("e", 19.0, &"wall_shelf_books")
	f.put(&"rug_large", 16.8, 12.0, 90)
	f.at(&"sofa_camelback", 16.8, 9.3, 180)
	f.at(&"settee_rose", 16.8, 14.8, 0)
	var tea := f.at(&"table_tea", 17.0, 12.0, 90)
	f.at(&"chair_bergere", 14.0, 12.0, -90)
	var st2 := f.at(&"table_side", 14.0, 13.1)
	var cart := f.at(&"tea_cart", 19.6, 15.9)
	var gt := f.at(&"table_round", 10.6, 2.7)
	f.at(&"chair_simple", 9.6, 3.2)
	f.at(&"chair_simple", 11.6, 2.2)
	f.set_on(gt, [&"chess_set", &"candlestick_brass"])
	f.at(&"ottoman_tufted", 19.0, 12.0)
	f.at(&"fire_screen", 20.35, 12.0, 90)
	f.at(&"log_basket", 21.0, 9.4)
	# the labyrinth of stacks before the west mezzanine, bays between them
	for z in [8.0, 11.1, 14.2]:
		var st := f.at(&"library_stack", 5.6, z, 0)
		if st != null:
			f.put_on(&"candle_cluster" if z == 8.0 else (&"candlestick_brass" if z == 11.1 else &"hurricane_lamp"),
					5.6 + (z - 11.1) * 0.2, z, 0, 2.5)
			f.put_on(&"books_upright_bookends" if z == 8.0 else (&"book_stack" if z == 11.1 else &"astrolabe"),
					5.6 - 1.0 + (z - 11.1) * 0.1, z, 0, 2.5)
	f.at(&"library_ladder", 1.65, 8.0, -90)
	f.at(&"library_ladder", 9.4, 18.25, 0)
	# the reading table under the chandelier, the writing desk (station) by the windows
	f.put(&"rug_round", 11.0, 12.6)
	var lt := f.at(&"library_table", 11.0, 12.6, 0)
	for c in [Vector2(10.3, 11.65), Vector2(11.7, 11.65), Vector2(10.3, 13.55), Vector2(11.7, 13.55)]:
		f.at(&"chair_simple", c.x, c.y)
	f.at(&"chair_simple", 11.0, 7.0)
	var desk_top := ManorDecorDecks.top_of(&"desk_writing")
	f.put_on(&"quill_and_parchment", 10.7, 6.05, 170, desk_top)
	f.put_on(&"letter_rack", 11.55, 5.85, 180, desk_top)
	f.put_on(&"candlestick_crystal", 10.3, 5.8, 0, desk_top)
	f.at(&"globe_stand", 13.4, 5.6)
	f.put_on(&"book_open", 8.6, 4.4, 30, 1.12)
	f.at(&"reading_lectern", 8.6, 4.4, 30)
	f.at(&"wingback_chair", 2.0, 5.2, 135)
	var side := f.at(&"table_side", 3.0, 7.0)
	var wd := f.at(&"writing_desk_small", 14.8, 2.6, 180)
	f.at(&"chair_low_back", 14.8, 3.6, 0)
	f.at(&"candle_tree", 8.3, 16.6)
	f.at(&"floor_candlestand", 13.6, 16.4)
	f.at(&"floor_candlestand", 19.4, 17.8)
	f.at(&"potted_roses", 21.0, 19.0)
	f.set_on(lt, [&"globe_table", &"candelabra", &"map_rolls", &"magnifier_glass", &"inkstand"])
	if not ws.is_empty():
		f.set_on(ws[0], [&"terrarium_bell"])
	_dress(f, [lb1, lb2, tea, side, wd, st2, cart], &"library", 3)
	f.dress_all(&"library", 2)
	f.mantel(&"library")
	_wall_accents(f, &"cosy", ["n", "e"])
	f.sconces(2.4)


## Tamlin's private study [X]: his desk with its back to the hearth, the border
## map on its table, maps and books, a sofa under the map of his court. The walk
## from the garden saloon to the library crosses it (z 6-7) and stays open.
static func _tamlin_study(f: ManorFurnisher) -> void:
	f.light(&"chandelier_small", 5, 7)
	f.put(&"rug_large", 5, 3.6)
	var desk := f.at(&"desk_large", 5, 3.6, 0)
	f.at(&"armchair", 5, 2.3, 180)
	f.at(&"chair_bergere", 3.4, 5.3, 160)
	f.at(&"chair_bergere", 6.6, 5.3, -160)
	f.fit_wall("w", 2.8, &"bookcase_tall")
	f.fit_wall("e", 2.6, &"bureau_secretary")
	f.at(&"plant_stand_fern", 0.65, 0.65)
	f.at(&"plant_stand_fern", 9.35, 0.65)
	var lb := f.fit_wall("e", 8.0, &"bookcase_low")
	# south half: the map table, a sofa under the court's map, the cold hearth's passage
	f.put(&"rug_large", 5.6, 10.6)
	var mt := f.at(&"map_table", 5.6, 10.5, 0)
	for c in [Vector2(5.6, 9.2), Vector2(5.6, 11.8), Vector2(3.9, 10.5), Vector2(7.3, 10.5)]:
		f.at(&"chair_simple", c.x, c.y)
	f.fit_wall("w", 10.9, &"sofa_camelback")
	f.hang("w", 10.9, &"map_wall", 2.4)
	var st := f.fit_wall("w", 9.3, &"table_side")
	f.at(&"footstool_velvet", 1.9, 10.9)
	f.fit_wall("e", 10.4, &"bookcase_tall")
	f.at(&"globe_stand", 8.6, 12.4)
	f.at(&"clock_grandfather", 0.75, 13.2, 0)
	f.fit_wall("s", 8.4, &"chest_trunk")
	f.fit_wall("e", 12.8, &"log_basket")
	f.set_on(mt, [&"quill_and_parchment", &"hourglass", &"magnifier_glass", &"astrolabe"])
	f.set_on(desk, [&"letter_rack", &"inkstand", &"candlestick_brass", &"decanter_set"])
	_dress(f, [lb, st], &"study", 1)
	f.dress_all(&"study")
	f.hang("s", 2.0, &"barometer_wall", 1.8)
	f.art("e", 10.4, &"painting_small", 3.6)
	f.sconces(3.0)


## [C] Pale wooden floors, bright light, a few large chairs and benches; [X] the
## pictures hung salon-style in clusters, three large works on the long north
## wall, the masked portrait over the vault lever at the east end.
static func _gallery(f: ManorFurnisher) -> void:
	for x in [6.0, 16.0, 26.0]:
		f.light(&"chandelier_crystal", x, 4)
	f.put(&"rug_runner", 9.5, 4, 90)
	f.put(&"rug_runner", 22.5, 4, 90)
	# north wall: three large works, smaller ones clustered between and above
	for t in [6.0, 16.0, 26.0]:
		f.art("n", t, &"painting_large", 1.95, 1.0)
	for c in [[10.6, 1.6, &"painting_medium", 0.8], [11.2, 3.0, &"painting_small", 1.0], [10.0, 3.1, &"painting_small", 0.8],
			[21.4, 1.7, &"portrait_masked", 0.7], [20.7, 3.25, &"painting_small", 1.1], [22.1, 3.2, &"painting_small", 0.75],
			[1.6, 2.0, &"painting_medium", 1.0], [30.4, 2.0, &"painting_medium", 0.9]]:
		f.art("n", c[0], c[2], c[1], c[3])
	# south wall: either side of the door
	for c in [[4.0, 2.0, &"painting_large", 0.75], [8.6, 1.7, &"painting_medium", 1.2], [8.4, 3.2, &"painting_small", 0.9],
			[11.6, 2.4, &"portrait_masked", 1.0], [20.4, 2.2, &"painting_medium", 1.3], [24.4, 1.7, &"painting_small", 1.4],
			[24.5, 2.9, &"painting_small", 0.7], [28.4, 2.0, &"painting_large", 0.7]]:
		f.art("s", c[0], c[2], c[1], c[3])
	f.art("w", 4.0, &"portrait_masked", 1.95, 1.4)
	f.art("e", 4.0, &"portrait_masked", 1.95, 1.0)        # over the mask-vault lever
	# the floor: viewing benches back to back, a pair of large chairs, sculpture on pedestals
	f.at(&"hall_bench_cushioned", 9.5, 3.4, 180)
	f.at(&"hall_bench_cushioned", 9.5, 4.6, 0)
	f.at(&"settee_rose", 22.5, 4.0, 180)
	f.at(&"wingback_chair", 13.6, 1.6, 200)
	f.at(&"wingback_chair", 18.4, 1.6, 160)
	var ts := f.at(&"table_side", 16.0, 1.3)
	f.at(&"statue_stag", 28.6, 4.0, 90)
	f.at(&"bust_pedestal", 4.6, 1.0)
	f.at(&"bust_pedestal", 4.6, 7.0)
	f.at(&"orange_tree_tub", 0.9, 1.0)
	f.at(&"orange_tree_tub", 0.9, 7.0)
	f.at(&"cabinet_curio", 0.55, 2.3, -90)
	f.at(&"cabinet_curio", 0.55, 5.7, -90)
	f.at(&"urn_flowers", 31.0, 1.2)
	f.at(&"urn_flowers", 31.0, 6.8)
	var c1 := f.fit_wall("s", 13.4, &"console_gilt")
	var c2 := f.fit_wall("s", 18.6, &"commode_serpentine")
	f.fit_wall("n", 13.6, &"etagere_gilt")
	_dress(f, [c1, c2, ts], &"parlour", 1)
	f.sconces(5.0, 2.9)


## The Gilded Corridor [C?]: pier tables and mirrors, a sunburst clock; the
## masked portraits on its south wall are sombre (amarantha_curse). The wound
## walk runs down its middle.
static func _east_corridor_l0(f: ManorFurnisher) -> void:
	_corridor_lights(f)
	f.put(&"rug_runner", 6, 2, 90)
	f.put(&"rug_runner", 21.5, 2, 90)
	var a := f.fit_wall("n", 6.5, &"console_gilt")
	f.hang("n", 6.5, &"wall_mirror_oval", 1.95)
	var b := f.fit_wall("n", 24.5, &"commode_serpentine")
	f.hang("n", 24.5, &"wall_clock_sunburst", 2.1)
	f.fit_wall("n", 12.0, &"plant_stand_fern")
	f.fit_wall("n", 19.2, &"hall_bench_cushioned")
	f.fit_wall("n", 30.6, &"bust_pedestal")
	f.fit_wall("n", 1.0, &"orange_tree_tub")
	f.fit_wall("s", 6.0, &"hall_bench_cushioned")
	f.fit_wall("s", 15.5, &"bureau_secretary")
	f.fit_wall("s", 20.0, &"clock_grandfather")
	_shelves(f, f.fit_wall("s", 23.5, &"etagere_gilt"), &"hall")
	f.fit_wall("s", 26.0, &"umbrella_stand")
	f.fit_wall("s", 2.6, &"plant_stand_fern")
	for t in [4.0, 13.5, 22.5]:
		f.art("s", t, &"portrait_masked", 2.0, 0.85)
	for t in [3.0, 10.0, 20.0, 28.6]:
		f.art("n", t, &"painting_medium", 2.0, 0.9)
	_dress(f, [a, b], &"hall", 1)
	f.sconces(4.0)


## The Portrait Corridor [C?]: the hallway paintings Feyre studies on her first
## exploration, with benches to sit and look, busts on pedestals between.
static func _west_corridor_l0(f: ManorFurnisher) -> void:
	_corridor_lights(f)
	f.put(&"rug_runner", 6, 2, 90)
	f.put(&"rug_runner", 17, 2, 90)
	f.put(&"rug_runner", 27.5, 2, 90)
	f.fit_wall("n", 5.0, &"hall_bench_cushioned")
	f.fit_wall("n", 17.0, &"settee_rose")
	f.fit_wall("n", 26.0, &"hall_bench_cushioned")
	f.fit_wall("n", 14.0, &"bust_pedestal")
	f.fit_wall("n", 29.6, &"orange_tree_tub")
	f.fit_wall("s", 16.8, &"bust_pedestal")
	var d := f.fit_wall("s", 10.0, &"console_gilt")
	var e := f.fit_wall("s", 2.6, &"commode_serpentine")
	_shelves(f, f.fit_wall("s", 18.6, &"etagere_gilt"), &"parlour")
	f.fit_wall("s", 27.0, &"plant_stand_fern")
	f.fit_wall("s", 29.0, &"clock_grandfather")
	for c in [[5.0, &"portrait_masked", 2.1, 0.9], [8.2, &"painting_small", 2.0, 1.0], [17.0, &"painting_large", 2.3, 0.8],
			[22.0, &"painting_medium", 2.0, 1.0], [26.0, &"portrait_masked", 2.1, 1.0], [30.4, &"painting_small", 1.9, 1.2]]:
		f.art("n", c[0], c[1], c[2], c[3])
	for c in [[2.0, &"painting_medium", 2.0, 0.9], [10.0, &"painting_medium", 2.2, 1.1], [21.4, &"portrait_masked", 2.1, 0.8],
			[28.4, &"painting_small", 2.1, 0.9]]:
		f.art("s", c[0], c[1], c[2], c[3])
	_dress(f, [d, e], &"parlour", 1)
	f.sconces(4.5)


static func _corridor_lights(f: ManorFurnisher) -> void:
	var n := int(f.width() / 8.0)
	for i in n:
		f.light(&"chandelier_small", (i + 0.5) * f.width() / n, 2)


# --- first floor ---------------------------------------------------------------------

## [C] Halls of gold and silver where the grand stair arrives; [X] the ch7 still
## life of the green glass vase hangs here (first slot: the west wall's large
## painting), balustrades round the stairwell, a sitting group either side.
static func _upper_hall(f: ManorFurnisher) -> void:
	f.light(&"chandelier_crystal", 8, 5)
	f.light(&"chandelier_crystal", 8, 16)
	# round the stairwell (x 3..13, z 10..22): the stair arrives at its north edge
	for z in [11.6, 14.6, 17.6, 20.5]:
		f.put(&"balustrade", 2.8, z, 90)
		f.put(&"balustrade", 13.2, z, 90)
	for x in [4.6, 11.4]:
		f.put(&"balustrade", x, 22.15)
	f.art("w", 5.0, &"painting_large", 2.2, 0.8)   # the still life (ch7): green glass vase of summer flowers
	f.put(&"rug_round", 8, 5)
	f.set_on(f.at(&"hall_table_round", 8, 5), [&"vase_hydrangea_pink", &"candlestick_crystal", &"book_pile_ribbon"])
	# north wall either side of the loggia door
	var c := f.fit_wall("n", 3.0, &"console_gilt")
	f.hang("n", 3.0, &"mirror_gilt", 2.1)
	var m := f.fit_wall("n", 13.0, &"commode_serpentine")
	f.art("n", 13.0, &"painting_medium", 2.2)
	# west: a settee and footstool under the still life; east: a pair of bergères
	f.fit_wall("w", 5.0, &"settee_rose")
	f.at(&"footstool_velvet", 1.9, 3.0)
	f.at(&"chair_bergere", 14.6, 3.6, 90)
	f.at(&"chair_bergere", 14.6, 6.4, 90)
	var st := f.at(&"table_side", 15.0, 5.0)
	f.fit_wall("e", 8.6, &"plant_stand_fern")
	f.fit_wall("w", 8.6, &"bust_pedestal")
	# the side halls by the stairwell, and the south end either side of the nook door
	f.fit_wall("w", 17.5, &"clock_grandfather")
	_shelves(f, f.fit_wall("e", 17.5, &"etagere_gilt"), &"parlour")
	var s1 := f.fit_wall("s", 3.4, &"console_gilt")
	var s2 := f.fit_wall("s", 12.6, &"commode_serpentine")
	f.at(&"potted_palm", 1.0, 23.0)
	f.at(&"orange_tree_tub", 15.0, 23.0)
	f.art("e", 5.0, &"painting_large", 2.2, 0.75)
	for c2 in [["w", 12.2, &"painting_small", 1.9, 1.0], ["w", 14.6, &"painting_medium", 2.0, 0.9], ["w", 20.6, &"painting_small", 1.9, 1.2],
			["e", 12.2, &"portrait_masked", 2.0, 0.8], ["e", 14.8, &"painting_small", 1.8, 1.3], ["e", 20.6, &"painting_medium", 2.1, 0.8],
			["s", 3.4, &"painting_medium", 2.2, 0.9], ["s", 12.6, &"painting_small", 2.2, 1.4]]:
		f.art(c2[0], c2[1], c2[2], c2[3], c2[4])
	_dress(f, [c, m, st, s1, s2], &"hall", 2)
	f.sconces(3.0)


## East gallery corridor upstairs (pearl, carpet): Feyre's door is off it.
static func _east_corridor_l1(f: ManorFurnisher) -> void:
	# doors: north 6.2-7.8 (Feyre's morning room side), 14.2-15.8; south 7.2-8.8, 24.2-25.8
	_corridor_lights(f)
	f.put(&"rug_runner", 7, 2, 90)
	f.put(&"rug_runner", 20, 2, 90)
	f.put(&"rug_runner", 29.5, 2, 90)
	var a := f.fit_wall("n", 3.4, &"commode_serpentine")
	f.hang("n", 3.4, &"wall_mirror_oval", 2.0)
	f.fit_wall("n", 11.0, &"bust_pedestal")
	f.fit_wall("n", 21.5, &"chaise_longue")
	f.fit_wall("n", 28.0, &"plant_stand_fern")
	f.fit_wall("n", 31.6, &"orange_tree_tub")
	f.fit_wall("s", 3.4, &"hall_bench_cushioned")
	f.fit_wall("s", 14.4, &"clock_grandfather")
	var b := f.fit_wall("s", 19.0, &"console_gilt")
	_shelves(f, f.fit_wall("s", 28.0, &"etagere_gilt"), &"parlour")
	f.fit_wall("s", 31.6, &"potted_roses")
	for c in [[10.0, &"painting_medium", 2.0, 1.0], [12.6, &"painting_small", 2.1, 0.9], [26.0, &"painting_large", 2.2, 0.7],
			[31.6, &"painting_small", 2.4, 1.2]]:
		f.art("n", c[0], c[1], c[2], c[3])
	for c in [[2.4, &"painting_medium", 2.2, 0.8], [11.6, &"portrait_masked", 2.1, 0.9], [21.0, &"painting_medium", 2.0, 1.1]]:
		f.art("s", c[0], c[1], c[2], c[3])
	_dress(f, [a, b], &"parlour", 1)
	f.sconces(4.5)


## West gallery corridor upstairs (blush): more hall paintings (ch7), a secretary.
static func _west_corridor_l1(f: ManorFurnisher) -> void:
	# doors: north 5.2-6.8, 25.2-26.8; south 7.2-8.8, 24.2-25.8
	_corridor_lights(f)
	f.put(&"rug_runner", 6, 2, 90)
	f.put(&"rug_runner", 17, 2, 90)
	f.put(&"rug_runner", 28, 2, 90)
	f.fit_wall("n", 2.6, &"bureau_secretary")
	f.fit_wall("n", 16.5, &"hall_bench_cushioned")
	var a := f.fit_wall("n", 29.5, &"console_gilt")
	f.hang("n", 29.5, &"mirror_gilt", 2.1)
	f.fit_wall("n", 21.0, &"bust_pedestal")
	f.fit_wall("s", 2.4, &"plant_stand_fern")
	f.fit_wall("s", 14.6, &"settee_rose")
	var b := f.fit_wall("s", 19.6, &"commode_serpentine")
	f.fit_wall("s", 27.4, &"clock_grandfather")
	f.fit_wall("s", 30.4, &"orange_tree_tub")
	for c in [[8.4, &"painting_medium", 2.0, 1.0], [16.5, &"painting_large", 2.3, 0.75], [22.6, &"portrait_masked", 2.1, 0.9],
			[32.0, &"painting_small", 1.9, 1.0]]:
		f.art("n", c[0], c[1], c[2], c[3])
	for c in [[10.6, &"painting_small", 2.0, 1.3], [14.6, &"painting_medium", 2.2, 1.0], [20.2, &"painting_medium", 2.2, 0.8],
			[28.4, &"portrait_masked", 2.4, 0.7]]:
		f.art("s", c[0], c[1], c[2], c[3])
	_dress(f, [a, b], &"hall", 1)
	f.sconces(4.5)


## [C] Ch6: pale green walls sketched with gold, golden mouldings, ivory furniture
## and rugs, a gigantic bed (station, west wall) with curtains from a towering
## headboard, emerald silk curtains with gold (ManorRoomFinish), an armoire
## (ch8), a marble vanity with drawers, a roaring fire with a low-backed chair
## before it, windows to the garden (the curtain trap's window, x 7, stays clear).
static func _feyre_bedroom(f: ManorFurnisher) -> void:
	f.light(&"chandelier_crystal", 7, 9.5)
	f.put(&"rug_large", 7, 12.2, 90)
	f.put(&"rug_round", 4.6, 4.6)
	f.put(&"rug_round", 10.5, 4.2, 0, 0.0, 0.8)
	# the bed: nightstands either side of the headboard
	f.set_on(f.at(&"nightstand", 0.55, 10.2, -90), [&"candlestick_crystal", &"posy_teacup"])
	f.set_on(f.at(&"nightstand", 0.55, 13.8, -90), [&"hurricane_lamp", &"book_pile_ribbon"])
	f.fit_wall("w", 7.9, &"chaise_longue")
	var bs1 := f.fit_wall("w", 6.4, &"table_side")
	var bs2 := f.at(&"table_side", 8.5, 16.3)
	f.at(&"footstool_velvet", 2.0, 6.4)
	# she learns her letters [C ch 13-14]: a small writing desk under the window light
	var wd := f.fit_wall("w", 2.0, &"writing_desk_small")
	f.at(&"chair_simple", 1.25, 2.0)
	f.set_on(wd, [&"books_childrens", &"quill_and_parchment"])
	# the hearth (station, east wall): the low-backed chair before it, tools and logs
	f.at(&"chair_low_back", 12.0, 11.0, -90)
	f.fit_wall("e", 12.7, &"fire_tools")
	f.fit_wall("e", 9.3, &"log_basket")
	# south wall: the armoire and the marble vanity
	f.fit_wall("s", 3.0, &"armoire_ivory")
	var van := f.fit_wall("s", 11.0, &"vanity_marble")
	f.hang("s", 11.0, &"wall_mirror_oval", 1.75)
	f.at(&"pouf_stool", 11.0, 18.5)
	f.set_on(van, [&"hand_mirror_brush", &"perfume_bottles_tall", &"jewelry_box"])
	f.fit_wall("s", 5.3, &"cheval_mirror")
	# north: window seats either side of the trap window, a breakfast table in the light
	var seats := f.under_windows("n", &"window_seat", 0.0, 0.8)
	var on := [[&"cushion_pile", &"fan_lace"], [&"cushion_pile", &"book_open"]]
	var k := 0
	for p in seats:
		if absf(p.position.x - 7.0) > 2.0:
			f.set_on(p, on[k % on.size()])
			k += 1
	var tr := f.at(&"table_round", 10.5, 4.2)
	f.at(&"chair_simple", 9.3, 4.4)
	f.at(&"chair_simple", 11.7, 4.0)
	var cm := f.fit_wall("e", 2.6, &"commode_serpentine")
	f.hang("e", 2.6, &"wall_clock_sunburst", 2.0)
	# the south-east corner: a settee and tea table by the bath door
	f.at(&"settee_rose", 10.0, 16.3, 0)
	var tea := f.at(&"table_tea", 10.0, 15.0)
	f.fit_wall("e", 18.3, &"plant_stand_fern")
	f.at(&"potted_roses", 0.7, 1.0)
	f.at(&"floor_candlestand", 0.7, 18.9)
	f.fit_wall("w", 17.0, &"bureau_secretary")
	_shelves(f, f.fit_wall("e", 4.1, &"etagere_gilt"), &"bedroom")
	# a pier table between the cheval glass and the vanity
	var pt := f.fit_wall("s", 9.2, &"console_gilt")
	f.at(&"hatbox_stack", 13.3, 18.9)
	f.art("w", 7.9, &"painting_medium", 2.0)
	f.art("e", 18.3, &"painting_small", 1.9, 1.2)
	_dress(f, [tr, tea, cm, bs1, bs2, pt], &"bedroom", 3)
	f.dress_all(&"bedroom", 2)
	_wall_accents(f, &"cosy")
	_wall_accents(f, &"grand")
	f.sconces(2.6)


## [C] Hot water and scented baths, Alis attends (ch6-7); the tub's form is ours.
static func _feyre_bath(f: ManorFurnisher) -> void:
	f.light(&"chandelier_small", 3, 4.4)
	f.put(&"rug_round", 2.6, 5.6, 0, 0.0, 0.5)
	var ws := f.fit_wall("e", 4.8, &"washstand")
	f.hang("e", 4.8, &"mirror_gilt", 1.85)
	f.fit_wall("e", 6.9, &"towel_rack")
	f.fit_wall("s", 3.4, &"linen_press")
	f.fit_wall("n", 4.6, &"candle_bank")
	f.at(&"fern_pot", 5.3, 0.9)
	var stool := f.at(&"stool", 4.0, 2.3)
	f.at(&"folding_screen_painted", 1.3, 6.3, 60)
	f.at(&"hatbox_stack", 0.6, 7.3)
	var bench := f.fit_wall("n", 1.85, &"bench_settle")
	f.at(&"potted_roses", 5.3, 7.25)
	f.fit_wall("w", 6.5, &"cheval_mirror")
	f.fit_wall("e", 2.2, &"chaise_longue")
	f.at(&"plant_stand_fern", 0.55, 0.55)
	f.at(&"footstool_velvet", 4.2, 3.6)
	f.hang("e", 2.0, &"soap_shelf", 1.3)
	f.hang("w", 6.4, &"wall_shelf_curios", 1.7)
	f.set_on(ws, [&"basin_and_jug"])
	f.set_on(stool, [&"linen_stack"])
	f.set_on(bench, [&"perfume_bottles_tall", &"shell_dish"])
	f.put_on(&"bowl_floating_blossoms", 5.4, 1.0, 0, 1.0)
	f.sconces(2.4)


## [C] An empty room on the first floor with a table full of canvases, gleaming
## brushes, so many paints, clear bright light (bare windows); white roses
## (ch22). The studio nook (L30-6) is built round the easel station at runtime:
## its corner (x 6..11, z 14..20) is left to it.
static func _painting_room(f: ManorFurnisher) -> void:
	f.light(&"chandelier_crystal", 8, 7)
	f.put(&"rug_large", 8, 6.5)
	var tbl := f.at(&"table_work", 8, 6.5, 0)
	f.set_on(tbl, [&"pigment_jars", &"vase_white_roses", &"apples_bowl", &"jug_daffodils"])
	f.dsl.prop(f.room, &"canvas_stack", 8.0, 7.6, 180, 0.0, 0.8)
	f.fit_wall("w", 3.0, &"canvas_stack")
	f.fit_wall("w", 5.4, &"bookcase_low")
	f.fit_wall("w", 12.2, &"chair_bergere")
	f.fit_wall("e", 3.0, &"canvas_stack")
	var pt := f.fit_wall("e", 7.0, &"paint_table")
	f.fit_wall("e", 11.5, &"chaise_longue")
	var dr := f.fit_wall("n", 3.0, &"dresser")
	f.fit_wall("n", 12.8, &"folding_screen_painted")
	f.at(&"easel", 3.2, 10.5, 30)
	f.at(&"easel", 13.0, 15.8, -25)
	f.at(&"stool", 4.2, 11.6)
	f.at(&"potted_roses", 4.6, 18.8)
	f.at(&"vase_tall", 0.8, 19.0)
	f.at(&"potted_palm", 5.2, 1.1)
	f.at(&"fern_pot", 11.6, 18.9)
	f.at(&"music_stand", 14.6, 1.0)
	f.art("w", 9.0, &"painting_medium", 1.9, 1.0)
	f.art("e", 15.5, &"painting_small", 1.9)
	f.art("n", 12.8, &"painting_small", 2.6, 0.8)
	_dress(f, [pt, dr], &"studio", 1)
	f.dress_all(&"studio", 1)
	f.sconces(4.5)


## Tamlin's bedchamber [C]: the hearth (station, east wall) with a fireside pair;
## [X] the bed against the south wall, his weapons; the west wall's middle is the
## Calanmai painting's place (L45 anchor), only low furniture under it.
static func _tamlin_bedchamber(f: ManorFurnisher) -> void:
	f.light(&"chandelier_crystal", 9, 6)
	f.reserve("w", TAMLIN_PAINTING_T - 1.0, TAMLIN_PAINTING_T + 1.0)
	f.put(&"rug_large", 5.6, 6, 90)
	f.put(&"rug_round", 12.6, 6)
	f.at(&"bed_canopy", 3.6, 10.4, 0)
	f.set_on(f.at(&"nightstand", 1.8, 11.4), [&"candlestick_brass", &"hourglass"])
	f.set_on(f.at(&"nightstand", 5.4, 11.4), [&"book_pile_ribbon"])
	f.at(&"bed_bench", 3.6, 8.65)
	var w := f.at(&"commode_serpentine", 0.6, TAMLIN_PAINTING_T, -90)
	f.at(&"chair_bergere", 15.0, 4.0, 120)
	f.at(&"chair_bergere", 15.0, 8.0, 60)
	var st := f.at(&"table_side", 15.6, 6.0)
	f.fit_wall("n", 3.5, &"weapon_rack")
	f.fit_wall("n", 6.4, &"wardrobe_tall")
	f.fit_wall("n", 13.6, &"armor_stand")
	f.fit_wall("n", 15.6, &"bow_rack")
	var desk := f.fit_wall("s", 13.6, &"desk_writing")
	f.at(&"chair_simple", 13.6, 10.5)
	f.fit_wall("s", 16.9, &"plant_stand_fern")
	f.fit_wall("e", 10.6, &"bookcase_tall")
	var ch := f.at(&"chest_trunk", 0.7, 2.0, -90)
	# a card table by the north windows: the hunt's maps and a game of chess
	var ct := f.at(&"table_round", 9.6, 3.2)
	f.at(&"chair_simple", 8.5, 3.2)
	f.at(&"chair_simple", 10.7, 3.2)
	f.set_on(ct, [&"chess_set", &"candle_cluster", &"apples_bowl"])
	_shelves(f, f.fit_wall("s", 11.4, &"etagere_gilt"), &"study")
	var drs := f.fit_wall("w", 10.2, &"dresser")
	f.fit_wall("w", 3.3, &"clock_grandfather")
	f.art("n", 10.6, &"painting_small", 2.0, 1.1)
	f.hang("s", 6.4, &"mask_display", 2.4)
	f.hang("e", 1.6, &"barometer_wall", 1.8)
	_dress(f, [w, st, desk, ch, drs], &"study", 3)
	f.dress_all(&"study", 2)
	f.mantel(&"study")
	_wall_accents(f, &"cosy")
	_wall_accents(f, &"grand", ["n", "s", "e"])
	f.sconces(3.0)


# --- service wing --------------------------------------------------------------------

## [C] The kitchen with its garden doors, the range (station) and the old hearth
## (station); a central table [X but safe]. Alis's hiding spot by the larder stays clear.
static func _svc_kitchen(f: ManorFurnisher) -> void:
	for x in [4.0, 10.0]:
		f.light(&"lantern_hanging", x, 6.5)
	f.put(&"pot_rack_hanging", 7.0, 6.8, 0, ManorFurnishContext.ceiling_of(f.room) - 0.75)
	f.put(&"rug_round", 9.6, 11.4, 0, 0.0, 0.6)
	var isl := f.at(&"table_kitchen", 7.0, 6.8, 0)
	f.set_on(isl, [&"bread_board", &"pie_lattice", &"mixing_bowls", &"egg_basket", &"rolling_pin_flour", &"copper_kettle"])
	f.at(&"stool", 5.6, 8.0)
	f.at(&"stool", 8.4, 8.0)
	f.fit_wall("n", 4.6, &"sink_stone")
	var dc := f.fit_wall("n", 9.2, &"dresser_crockery")
	f.fit_wall("e", 7.0, &"bread_oven")
	var fb := f.fit_wall("e", 0.9, &"flour_bin")
	f.fit_wall("e", 12.9, &"butter_churn")
	_shelves(f, f.fit_wall("w", 2.6, &"pantry_shelf"), &"kitchen")
	f.fit_wall("w", 11.4, &"dough_trough")
	var tw := f.fit_wall("s", 2.6, &"table_work")
	f.fit_wall("s", 12.6, &"barrel")
	f.at(&"sack_flour", 0.75, 13.2)
	f.at(&"basket_produce", 4.4, 13.3)
	f.hang("w", 6.8, &"plate_rack_wall", 2.1)
	f.hang("s", 6.4, &"garlic_braid_wall", 1.9)
	f.hang("s", 13.4, &"herb_bundle_hanging", 2.2)
	f.hang("n", 0.9, &"copper_pots", 2.2)
	_dress(f, [tw, dc, fb], &"kitchen", 2)
	_wall_accents(f, &"work")


## [C] Ch12: a supply closet with a worktable, cabinets, drawers and a deep sink.
## The worktable and sink are built by the wound-dressing scene (their marks stay
## clear); the bandages and linen it gathers sit on shelves at the north wall's
## ends and the bowl on the washstand under the west window (stage src_ marks).
static func _svc_infirmary(f: ManorFurnisher) -> void:
	f.light(&"lantern_hanging", 5, 3.5)
	f.fit_wall("n", 2.0, &"bandage_shelf")
	f.fit_wall("n", 8.0, &"bandage_shelf")
	f.set_on(f.at(&"washstand", 2.0, 6.45, 0), [&"basin_and_jug"])
	f.set_on(f.fit_wall("w", 5.6, &"drawer_chest_apothecary"), [&"herb_bell_jars", &"salve_jars", &"brass_scales"])
	f.fit_wall("w", 1.2, &"linen_press")
	f.fit_wall("s", 5.0, &"apothecary_cabinet")
	f.at(&"chair_simple", 3.3, 1.9)
	f.hang("e", 1.4, &"medicine_cabinet_wall", 1.6)
	f.hang("s", 9.0, &"herb_bundle_hanging", 2.2)
	f.dress_all(&"infirmary", 1)
	_wall_accents(f, &"work")


## The service passage under the kitchen hall: the bite (ch21) and two hall marks
## are staged here; only pieces against the walls.
static func _svc_passage_0(f: ManorFurnisher) -> void:
	for x in [8.0, 24.0]:
		f.light(&"lantern_hanging", x, 3)
	f.put(&"rug_runner", 13.5, 3, 90)
	f.put(&"rug_runner", 25.5, 3, 90)
	f.fit_wall("n", 13.0, &"bench_settle")
	f.fit_wall("n", 27.4, &"coat_rack")
	f.fit_wall("n", 25.0, &"chest_trunk")
	f.fit_wall("s", 10.2, &"bench_settle")
	f.fit_wall("s", 24.0, &"barrel")
	f.fit_wall("s", 28.8, &"crate")
	f.fit_wall("n", 31.0, &"umbrella_stand")
	f.fit_wall("s", 13.0, &"linen_press")
	f.fit_wall("s", 22.4, &"crate")
	f.fit_wall("s", 30.4, &"barrel")
	var d1 := f.fit_wall("s", 2.6, &"dresser")
	var d2 := f.fit_wall("n", 19.9, &"sideboard")
	f.art("n", 3.0, &"painting_small", 1.7, 0.9)
	f.art("s", 13.0, &"painting_small", 2.6, 0.8)
	_dress(f, [d1, d2], &"service", 2)
	f.hang("n", 4.0, &"servants_bell_board", 2.0)
	f.hang("n", 20.0, &"barometer_wall", 1.8)
	f.hang("s", 4.0, &"wall_shelf_books", 1.8)
	f.hang("s", 19.4, &"herb_bundle_hanging", 2.1)
	_wall_accents(f, &"cosy", ["n", "s"])
	f.sconces(4.0)


## Alis's room [X]: small, warm, a mother-figure's room (her nephews' things),
## the loose floorboard (secret, south-west) left bare.
static func _svc_alis_room(f: ManorFurnisher) -> void:
	f.light(&"lantern_hanging", 5, 7)
	f.put(&"rug_round", 5, 7.5, 0, 0.0, 0.8)
	f.put(&"rug_runner", 2.4, 3.2, 90, 0.0, 0.6)
	f.fit_wall("e", 4.0, &"bed_single")
	f.fit_wall("e", 7.5, &"bed_single")       # her sister's two boys she raises [C]
	f.at(&"cradle_chest", 7.2, 5.75, 90)
	f.fit_wall("w", 10.6, &"wardrobe_tall")
	f.fit_wall("n", 2.0, &"loom_upright")
	var tr := f.at(&"table_round", 5.0, 4.0)
	f.at(&"chair_simple", 3.9, 4.0)
	f.at(&"chair_simple", 6.1, 4.0)
	var ns := f.at(&"nightstand", 9.4, 6.0)
	f.fit_wall("w", 6.0, &"chest_trunk")
	var dr := f.fit_wall("e", 10.5, &"dresser")
	f.hang("e", 10.5, &"wall_mirror_oval", 1.8)
	f.at(&"spinning_wheel", 2.6, 8.4, 30)
	f.at(&"armchair", 5.5, 10.0, 200)
	var ts := f.at(&"table_side", 4.2, 10.9)
	f.fit_wall("s", 5.0, &"window_seat")
	f.at(&"rocking_horse", 7.2, 12.4, 20)
	f.at(&"embroidery_frame", 2.4, 11.4, 60)
	f.fit_wall("n", 8.0, &"coat_rack")
	f.fit_wall("w", 2.0, &"bookcase_low")
	f.at(&"fern_pot", 9.2, 1.0)
	f.hang("w", 9.6, &"wall_shelf_curios", 1.7)
	f.set_on(ns, [&"candlestick_brass", &"posy_teacup"])
	_dress(f, [dr, ts, tr], &"service", 1)
	f.dress_all(&"service", 1)


## The servants' hall [X]: the long table where the household eats, the hearth
## (station, west wall), the bell board; the wound walk along the east and north
## sides stays open (runners laid along it).
static func _svc_servants_hall(f: ManorFurnisher) -> void:
	f.light(&"lantern_hanging", 6, 5)
	f.light(&"lantern_hanging", 6, 10)
	f.put(&"rug_runner", 12.8, 5.0)
	f.put(&"rug_runner", 12.8, 10.0)
	f.put(&"rug_round", 9.6, 1.6, 0, 0.0, 0.6)
	var t := f.at(&"table_kitchen", 6.0, 7.5, 90)
	f.at(&"bench_settle", 4.9, 7.5, 90)
	f.at(&"bench_settle", 7.1, 7.5, -90)
	f.fit_wall("n", 2.6, &"dresser_crockery")
	f.fit_wall("n", 11.5, &"bookcase_low")
	f.fit_wall("s", 4.65, &"linen_press")
	var sb := f.fit_wall("s", 9.35, &"sideboard")
	f.fit_wall("s", 13.2, &"crate")
	f.put(&"rug_round", 5.3, 12.0, 0, 0.0, 0.8)
	var tr := f.at(&"table_round", 2.4, 2.4)
	f.at(&"chair_simple", 2.4, 1.3)
	f.at(&"chair_simple", 3.5, 2.4)
	f.at(&"chair_simple", 6.0, 9.6)
	f.at(&"chair_simple", 6.0, 5.4)
	f.fit_wall("w", 9.4, &"ironing_table")
	f.fit_wall("n", 4.6, &"coat_rack")
	f.at(&"basket_produce", 0.75, 13.3)
	f.at(&"sack_flour", 1.5, 13.3)
	f.hang("n", 9.6, &"servants_bell_board", 2.0)
	var dr := f.fit_wall("w", 3.4, &"dresser")
	f.fit_wall("w", 11.6, &"barrel")
	f.at(&"armchair", 2.2, 5.0, 120)
	f.at(&"spinning_wheel", 2.2, 11.9, 60)
	f.at(&"log_basket", 0.6, 7.5, 90)
	f.fit_wall("w", 1.4, &"chest_trunk")
	f.set_on(t, [&"bread_board", &"jam_jars", &"teacup_set", &"apples_bowl", &"cheese_board"])
	_dress(f, [sb, dr, tr], &"service", 2)
	_wall_accents(f, &"work")
	f.sconces(3.5)
