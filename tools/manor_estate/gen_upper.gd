## Generator: the manor's upper storeys (sub-lane B).
##
## Level 1 (first floor) of the main block and west wing, level 2 (attic) of the
## main block, level 3 (four corner tower tops), and the roofs over the main
## block and west wing. Run:
##   godot --headless -s tools/manor_estate/gen_upper.gd
## Writes data/regions/spring_court/manor_estate/house/upper.tres.
##
## Canon tags follow lore/02-locations/spring-manor-house.md: Feyre's bedroom
## with its bathing chamber and garden windows, Tamlin's and Lucien's rooms and
## the painting room are canon; everything else is invented ("X").
extends SceneTree

# Wall colours (R3: never grey; vary per room).
const BLUSH := Color(1.0, 0.86, 0.89)
const ROSE := Color(0.99, 0.75, 0.83)
const LILAC := Color(0.88, 0.80, 0.98)
const MINT := Color(0.80, 0.96, 0.88)
const BUTTER := Color(1.0, 0.95, 0.76)
const PERI := Color(0.82, 0.85, 1.0)
const PEARL := Color(0.99, 0.96, 0.94)
const PEACH := Color(1.0, 0.87, 0.78)
const SAGE := Color(0.84, 0.93, 0.80)

const SLATE := Color(0.60, 0.52, 0.80)
const GOLD := Color(1.0, 0.80, 0.38)

var dsl := ManorLayoutDSL.new(&"upper")


func _init() -> void:
	_level_1_main()
	_level_1_west_wing()
	_level_2_attic()
	_level_3_towers()
	_roofs()
	dsl.save()
	quit()


## Adds props from rows [id, x, z, yaw?, y?, scale?] (room-local metres).
func _p(r: ManorRoomDef, rows: Array) -> void:
	for row in rows:
		var yaw: float = row[3] if row.size() > 3 else 0.0
		var y: float = row[4] if row.size() > 4 else 0.0
		var s: float = row[5] if row.size() > 5 else 1.0
		dsl.prop(r, row[0], row[1], row[2], yaw, y, s)


# --- Level 1: main block -----------------------------------------------------

