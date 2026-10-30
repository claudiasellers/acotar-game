## Generator: the service wing (HOUSE_SERVICE = Rect2(42,-68,32,34)) on levels -1..2,
## its back stairs, roof and kitchen-yard porch.
## Run: godot --headless -s tools/manor_estate/gen_service.gd
##
## Plan (world XZ): a service passage runs east-west along z -54..-48 on levels 0..2,
## from the main-block door at (42,-50) to the kitchen-yard door at (74,-51) on level 0.
## North band z -68..-54 holds the big rooms and the back-stair core (x 62..68);
## south band z -48..-34 holds the smaller rooms. Cellars sit inside the service
## cellar zone Rect2(45,-65,26,28).
extends SceneTree

const BLUSH := Color(1.0, 0.86, 0.88)
const ROSE := Color(0.99, 0.74, 0.82)
const LILAC := Color(0.86, 0.78, 0.98)
const PERI := Color(0.78, 0.82, 1.0)
const MINT := Color(0.78, 0.96, 0.87)
const BUTTER := Color(1.0, 0.95, 0.72)
const PEARL := Color(0.99, 0.96, 0.94)
const PEACH := Color(1.0, 0.86, 0.76)
const CELLAR_WARM := Color(0.98, 0.88, 0.76)

var dsl := ManorLayoutDSL.new(&"service")


func _init() -> void:
	_cellars()
	_ground()
	_first()
	_attic()
	_stairs_and_roof()
	_secrets()
	dsl.save()
	quit()


## Adds props from rows of [id, x, z, yaw = 0, y = 0, scale = 1] (room-local).
func _props(r: ManorRoomDef, rows: Array) -> void:
	for row in rows:
		var yaw: float = row[3] if row.size() > 3 else 0.0
		var y: float = row[4] if row.size() > 4 else 0.0
		var s: float = row[5] if row.size() > 5 else 1.0
		dsl.prop(r, row[0], row[1], row[2], yaw, y, s)


func _room(id: StringName, name: String, level: int, rect: Rect2, canon: String,
		floor_kind: StringName, wall: Color, notes: String, rows: Array,
		kind: StringName = &"room") -> ManorRoomDef:
	var r := dsl.room(id, name, level, rect, canon, floor_kind, wall, 0.0, kind)
	r.notes = notes
	_props(r, rows)
	return r


# --- Level -1: cellars --------------------------------------------------------

func _cellars() -> void:
	_room(&"svc_wine_cellar", "Wine Cellar", -1, Rect2(45, -65, 17, 14), "X", &"flagstone", CELLAR_WARM,
		"Vaulted racks of faerie wine; a tasting table under a lantern.", [
		[&"wine_rack", 2.0, 0.6], [&"wine_rack", 4.5, 0.6], [&"wine_rack", 7.0, 0.6],
		[&"wine_rack", 9.5, 0.6], [&"wine_rack", 12.0, 0.6], [&"wine_rack", 14.5, 0.6],
		[&"barrel_rack", 3.0, 13.2, 180.0], [&"barrel_rack", 13.5, 13.2, 180.0],
		[&"table_work", 8.5, 7.0], [&"chair_simple", 8.0, 8.0, 180.0], [&"chair_simple", 9.2, 6.0],
		[&"candelabra", 8.5, 7.0, 0.0, 0.9], [&"lantern_hanging", 8.5, 7.0, 0.0, 2.9],
		[&"candle_sconce", 0.4, 7.0, 90.0, 1.8], [&"crate", 1.2, 11.5], [&"crate", 1.2, 10.6, 15.0],
		[&"barrel", 15.8, 9.0], [&"barrel", 15.8, 10.0],
	])
	_room(&"svc_cellar_stair_hall", "Cellar Stair Hall", -1, Rect2(62, -65, 9, 14), "X", &"flagstone", PEACH,
		"Foot of the service cellar stair; stores waiting to go up.", [
		[&"lantern_hanging", 1.6, 7.0, 0.0, 2.8], [&"candle_sconce", 0.4, 4.0, 90.0, 1.8],
		[&"candle_sconce", 8.6, 4.0, -90.0, 1.8], [&"crate", 7.6, 2.0], [&"crate", 7.6, 3.0, 10.0],
		[&"barrel", 1.2, 2.0], [&"sack_flour", 7.6, 11.0], [&"sack_flour", 8.1, 11.6],
		[&"coat_rack", 1.0, 12.4], [&"basket_produce", 2.2, 12.8],
	])
	_room(&"svc_cellar_passage", "Cellar Passage", -1, Rect2(45, -51, 26, 4), "X", &"flagstone", BUTTER,
		"Lantern-lit passage linking the cellars.", [
		[&"lantern_hanging", 5.0, 2.0, 0.0, 2.8], [&"lantern_hanging", 13.0, 2.0, 0.0, 2.8],
		[&"lantern_hanging", 21.0, 2.0, 0.0, 2.8], [&"candle_sconce", 0.4, 2.0, 90.0, 1.8],
		[&"candle_sconce", 25.6, 2.0, -90.0, 1.8], [&"barrel", 1.0, 1.0], [&"crate", 25.0, 3.2],
		[&"bench_settle", 17.5, 3.4, 180.0],
	])
	_room(&"svc_root_cellar", "Root Cellar", -1, Rect2(45, -47, 9, 10), "X", &"flagstone", CELLAR_WARM,
		"Bins of roots and apples from the kitchen garden.", [
		[&"pantry_shelf", 0.5, 4.0, 90.0], [&"pantry_shelf", 8.5, 5.0, -90.0],
		[&"basket_produce", 2.0, 8.8], [&"basket_produce", 2.8, 9.2], [&"basket_produce", 6.0, 9.0],
		[&"basket_produce", 4.5, 5.0], [&"sack_flour", 7.6, 1.0], [&"sack_flour", 8.0, 1.6],
		[&"sack_flour", 1.0, 1.0], [&"crate", 4.5, 9.2], [&"crate", 7.2, 9.0, 20.0],
		[&"barrel", 1.2, 8.2], [&"lantern_hanging", 4.5, 5.0, 0.0, 2.8],
		[&"herb_bundle_hanging", 4.5, 9.7, 180.0, 2.4],
	])
	_room(&"svc_cold_store", "Cold Store", -1, Rect2(54, -47, 9, 10), "X", &"stone", PERI,
		"Frost-charmed larder: cheeses, butter crocks, game. One jar on the south shelf is loose...", [
		[&"cheese_shelf", 0.5, 3.0, 90.0], [&"cheese_shelf", 0.5, 7.0, 90.0],
		[&"pantry_shelf", 4.5, 9.5, 180.0], [&"pantry_shelf", 8.5, 2.0, -90.0],
		[&"barrel", 7.8, 8.6], [&"barrel", 7.0, 9.2], [&"crate", 2.0, 9.2],
		[&"table_work", 4.5, 5.0], [&"basket_produce", 4.0, 5.0, 0.0, 0.9],
		[&"cake_stand", 5.2, 5.0, 0.0, 0.9], [&"lantern_hanging", 4.5, 5.0, 0.0, 2.8],
		[&"faelight_orb", 6.5, 0.5, 0.0, 2.6],
	])
	_room(&"svc_smugglers_passage", "Smugglers' Passage", -1, Rect2(63, -47, 8, 10), "X", &"flagstone", CELLAR_WARM,
		"Behind the cold-store shelf: an old run used by long-gone smugglers. Hidden.", [
		[&"crate", 1.0, 1.0], [&"crate", 1.0, 1.8, 25.0], [&"crate", 6.8, 9.0],
		[&"barrel", 7.0, 1.2], [&"barrel", 6.2, 1.2], [&"chest_trunk", 4.0, 9.3, 180.0],
		[&"lantern_hanging", 4.0, 5.0, 0.0, 2.8], [&"candle_sconce", 7.6, 5.0, -90.0, 1.6],
		[&"sack_flour", 1.0, 8.8], [&"coat_rack", 7.2, 6.8], [&"bench_settle", 4.0, 0.6],
	])


