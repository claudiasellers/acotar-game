## What dresses the manor's rooms: the small things dealt onto surfaces, the
## floor accents and the wall pieces, by room style, plus where each surface
## prop's top is. Decks are dealt without replacement (ManorFurnisher), so a
## detail never repeats inside a room; every deck is long enough that rooms of
## one style still come out different.
class_name ManorDecorDecks
extends RefCounted

## Small things that sit on a surface, by style.
const DETAIL := {
	&"hall": [&"vase_hydrangea_blue", &"vase_hydrangea_pink", &"urn_hydrangea_white", &"vase_lilies", &"vase_peonies",
		&"mantel_clock_gilt", &"candlestick_brass", &"candlestick_crystal", &"hurricane_lamp", &"letter_rack",
		&"figurine_deer", &"bowl_floating_blossoms", &"songbird_cage_small", &"vase_irises", &"trinket_box_enamel",
		&"potpourri_bowl", &"book_pile_ribbon", &"fruit_bowl", &"vase_roses", &"music_box", &"candle_cluster",
		&"mantel_clock_porcelain", &"bonbon_dish", &"shell_dish", &"posy_teacup", &"vase_tulips", &"figurine_swan",
		&"jug_daffodils", &"terrarium_bell", &"books_upright_bookends", &"globe_table", &"hourglass", &"fan_lace",
		&"butterfly_dome", &"petal_bowl", &"decanter_set", &"teacup_set", &"sheet_music", &"apples_bowl", &"tea_service_silver", &"playing_cards"],
	&"parlour": [&"vase_peonies", &"vase_tulips", &"mantel_clock_porcelain", &"candlestick_crystal", &"figurine_swan",
		&"bonbon_dish", &"book_pile_ribbon", &"trinket_box_enamel", &"fan_lace", &"music_box", &"teacup_set",
		&"tea_service_silver", &"decanter_set", &"fruit_bowl", &"potpourri_bowl", &"terrarium_bell", &"songbird_cage_small",
		&"shell_dish", &"playing_cards", &"chess_set", &"cake_stand", &"macaron_tower", &"butterfly_dome", &"petal_bowl",
		&"posy_teacup", &"vase_roses", &"hurricane_lamp", &"bowl_floating_blossoms", &"vase_lilies", &"figurine_deer"],
	&"library": [&"book_open", &"book_pile_ribbon", &"books_upright_bookends", &"globe_table", &"hourglass", &"astrolabe",
		&"magnifier_glass", &"map_rolls", &"letter_rack", &"inkstand", &"candlestick_brass", &"candle_cluster",
		&"hurricane_lamp", &"book_stack", &"candelabra", &"terrarium_bell", &"vase_irises", &"decanter_set", &"chess_set",
		&"posy_teacup", &"candlestick_crystal", &"mantel_clock_gilt", &"trinket_box_enamel", &"quill_and_parchment",
		&"sheet_music", &"potpourri_bowl", &"vase_tulips", &"songbird_cage_small", &"shell_dish", &"teacup_set",
		&"tea_service_silver", &"apples_bowl", &"figurine_deer", &"book_pile_ribbon", &"bonbon_dish",
		&"vase_roses", &"vase_peonies", &"fruit_bowl", &"mantel_clock_porcelain", &"playing_cards", &"figurine_swan", &"music_box", &"jug_daffodils", &"brass_scales", &"fan_lace", &"butterfly_dome", &"star_lamp"],
	&"study": [&"quill_and_parchment", &"letter_rack", &"map_rolls", &"hourglass", &"decanter_set", &"candlestick_brass",
		&"book_open", &"globe_table", &"magnifier_glass", &"inkstand", &"astrolabe", &"candle_cluster", &"book_stack",
		&"books_upright_bookends", &"chess_set", &"hurricane_lamp", &"apples_bowl", &"vase_irises", &"figurine_deer",
		&"candlestick_crystal", &"mantel_clock_gilt", &"trinket_box_enamel", &"tea_service_silver", &"sheet_music",
		&"brass_scales", &"playing_cards", &"teacup_set", &"book_pile_ribbon", &"fruit_bowl", &"terrarium_bell",
		&"shell_dish", &"songbird_cage_small"],
	&"bedroom": [&"hand_mirror_brush", &"jewelry_box", &"perfume_tray", &"perfume_bottles_tall", &"trinket_box_enamel",
		&"shell_dish", &"fan_lace", &"book_open", &"book_pile_ribbon", &"candlestick_crystal", &"hurricane_lamp",
		&"music_box", &"posy_teacup", &"potpourri_bowl", &"star_lamp", &"jewelry_tree", &"figurine_swan", &"bonbon_dish",
		&"mantel_clock_porcelain", &"vase_peonies", &"vase_tulips", &"bowl_floating_blossoms", &"sewing_basket",
		&"letter_rack", &"teacup_set", &"vase_lilies", &"butterfly_dome", &"petal_bowl",
		&"hourglass", &"terrarium_bell", &"songbird_cage_small", &"vase_roses", &"vase_irises", &"jug_daffodils", &"candle_cluster", &"makeup_palette", &"figurine_deer", &"mantel_clock_gilt"],
	&"dining": [&"fruit_bowl", &"decanter_set", &"tea_service_silver", &"candlestick_brass", &"candle_cluster",
		&"bowl_floating_blossoms", &"vase_peonies", &"cake_stand", &"macaron_tower", &"bonbon_dish", &"lemon_tarts_tray",
		&"candlestick_crystal", &"hurricane_lamp", &"vase_lilies", &"apples_bowl", &"teacup_set", &"posy_teacup",
		&"vase_tulips", &"vase_irises", &"figurine_swan", &"mantel_clock_porcelain", &"cheese_board", &"chocolate_torte",
		&"pie_lattice", &"potpourri_bowl", &"shell_dish", &"music_box", &"vase_hydrangea_blue", &"petal_bowl",
		&"butterfly_dome", &"terrarium_bell", &"songbird_cage_small", &"mantel_clock_gilt",
		&"vase_roses", &"vase_hydrangea_pink", &"urn_hydrangea_white", &"jug_daffodils", &"trinket_box_enamel", &"figurine_deer", &"fan_lace", &"playing_cards", &"honey_jars", &"jam_jars", &"hourglass", &"letter_rack"],
	&"kitchen": [&"bread_board", &"pie_lattice", &"cheese_board", &"egg_basket", &"honey_jars", &"jam_jars",
		&"copper_kettle", &"mixing_bowls", &"rolling_pin_flour", &"knife_block", &"veg_chopping_board",
		&"lemon_tarts_tray", &"chocolate_torte", &"apples_bowl", &"salt_crock", &"basket_produce", &"copper_pots",
		&"mortar_pestle", &"cake_stand", &"jug_daffodils", &"macaron_tower", &"candlestick_brass"],
	&"infirmary": [&"bandage_rolls", &"basin_and_jug", &"salve_jars", &"brass_scales", &"linen_stack", &"herb_bell_jars",
		&"vial_rack", &"mortar_pestle", &"candlestick_brass", &"hourglass", &"book_open", &"quill_and_parchment",
		&"posy_teacup", &"hurricane_lamp"],
	&"studio": [&"vase_white_roses", &"jug_daffodils", &"fruit_bowl", &"shell_dish", &"figurine_swan", &"book_open",
		&"hourglass", &"teacup_set", &"candlestick_brass", &"apples_bowl", &"terrarium_bell", &"bowl_floating_blossoms",
		&"posy_teacup", &"vase_irises"],
	&"service": [&"letter_rack", &"candlestick_brass", &"quill_and_parchment", &"linen_stack", &"sewing_basket",
		&"jug_daffodils", &"apples_bowl", &"playing_cards", &"teacup_set", &"salt_crock", &"bread_board", &"book_open",
		&"hourglass", &"posy_teacup", &"jam_jars", &"honey_jars", &"hurricane_lamp", &"sewing_basket", &"candle_cluster",
		&"egg_basket", &"basin_and_jug", &"potpourri_bowl", &"shell_dish", &"music_box", &"fruit_bowl", &"fan_lace"],
	&"music": [&"fiddle_and_bow", &"sheet_music", &"music_box", &"candlestick_crystal", &"vase_tulips",
		&"decanter_set", &"bonbon_dish", &"figurine_swan", &"hurricane_lamp"],
}