func _level_1_main() -> void:
	# Upper hall over the grand stair (hole Rect2(-5,-52,10,12) = local x 3..13, z 10..22).
	var hall := dsl.room(&"upper_hall", "Upper Hall", 1, Rect2(-8, -62, 16, 24), "C", &"marble", PEARL)
	hall.notes = "Halls of gold and silver; the grand stair arrives here. Hall paintings (still life of a green glass vase) per ch7."
	_p(hall, [
		[&"chandelier_crystal", 8, 5, 0, 2.6], [&"chandelier_crystal", 8, 16, 0, 2.6],
		[&"balustrade", 2.6, 16, 90], [&"balustrade", 13.4, 16, 90], [&"balustrade", 8, 9.6],
		[&"statue_maiden", 1.4, 2.5], [&"statue_maiden", 14.6, 2.5],
		[&"painting_large", 3.5, 0.2, 0, 1.2], [&"painting_large", 12.5, 0.2, 0, 1.2],
		[&"painting_medium", 0.15, 7, 90, 1.4], [&"painting_medium", 15.85, 7, -90, 1.4],
		[&"urn_flowers", 1.4, 9], [&"urn_flowers", 14.6, 9],
		[&"potted_palm", 1.2, 22.6], [&"potted_palm", 14.8, 22.6],
		[&"rug_round", 8, 5], [&"table_side", 1.0, 17], [&"vase_roses", 1.0, 17, 0, 0.7],
		[&"candle_sconce", 0.15, 14, 90, 1.9], [&"candle_sconce", 15.85, 14, -90, 1.9],
		[&"clock_grandfather", 15.4, 18, -90],
	])

	var loggia := dsl.room(&"garden_loggia", "Garden Loggia", 1, Rect2(-8, -72, 16, 10), "X", &"marble", MINT)
	loggia.notes = "Open-feeling garden room over the terrace; tall windows onto the rose gardens."
	_p(loggia, [
		[&"column_marble", 2, 1.2], [&"column_marble", 6, 1.2], [&"column_marble", 10, 1.2], [&"column_marble", 14, 1.2],
		[&"potted_roses", 1, 8.8], [&"potted_roses", 15, 8.8], [&"orange_tree_tub", 4, 8.8], [&"orange_tree_tub", 12, 8.8],
		[&"garden_bench", 5, 4.5], [&"garden_bench", 11, 4.5], [&"table_tea", 8, 5.5],
		[&"cake_stand", 8, 5.5, 0, 0.5], [&"lantern_hanging", 8, 3, 0, 3.4], [&"flower_garland", 8, 0.3, 0, 3.4],
		[&"birdcage_gilt", 1.2, 4],
	])

	var nook := dsl.room(&"front_reading_nook", "Front Reading Nook", 1, Rect2(-8, -38, 16, 10), "X", &"wood", BUTTER)
	_p(nook, [
		[&"window_seat", 5, 9.4, 180], [&"window_seat", 11, 9.4, 180], [&"cushion_pile", 8, 8.8],
		[&"bookcase_tall", 0.4, 1.5, 90], [&"bookcase_tall", 15.6, 1.5, -90],
		[&"bookcase_tall", 0.4, 8.5, 90], [&"bookcase_tall", 15.6, 8.5, -90],
		[&"armchair", 5, 5, 30], [&"armchair", 11, 5, -30], [&"table_tea", 8, 5],
		[&"book_stack", 8, 5, 0, 0.5], [&"reading_lectern", 3, 2], [&"floor_candlestand", 13, 2],
		[&"rug_round", 8, 5], [&"chandelier_small", 8, 5, 0, 3.3], [&"vase_roses", 8, 9.4, 0, 0.6],
	])

	var corr_e := dsl.room(&"east_corridor", "East Gallery Corridor", 1, Rect2(8, -52, 34, 4), "C?", &"carpet", PEARL, 0.0, &"corridor")
	_p(corr_e, [
		[&"rug_runner", 6, 2, 90], [&"rug_runner", 17, 2, 90], [&"rug_runner", 28, 2, 90],
		[&"painting_small", 10, 0.15, 0, 1.5], [&"painting_medium", 28, 0.15, 0, 1.4],
		[&"painting_medium", 3, 3.85, 180, 1.4], [&"painting_small", 20, 3.85, 180, 1.5], [&"painting_medium", 30, 3.85, 180, 1.4],
		[&"candle_sconce", 12.5, 0.15, 0, 1.9], [&"candle_sconce", 21, 0.15, 0, 1.9], [&"candle_sconce", 12, 3.85, 180, 1.9],
		[&"table_side", 32.5, 0.5], [&"vase_tall", 32.5, 0.5, 0, 0.7], [&"potted_palm", 33.2, 3.2],
	])

	var corr_w := dsl.room(&"west_corridor", "West Gallery Corridor", 1, Rect2(-42, -52, 34, 4), "C?", &"carpet", BLUSH, 0.0, &"corridor")
	corr_w.notes = "Hall paintings Feyre studies on her first exploration (ch7)."
	_p(corr_w, [
		[&"rug_runner", 6, 2, 90], [&"rug_runner", 17, 2, 90], [&"rug_runner", 28, 2, 90],
		[&"painting_medium", 12, 0.15, 0, 1.4], [&"painting_large", 19, 0.15, 0, 1.2],
		[&"painting_medium", 3, 3.85, 180, 1.4], [&"painting_small", 14, 3.85, 180, 1.5], [&"painting_medium", 30, 3.85, 180, 1.4],
		[&"candle_sconce", 2, 0.15, 0, 1.9], [&"candle_sconce", 31, 0.15, 0, 1.9], [&"candle_sconce", 19, 3.85, 180, 1.9],
		[&"bust_pedestal", 22.5, 0.6], [&"table_side", 1.0, 3.3], [&"vase_roses", 1.0, 3.3, 0, 0.7],
	])

	# Attic stair hall: stair Rect2(10,-61,4,7) = local x 2..6, z 1..8; rises south.
	var sh := dsl.room(&"attic_stair_hall", "Attic Stair Hall", 1, Rect2(8, -62, 8, 10), "X", &"wood", PERI, 0.0, &"stair_hall")
	_p(sh, [
		[&"coat_rack", 0.8, 9.2], [&"lantern_hanging", 7, 5, 0, 3.4], [&"candle_sconce", 0.15, 5, 90, 1.9],
		[&"candle_sconce", 7.85, 5, -90, 1.9], [&"painting_small", 0.15, 2, 90, 1.5], [&"fern_pot", 0.8, 0.8],
		[&"chest_trunk", 7.3, 5.5, -90], [&"stool", 0.9, 7.5],
	])

	var morning := dsl.room(&"feyre_morning_room", "Feyre's Morning Room", 1, Rect2(8, -72, 8, 10), "X", &"wood", MINT)
	morning.notes = "A small sunny reading nook off Feyre's bedroom, looking over the gardens."
	_p(morning, [
		[&"window_seat", 4, 0.5], [&"cushion_pile", 4, 0.9, 0, 0.6, 0.6], [&"armchair", 5.5, 5, -45],
		[&"table_side", 4.2, 5.5], [&"vase_roses", 4.2, 5.5, 0, 0.7], [&"desk_writing", 0.6, 8.6, 90],
		[&"inkstand", 0.6, 8.6, 0, 0.8], [&"bookcase_low", 7.5, 8.8, -90], [&"potted_roses", 7.3, 1],
		[&"rug_round", 4, 5, 0, 0.0, 0.8], [&"chandelier_small", 4, 5, 0, 3.3],
	])

	# Feyre's bedroom [C]: canopy bed (station), window seats onto the gardens, hearth.
	var bed := dsl.room(&"feyre_bedroom", "Feyre's Bedroom", 1, Rect2(16, -72, 14, 20), "C", &"wood", BLUSH)
	bed.notes = "Second level, attached bathing chamber, windows over the garden with a wisteria trellis below (ch7, ch11)."
	_p(bed, [
		[&"window_seat", 4, 0.5], [&"window_seat", 10, 0.5], [&"cushion_pile", 4, 0.9, 0, 0.6, 0.6], [&"cushion_pile", 10, 0.9, 0, 0.6, 0.6],
		[&"nightstand", 0.4, 10, 90], [&"nightstand", 0.4, 14.4, 90],
		[&"vase_roses", 0.4, 10, 0, 0.7], [&"candelabra", 0.4, 14.4, 0, 0.7],
		[&"rug_large", 6, 12.2, 90], [&"chaise_longue", 6.5, 16.5, 90],
		[&"armchair", 10.5, 9, 60], [&"armchair", 10.5, 13, 120], [&"table_tea", 11, 11],
		[&"chandelier_crystal", 7, 10, 0, 2.6], [&"candle_sconce", 13.85, 3, -90, 1.9], [&"candle_sconce", 0.15, 4, 90, 1.9],
		[&"dresser", 3, 19.5, 180], [&"painting_medium", 11, 19.85, 180, 1.4], [&"mirror_gilt", 3, 19.85, 180, 1.5],
		[&"potted_roses", 13.3, 1], [&"potted_roses", 0.7, 1], [&"floor_candlestand", 13.3, 18.8],
	])

	# Dressing room [X]: the user's headline request.
	var dr := dsl.room(&"dressing_room", "Feyre's Dressing Room", 1, Rect2(30, -72, 12, 12), "X", &"carpet", ROSE)
	dr.notes = "Outfits (wardrobe station) and makeup/hair (dressing_mirror station). A mirror door hides the jewellery closet."
	_p(dr, [
		[&"gown_rack", 5.6, 0.6], [&"gown_rack", 9.2, 0.6], [&"wardrobe_tall", 11.0, 2.0, -90],
		[&"mannequin_gown", 4.2, 5.6], [&"mannequin_gown", 6.0, 7.4], [&"mannequin_gown", 7.8, 5.6],
		[&"rug_round", 6, 6.2], [&"shoe_shelf", 0.3, 2.6, 90], [&"shoe_shelf", 0.3, 9.6, 90],
		[&"hat_stand", 1.0, 11.2], [&"hat_stand", 2.6, 11.2], [&"dressing_screen", 4.2, 10.4, 20],
		[&"cheval_mirror", 6.4, 11.4, 180], [&"cheval_mirror", 11.4, 10.4, -90],
		[&"vanity_table", 11.6, 6.0, -90], [&"pouf_stool", 10.6, 6.0], [&"pouf_stool", 6.0, 3.6], [&"pouf_stool", 8.6, 9.6],
		[&"jewelry_box", 11.6, 5.4, -90, 0.8], [&"perfume_tray", 11.6, 6.6, -90, 0.8], [&"makeup_palette", 11.4, 6.0, -90, 0.8],
		[&"chandelier_crystal", 6, 6, 0, 2.6], [&"candle_sconce", 11.85, 4.4, -90, 1.9], [&"candle_sconce", 11.85, 7.6, -90, 1.9],
		[&"vase_roses", 11.6, 4.6, 0, 0.8], [&"chaise_longue", 2.2, 6.0, 90],
		# jewel box (experience bar §2.6): the vanity under the bulb-lit mirror
		# station is the hero; a wall of gilt mirrors over the shoe shelves
		# multiplies the light.
		[&"mirror_gilt", 0.3, 2.4, 90, 1.45], [&"mirror_gilt", 0.3, 3.6, 90, 1.45], [&"mirror_gilt", 0.3, 4.8, 90, 1.45],
		[&"mirror_gilt", 0.3, 6.0, 90, 1.45], [&"mirror_gilt", 0.3, 7.2, 90, 1.45], [&"mirror_gilt", 0.3, 8.4, 90, 1.45],
		[&"mirror_gilt", 0.3, 9.6, 90, 1.45],
	])

	var closet := dsl.room(&"jewel_closet", "Hidden Jewellery Closet", 1, Rect2(36, -60, 6, 8), "X", &"carpet", BUTTER)
	closet.notes = "Behind the dressing room's mirror door."
	_p(closet, [
		[&"cabinet_curio", 0.4, 4, 90], [&"cabinet_curio", 5.6, 4, -90], [&"table_side", 3, 6.5],
		[&"jewelry_box", 3, 6.5, 0, 0.7], [&"jewelry_box", 0.4, 4, 0, 1.0], [&"mask_display", 3, 7.85, 180, 1.4],
		[&"hat_stand", 5.3, 7.2], [&"chandelier_small", 3, 4, 0, 3.3], [&"mirror_gilt", 5.85, 1.5, -90, 1.4],
		[&"pouf_stool", 2.2, 4.5], [&"rug_round", 3, 4, 0, 0.0, 0.6],
	])

	var bath := dsl.room(&"feyre_bath", "Feyre's Bathing Chamber", 1, Rect2(30, -60, 6, 8), "C", &"tile", MINT)
	bath.notes = "Hot water, scented baths; Alis attends (ch6-7)."
	_p(bath, [
		[&"soap_shelf", 5.8, 4.2, -90, 0.9], [&"towel_rack", 5.6, 6.8, -90], [&"washstand", 3.2, 7.6, 180],
		[&"perfume_tray", 3.2, 7.6, 180, 0.9], [&"mirror_gilt", 3.2, 7.85, 180, 1.5], [&"candelabra", 0.6, 1.0],
		[&"vase_roses", 5.4, 0.6], [&"fern_pot", 0.6, 7.4], [&"chandelier_small", 3, 3, 0, 3.3],
		[&"candle_bank", 5.6, 2.2, -90], [&"rug_round", 2.4, 5.2, 0, 0.0, 0.5], [&"faelight_orb", 3.5, 2, 0, 2.6],
	])

	var paint := dsl.room(&"painting_room", "Painting Room", 1, Rect2(8, -48, 16, 20), "C", &"wood", PEARL)
	paint.notes = "Stocked with canvases, paints and brushes; Alis shows her (ch19); Tamlin first sees her work here (ch22). South light."
	_p(paint, [
		[&"easel", 4, 15.5, 10], [&"easel", 12, 15.5, -10], [&"canvas_stack", 0.6, 3, 90], [&"canvas_stack", 0.6, 6, 90],
		[&"canvas_stack", 15.4, 3, -90], [&"paint_table", 8, 10.5], [&"pigment_jars", 8, 10.5, 0, 0.9],
		[&"pigment_jars", 14.6, 9.5, 0, 0.9], [&"table_work", 14.6, 9.5, 90], [&"stool", 4.5, 14], [&"stool", 11.5, 14],
		[&"vase_tall", 7.2, 10.2, 0, 0.9, 0.5], [&"chaise_longue", 12.5, 3.5, 0], [&"vase_roses", 10.5, 3.5],
		[&"painting_medium", 0.15, 12, 90, 1.5], [&"painting_large", 15.85, 15, -90, 1.2], [&"painting_small", 4, 0.15, 0, 1.6],
		[&"rug_large", 8, 13], [&"chandelier_crystal", 8, 8, 0, 2.6], [&"potted_palm", 1, 19], [&"potted_palm", 15, 19],
		[&"faelight_orb", 8, 15.5, 0, 2.4],
	])

	var tam := dsl.room(&"tamlin_bedchamber", "Tamlin's Bedchamber", 1, Rect2(24, -48, 18, 12), "C", &"wood", SAGE)
	_p(tam, [
		[&"bed_canopy", 1.5, 6, 90], [&"nightstand", 0.4, 3.6, 90], [&"nightstand", 0.4, 8.4, 90],
		[&"candelabra", 0.4, 3.6, 0, 0.7], [&"chest_trunk", 4.3, 6, 90], [&"rug_large", 9, 6, 90],
		[&"wingback_chair", 14.5, 4, 120], [&"wingback_chair", 14.5, 8, 60], [&"table_side", 15, 6],
		[&"mask_display", 9, 11.85, 180, 1.4], [&"weapon_rack", 4, 0.4], [&"armor_stand", 13, 0.8],
		[&"desk_writing", 13, 10.8, 180], [&"bookcase_tall", 5, 11.6, 180], [&"chandelier_crystal", 9, 6, 0, 2.6],
		[&"potted_palm", 0.8, 11.2], [&"candle_sconce", 17.85, 2, -90, 1.9], [&"candle_sconce", 17.85, 10, -90, 1.9],
	])

	var tbath := dsl.room(&"tamlin_bath", "Tamlin's Bathing & Dressing Room", 1, Rect2(24, -36, 18, 8), "X", &"marble", PERI)
	_p(tbath, [
		[&"bath_sunken", 12, 4.5], [&"towel_rack", 16, 7.4, 180], [&"soap_shelf", 17.8, 3, -90, 0.9],
		[&"washstand", 4, 0.4], [&"mirror_gilt", 4, 0.15, 0, 1.5], [&"wardrobe_tall", 1.2, 4, 90],
		[&"coat_rack", 7, 0.6], [&"chest_trunk", 1.2, 7.2], [&"bench_settle", 7, 6.8, 180],
		[&"fern_pot", 17, 0.8], [&"chandelier_small", 12, 4, 0, 3.3], [&"candle_bank", 17.6, 6, -90],
	])

	var gal := dsl.room(&"portrait_gallery", "Long Portrait Gallery", 1, Rect2(-42, -72, 34, 8), "X", &"marble", ROSE)
	gal.notes = "Masked portraits of the court's past; tall windows onto the gardens."
	var gal_rows: Array = [
		[&"chaise_longue", 11, 4], [&"chaise_longue", 23, 4], [&"statue_maiden", 1.2, 4], [&"vase_tall", 32.8, 6.8],
	]
	for x in [3.0, 10.0, 14.0, 18.0, 22.0, 26.0]:
		gal_rows.append([&"portrait_masked", x, 7.85, 180, 1.4])
	for x in [5.0, 13.0, 21.0, 29.0]:
		gal_rows.append([&"rug_runner", x, 4, 90])
	for x in [6.0, 17.0, 28.0]:
		gal_rows.append([&"chandelier_crystal", x, 4, 0, 2.6])
	for x in [8.5, 16.5, 25.0]:
		gal_rows.append([&"bust_pedestal", x, 1.0])
	_p(gal, gal_rows)

	var g1 := dsl.room(&"guest_suite_periwinkle", "Periwinkle Guest Suite", 1, Rect2(-42, -64, 12, 12), "X", &"wood", PERI)
	_p(g1, [
		[&"bed_canopy", 1.5, 6, 90], [&"nightstand", 0.4, 3.8, 90], [&"nightstand", 0.4, 8.2, 90],
		[&"vase_roses", 0.4, 3.8, 0, 0.7], [&"wardrobe_tall", 11.6, 3, -90], [&"dresser", 11.6, 9, -90],
		[&"armchair", 8, 9.5, -150], [&"table_side", 9, 10.6], [&"rug_large", 6, 6, 90],
		[&"chandelier_small", 6, 6, 0, 3.3], [&"washstand", 2, 11.6, 180], [&"dressing_screen", 10, 0.8],
		[&"painting_medium", 0.15, 10, 90, 1.5], [&"fireplace_small", 11.7, 6, -90],
	])

	var cab := dsl.room(&"lucien_cabinet", "Lucien's Hidden Cabinet", 1, Rect2(-30, -64, 6, 12), "X", &"wood", PEACH)
	cab.notes = "Behind a panel in Lucien's chambers: the emissary's maps, letters and fox masks."
	_p(cab, [
		[&"desk_writing", 3, 1.0], [&"inkstand", 3, 1.0, 0, 0.8], [&"chair_simple", 3, 2.2, 180],
		[&"map_wall", 0.1, 6, 90, 1.2], [&"scroll_rack", 5.6, 3, -90], [&"chest_trunk", 1.0, 11],
		[&"weapon_rack", 5.6, 9, -90], [&"candle_bank", 0.6, 3], [&"bookcase_low", 0.4, 9, 90],
		[&"mask_display", 3, 11.85, 180, 1.4], [&"lantern_hanging", 3, 6, 0, 3.4],
	])

	var luc := dsl.room(&"lucien_chambers", "Lucien's Chambers", 1, Rect2(-24, -64, 16, 12), "C", &"wood", BUTTER)
	_p(luc, [
		[&"bed_canopy", 14.5, 6, -90], [&"nightstand", 15.6, 3.8, -90], [&"nightstand", 15.6, 8.2, -90],
		[&"candelabra", 15.6, 3.8, 0, 0.7], [&"wardrobe_tall", 4, 0.4], [&"desk_writing", 2, 10.8, 180],
		[&"inkstand", 2, 10.8, 0, 0.8], [&"bookcase_tall", 0.4, 2.5, 90], [&"armchair", 6, 6, 90],
		[&"rug_large", 8, 6, 90], [&"chandelier_small", 8, 6, 0, 3.3], [&"weapon_rack", 9, 0.4],
		[&"globe_stand", 4.5, 9.5], [&"potted_palm", 15, 11], [&"mask_display", 15.85, 10, -90, 1.4],
		[&"loose_panel", 0.1, 6, 90, 0.8],
	])

	var g2 := dsl.room(&"guest_suite_lilac", "Lilac Guest Suite", 1, Rect2(-42, -48, 16, 20), "X", &"wood", LILAC)
	_p(g2, [
		[&"bed_canopy", 1.5, 10, 90], [&"nightstand", 0.4, 7.8, 90], [&"nightstand", 0.4, 12.2, 90],
		[&"vase_roses", 0.4, 7.8, 0, 0.7], [&"wardrobe_tall", 15.6, 4, -90], [&"chaise_longue", 8, 17.5],
		[&"vanity_table", 15.6, 12, -90], [&"vanity_mirror", 15.9, 12, -90, 0.9], [&"pouf_stool", 14.6, 12],
		[&"cheval_mirror", 15.2, 16.5, -90], [&"rug_large", 7, 10, 90], [&"chandelier_crystal", 8, 10, 0, 2.6],
		[&"fireplace_small", 3, 0.4], [&"armchair", 2, 2.6, 160], [&"armchair", 4.5, 2.6, -160],
		[&"table_tea", 3.2, 3.2], [&"potted_roses", 15, 19], [&"painting_large", 0.15, 16, 90, 1.2],
	])

	var sew := dsl.room(&"sewing_room", "Sewing & Needlework Room", 1, Rect2(-26, -48, 18, 10), "X", &"wood", MINT)
	_p(sew, [
		[&"table_work", 9, 5], [&"spinning_wheel", 2, 2], [&"embroidery_frame", 4, 7.5],
		[&"mannequin_gown", 15, 2], [&"mannequin_gown", 16.6, 4], [&"ironing_table", 14, 8.6],
		[&"chair_simple", 8, 6.2, 180], [&"chair_simple", 10, 6.2, 180], [&"chair_simple", 3.4, 8.4],
		[&"linen_press", 0.4, 6, 90], [&"chest_trunk", 6, 0.5], [&"bookcase_low", 12, 0.3],
		[&"chandelier_small", 9, 5, 0, 3.3], [&"candelabra", 9, 4.6, 0, 0.9], [&"faelight_orb", 4, 7.5, 0, 2.3],
		[&"rug_large", 9, 5, 90, 0.0, 0.8], [&"hat_stand", 17.4, 8.8],
	])

	var par := dsl.room(&"rose_parlour", "Rose Parlour", 1, Rect2(-26, -38, 18, 10), "X", &"carpet", ROSE)
	_p(par, [
		[&"sofa", 7, 6.5, 180], [&"armchair", 4, 4, 90], [&"armchair", 10, 4, -90], [&"table_tea", 7, 4.5],
		[&"cake_stand", 7, 4.5, 0, 0.5], [&"harp_gilt", 15.5, 2], [&"birdcage_gilt", 16.8, 8.6],
		[&"vase_roses", 12.5, 0.4, 0, 0.0], [&"rug_round", 7, 5], [&"chandelier_crystal", 8, 5, 0, 2.6],
		[&"cabinet_curio", 10, 0.3], [&"potted_roses", 1, 9], [&"painting_medium", 7, 0.15, 0, 1.6],
	])