# --- Level 0: kitchens and the working ground floor -----------------------------

func _ground() -> void:
	_room(&"svc_passage_0", "Service Passage", 0, Rect2(42, -54, 32, 6), "C?", &"tile", BUTTER,
		"From the main-block door (42,-50) to the kitchen-yard door (74,-51).", [
		[&"rug_runner", 8.0, 3.0, 90.0], [&"rug_runner", 22.0, 3.0, 90.0],
		[&"candle_sconce", 3.0, 0.4, 0.0, 1.8], [&"candle_sconce", 14.0, 0.4, 0.0, 1.8],
		[&"candle_sconce", 20.0, 0.4, 0.0, 1.8], [&"candle_sconce", 26.0, 0.4, 0.0, 1.8],
		[&"clock_grandfather", 3.5, 5.5, 180.0], [&"bench_settle", 12.5, 5.5, 180.0],
		[&"painting_small", 6.5, 0.3, 0.0, 1.6], [&"lantern_hanging", 16.0, 3.0, 0.0, 3.4],
		[&"coat_rack", 31.2, 0.9], [&"hat_stand", 31.2, 5.2], [&"fern_pot", 23.0, 5.4],
		[&"potted_roses", 1.0, 0.9],
	])
	_room(&"svc_kitchen", "Kitchens", 0, Rect2(42, -68, 14, 14), "C?", &"tile", MINT,
		"Cozy and bright: iron range, big hearth, copper pots, long scrubbed tables, crockery dresser. Feyre comes here hungry on Calanmai night (ch21).", [
		[&"table_kitchen", 5.5, 8.0], [&"table_kitchen", 9.0, 8.0],
		[&"bench_settle", 5.5, 9.2], [&"bench_settle", 9.0, 9.2],
		[&"bench_settle", 5.5, 6.8, 180.0], [&"bench_settle", 9.0, 6.8, 180.0],
		[&"dresser_crockery", 3.0, 13.4, 180.0], [&"dresser_crockery", 13.4, 7.0, -90.0],
		[&"copper_pots", 3.5, 0.3, 0.0, 1.7], [&"copper_pots", 10.5, 0.3, 0.0, 1.7],
		[&"pot_rack_hanging", 7.2, 8.0, 0.0, 3.0], [&"herb_bundle_hanging", 12.2, 0.4, 0.0, 2.2],
		[&"basket_produce", 5.0, 8.0, 0.0, 0.9], [&"cake_stand", 9.6, 8.0, 0.0, 0.9],
		[&"vase_roses", 7.2, 8.0, 0.0, 0.9], [&"chandelier_small", 7.0, 4.0, 0.0, 3.4],
		[&"candle_sconce", 0.3, 2.5, 90.0, 1.9], [&"candle_sconce", 0.3, 11.5, 90.0, 1.9],
		[&"sack_flour", 13.2, 12.6], [&"sack_flour", 12.6, 13.0], [&"barrel", 13.0, 1.4],
		[&"stool", 2.4, 5.0], [&"stool", 2.4, 9.0], [&"potted_roses", 0.8, 13.2],
	])
	_room(&"svc_bakery", "Bakery Corner", 0, Rect2(56, -68, 6, 7), "X", &"tile", PEACH,
		"Bread oven, flour sacks and proving baskets.", [
		[&"table_work", 3.0, 4.0], [&"basket_produce", 2.4, 4.0, 0.0, 0.9],
		[&"cake_stand", 3.8, 4.0, 0.0, 0.9], [&"sack_flour", 5.2, 1.4], [&"sack_flour", 5.4, 2.2],
		[&"sack_flour", 5.2, 6.2], [&"pantry_shelf", 5.6, 4.2, -90.0], [&"stool", 1.0, 6.2],
		[&"candle_sconce", 0.3, 1.6, 90.0, 1.8], [&"copper_pots", 0.3, 5.4, 90.0, 1.5],
		[&"lantern_hanging", 3.0, 3.5, 0.0, 3.2],
	])
	_room(&"svc_scullery", "Scullery", 0, Rect2(56, -61, 6, 7), "C?", &"tile", PERI,
		"Stone sinks, soap, buckets: where the dishes go.", [
		[&"sink_stone", 5.4, 2.0, -90.0], [&"sink_stone", 5.4, 5.0, -90.0],
		[&"barrel", 0.8, 1.0], [&"barrel", 0.8, 6.2], [&"copper_pots", 5.7, 3.5, -90.0, 1.6],
		[&"stool", 4.3, 3.5], [&"basket_produce", 1.8, 0.8], [&"towel_rack", 4.4, 0.4],
		[&"soap_shelf", 5.7, 6.4, -90.0, 1.2], [&"crate", 4.8, 6.4],
		[&"candle_sconce", 0.3, 1.5, 90.0, 1.8], [&"lantern_hanging", 3.0, 3.5, 0.0, 3.2],
	])
	_room(&"svc_back_stair_0", "Back Stairs (Ground)", 0, Rect2(62, -68, 6, 14), "X", &"wood", BLUSH,
		"Service stair up (west) and the cellar stair coming up (east).", [
		[&"candle_sconce", 5.7, 2.0, -90.0, 1.8], [&"candle_sconce", 5.7, 13.0, -90.0, 1.8],
		[&"candle_sconce", 0.3, 12.8, 90.0, 1.8], [&"lantern_hanging", 4.4, 2.0, 0.0, 3.6],
		[&"coat_rack", 5.4, 0.6], [&"painting_small", 4.5, 0.3, 0.0, 1.6], [&"fern_pot", 5.3, 13.3],
	])
	_room(&"svc_dairy", "Dairy", 0, Rect2(68, -68, 6, 14), "X", &"tile", BUTTER,
		"Cool white dairy: churns, cream pans, cheese shelf.", [
		[&"cheese_shelf", 3.0, 0.5], [&"barrel", 1.0, 3.0], [&"barrel", 1.0, 4.0], [&"barrel", 1.0, 5.0],
		[&"table_work", 3.5, 7.0, 90.0], [&"basket_produce", 3.5, 6.4, 0.0, 0.9],
		[&"cake_stand", 3.5, 7.6, 0.0, 0.9], [&"pantry_shelf", 0.5, 10.0, 90.0],
		[&"sink_stone", 5.4, 10.0, -90.0], [&"stool", 2.4, 9.0],
		[&"lantern_hanging", 3.0, 7.0, 0.0, 3.2], [&"candle_sconce", 0.3, 7.0, 90.0, 1.8],
		[&"fern_pot", 5.3, 13.3], [&"vase_roses", 5.4, 1.0],
	])
	_room(&"svc_servants_hall", "Servants' Hall", 0, Rect2(42, -48, 14, 14), "X", &"wood", BLUSH,
		"Long table and a warm hearth where the masked staff eat together.", [
		[&"table_dining_long", 7.5, 7.0], [&"bench_settle", 5.0, 6.0, 180.0], [&"bench_settle", 9.6, 6.0, 180.0],
		[&"bench_settle", 5.0, 8.0], [&"bench_settle", 9.6, 8.0],
		[&"chair_dining", 3.0, 7.0, 90.0], [&"chair_dining", 12.0, 7.0, -90.0],
		[&"chandelier_small", 5.0, 7.0, 0.0, 3.4], [&"chandelier_small", 10.0, 7.0, 0.0, 3.4],
		[&"dresser_crockery", 13.4, 3.0, -90.0], [&"sideboard", 7.0, 13.4, 180.0],
		[&"clock_grandfather", 13.4, 13.0, -90.0], [&"armchair", 2.0, 3.6, 45.0],
		[&"armchair", 2.0, 10.4, 135.0], [&"rug_large", 2.6, 7.0, 90.0],
		[&"painting_medium", 11.0, 0.3, 0.0, 1.8], [&"potted_roses", 1.0, 13.0],
		[&"vase_roses", 7.5, 7.0, 0.0, 0.8], [&"candle_sconce", 0.3, 3.0, 90.0, 1.9],
		[&"candle_sconce", 0.3, 11.0, 90.0, 1.9],
	])
	_room(&"svc_pantry", "Pantry", 0, Rect2(56, -48, 8, 7), "C?", &"wood", BUTTER,
		"Dry goods, preserves, honey and jams in jewel jars.", [
		[&"pantry_shelf", 0.5, 3.5, 90.0], [&"pantry_shelf", 7.5, 3.5, -90.0],
		[&"pantry_shelf", 2.0, 6.5, 180.0], [&"pantry_shelf", 6.0, 6.5, 180.0],
		[&"sack_flour", 1.0, 0.8], [&"sack_flour", 1.6, 0.8], [&"barrel", 7.0, 0.9],
		[&"crate", 6.0, 0.9], [&"table_work", 4.0, 3.5], [&"basket_produce", 3.5, 3.5, 0.0, 0.9],
		[&"cake_stand", 4.6, 3.5, 0.0, 0.9], [&"herb_bundle_hanging", 4.0, 3.5, 0.0, 2.6],
		[&"lantern_hanging", 4.0, 2.0, 0.0, 3.2],
	])
	_room(&"svc_housekeeper", "Housekeeper's Office", 0, Rect2(56, -41, 8, 7), "X", &"carpet", LILAC,
		"Ledgers, keys and menus; where Alis plans the household.", [
		[&"desk_writing", 4.0, 1.2, 180.0], [&"chair_simple", 4.0, 2.2, 180.0],
		[&"inkstand", 3.6, 1.2, 0.0, 0.8], [&"candelabra", 4.8, 1.2, 0.0, 0.8],
		[&"bookcase_low", 0.5, 1.5, 90.0], [&"scroll_rack", 2.0, 6.5, 180.0],
		[&"chest_trunk", 5.0, 6.5, 180.0], [&"armchair", 6.2, 5.2, -135.0], [&"rug_round", 4.0, 4.0],
		[&"table_side", 7.0, 6.2], [&"vase_roses", 7.0, 6.2, 0.0, 0.7],
		[&"painting_small", 7.7, 1.2, -90.0, 1.6], [&"candle_sconce", 0.3, 5.5, 90.0, 1.8],
	])
	_room(&"svc_stillroom", "Stillroom", 0, Rect2(64, -48, 10, 7), "X", &"tile", MINT,
		"Drying racks, alembics and the apothecary cabinet: tinctures, salves and cordials.", [
		[&"drying_rack_herbs", 0.5, 2.0, 90.0], [&"drying_rack_herbs", 0.5, 5.0, 90.0],
		[&"apothecary_cabinet", 2.0, 0.4], [&"table_work", 4.0, 3.5],
		[&"alembic", 3.4, 3.5, 0.0, 0.9], [&"alembic", 4.6, 3.5, 0.0, 0.9],
		[&"vial_rack", 9.3, 2.0, -90.0, 0.95], [&"mortar_pestle", 9.3, 5.0, 0.0, 0.95],
		[&"herb_bundle_hanging", 7.6, 0.4, 0.0, 2.2], [&"herb_bundle_hanging", 2.0, 6.6, 180.0, 2.2],
		[&"stool", 7.8, 3.5], [&"lantern_hanging", 5.0, 3.5, 0.0, 3.4], [&"fern_pot", 8.6, 6.3],
		[&"pigment_jars", 4.0, 3.9, 0.0, 0.9],
	])
	_room(&"svc_infirmary", "Infirmary", 0, Rect2(64, -41, 10, 7), "C", &"wood", PEARL,
		"Small infirmary: cots and bandage shelves. Feyre dresses Tamlin's Bogge-bitten hand here (ch12).", [
		[&"infirmary_cot", 4.5, 4.5], [&"infirmary_cot", 6.5, 4.5],
		[&"bandage_shelf", 2.0, 0.4], [&"bandage_shelf", 8.0, 0.4],
		[&"washstand", 2.0, 6.6, 180.0], [&"towel_rack", 3.4, 6.7, 180.0],
		[&"nightstand", 5.5, 6.2], [&"vial_rack", 5.5, 6.2, 0.0, 0.7],
		[&"table_side", 2.6, 2.6], [&"mortar_pestle", 2.6, 2.6, 0.0, 0.7],
		[&"chair_simple", 9.2, 2.4, -90.0], [&"candle_sconce", 9.7, 1.0, -90.0, 1.8],
		[&"lantern_hanging", 5.0, 3.5, 0.0, 3.4], [&"vase_roses", 5.2, 6.2, 0.0, 0.7],
	])
	# Kitchen-yard porch on the east facade (props only).
	var porch := _room(&"svc_kitchen_yard_porch", "Kitchen-Yard Porch", 0, Rect2(74, -56, 6, 10), "X", &"stone", PEARL,
		"Covered porch with steps down to the kitchen yard; deliveries and herb pots.", [
		[&"stone_steps", 1.8, 5.0, 90.0, -0.9], [&"column_marble", 0.4, 0.5, 0.0, -0.9, 1.28],
		[&"column_marble", 3.6, 0.5, 0.0, -0.9, 1.28], [&"column_marble", 0.4, 9.5, 0.0, -0.9, 1.28],
		[&"column_marble", 3.6, 9.5, 0.0, -0.9, 1.28], [&"lantern_hanging", 2.0, 5.0, 0.0, 3.4],
		[&"potted_roses", 3.6, 1.6, 0.0, -0.9], [&"potted_roses", 3.6, 8.4, 0.0, -0.9],
		[&"barrel", 5.0, 1.0, 0.0, -0.9], [&"barrel", 5.3, 1.9, 0.0, -0.9],
		[&"crate", 5.0, 9.0, 0.0, -0.9], [&"basket_produce", 5.2, 8.2, 0.0, -0.9],
		[&"garden_bench", 5.4, 5.0, -90.0, -0.9], [&"flower_garland", 2.0, 0.5, 0.0, 3.6],
	], &"exterior")
	porch.windows = false