## Floor-standing accents, dealt into corners, beside doors and between pieces.
const FLOOR := {
	&"grand": [&"urn_flowers", &"vase_tall", &"potted_palm", &"orange_tree_tub", &"bust_pedestal", &"plant_stand_fern",
		&"candle_tree", &"floor_candlestand", &"birdcage_gilt", &"globe_stand", &"potted_roses", &"fern_pot",
		&"umbrella_stand", &"swan_planter"],
	&"cosy": [&"potted_roses", &"fern_pot", &"plant_stand_fern", &"floor_candlestand", &"log_basket", &"vase_tall",
		&"birdcage_gilt", &"hatbox_stack", &"potted_palm", &"parasol_stand"],
	&"work": [&"barrel", &"crate", &"sack_flour", &"basket_produce", &"fern_pot", &"butter_churn", &"potted_roses"],
}

## Wall pieces (hung, no collision), dealt onto bare wall spans.
const WALL := {
	&"grand": [&"wall_clock_sunburst", &"wall_mirror_oval", &"mirror_gilt", &"tapestry_roses", &"tapestry_hunt",
		&"wall_shelf_curios", &"flower_garland", &"barometer_wall"],
	&"cosy": [&"wall_mirror_oval", &"wall_shelf_curios", &"wall_shelf_books", &"barometer_wall", &"flower_garland",
		&"wall_clock_sunburst", &"mirror_gilt"],
	&"work": [&"plate_rack_wall", &"garlic_braid_wall", &"herb_bundle_hanging", &"servants_bell_board",
		&"wall_shelf_books", &"barometer_wall", &"medicine_cabinet_wall"],
}