# --- Level 1: west wing ------------------------------------------------------

func _level_1_west_wing() -> void:
	var wh := dsl.room(&"west_wing_hall", "West Wing Hall", 1, Rect2(-58, -54, 16, 8), "X", &"marble", PEARL)
	_p(wh, [
		[&"rug_runner", 8, 4, 90], [&"chandelier_small", 4, 4, 0, 3.3], [&"chandelier_small", 12, 4, 0, 3.3],
		[&"bust_pedestal", 2, 0.8], [&"bust_pedestal", 14, 0.8], [&"painting_large", 3, 7.85, 180, 1.2],
		[&"painting_large", 13, 7.85, 180, 1.2], [&"urn_flowers", 1, 7], [&"urn_flowers", 15, 7],
		[&"clock_grandfather", 11, 0.4], [&"table_side", 5, 0.5],
	])

	var nur := dsl.room(&"old_nursery", "Old Nursery", 1, Rect2(-58, -68, 16, 14), "X", &"carpet", BUTTER)
	nur.notes = "Dust sheets and a rocking horse: a court that has had no children for a long time."
	_p(nur, [
		[&"cradle_chest", 8, 7], [&"bed_single", 1, 3], [&"bed_single", 15, 3], [&"rocking_horse", 4, 9],
		[&"dollhouse", 13, 12.8, 180], [&"chest_trunk", 2, 12.8], [&"rug_round", 8, 7],
		[&"chandelier_small", 8, 7, 0, 3.3], [&"window_seat", 8, 0.5], [&"bookcase_low", 15.6, 8, -90],
		[&"table_round", 11, 9], [&"chair_simple", 10, 9.8, 160], [&"chair_simple", 12, 9.8, -160],
		[&"cake_stand", 11, 9, 0, 0.75, 0.6], [&"cushion_pile", 5, 1.2],
	])

	var pf := dsl.room(&"pressed_flower_study", "Pressed-Flower Study", 1, Rect2(-74, -68, 16, 14), "X", &"wood", MINT)
	_p(pf, [
		[&"table_work", 8, 7], [&"drying_rack_herbs", 0.6, 4, 90], [&"herb_bundle_hanging", 6, 4, 0, 3.2],
		[&"herb_bundle_hanging", 10, 4, 0, 3.2], [&"cabinet_curio", 0.4, 10, 90], [&"cabinet_curio", 3, 13.6, 180],
		[&"desk_writing", 12, 12.8, 180], [&"inkstand", 12, 12.8, 0, 0.8], [&"potted_roses", 1, 1],
		[&"potted_roses", 15, 1], [&"fern_pot", 15, 10], [&"window_seat", 8, 0.5], [&"chandelier_small", 8, 7, 0, 3.3],
		[&"book_stack", 8, 7, 0, 0.9], [&"armchair", 13, 9, -120], [&"vial_rack", 7, 13.6, 180],
	])

	var gw := dsl.room(&"guest_suite_wisteria", "Wisteria Guest Suite", 1, Rect2(-74, -54, 16, 20), "X", &"wood", LILAC)
	_p(gw, [
		[&"bed_canopy", 1.5, 10, 90], [&"nightstand", 0.4, 7.8, 90], [&"nightstand", 0.4, 12.2, 90],
		[&"candelabra", 0.4, 12.2, 0, 0.7], [&"wardrobe_tall", 8, 0.4], [&"dresser", 12, 19.6, 180],
		[&"chaise_longue", 8, 15], [&"rug_large", 7, 10, 90], [&"chandelier_crystal", 8, 10, 0, 2.6],
		[&"fireplace_small", 15.7, 15, -90], [&"vanity_table", 3, 19.6, 180], [&"pouf_stool", 3, 18.6],
		[&"potted_roses", 15, 1], [&"washstand", 4, 0.4], [&"dressing_screen", 13, 1], [&"painting_medium", 0.15, 16, 90, 1.5],
	])

	var ms := dsl.room(&"wisteria_salon", "Wisteria Music Salon", 1, Rect2(-58, -46, 16, 12), "X", &"marble", PERI)
	_p(ms, [
		[&"harp_gilt", 3, 3], [&"lute_on_stand", 5, 1.5], [&"music_stand", 4, 5], [&"music_stand", 6, 4],
		[&"sofa", 10, 10.8, 180], [&"armchair", 13.5, 7, -90], [&"armchair", 7, 7, 90], [&"table_tea", 10, 7.5],
		[&"rug_round", 10, 7.5], [&"chandelier_crystal", 8, 6, 0, 2.6], [&"potted_palm", 1, 11],
		[&"potted_palm", 15, 1], [&"birdcage_gilt", 15, 11], [&"vase_roses", 10, 7.5, 0, 0.5],
	])