# --- Level 1: laundry, linen, Alis and the staff bedrooms -----------------------

func _first() -> void:
	_room(&"svc_passage_1", "Upper Service Passage", 1, Rect2(42, -54, 32, 6), "X", &"wood", ROSE,
		"Links the main block's first floor (42,-50) to the staff rooms.", [
		[&"rug_runner", 8.0, 3.0, 90.0], [&"rug_runner", 23.0, 3.0, 90.0],
		[&"candle_sconce", 3.0, 0.4, 0.0, 1.8], [&"candle_sconce", 11.0, 0.4, 0.0, 1.8],
		[&"candle_sconce", 19.5, 0.4, 0.0, 1.8], [&"candle_sconce", 26.0, 0.4, 0.0, 1.8],
		[&"painting_small", 10.0, 5.7, 180.0, 1.6], [&"painting_small", 21.0, 5.7, 180.0, 1.6],
		[&"chest_trunk", 12.0, 5.4, 180.0], [&"fern_pot", 31.2, 0.8], [&"bench_settle", 31.2, 3.2, -90.0],
		[&"lantern_hanging", 16.0, 3.0, 0.0, 3.4],
	])
	_room(&"svc_laundry", "Laundry", 1, Rect2(42, -68, 12, 14), "X", &"tile", MINT,
		"Copper tubs, drying lines heavy with linens, ironing tables.", [
		[&"laundry_tub", 2.0, 1.0], [&"laundry_tub", 4.0, 1.0], [&"laundry_tub", 6.0, 1.0],
		[&"sink_stone", 9.0, 0.8], [&"drying_line", 4.0, 6.0], [&"drying_line", 4.0, 9.0],
		[&"ironing_table", 9.5, 6.0, 90.0], [&"ironing_table", 9.5, 9.5, 90.0],
		[&"basket_produce", 2.0, 11.5], [&"basket_produce", 6.5, 11.8],
		[&"soap_shelf", 0.3, 4.0, 90.0, 1.2], [&"towel_rack", 0.4, 7.5, 90.0],
		[&"stool", 8.4, 6.0], [&"lantern_hanging", 6.0, 7.0, 0.0, 3.4],
		[&"copper_pots", 11.7, 3.0, -90.0, 1.5], [&"chest_trunk", 2.0, 13.3, 180.0],
	])
	_room(&"svc_linen_room", "Linen Room", 1, Rect2(54, -68, 8, 14), "X", &"wood", LILAC,
		"Presses of lavender-scented sheets, towels and table linen.", [
		[&"linen_press", 0.6, 3.0, 90.0], [&"linen_press", 0.6, 11.0, 90.0],
		[&"linen_press", 7.4, 3.0, -90.0], [&"linen_press", 7.4, 7.0, -90.0], [&"linen_press", 7.4, 11.0, -90.0],
		[&"table_work", 4.0, 6.0, 90.0], [&"ironing_table", 4.0, 9.0, 90.0],
		[&"basket_produce", 4.0, 5.6, 0.0, 0.9], [&"basket_produce", 2.0, 1.0],
		[&"chest_trunk", 4.0, 0.6], [&"cushion_pile", 2.0, 12.5],
		[&"herb_bundle_hanging", 4.0, 0.4, 0.0, 2.4], [&"lantern_hanging", 4.0, 7.0, 0.0, 3.4],
	])
	_room(&"svc_back_stair_1", "Back Stairs (First Floor)", 1, Rect2(62, -68, 6, 14), "X", &"wood", PEACH,
		"Service stair continues up to the attic (east flight).", [
		[&"lantern_hanging", 3.0, 1.0, 0.0, 3.6], [&"painting_small", 4.5, 0.3, 0.0, 1.6],
		[&"fern_pot", 5.3, 13.3], [&"coat_rack", 0.6, 13.3], [&"candle_sconce", 0.3, 12.5, 90.0, 1.6],
		[&"candle_sconce", 5.7, 12.5, -90.0, 1.6], [&"basket_produce", 5.3, 0.8],
	])
	_room(&"svc_servants_wash", "Servants' Washroom", 1, Rect2(68, -68, 6, 14), "X", &"tile", PERI,
		"Two copper tubs behind a screen, washstands and warm towels.", [
		[&"bathtub_clawfoot", 3.0, 2.0], [&"bathtub_clawfoot", 3.0, 5.4],
		[&"dressing_screen", 3.0, 7.6], [&"washstand", 0.6, 9.0, 90.0], [&"washstand", 0.6, 11.0, 90.0],
		[&"mirror_gilt", 0.3, 10.0, 90.0, 1.4], [&"towel_rack", 5.6, 9.0, -90.0],
		[&"soap_shelf", 5.7, 11.0, -90.0, 1.2], [&"stool", 2.0, 12.4], [&"fern_pot", 5.3, 13.3],
		[&"candle_sconce", 0.3, 4.0, 90.0, 1.8],
	])
	_room(&"svc_alis_room", "Alis's Room", 1, Rect2(42, -48, 10, 14), "C?", &"wood", BUTTER,
		"Practical and warm: her nephews' drawings pinned up, their toys in a chest, an old cradle.", [
		[&"bed_single", 1.2, 11.0], [&"nightstand", 2.6, 12.8], [&"wardrobe_tall", 0.5, 4.0, 90.0],
		[&"dresser", 9.5, 4.0, -90.0], [&"washstand", 9.5, 8.0, -90.0], [&"mirror_gilt", 9.7, 8.0, -90.0, 1.3],
		[&"table_round", 5.0, 7.0], [&"chair_simple", 4.0, 7.0, 90.0], [&"chair_simple", 6.0, 7.0, -90.0],
		[&"rug_round", 5.0, 7.0], [&"candelabra", 5.0, 7.0, 0.0, 0.75], [&"book_stack", 5.4, 6.7, 0.0, 0.75],
		[&"cradle_chest", 7.0, 12.8, 180.0], [&"chest_trunk", 4.5, 12.8, 180.0],
		[&"toy_wooden_horse", 4.5, 12.0, 30.0], [&"painting_small", 2.0, 0.3, 0.0, 1.5],
		[&"painting_small", 8.0, 0.3, 0.0, 1.5], [&"coat_rack", 8.8, 1.0], [&"basket_produce", 3.0, 8.8],
		[&"potted_roses", 9.2, 13.0],
	])
	_room(&"svc_maids_dorm", "Maids' Dormitory", 1, Rect2(52, -48, 11, 14), "X", &"wood", BLUSH,
		"Four neat beds with rose quilts, a shared wardrobe and mirror.", [
		[&"bed_servant", 1.5, 12.6, 180.0], [&"bed_servant", 4.0, 12.6, 180.0],
		[&"bed_servant", 7.0, 12.6, 180.0], [&"bed_servant", 9.5, 12.6, 180.0],
		[&"nightstand", 2.75, 13.2], [&"nightstand", 8.25, 13.2], [&"chest_trunk", 1.5, 10.8],
		[&"chest_trunk", 9.5, 10.8], [&"wardrobe_tall", 0.5, 5.0, 90.0], [&"washstand", 10.5, 5.0, -90.0],
		[&"mirror_gilt", 10.7, 7.0, -90.0, 1.4], [&"rug_large", 5.5, 7.0], [&"chair_simple", 8.0, 3.0],
		[&"dressing_screen", 2.2, 2.0], [&"candle_sconce", 0.3, 8.0, 90.0, 1.8],
		[&"candle_sconce", 10.7, 2.0, -90.0, 1.8], [&"vase_roses", 2.75, 13.2, 0.0, 0.7],
	])
	_room(&"svc_footmen_room", "Footmen's Room", 1, Rect2(63, -48, 11, 7), "X", &"wood", PERI,
		"Two beds for the masked footmen, boots lined up, livery on the rack.", [
		[&"bed_servant", 1.2, 4.5], [&"bed_servant", 9.8, 4.5], [&"wardrobe_tall", 1.5, 0.5],
		[&"chest_trunk", 1.2, 6.3, 180.0], [&"chest_trunk", 9.8, 6.3, 180.0], [&"nightstand", 2.6, 5.0],
		[&"washstand", 8.6, 0.5], [&"coat_rack", 10.5, 2.0], [&"mirror_gilt", 10.7, 2.8, -90.0, 1.4],
		[&"shoe_shelf", 3.0, 6.6, 180.0], [&"candle_sconce", 0.3, 2.5, 90.0, 1.8],
	])
	_room(&"svc_sewing_room", "Sewing Room", 1, Rect2(63, -41, 11, 7), "X", &"wood", ROSE,
		"Mending and gown alterations: dress forms, bolts of silk, a sunny window seat.", [
		[&"table_work", 5.5, 3.5], [&"chair_simple", 5.0, 4.6, 180.0], [&"chair_simple", 6.2, 2.4],
		[&"mannequin_gown", 1.0, 1.4], [&"mannequin_gown", 2.4, 1.4, 20.0], [&"gown_rack", 7.0, 6.3, 180.0],
		[&"basket_produce", 5.0, 3.5, 0.0, 0.9], [&"basket_produce", 1.0, 6.2],
		[&"window_seat", 10.4, 3.5, -90.0], [&"cushion_pile", 10.0, 3.5, 0.0, 0.6],
		[&"candelabra", 6.2, 3.5, 0.0, 0.9], [&"chest_trunk", 3.0, 6.4, 180.0],
		[&"lantern_hanging", 5.5, 3.5, 0.0, 3.4],
	])