## Ids that may repeat inside a room: sets that only make sense as several
## (chairs round a table, a wall of bookcases, beds in a dormitory), lights,
## and the painting slots L39 fills with unique works.
const MAY_REPEAT := [&"chair_dining", &"chair_simple", &"bookcase_tall", &"bookcase_low", &"library_stack",
	&"library_mezzanine", &"pew", &"bed_servant", &"barrel", &"crate", &"window_seat", &"column_marble", &"pilaster",
	&"colonnade_screen", &"candle_sconce", &"chandelier_crystal", &"chandelier_small", &"lantern_hanging",
	&"painting_large", &"painting_medium", &"painting_small", &"portrait_masked", &"rug_runner", &"stool",
	&"wine_rack", &"pantry_shelf", &"barrel_rack", &"hall_table_round", &"cheese_shelf", &"music_stand", &"cushion_pile", &"balustrade",
	&"faelight_orb", &"bench_settle", &"sack_flour", &"hay_bale", &"canvas_stack", &"balustrade", &"chair_dining"]

## Usable top of each surface: [half width, half depth, most items]. The
## height comes from the model (top_of).
const SURFACE := {
	&"table_side": [0.2, 0.2, 2], &"table_tea": [0.38, 0.22, 3], &"table_round": [0.5, 0.5, 3],
	&"table_work": [1.05, 0.42, 4], &"desk_writing": [0.68, 0.3, 3], &"desk_large": [0.98, 0.45, 4],
	&"sideboard": [0.98, 0.24, 4], &"dresser": [0.63, 0.24, 3], &"nightstand": [0.24, 0.19, 2],
	&"chest_trunk": [0.45, 0.24, 2], &"bookcase_low": [0.72, 0.18, 3], &"console_gilt": [0.68, 0.18, 3],
	&"hall_table_round": [0.42, 0.42, 2], &"commode_serpentine": [0.58, 0.22, 3], &"writing_desk_small": [0.45, 0.2, 2],
	&"library_table": [1.2, 0.5, 5], &"vanity_marble": [0.6, 0.24, 3], &"kitchen_island": [1.4, 0.6, 6],
	&"table_kitchen": [1.5, 0.5, 5], &"stillroom_bench": [1.2, 0.38, 4], &"flour_bin": [0.4, 0.25, 1],
	&"cabinet_curio": [0.55, 0.2, 2], &"drawer_chest_apothecary": [0.65, 0.2, 3], &"washstand": [0.32, 0.18, 1], &"dresser_crockery": [0.9, 0.2, 3], &"paint_table": [0.55, 0.3, 2],
	&"tea_cart": [0.45, 0.2, 2], &"window_seat": [0.85, 0.28, 2],
}

static var _tops: Dictionary = {}


## Height of a surface prop's top, read from its model: the highest vertex
## over the middle of its footprint (so rails and back boards don't count).
## Falls back to the catalogue height.
static func top_of(id: StringName) -> float:
	if _tops.has(id):
		return _tops[id]
	var size := PropLib.size_of(id)
	var top := size.y
	var meshes := PropModels.prop(id)
	if not meshes.is_empty() and meshes[0] != null:
		var m: Mesh = meshes[0]
		var best := -1.0
		for s in m.get_surface_count():
			var verts: PackedVector3Array = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				if absf(v.x) <= size.x * 0.3 and absf(v.z) <= size.z * 0.25 and v.y > best:
					best = v.y
		if best > 0.05:
			top = best
	_tops[id] = top
	return top


static func is_decor(id: StringName) -> bool:
	for table in [DETAIL, FLOOR, WALL]:
		for style in table:
			if (table[style] as Array).has(id):
				return true
	return false


## A small thing or a wall piece (never twice in a room); floor accents may pair.
static func is_small_decor(id: StringName) -> bool:
	for table in [DETAIL, WALL]:
		for style in table:
			if (table[style] as Array).has(id):
				return true
	return false