# --- Level 2: attic ----------------------------------------------------------

func _level_2_attic() -> void:
	var lh := dsl.room(&"attic_long_hall", "Attic Long Hall", 2, Rect2(-32, -54, 64, 8), "X", &"wood", BUTTER, 0.0, &"corridor")
	var lh_rows: Array = [
		[&"chest_trunk", 4, 7.4, 180], [&"chest_trunk", 30, 0.6], [&"chest_trunk", 58, 7.4, 180],
		[&"crate", 16, 0.7], [&"crate", 52, 0.7], [&"coat_rack", 63, 7], [&"painting_small", 40, 7.85, 180, 1.5],
		[&"painting_small", 8, 0.15, 0, 1.5],
	]
	for x in [4.0, 15.0, 26.0, 37.0, 48.0, 59.0]:
		lh_rows.append([&"rug_runner", x, 4, 90])
	for x in [8.0, 24.0, 40.0, 56.0]:
		lh_rows.append([&"lantern_hanging", x, 4, 0, 3.4])
	_p(lh, lh_rows)

	# Stair well over the attic stair (hole local x 2..6, z 1..8; arrives south into the long hall).
	var well := dsl.room(&"attic_stair_well", "Attic Stair Well", 2, Rect2(8, -62, 8, 8), "X", &"wood", PERI, 0.0, &"stair_hall")
	_p(well, [
		[&"balustrade", 1.6, 4.5, 90], [&"balustrade", 6.4, 4.5, 90], [&"balustrade", 4, 0.6],
		[&"lantern_hanging", 4, 4.5, 0, 3.4], [&"chest_trunk", 7.2, 3, -90], [&"crate", 0.8, 6.8],
		[&"fern_pot", 7.3, 7.2],
	])

	var trunks := dsl.room(&"attic_trunk_room", "Attic Trunk Room", 2, Rect2(-32, -72, 20, 18), "X", &"wood", PEACH)
	trunks.notes = "Attic storeroom: travel trunks, old gowns and coats."
	_p(trunks, [
		[&"chest_trunk", 2, 2], [&"chest_trunk", 2, 5], [&"chest_trunk", 5, 2, 90], [&"chest_trunk", 18, 14],
		[&"chest_trunk", 18, 10, 90], [&"crate", 9, 1], [&"crate", 10.5, 1], [&"crate", 9.7, 1, 0, 0.8],
		[&"barrel", 15, 1], [&"wardrobe_tall", 19.6, 4, -90], [&"wardrobe_tall", 0.4, 12, 90],
		[&"hat_stand", 6, 9], [&"coat_rack", 7, 10], [&"mannequin_gown", 12, 8], [&"cheval_mirror", 13.5, 9, -30],
		[&"lantern_hanging", 6, 6, 0, 3.4], [&"lantern_hanging", 14, 12, 0, 3.4], [&"rug_large", 10, 9],
	])

	var loft := dsl.room(&"attic_painting_loft", "Covered-Painting Loft", 2, Rect2(-12, -72, 20, 18), "X", &"wood", LILAC)
	loft.notes = "Attic storeroom: dust-sheeted paintings and statues waiting for the gallery to reopen."
	_p(loft, [
		[&"canvas_stack", 1, 2, 90], [&"canvas_stack", 1, 6, 90], [&"canvas_stack", 19, 2, -90], [&"canvas_stack", 19, 8, -90],
		[&"painting_large", 6, 0.6, 10], [&"painting_large", 13, 0.6, -10], [&"portrait_masked", 3, 16.6, 170],
		[&"portrait_masked", 17, 16.6, -170], [&"easel", 9, 9], [&"easel", 11, 10, 30], [&"bust_pedestal", 6, 12],
		[&"statue_maiden", 15, 12], [&"crate", 4, 9], [&"crate", 16, 5], [&"lantern_hanging", 6, 8, 0, 3.4],
		[&"lantern_hanging", 14, 8, 0, 3.4], [&"chest_trunk", 10, 16.8],
	])

	var linen := dsl.room(&"attic_costume_store", "Linen & Costume Store", 2, Rect2(16, -72, 16, 18), "X", &"wood", BLUSH)
	linen.notes = "Old Calanmai and Solstice masks and costumes. A loose board hides the lever to the Moon Tower stair."
	_p(linen, [
		[&"linen_press", 0.4, 3, 90], [&"linen_press", 0.4, 7, 90], [&"linen_press", 0.4, 11, 90],
		[&"wardrobe_tall", 6, 0.4], [&"wardrobe_tall", 10, 0.4], [&"mask_display", 15.85, 10, -90, 1.4],
		[&"mask_display", 15.85, 14, -90, 1.4], [&"mannequin_gown", 6, 8], [&"mannequin_gown", 9, 8],
		[&"chest_trunk", 12, 16.8], [&"chest_trunk", 3, 16.8], [&"drying_line", 8, 12, 90],
		[&"ironing_table", 12, 11], [&"hat_stand", 14.5, 2], [&"lantern_hanging", 8, 8, 0, 3.4],
		[&"loose_panel", 15.9, 6, -90, 0.6],
	])

	var herb := dsl.room(&"attic_herb_loft", "Herb-Drying Loft", 2, Rect2(-32, -46, 22, 18), "X", &"wood", SAGE)
	var herb_rows: Array = [
		[&"drying_rack_herbs", 0.6, 5, 90], [&"drying_rack_herbs", 0.6, 11, 90], [&"drying_rack_herbs", 21.4, 8, -90],
		[&"drying_line", 8, 6, 90], [&"drying_line", 14, 6, 90], [&"table_work", 11, 12],
		[&"basket_produce", 10, 13.6], [&"basket_produce", 12.5, 10.6], [&"stool", 11, 10.4], [&"barrel", 20, 16.6],
		[&"vial_rack", 6, 17.6, 180], [&"lantern_hanging", 6, 12, 0, 3.4], [&"lantern_hanging", 16, 12, 0, 3.4],
	]
	for x in [4.0, 7.0, 10.0, 13.0, 16.0, 19.0]:
		herb_rows.append([&"herb_bundle_hanging", x, 3.5, 0, 3.2])
	_p(herb, herb_rows)

	var play := dsl.room(&"attic_playroom", "Forgotten Playroom", 2, Rect2(-10, -46, 20, 18), "X", &"carpet", ROSE)
	play.notes = "A secret-feeling attic playroom: dollhouse, rocking horse, a doll's tea party under the eaves."
	_p(play, [
		[&"rocking_horse", 4, 6], [&"dollhouse", 16, 4], [&"chest_trunk", 1.2, 12, 90], [&"cushion_pile", 6, 14],
		[&"cushion_pile", 8, 15], [&"table_round", 12, 12], [&"chair_simple", 11, 13, 160], [&"chair_simple", 13, 13, -160],
		[&"cake_stand", 12, 12, 0, 0.75, 0.6], [&"birdcage_gilt", 18.8, 9], [&"bookcase_low", 0.4, 6, 90],
		[&"rug_round", 10, 10], [&"window_seat", 10, 17.5, 180], [&"lantern_hanging", 10, 9, 0, 3.4],
		[&"faelight_orb", 16, 4, 0, 2.2],
	])

	var loom := dsl.room(&"attic_weaving_loft", "Weaving Loft", 2, Rect2(10, -46, 22, 18), "X", &"wood", PERI)
	_p(loom, [
		[&"loom_upright", 4, 3], [&"loom_upright", 10, 3], [&"spinning_wheel", 16, 4], [&"chest_trunk", 20.8, 10, -90],
		[&"chest_trunk", 20.8, 14, -90], [&"basket_produce", 15, 7], [&"basket_produce", 6, 7], [&"bench_settle", 7, 6],
		[&"table_work", 11, 12], [&"tapestry_roses", 11, 17.85, 180, 1.0], [&"stool", 11, 10.6],
		[&"lantern_hanging", 6, 9, 0, 3.4], [&"lantern_hanging", 16, 9, 0, 3.4], [&"rug_large", 11, 12],
	])

	var wg := dsl.room(&"attic_west_gable", "West Gable Storeroom", 2, Rect2(-42, -62, 10, 24), "X", &"wood", PEARL)
	_p(wg, [
		[&"chest_trunk", 1, 3, 90], [&"chest_trunk", 1, 6, 90], [&"chest_trunk", 9, 18, -90], [&"crate", 1, 15],
		[&"crate", 1, 16.4], [&"crate", 8.6, 3], [&"wardrobe_tall", 0.4, 10, 90], [&"dressing_screen", 8, 21, 70],
		[&"mirror_gilt", 9.6, 7, -90, 0.0], [&"canvas_stack", 9.4, 15, -90], [&"armchair", 5, 18, 30],
		[&"lantern_hanging", 5, 6, 0, 3.4], [&"lantern_hanging", 5, 18, 0, 3.4],
	])

	var eg := dsl.room(&"attic_schoolroom", "Old Schoolroom", 2, Rect2(32, -62, 10, 24), "X", &"wood", MINT)
	_p(eg, [
		[&"desk_writing", 3, 7], [&"desk_writing", 7, 7], [&"desk_writing", 3, 11], [&"desk_writing", 7, 11],
		[&"chair_simple", 3, 8], [&"chair_simple", 7, 8], [&"desk_large", 5, 3, 180], [&"globe_stand", 1, 17],
		[&"bookcase_tall", 9.6, 16, -90], [&"map_wall", 5, 0.1, 0, 1.2], [&"lantern_hanging", 5, 9, 0, 3.4],
		[&"lantern_hanging", 5, 18, 0, 3.4], [&"chest_trunk", 1.2, 21],
	])

	# Corner tower bases (stairs up to level 3).
	var nw := dsl.room(&"observatory_stair", "Observatory Tower Stair", 2, Rect2(-42, -72, 10, 10), "X", &"wood", PERI)
	_p(nw, [[&"chest_trunk", 7, 1, 0], [&"crate", 8.6, 3], [&"globe_stand", 7, 5], [&"bookcase_low", 9.6, 7, -90],
			[&"lantern_hanging", 7, 5, 0, 3.4], [&"candle_sconce", 9.85, 2, -90, 1.9], [&"rug_round", 7, 6, 0, 0.0, 0.6]])
	var ne := dsl.room(&"rose_tower_stair", "Rose Tower Stair", 2, Rect2(32, -72, 10, 10), "X", &"wood", ROSE)
	_p(ne, [[&"potted_roses", 1, 1], [&"potted_roses", 5, 1], [&"chest_trunk", 1.2, 8, 90], [&"vase_roses", 3, 4],
			[&"lantern_hanging", 3, 5, 0, 3.4], [&"candle_sconce", 0.15, 4, 90, 1.9], [&"cushion_pile", 3, 6]])
	var sw := dsl.room(&"lantern_tower_stair", "Lantern Tower Stair", 2, Rect2(-42, -38, 10, 10), "X", &"wood", BUTTER)
	_p(sw, [[&"lantern_hanging", 7, 5, 0, 3.4], [&"lantern_hanging", 7, 8, 0, 2.6], [&"chest_trunk", 7, 9.2],
			[&"crate", 9, 6], [&"coat_rack", 9, 1], [&"candle_sconce", 9.85, 4, -90, 1.9], [&"fern_pot", 5, 9]])
	var se := dsl.room(&"moon_tower_hidden", "Hidden Moon-Tower Room", 2, Rect2(32, -38, 10, 10), "X", &"carpet", LILAC)
	se.notes = "The attic secret room: behind a panel in the Old Schoolroom, opened by a lever in the Linen & Costume Store."
	_p(se, [[&"cushion_pile", 2, 2], [&"cushion_pile", 3, 4], [&"candle_bank", 1, 8], [&"chest_trunk", 3, 9.2],
			[&"rug_round", 3, 5, 0, 0.0, 0.7], [&"faelight_orb", 3, 5, 0, 2.6], [&"painting_small", 0.15, 5, 90, 1.5],
			[&"bookcase_low", 0.4, 7, 90]])