# --- Level 2: attic -------------------------------------------------------------

func _attic() -> void:
	_room(&"svc_passage_2", "Attic Passage", 2, Rect2(42, -54, 32, 6), "X", &"wood", PEARL,
		"Sloped-ceiling attic corridor under the lilac slates.", [
		[&"rug_runner", 9.0, 3.0, 90.0], [&"rug_runner", 21.0, 3.0, 90.0],
		[&"candle_sconce", 2.0, 0.4, 0.0, 1.8], [&"candle_sconce", 11.0, 0.4, 0.0, 1.8],
		[&"candle_sconce", 26.0, 0.4, 0.0, 1.8], [&"chest_trunk", 3.0, 5.4, 180.0],
		[&"chest_trunk", 14.0, 5.4, 180.0], [&"crate", 31.0, 1.0], [&"lantern_hanging", 8.0, 3.0, 0.0, 3.4],
		[&"lantern_hanging", 24.0, 3.0, 0.0, 3.4], [&"fern_pot", 31.0, 5.2],
	])
	_room(&"svc_back_stair_2", "Back Stairs (Attic)", 2, Rect2(62, -68, 6, 14), "X", &"wood", MINT,
		"Top of the back stairs.", [
		[&"lantern_hanging", 1.5, 7.0, 0.0, 3.4], [&"crate", 1.0, 2.0], [&"chest_trunk", 1.0, 10.0, 90.0],
		[&"coat_rack", 0.6, 12.6], [&"candle_sconce", 0.3, 4.0, 90.0, 1.8],
		[&"candle_sconce", 0.3, 8.0, 90.0, 1.8], [&"painting_small", 1.5, 0.3, 0.0, 1.6],
	])
	_room(&"svc_maid_bedroom_a", "Attic Bedroom (Rose)", 2, Rect2(42, -68, 10, 14), "X", &"wood", BLUSH,
		"Two beds under the eaves, rose quilts and pressed flowers.", [
		[&"bed_servant", 1.2, 2.0], [&"bed_servant", 8.8, 2.0], [&"nightstand", 2.5, 1.0],
		[&"wardrobe_tall", 0.5, 8.0, 90.0], [&"washstand", 9.5, 8.0, -90.0], [&"chair_simple", 7.0, 10.0],
		[&"rug_round", 5.0, 6.0], [&"mirror_gilt", 9.7, 9.5, -90.0, 1.4], [&"potted_roses", 1.0, 13.0],
		[&"candle_sconce", 0.3, 5.0, 90.0, 1.8], [&"chest_trunk", 5.0, 0.6], [&"painting_small", 5.0, 0.3, 0.0, 1.8],
	])
	_room(&"svc_maid_bedroom_b", "Attic Bedroom (Lilac)", 2, Rect2(52, -68, 10, 14), "X", &"wood", LILAC,
		"A bright attic room with a window seat and a birdcage.", [
		[&"bed_servant", 1.2, 2.0], [&"bed_single", 8.6, 2.2], [&"nightstand", 2.5, 1.0],
		[&"dresser", 9.5, 7.0, -90.0], [&"washstand", 0.5, 8.0, 90.0], [&"window_seat", 5.0, 0.5],
		[&"cushion_pile", 5.0, 0.6, 0.0, 0.6], [&"birdcage_gilt", 8.6, 11.0], [&"rug_round", 5.0, 7.0],
		[&"chair_simple", 3.0, 11.0], [&"candle_sconce", 9.7, 4.0, -90.0, 1.8], [&"vase_roses", 2.5, 1.0, 0.0, 0.7],
	])
	_room(&"svc_box_room", "Box Room", 2, Rect2(68, -68, 6, 14), "X", &"wood", BUTTER,
		"Old trunks, a stopped clock, rolled canvases and the top of the dumbwaiter shaft.", [
		[&"crate", 1.0, 3.0], [&"crate", 1.0, 3.8, 15.0], [&"crate", 1.8, 3.2, 40.0], [&"crate", 4.8, 12.6],
		[&"chest_trunk", 1.0, 7.0, 90.0], [&"chest_trunk", 5.0, 7.0, -90.0], [&"barrel", 1.0, 12.6],
		[&"canvas_stack", 3.0, 13.4, 180.0], [&"clock_grandfather", 0.5, 10.0, 90.0],
		[&"dressing_screen", 3.0, 9.6], [&"birdcage_gilt", 4.8, 10.6], [&"dumbwaiter", 5.4, 1.0, -90.0],
		[&"lantern_hanging", 3.0, 6.0, 0.0, 3.4],
	])
	_room(&"svc_drying_loft", "Herb Drying Loft", 2, Rect2(42, -48, 16, 14), "X", &"wood", MINT,
		"Warm loft where stillroom herbs and flowers hang to dry.", [
		[&"drying_rack_herbs", 0.5, 3.0, 90.0], [&"drying_rack_herbs", 0.5, 7.0, 90.0],
		[&"drying_rack_herbs", 15.5, 3.0, -90.0], [&"drying_rack_herbs", 15.5, 7.0, -90.0],
		[&"herb_bundle_hanging", 4.0, 5.0, 0.0, 2.6], [&"herb_bundle_hanging", 8.0, 5.0, 0.0, 2.6],
		[&"herb_bundle_hanging", 12.0, 5.0, 0.0, 2.6], [&"herb_bundle_hanging", 8.0, 9.0, 0.0, 2.6],
		[&"drying_line", 5.0, 11.0], [&"drying_line", 11.0, 11.0], [&"table_work", 8.0, 7.0],
		[&"mortar_pestle", 7.4, 7.0, 0.0, 0.9], [&"basket_produce", 8.6, 7.0, 0.0, 0.9],
		[&"basket_produce", 2.0, 13.0], [&"basket_produce", 14.0, 13.0], [&"stool", 8.0, 8.2],
		[&"lantern_hanging", 4.0, 9.0, 0.0, 3.4], [&"lantern_hanging", 12.0, 9.0, 0.0, 3.4],
	])
	_room(&"svc_attic_playroom", "Attic Playroom", 2, Rect2(58, -48, 16, 14), "X", &"carpet", PERI,
		"Where Alis's nephews sleep and play when they visit: two beds, toys, a globe.", [
		[&"bed_single", 1.0, 11.0], [&"bed_single", 3.0, 11.0], [&"nightstand", 2.0, 12.8],
		[&"chest_trunk", 6.0, 13.2, 180.0], [&"toy_wooden_horse", 8.0, 7.0, 45.0], [&"rug_round", 8.0, 7.0],
		[&"table_round", 12.0, 4.0], [&"chair_simple", 11.0, 4.0, 90.0], [&"chair_simple", 13.0, 4.0, -90.0],
		[&"book_stack", 12.0, 4.0, 0.0, 0.75], [&"globe_stand", 14.6, 10.0], [&"cushion_pile", 13.0, 12.6],
		[&"window_seat", 15.4, 7.0, -90.0], [&"painting_small", 4.0, 0.3, 0.0, 1.6],
		[&"birdcage_gilt", 1.0, 2.0], [&"lantern_hanging", 8.0, 7.0, 0.0, 3.4],
	])