# --- Level 3: tower tops -----------------------------------------------------

func _level_3_towers() -> void:
	# Holes: west towers local x 1..4; east towers local x 6.5..9.5; z 1.5..8.5.
	var obs := dsl.room(&"observatory", "Star Observatory", 3, Rect2(-42, -72, 10, 10), "X", &"wood", PERI)
	obs.notes = "Under the gold dome: a brass telescope and star charts."
	_p(obs, [
		[&"telescope_brass", 7, 3, 30], [&"globe_stand", 8.5, 7.5], [&"map_table", 7, 5.5, 90, 0.0, 0.7],
		[&"map_wall", 5, 9.85, 180, 1.2], [&"armchair", 5.5, 8.5, 180], [&"bookcase_low", 9.6, 1.2, -90],
		[&"desk_writing", 2.5, 0.6], [&"inkstand", 2.5, 0.6, 0, 0.8], [&"faelight_orb", 5, 2, 0, 3.0],
		[&"faelight_orb", 8, 8, 0, 3.2], [&"faelight_orb", 3, 9, 0, 3.4], [&"rug_round", 7, 5, 0, 0.0, 0.8],
	])
	var bower := dsl.room(&"rose_bower", "Rose-Tower Bower", 3, Rect2(32, -72, 10, 10), "X", &"carpet", BLUSH)
	bower.notes = "A flower-filled lookout: climbing roses inside the tower and a view over the whole court."
	_p(bower, [
		[&"rose_arbor", 3, 0.8], [&"potted_roses", 0.8, 0.8], [&"potted_roses", 5.2, 0.8], [&"potted_roses", 0.8, 9.2],
		[&"potted_roses", 5.2, 9.2], [&"chaise_longue", 2.5, 5, 90], [&"cushion_pile", 4, 7.5], [&"cushion_pile", 4.2, 3],
		[&"vase_roses", 2.5, 8], [&"flower_garland", 3, 0.2, 0, 3.0], [&"table_tea", 4.5, 5], [&"birdcage_gilt", 1, 7],
		[&"faelight_orb", 3, 5, 0, 3.0],
	])
	var lant := dsl.room(&"lantern_lookout", "Lantern Tower Lookout", 3, Rect2(-42, -38, 10, 10), "X", &"wood", BUTTER)
	_p(lant, [
		[&"window_seat", 7, 9.5, 180], [&"window_seat", 9.5, 5, -90], [&"lantern_hanging", 6, 3, 0, 3.4],
		[&"lantern_hanging", 8, 6, 0, 3.4], [&"lantern_hanging", 6, 8, 0, 3.0], [&"armchair", 6.5, 5, 90],
		[&"table_side", 7.5, 3.5], [&"map_wall", 6, 0.1, 0, 1.2], [&"chest_trunk", 8.6, 1], [&"rug_round", 7, 6, 0, 0.0, 0.6],
		[&"fern_pot", 5, 9.3],
	])
	var moon := dsl.room(&"moon_tower", "Moon Tower Hideaway", 3, Rect2(32, -38, 10, 10), "X", &"carpet", LILAC)
	moon.notes = "Reached only through the hidden tower room: moonlit cushions and a forgotten portrait."
	_p(moon, [
		[&"cushion_pile", 2, 2], [&"cushion_pile", 3.5, 3], [&"chaise_longue", 2.5, 6, 90], [&"window_seat", 3, 9.5, 180],
		[&"portrait_masked", 0.15, 5, 90, 1.4], [&"candle_bank", 5, 0.6], [&"bookcase_low", 0.4, 8.5, 90],
		[&"desk_writing", 3, 0.6], [&"faelight_orb", 2, 5, 0, 3.0], [&"faelight_orb", 4, 8, 0, 2.6],
		[&"rug_round", 3, 5, 0, 0.0, 0.7], [&"harp_gilt", 5, 8.8],
	])