# --- Doors, stairs, stations, roof ----------------------------------------------

func _stairs_and_roof() -> void:
	# Level -1 doors.
	for at in [Vector2(53, -51), Vector2(66, -51), Vector2(62, -58), Vector2(49.5, -47), Vector2(58.5, -47)]:
		dsl.door(-1, at)
	# Level 0 doors (the main-block door at (42,-50) belongs to lane A).
	dsl.door(0, Vector2(52, -54), &"open", 2.4)        # passage <-> kitchen
	for at in [Vector2(59, -54), Vector2(65, -54), Vector2(71, -54), Vector2(60, -48),
			Vector2(69, -48), Vector2(56, -64.5), Vector2(56, -57.5), Vector2(59, -61),
			Vector2(56, -37.5), Vector2(64, -37.5), Vector2(69, -41)]:
		dsl.door(0, at)
	dsl.door(0, Vector2(49, -48), &"open", 2.4)        # passage <-> servants' hall
	var yard := dsl.door(0, Vector2(74, -51), &"door", 2.0)
	yard.notes = "Kitchen-yard door: steps and covered porch outside."
	# Level 1 doors (the main-block door at (42,-50) belongs to lane B).
	for at in [Vector2(48, -54), Vector2(58, -54), Vector2(65, -54), Vector2(71, -54),
			Vector2(47, -48), Vector2(57.5, -48), Vector2(68.5, -48), Vector2(68.5, -41), Vector2(54, -61)]:
		dsl.door(1, at)
	# Level 2 doors.
	for at in [Vector2(47, -54), Vector2(57, -54), Vector2(65, -54), Vector2(71, -54),
			Vector2(50, -48), Vector2(66, -48)]:
		dsl.door(2, at)

	dsl.stair(&"svc_cellar", -1, Rect2(65.2, -64, 2.4, 8), &"north", &"cellar")
	dsl.stair(&"svc_back_0", 0, Rect2(62.5, -66, 2.4, 9), &"north", &"service")
	dsl.stair(&"svc_back_1", 1, Rect2(65.2, -66, 2.4, 9), &"north", &"service")

	dsl.station(&"kitchen", "Kitchen Range", 0, Vector3(49.0, 0.0, -67.2), &"range_iron", 0.0, "C")
	dsl.station(&"hearth", "Kitchen Hearth", 0, Vector3(42.7, 0.0, -61.0), &"hearth_kitchen", 90.0, "C?")
	dsl.station(&"hearth", "Servants' Hall Fire", 0, Vector3(42.5, 0.0, -41.0), &"fireplace_small", 90.0, "X")
	dsl.station(&"bread_oven", "Bread Oven", 0, Vector3(59.0, 0.0, -67.2), &"bread_oven", 0.0, "X")
	dsl.station(&"stillroom", "Stillroom Bench", 0, Vector3(73.3, 0.0, -44.5), &"stillroom_bench", -90.0, "X")
	dsl.station(&"infirmary", "Infirmary Cot", 0, Vector3(72.5, 0.0, -36.5), &"infirmary_cot", 0.0, "C")

	dsl.roof(ManorSitePlan.HOUSE_SERVICE, 2, &"hip", 6.0, EstateKit.SLATE)
	dsl.roof(Rect2(74, -57, 4, 12), 0, &"flat", 0.6, EstateKit.SLATE)   # porch canopy


func _secrets() -> void:
	# A loose jar on the cold-store shelf swings the east shelf open onto the smugglers' run.
	dsl.secret_door(-1, Vector2(63, -42), &"smugglers_run", &"bookcase")
	dsl.secret(&"smugglers_run", &"lever", -1, Vector3(58.5, 1.4, -37.7), &"", &"loose_jar",
		"A jar of plum preserves that will not lift: tilt it and the east shelf swings away.")
	dsl.secret(&"smugglers_coin", &"keepsake", -1, Vector3(69.5, 0.1, -38.4), &"col_smugglers_coin", &"",
		"An old gold coin wedged behind the smugglers' chest.")
	dsl.secret(&"dumbwaiter_shaft", &"discovery", 2, Vector3(72.6, 1.0, -66.8), &"", &"dumbwaiter",
		"The dumbwaiter shaft is just wide enough to hide in: a child's chalk marks inside.")
	dsl.secret(&"alis_floorboard", &"keepsake", 1, Vector3(43.4, 0.05, -35.6), &"col_carved_wooden_bird", &"loose_panel",
		"Under a loose floorboard: a little wooden bird one of Alis's nephews carved.")
	dsl.secret(&"pantry_honey", &"keepsake", 0, Vector3(63.4, 2.0, -44.5), &"col_honeycomb_charm", &"",
		"Tucked on the top pantry shelf: a honeycomb charm left for the house brownie.")