# --- Doors, stairs, stations, secrets, roofs ----------------------------------

func _roofs() -> void:
	_doors_and_stairs()
	_stations_and_secrets()
	# Main block: central gable (ridge east-west), gable ends between the towers.
	dsl.roof(Rect2(-32, -72, 64, 44), 2, &"gable_x", 8.0, SLATE)
	dsl.roof(Rect2(-42, -62, 10, 24), 2, &"gable_z", 5.0, SLATE)
	dsl.roof(Rect2(32, -62, 10, 24), 2, &"gable_z", 5.0, SLATE)
	# West wing (two storeys): hip roof.
	dsl.roof(ManorSitePlan.HOUSE_WEST, 1, &"hip", 7.0, SLATE)
	# Corner towers: observatory dome (gold-pearl), three lilac cones; gold finials on all.
	dsl.roof(Rect2(-42, -72, 10, 10), 3, &"dome", 5.5, Color(1.0, 0.88, 0.62))
	for t in [Rect2(32, -72, 10, 10), Rect2(-42, -38, 10, 10), Rect2(32, -38, 10, 10)]:
		dsl.roof(t, 3, &"cone", 11.0, SLATE)
	for c in [Vector2(-37, -67), Vector2(37, -67), Vector2(-37, -33), Vector2(37, -33)]:
		var h := 8.5 if c == Vector2(-37, -67) else 13.5
		dsl.roof(Rect2(c.x - 0.5, c.y - 0.5, 1.0, 1.0), 3, &"cone", h, GOLD)


func _doors_and_stairs() -> void:
	# Level 1, fixed connection points.
	dsl.door(1, Vector2(42, -50), &"door", 2.0)       # to the service wing
	dsl.door(1, Vector2(-42, -50), &"open", 2.4)      # to the west wing
	# Level 1, main block.
	dsl.door(1, Vector2(0, -62), &"open", 3.0)        # upper hall -> loggia
	dsl.door(1, Vector2(0, -38), &"open", 2.4)        # upper hall -> reading nook
	dsl.door(1, Vector2(-8, -50), &"open", 2.4)
	dsl.door(1, Vector2(8, -50), &"open", 2.4)
	dsl.door(1, Vector2(-8, -68), &"open", 2.0)       # loggia -> portrait gallery
	dsl.door(1, Vector2(8, -67))                      # loggia -> morning room
	dsl.door(1, Vector2(16, -67))                     # morning room -> bedroom
	dsl.door(1, Vector2(15, -62))                     # morning room -> attic stair hall
	dsl.door(1, Vector2(15, -52))                     # attic stair hall -> corridor
	dsl.door(1, Vector2(23, -52))                     # Feyre's bedroom (she locks it, ch7)
	dsl.door(1, Vector2(30, -66))                     # bedroom -> dressing room
	dsl.door(1, Vector2(30, -56))                     # bedroom -> bath
	dsl.secret_door(1, Vector2(39, -60), &"jewel_closet", &"mirror")
	dsl.door(1, Vector2(16, -48))                     # painting room
	dsl.door(1, Vector2(33, -48))                     # Tamlin's bedchamber
	dsl.door(1, Vector2(33, -36))                     # Tamlin's bath
	dsl.door(1, Vector2(8, -33))                      # painting room -> reading nook
	dsl.door(1, Vector2(-8, -33))                     # reading nook -> rose parlour
	dsl.door(1, Vector2(-17, -38))                    # rose parlour -> sewing room
	dsl.door(1, Vector2(-17, -48))                    # sewing room -> corridor
	dsl.door(1, Vector2(-34, -48))                    # lilac guest suite
	dsl.door(1, Vector2(-36, -52))                    # periwinkle guest suite
	dsl.door(1, Vector2(-16, -52))                    # Lucien's chambers
	dsl.door(1, Vector2(-12, -64))                    # Lucien -> gallery
	dsl.door(1, Vector2(-36, -64))                    # periwinkle suite -> gallery
	dsl.secret_door(1, Vector2(-24, -58), &"lucien_cabinet", &"panel")
	# Level 1, west wing.
	dsl.door(1, Vector2(-50, -54))                    # hall -> nursery
	dsl.door(1, Vector2(-58, -61))                    # nursery -> pressed-flower study
	dsl.door(1, Vector2(-58, -50))                    # hall -> wisteria suite
	dsl.door(1, Vector2(-50, -46), &"open", 2.4)      # hall -> music salon
	# Level 2.
	dsl.door(2, Vector2(12, -54), &"open", 4.2)       # stair well -> long hall (stair arrives here)
	dsl.door(2, Vector2(-22, -54))
	dsl.door(2, Vector2(-2, -54))
	dsl.door(2, Vector2(24, -54))
	dsl.door(2, Vector2(-21, -46))
	dsl.door(2, Vector2(0, -46))
	dsl.door(2, Vector2(21, -46))
	dsl.door(2, Vector2(-32, -50))
	dsl.door(2, Vector2(32, -50))
	dsl.door(2, Vector2(-37, -62))
	dsl.door(2, Vector2(-32, -67))
	dsl.door(2, Vector2(-37, -38))
	dsl.door(2, Vector2(37, -62))
	dsl.door(2, Vector2(32, -67))
	dsl.secret_door(2, Vector2(37, -38), &"moon_tower", &"panel")
	# Stairs.
	dsl.stair(&"attic", 1, Rect2(10, -61, 4, 7), &"south", &"service")
	dsl.stair(&"tower_nw", 2, Rect2(-41, -70.5, 3, 7), &"north", &"spiral_tower")
	dsl.stair(&"tower_ne", 2, Rect2(38.5, -70.5, 3, 7), &"north", &"spiral_tower")
	dsl.stair(&"tower_sw", 2, Rect2(-41, -36.5, 3, 7), &"south", &"spiral_tower")
	dsl.stair(&"tower_se", 2, Rect2(38.5, -36.5, 3, 7), &"south", &"spiral_tower")


func _stations_and_secrets() -> void:
	dsl.station(&"bed", "Feyre's Canopy Bed", 1, Vector3(17.6, 0, -60), &"bed_canopy", 90, "C")
	dsl.station(&"bath", "Scented Bath", 1, Vector3(32.4, 0, -57.8), &"bathtub_clawfoot", 90, "C")
	dsl.station(&"wardrobe", "Feyre's Wardrobe", 1, Vector3(32.2, 0, -71.4), &"wardrobe_tall", 0, "C?")
	dsl.station(&"dressing_mirror", "Vanity Mirror", 1, Vector3(41.85, 0.9, -66), &"vanity_mirror", -90, "X")
	dsl.station(&"easel", "Feyre's Easel", 1, Vector3(16, 0, -32.5), &"easel", 180, "C")
	dsl.station(&"hearth", "Bedroom Hearth", 1, Vector3(29.6, 0, -61), &"fireplace_small", -90, "X")
	dsl.station(&"hearth", "Tamlin's Hearth", 1, Vector3(41.5, 0, -42), &"fireplace_grand", -90, "X")
	dsl.station(&"hearth", "Rose Parlour Hearth", 1, Vector3(-25.6, 0, -33), &"fireplace_small", 90, "X")

	# Mirror door: a catch in the vanity's jewellery drawer.
	dsl.secret(&"jewel_closet", &"lever", 1, Vector3(41.6, 0.85, -64.6), &"", &"secret_lever",
			"Catch inside the vanity's jewellery drawer; the cheval-style mirror panel swings open.")
	# Lucien's panel: the loose panel beside his bookcase.
	dsl.secret(&"lucien_cabinet", &"lever", 1, Vector3(-23.8, 0.8, -56.5), &"", &"loose_panel",
			"A loose panel by the wainscot opens into his hidden cabinet.")
	# Attic lever opens the Moon Tower stair.
	dsl.secret(&"moon_tower", &"lever", 2, Vector3(31.6, 0.6, -64.5), &"", &"secret_lever",
			"Under a loose board in the costume store; opens the panel in the Old Schoolroom.")
	# Keepsakes.
	dsl.secret(&"pressed_violet", &"keepsake", 1, Vector3(20, 0.65, -71.4), &"col_pressed_violet", &"",
			"Tucked under the window-seat cushion in Feyre's bedroom.")
	dsl.secret(&"pearl_hairpin", &"keepsake", 1, Vector3(39, 0.75, -53.5), &"col_pearl_hairpin", &"",
			"In the hidden jewellery closet.")
	dsl.secret(&"fox_charm", &"keepsake", 1, Vector3(-27, 0.8, -63), &"col_fox_mask_charm", &"",
			"On Lucien's hidden desk.")
	dsl.secret(&"silver_thimble", &"keepsake", 1, Vector3(-25.5, 0.1, -47.5), &"col_silver_thimble", &"",
			"Rolled under the linen press in the sewing room.")
	dsl.secret(&"painted_pebble", &"keepsake", 2, Vector3(-8.8, 0.7, -34), &"col_painted_pebble", &"",
			"In the playroom toy chest.")
	dsl.secret(&"moonstone", &"keepsake", 3, Vector3(34, 0.1, -35), &"col_moonstone_ring", &"",
			"Among the cushions of the Moon Tower hideaway.")
	dsl.secret(&"rose_bower_view", &"discovery", 3, Vector3(37, 1.0, -67), &"", &"",
			"Discovering the bower raises a flag (view over the whole court).")
