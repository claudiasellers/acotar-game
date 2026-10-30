## Generator: the manor's GROUND FLOOR (main block + west wing), the CELLARS
## under them, and the front/garden facade dressing of those parts.
##
## Run: godot --headless -s tools/manor_estate/gen_ground.gd
## Writes data/regions/spring_court/manor_estate/house/ground.tres.
extends SceneTree

# Wallpaper tints (R3: never grey).
const BLUSH := Color(1.0, 0.86, 0.89)
const LILAC := Color(0.89, 0.82, 0.98)
const MINT := Color(0.82, 0.96, 0.89)
const BUTTER := Color(1.0, 0.95, 0.76)
const PERI := Color(0.82, 0.86, 1.0)
const PEARL := Color(0.99, 0.96, 0.94)
const ROSE := Color(0.98, 0.74, 0.82)
const PEACH := Color(1.0, 0.87, 0.78)
const SAGE := Color(0.86, 0.94, 0.80)
const CELLAR_WARM := Color(0.96, 0.86, 0.80)
const CELLAR_ROSE := Color(0.94, 0.80, 0.80)
const CELLAR_LAV := Color(0.90, 0.84, 0.93)
const CELLAR_BUTTER := Color(0.97, 0.90, 0.76)

var dsl := ManorLayoutDSL.new(&"ground")
var R := {}   # id -> ManorRoomDef


func _init() -> void:
	_rooms()
	_doors()
	_stairs()
	_furnish_ground_main()
	_furnish_west_wing()
	_furnish_cellars()
	_exterior()
	_stations()
	_secrets()
	dsl.save()
	quit()


# --- helpers -----------------------------------------------------------------

func room(id: StringName, name: String, level: int, rect: Rect2, canon: String, floor_kind: StringName,
		wall: Color, notes: String = "", kind: StringName = &"room") -> ManorRoomDef:
	var r := dsl.room(id, name, level, rect, canon, floor_kind, wall, 0.0, kind)
	r.notes = notes
	R[id] = r
	return r


func p(id: StringName, prop_id: StringName, x: float, z: float, yaw: float = 0.0, y: float = 0.0,
		s: float = 1.0) -> void:
	dsl.prop(R[id], prop_id, x, z, yaw, y, s)


## World-coordinate placement (converted to room-local).
func pw(id: StringName, prop_id: StringName, wx: float, wz: float, yaw: float = 0.0, y: float = 0.0,
		s: float = 1.0) -> void:
	var r: ManorRoomDef = R[id]
	dsl.prop(r, prop_id, wx - r.rect.position.x, wz - r.rect.position.y, yaw, y, s)


func _ceiling(id: StringName) -> float:
	# Mirrors ManorHouseBuilder.ceiling_of (not referenced here: the builder needs autoloads).
	var lvl: int = R[id].level
	var storey := ManorSitePlan.CELLAR_DEPTH if lvl < 0 else ManorSitePlan.HOUSE_STOREY
	return storey - 0.32


func _blocked_by_door(r: ManorRoomDef, side: String, along_world: float, half: float) -> bool:
	for d in dsl.layout.doors:
		if d.level != r.level:
			continue
		var on_wall := false
		var along := 0.0
		match side:
			"n":
				on_wall = absf(d.at.y - r.rect.position.y) < 0.6
				along = d.at.x
			"s":
				on_wall = absf(d.at.y - r.rect.end.y) < 0.6
				along = d.at.x
			"w":
				on_wall = absf(d.at.x - r.rect.position.x) < 0.6
				along = d.at.y
			"e":
				on_wall = absf(d.at.x - r.rect.end.x) < 0.6
				along = d.at.y
		if on_wall and absf(along - along_world) < d.width * 0.5 + half + 0.35:
			return true
	return false


func _in_stair(r: ManorRoomDef, wx: float, wz: float) -> bool:
	for s in dsl.layout.stairs:
		if (s.level_from == r.level or s.level_from + 1 == r.level) and s.rect.grow(0.4).has_point(Vector2(wx, wz)):
			return true
	return false


## `count` props evenly along one wall ("n","s","w","e"), facing into the room;
## slots that hit a door (or, for floor props, a stair) are skipped.
func wall_line(id: StringName, prop_id: StringName, side: String, count: int, y: float = 0.0,
		margin: float = 0.8, from: float = -1.0, to: float = -1.0) -> int:
	var r: ManorRoomDef = R[id]
	var size := PropLib.size_of(prop_id)
	var inset := 0.25 + size.z * 0.5 + 0.03
	var w := r.rect.size.x
	var d := r.rect.size.y
	var length := w if side == "n" or side == "s" else d
	var a := margin if from < 0.0 else from
	var b := length - margin if to < 0.0 else to
	var placed := 0
	for i in count:
		var t := a + (i + 0.5) * (b - a) / count
		var x := 0.0
		var z := 0.0
		var yaw := 0.0
		match side:
			"n":
				x = t; z = inset; yaw = 180.0
			"s":
				x = t; z = d - inset; yaw = 0.0
			"w":
				x = inset; z = t; yaw = -90.0
			"e":
				x = w - inset; z = t; yaw = 90.0
		var along_world := r.rect.position.x + t if side == "n" or side == "s" else r.rect.position.y + t
		if _blocked_by_door(r, side, along_world, size.x * 0.5):
			continue
		if y < 0.5 and _in_stair(r, r.rect.position.x + x, r.rect.position.y + z):
			continue
		dsl.prop(r, prop_id, x, z, yaw, y)
		placed += 1
	return placed


func sconces(id: StringName, spacing: float = 5.0) -> void:
	var r: ManorRoomDef = R[id]
	var y := 1.9 if r.level >= 0 else 1.7
	for side in ["n", "s", "w", "e"]:
		var length := r.rect.size.x if side == "n" or side == "s" else r.rect.size.y
		wall_line(id, &"candle_sconce", side, maxi(1, int(length / spacing)), y)


## Hanging lights along the long axis of the room.
func hang(id: StringName, prop_id: StringName, n: int) -> void:
	var r: ManorRoomDef = R[id]
	var y := _ceiling(id) - PropLib.size_of(prop_id).y - 0.05
	var w := r.rect.size.x
	var d := r.rect.size.y
	for i in n:
		var t := (i + 0.5) / n
		if w >= d:
			p(id, prop_id, w * t, d * 0.5, 0.0, y)
		else:
			p(id, prop_id, w * 0.5, d * t, 0.0, y)


func corners(id: StringName, prop_id: StringName, inset: float = 0.9) -> void:
	var r: ManorRoomDef = R[id]
	var w := r.rect.size.x
	var d := r.rect.size.y
	for c in [Vector2(inset, inset), Vector2(w - inset, inset), Vector2(inset, d - inset), Vector2(w - inset, d - inset)]:
		if not _in_stair(r, r.rect.position.x + c.x, r.rect.position.y + c.y):
			p(id, prop_id, c.x, c.y)


# --- rooms -------------------------------------------------------------------

func _rooms() -> void:
	# Ground floor, main block (x -42..42, z -72..-28).
	room(&"garden_saloon", "Garden Saloon", 0, Rect2(-10, -72, 20, 12), "C?", &"marble", MINT,
			"Opens onto the terrace; orange trees, birdsong, light everywhere.")
	room(&"entrance_hall", "Entrance Hall", 0, Rect2(-10, -60, 20, 32), "C", &"marble", PEARL,
			"Halls of gold and silver behind the giant oak doors; the grand marble staircase. Hall paintings incl. the still life Feyre first stops at (green glass vase of roses, tulips, morning glory, goldenrod, maiden's lace, peonies).")
	room(&"library", "Library", 0, Rect2(-42, -72, 22, 20), "C?", &"wood", PERI,
			"Tall bookcases, ladders, reading nooks. A tilting rose-red book opens the bookcase passage to the hidden reading nook.")
	room(&"tamlin_study", "Tamlin's Study", 0, Rect2(-20, -72, 10, 14), "C", &"wood", SAGE,
			"Candles lit by magic; books. Wall mural of crocuses, lambs and roses (keeper correction), plus the mural of Prythian's history (the War, the seven courts, the mountain). The cold second fireplace on the south wall is a passage.")
	room(&"hidden_nook", "Hidden Reading Nook", 0, Rect2(-20, -58, 10, 6), "X", &"carpet", BLUSH,
			"Secret: behind the library bookcase and the study's cold fireplace.")
	room(&"west_corridor", "Portrait Corridor", 0, Rect2(-42, -52, 32, 4), "C?", &"wood", ROSE,
			"Hallway paintings Feyre studies on her first exploration.", &"corridor")
	room(&"map_room", "Map Room", 0, Rect2(-42, -48, 12, 10), "X", &"wood", BUTTER,
			"Maps of Prythian; a pin in the Spring Court on the wall map swings the east panel open.")
	room(&"map_stairwell", "Hidden Stairwell", 0, Rect2(-30, -48, 4, 10), "X", &"stone", CELLAR_WARM,
			"Secret stair behind the map room panel, down to the old tunnel.")
	room(&"armory", "Armory", 0, Rect2(-42, -38, 16, 10), "C?", &"flagstone", PEACH,
			"Bows and arrows (the yew longbow rack), straw targets, blades Tamlin and Lucien patrol with.")
	room(&"drawing_room", "Drawing Room", 0, Rect2(-26, -48, 16, 20), "C?", &"carpet", LILAC,
			"Sofas, a marble hearth, curios and a gilded birdcage.")
	room(&"east_corridor", "Gilded Corridor", 0, Rect2(10, -52, 32, 4), "C?", &"wood", BUTTER,
			"Leads to the gallery, dining hall and the service wing.", &"corridor")
	room(&"music_room", "Music Room", 0, Rect2(10, -72, 20, 12), "X", &"wood", PERI,
			"A gilt harp and a pearl pianoforte; doors to the terrace.")
	room(&"morning_room", "Morning Room", 0, Rect2(30, -72, 12, 12), "X", &"carpet", BUTTER,
			"Cozy breakfast room: porridge, eggs, bacon and aromatic tea in the sun.")
	room(&"gallery", "Gallery", 0, Rect2(10, -60, 32, 8), "C", &"marble", PEARL,
			"Closed and dusty until Tamlin has it cleaned and opens it after Feyre asks for paint (requires gallery_found). It overwhelms her.")
	room(&"dining_hall", "Dining Hall", 0, Rect2(10, -48, 22, 20), "C", &"marble", ROSE,
			"Formal dinners with Tamlin and Lucien; the table Tamlin shrinks (ch22).")
	room(&"butlers_pantry", "Butler's Pantry", 0, Rect2(32, -48, 10, 10), "X", &"tile", MINT,
			"Servery between dining hall and service wing; stair down to the wine vault.")
	room(&"china_room", "China & Silver Room", 0, Rect2(32, -38, 10, 10), "X", &"wood", LILAC,
			"Cabinets of pearl china and gold plate.")
	# Ground floor, west wing (x -74..-42, z -68..-34).
	room(&"rose_corridor", "Rose Corridor", 0, Rect2(-74, -52, 32, 4), "X", &"marble", BLUSH,
			"West wing spine, garlanded in roses.", &"corridor")
	room(&"ballroom", "Ballroom", 0, Rect2(-74, -68, 22, 16), "X", &"marble", PEARL,
			"Mirrors and four crystal chandeliers; normal storey height.")
	room(&"shrine", "Shrine of the Mother", 0, Rect2(-52, -68, 10, 16), "X", &"marble", LILAC,
			"Quiet chapel with pews, an altar and a bank of candles.")
	room(&"conservatory", "Conservatory", 0, Rect2(-74, -48, 18, 14), "X", &"tile", MINT,
			"Orange trees, palms, ferns and a little fountain.")
	room(&"flower_room", "Flower Room", 0, Rect2(-56, -48, 8, 14), "X", &"tile", SAGE,
			"Where the house flowers are arranged; stair down to the west cellars.")
	room(&"card_room", "Ladies' Card Room", 0, Rect2(-48, -48, 6, 8), "X", &"carpet", ROSE,
			"A round card table, candlelight.")
	room(&"powder_room", "Powder Room", 0, Rect2(-48, -40, 6, 6), "X", &"tile", BLUSH,
			"A little vanity for guests at balls.")
	# Cellars, main zone (x -39..39, z -69..-31).
	room(&"wine_vault", "Vaulted Wine Vault", -1, Rect2(14, -48, 25, 17), "X", &"flagstone", CELLAR_ROSE,
			"Barrel vaults of pale sparkling wine; stair up to the butler's pantry.")
	room(&"undercroft", "Undercroft", -1, Rect2(-10, -48, 24, 9), "X", &"flagstone", CELLAR_WARM,
			"Pillared vault joining the cellars.", &"corridor")
	room(&"preserves_cellar", "Preserves & Honey Cellar", -1, Rect2(-10, -39, 12, 8), "X", &"flagstone", CELLAR_BUTTER)
	room(&"cheese_cellar", "Cheese Cellar", -1, Rect2(2, -39, 12, 8), "X", &"flagstone", CELLAR_BUTTER)
	room(&"old_storerooms", "Old Storerooms", -1, Rect2(-26, -48, 16, 17), "X", &"stone", CELLAR_WARM,
			"Dust sheets over furniture from the years before the curse.")
	room(&"old_tunnel", "Old Tunnel", -1, Rect2(-32, -69, 6, 38), "X", &"stone", CELLAR_LAV,
			"Forgotten War-era passage; its hidden stair rises to the map room.", &"corridor")
	room(&"well_chamber", "Old Well Chamber", -1, Rect2(-39, -57, 7, 26), "X", &"stone", CELLAR_LAV,
			"A spring-fed well under the house; moss and faelights.")
	room(&"strongroom", "Old Strongroom", -1, Rect2(-39, -69, 7, 12), "X", &"stone", CELLAR_ROSE,
			"Iron-bound chests from Tamlin's father's day.")
	room(&"candle_store", "Candle & Lamp Store", -1, Rect2(-26, -69, 16, 21), "X", &"stone", CELLAR_BUTTER)
	room(&"cider_cellar", "Cider Cellar", -1, Rect2(-10, -69, 14, 21), "X", &"flagstone", CELLAR_WARM)
	room(&"mask_vault", "Mask Vault", -1, Rect2(4, -69, 10, 21), "X", &"stone", CELLAR_LAV,
			"SOMBRE (tag: amarantha_curse). Masks from the cursed masquerade - the curse's masks, not fashion. Opened by the lever behind a portrait in the gallery.")
	room(&"painting_store", "Forgotten Painting Store", -1, Rect2(14, -69, 12, 21), "X", &"stone", CELLAR_ROSE,
			"Canvases stored away before the curse; the west wall is false (mask vault).")
	room(&"cold_store", "Cold Store & Root Cellar", -1, Rect2(26, -69, 13, 21), "X", &"flagstone", CELLAR_WARM)
	# Cellars, west zone (x -71..-45, z -65..-37).
	room(&"west_undercroft", "West Undercroft", -1, Rect2(-58, -50, 13, 13), "X", &"flagstone", CELLAR_WARM,
			"Foot of the flower-room stair.")
	room(&"seed_cellar", "Bulb & Seed Cellar", -1, Rect2(-71, -50, 13, 13), "X", &"flagstone", CELLAR_BUTTER,
			"Bulbs and seeds for the conservatory and gardens.")
	room(&"ancestral_crypt", "Ancestral Crypt", -1, Rect2(-71, -65, 13, 15), "X", &"marble", CELLAR_LAV,
			"Quiet tombs of the High Lords of Spring; white roses for Tamlin's mother.")
	room(&"costume_store", "Masquerade Costume Store", -1, Rect2(-58, -65, 13, 15), "X", &"stone", CELLAR_ROSE,
			"SOMBRE (tag: amarantha_curse). Gowns and masks put away after the cursed masquerade.")
	# Exterior dressing.
	room(&"front_portico", "Front Portico", 0, Rect2(-42, -28, 84, 10), "C", &"stone", PEARL,
			"Grand marble staircase up to the giant oak doors; alabaster veiled in roses and ivy.", &"exterior")
	room(&"garden_facade", "Garden Facade", 0, Rect2(-42, -80, 84, 8), "C?", &"stone", PEARL,
			"Steps from the three terrace doors (terrace itself is the grounds lane's).", &"exterior")
	room(&"west_facade", "West Wing Facade", 0, Rect2(-80, -68, 6, 34), "X", &"stone", PEARL,
			"Climbing roses and orange tubs along the west wing.", &"exterior")
	room(&"west_south_facade", "West Wing South Facade", 0, Rect2(-74, -34, 32, 4), "X", &"stone", PEARL,
			"Urns and roses under the conservatory windows.", &"exterior")


# --- doors and stairs ----------------------------------------------------------

func _doors() -> void:
	var gate := dsl.door(0, Vector2(0, -28), &"gate", 2.4, 3.4)
	gate.region_id = &"manor_house"
	gate.notes = "Giant oak front doors that open by themselves."
	for x in [0.0, -24.0, 24.0]:
		dsl.door(0, Vector2(x, -72), &"door", 2.0, 3.0).notes = "Terrace door"
	dsl.door(0, Vector2(-42, -50), &"open", 2.4, 3.2).notes = "Main <-> west wing"
	dsl.door(0, Vector2(42, -50), &"door", 2.0, 3.0).notes = "Main <-> service wing"
	# Main block, ground.
	dsl.door(0, Vector2(0, -60), &"open", 3.2, 3.4)
	dsl.door(0, Vector2(-10, -50), &"open", 2.4, 3.2)
	dsl.door(0, Vector2(10, -50), &"open", 2.4, 3.2)
	dsl.door(0, Vector2(-10, -66))
	dsl.door(0, Vector2(10, -66), &"door", 2.0)
	dsl.door(0, Vector2(-31, -52), &"door", 2.0)
	dsl.door(0, Vector2(-20, -65))
	dsl.secret_door(0, Vector2(-20, -55), &"library_bookcase", &"bookcase")
	dsl.secret_door(0, Vector2(-15, -58), &"study_hearth", &"fireplace")
	dsl.door(0, Vector2(-36, -48))
	dsl.door(0, Vector2(-36, -38))
	dsl.secret_door(0, Vector2(-30, -39), &"map_panel", &"panel", 1.2)
	dsl.door(0, Vector2(-26, -33))
	dsl.door(0, Vector2(-18, -48), &"door", 2.0)
	dsl.door(0, Vector2(-10, -38), &"door", 2.0)
	dsl.door(0, Vector2(30, -66))
	dsl.locked_door(0, Vector2(26, -52), "gallery_opened").notes = "Tamlin opens the gallery after Feyre asks for paint."
	dsl.door(0, Vector2(21, -48), &"door", 2.0)
	dsl.door(0, Vector2(10, -38), &"door", 2.4)
	dsl.door(0, Vector2(32, -43))
	dsl.door(0, Vector2(32, -33))
	dsl.door(0, Vector2(40, -48))
	dsl.door(0, Vector2(39, -38))
	# West wing, ground.
	dsl.door(0, Vector2(-63, -52), &"open", 3.0, 3.2)
	dsl.door(0, Vector2(-47, -52))
	dsl.door(0, Vector2(-65, -48), &"open", 2.4)
	dsl.door(0, Vector2(-55, -48))
	dsl.door(0, Vector2(-45, -48))
	dsl.door(0, Vector2(-52, -60))
	dsl.door(0, Vector2(-56, -41))
	dsl.door(0, Vector2(-45, -40), &"door", 1.4)
	dsl.door(0, Vector2(-48, -37), &"door", 1.4)
	# Cellars, main.
	dsl.door(-1, Vector2(14, -44), &"open", 2.4)
	dsl.door(-1, Vector2(-10, -44), &"open", 2.0)
	dsl.door(-1, Vector2(-3, -48))
	dsl.door(-1, Vector2(-4, -39))
	dsl.door(-1, Vector2(8, -39))
	dsl.door(-1, Vector2(2, -35))
	dsl.door(-1, Vector2(14, -35))
	dsl.door(-1, Vector2(-18, -48))
	dsl.door(-1, Vector2(-10, -58))
	dsl.door(-1, Vector2(-26, -36), &"door", 1.4)
	dsl.door(-1, Vector2(-26, -62), &"door", 1.4)
	dsl.door(-1, Vector2(-32, -52), &"door", 1.4)
	dsl.door(-1, Vector2(-32, -63), &"door", 1.4)
	dsl.door(-1, Vector2(20, -48))
	dsl.door(-1, Vector2(30, -48))
	dsl.door(-1, Vector2(26, -58))
	dsl.secret_door(-1, Vector2(14, -58), &"mask_vault", &"wall")
	# Cellars, west.
	dsl.door(-1, Vector2(-58, -44))
	dsl.door(-1, Vector2(-48, -50))
	dsl.door(-1, Vector2(-64, -50))
	dsl.door(-1, Vector2(-58, -58))


func _stairs() -> void:
	dsl.stair(&"grand", 0, Rect2(-5, -52, 10, 12), &"north", &"grand")
	dsl.stair(&"main_cellar", -1, Rect2(34, -46.6, 3.2, 7), &"south", &"cellar")
	dsl.stair(&"map_secret", -1, Rect2(-29.6, -48, 3.2, 8), &"south", &"cellar")
	dsl.stair(&"west_cellar", -1, Rect2(-53.6, -46, 3.2, 8), &"south", &"cellar")


# --- furnishing: ground floor main block ----------------------------------------

func _furnish_ground_main() -> void:
	var id := &"garden_saloon"
	hang(id, &"chandelier_crystal", 2)
	sconces(id)
	p(id, &"rug_large", 10, 6.5)
	p(id, &"sofa", 6, 6.5, -90)
	p(id, &"sofa", 14, 6.5, 90)
	p(id, &"table_tea", 10, 6.5)
	p(id, &"vase_roses", 10, 6.5, 0, 0.5)
	p(id, &"armchair", 10, 9.0)
	p(id, &"orange_tree_tub", 7.5, 1.3)
	p(id, &"orange_tree_tub", 12.5, 1.3)
	corners(id, &"potted_palm")
	p(id, &"birdcage_gilt", 2.5, 6)
	p(id, &"window_seat", 3.5, 0.75, 180)
	p(id, &"window_seat", 16.5, 0.75, 180)
	p(id, &"urn_flowers", 6.5, 10.8)
	p(id, &"urn_flowers", 13.5, 10.8)
	wall_line(id, &"painting_medium", "w", 2, 1.6)

	id = &"entrance_hall"
	p(id, &"chandelier_crystal", 10, 4, 0, _ceiling(id) - 1.85)
	p(id, &"chandelier_crystal", 10, 26, 0, _ceiling(id) - 1.85)
	p(id, &"chandelier_small", 2.5, 14, 0, _ceiling(id) - 1.05)
	p(id, &"chandelier_small", 17.5, 14, 0, _ceiling(id) - 1.05)
	sconces(id, 4.0)
	for c in [Vector2(4.2, 9), Vector2(15.8, 9), Vector2(4.2, 21), Vector2(15.8, 21)]:
		p(id, &"column_marble", c.x, c.y)
	p(id, &"rug_runner", 10, 26)
	p(id, &"rug_round", 10, 4)
	p(id, &"statue_maiden", 6.5, 30)
	p(id, &"statue_maiden", 13.5, 30)
	p(id, &"urn_flowers", 4, 30.8)
	p(id, &"urn_flowers", 16, 30.8)
	p(id, &"clock_grandfather", 0.6, 3, -90)
	p(id, &"sideboard", 19.5, 4, 90)
	p(id, &"vase_roses", 19.5, 4, 0, 1.0)
	p(id, &"mirror_gilt", 19.8, 4, 90, 1.3)
	p(id, &"bench_settle", 1.5, 27, -90)
	p(id, &"bench_settle", 18.5, 27, 90)
	p(id, &"potted_palm", 1.2, 31)
	p(id, &"potted_palm", 18.8, 31)
	p(id, &"floor_candlestand", 4.2, 23)
	p(id, &"floor_candlestand", 15.8, 23)
	p(id, &"coat_rack", 1.0, 30.5)
	p(id, &"bust_pedestal", 7, 1.0)
	p(id, &"bust_pedestal", 13, 1.0)
	p(id, &"painting_medium", 0.4, 14, -90, 1.5)
	wall_line(id, &"painting_large", "w", 4, 1.4, 1.0, 16.0, 31.0)
	wall_line(id, &"painting_large", "e", 4, 1.4, 1.0, 10.0, 31.0)
	p(id, &"flower_garland", 10, 31.8, 0, 3.4)
	p(id, &"vase_tall", 2.5, 1.0)
	p(id, &"vase_tall", 17.5, 1.0)

	id = &"library"
	hang(id, &"chandelier_crystal", 2)
	sconces(id, 6.0)
	wall_line(id, &"bookcase_tall", "w", 8)
	wall_line(id, &"bookcase_tall", "s", 8)
	wall_line(id, &"bookcase_tall", "n", 8, 0.0, 0.8, 0.8, 14.0)
	wall_line(id, &"bookcase_tall", "e", 2, 0.0, 0.8, 0.8, 5.0)
	p(id, &"library_ladder", 0.95, 5, -90)
	p(id, &"library_ladder", 0.95, 14, -90)
	p(id, &"library_ladder", 6, 19.05, 0)
	p(id, &"library_ladder", 16, 19.05, 0)
	p(id, &"rug_large", 9, 10)
	p(id, &"rug_round", 17, 15.5)
	p(id, &"table_round", 9, 10)
	for a in [0.0, 90.0, 180.0, 270.0]:
		var v := Vector2(0, 1.2).rotated(deg_to_rad(a))
		p(id, &"chair_dining", 9 + v.x, 10 + v.y, a)
	p(id, &"book_stack", 9, 10, 0, 0.75)
	p(id, &"candelabra", 9.4, 9.6, 0, 0.75)
	p(id, &"reading_lectern", 4, 10, -90)
	p(id, &"wingback_chair", 15.5, 15, 120)
	p(id, &"wingback_chair", 18, 13.2, 160)
	p(id, &"table_side", 17, 15.5)
	p(id, &"book_stack", 17, 15.5, 0, 0.7)
	p(id, &"window_seat", 10, 0.75, 180)
	p(id, &"cushion_pile", 10, 0.8, 0, 0.6)
	p(id, &"window_seat", 20.5, 0.75, 180)
	p(id, &"globe_stand", 4, 15.5)
	p(id, &"floor_candlestand", 14, 17.5)
	p(id, &"book_stack", 3, 17, 0)
	p(id, &"book_stack", 12.5, 5.5, 30)
	p(id, &"fern_pot", 13.5, 1.0)
	p(id, &"potted_roses", 21, 9)
	p(id, &"chaise_longue", 13.5, 9.5, 90)

	id = &"tamlin_study"
	hang(id, &"chandelier_small", 2)
	sconces(id, 4.0)
	p(id, &"tapestry_roses", 0.3, 11, -90, 0.9)
	p(id, &"map_wall", 9.7, 11, 90, 1.3)
	p(id, &"desk_large", 5, 5.5, 180)
	p(id, &"armchair", 5, 4.3, 180)
	p(id, &"candelabra", 4.2, 5.5, 0, 0.8)
	p(id, &"inkstand", 5.6, 5.6, 0, 0.8)
	p(id, &"book_stack", 6, 5.3, 0, 0.8)
	p(id, &"wingback_chair", 3.5, 8.5, 20)
	p(id, &"wingback_chair", 6.5, 8.5, -20)
	p(id, &"rug_large", 5, 7.5, 90)
	p(id, &"bookcase_tall", 0.5, 2.6, -90)
	p(id, &"bookcase_tall", 9.5, 2.6, 90)
	p(id, &"globe_stand", 8.6, 13)
	p(id, &"clock_grandfather", 1.2, 13.5, 0)
	p(id, &"cabinet_curio", 8.6, 4.8, 90)
	p(id, &"vase_roses", 5.6, 0.7, 0, 1.0)

	id = &"hidden_nook"
	p(id, &"rug_round", 5, 3)
	p(id, &"cushion_pile", 3, 2.6)
	p(id, &"cushion_pile", 4.2, 3.6)
	p(id, &"armchair", 7, 3, 90)
	p(id, &"table_side", 6, 4.4)
	p(id, &"candelabra", 6, 4.4, 0, 0.7)
	p(id, &"bookcase_low", 2.4, 5.5, 0)
	p(id, &"bookcase_low", 7.8, 5.5, 0)
	p(id, &"book_stack", 2.0, 4.4)
	p(id, &"book_stack", 3.6, 1.4)
	for x in [2.0, 5.0, 8.0]:
		p(id, &"faelight_orb", x, 3, 0, 2.6)
	p(id, &"painting_small", 9.7, 3, 90, 1.5)
	p(id, &"vase_roses", 2.4, 5.5, 0, 1.2)

	for cid in [&"west_corridor", &"east_corridor"]:
		hang(cid, &"chandelier_small", 4)
		wall_line(cid, &"candle_sconce", "n", 6, 1.9)
		wall_line(cid, &"candle_sconce", "s", 6, 1.9)
		for x in [5.0, 16.0, 27.0]:
			p(cid, &"rug_runner", x, 2, 90)
		wall_line(cid, &"painting_medium", "n", 7, 1.5)
		wall_line(cid, &"portrait_masked" if cid == &"east_corridor" else &"painting_medium", "s", 4, 1.4, 2.0)
		p(cid, &"vase_tall", 31.2, 0.8)
		p(cid, &"potted_roses", 0.8, 3.2)
		p(cid, &"bust_pedestal", 0.7, 0.8)
	R[&"east_corridor"].notes += " The masked portraits are sombre (tag: amarantha_curse)."

	id = &"map_room"
	hang(id, &"chandelier_small", 1)
	sconces(id, 4.0)
	p(id, &"map_table", 6, 5)
	p(id, &"candelabra", 5.2, 4.6, 0, 0.9)
	p(id, &"inkstand", 6.8, 5.2, 0, 0.9)
	for c in [Vector2(4.2, 5), Vector2(7.8, 5), Vector2(6, 3.6), Vector2(6, 6.4)]:
		p(id, &"chair_simple", c.x, c.y)
	p(id, &"map_wall", 0.3, 3, -90, 1.2)
	p(id, &"map_wall", 0.3, 7, -90, 1.2)
	p(id, &"globe_stand", 10.5, 1.5)
	p(id, &"scroll_rack", 3, 9.5, 0)
	p(id, &"scroll_rack", 9, 9.5, 0)
	p(id, &"bookcase_low", 11.5, 4, 90)
	p(id, &"rug_large", 6, 5)
	p(id, &"vase_roses", 11.5, 4, 0, 1.2)

	id = &"map_stairwell"
	for z in [2.0, 6.0]:
		p(id, &"candle_sconce", 0.4, z, -90, 2.2)
		p(id, &"candle_sconce", 3.6, z, 90, 2.2)
	p(id, &"lantern_hanging", 2, 9, 0, _ceiling(id) - 0.75)
	p(id, &"faelight_orb", 2, 4, 0, 3.4)
	p(id, &"painting_small", 3.7, 9, 90, 1.5)
	p(id, &"loose_panel", 0.3, 9.6, -90, 0.3)

	id = &"armory"
	hang(id, &"chandelier_small", 2)
	sconces(id, 4.0)
	wall_line(id, &"weapon_rack", "n", 3, 0.0, 0.8, 0.8, 4.4)
	wall_line(id, &"weapon_rack", "n", 2, 0.0, 0.8, 7.6, 15.2)
	for x in [3.0, 6.0, 9.0]:
		p(id, &"armor_stand", x, 9.4, 0)
	p(id, &"target_straw", 14.5, 2.0, 90)
	p(id, &"target_straw", 14.5, 8.0, 90)
	p(id, &"quiver_barrel", 1.5, 1.5)
	p(id, &"quiver_barrel", 1.2, 8.6)
	p(id, &"table_work", 7, 5)
	p(id, &"stool", 7, 6.1)
	p(id, &"chest_trunk", 12, 9.4)
	p(id, &"tapestry_roses", 15.7, 5, 90, 1.2)
	p(id, &"rug_runner", 9, 5, 90)

	id = &"drawing_room"
	hang(id, &"chandelier_crystal", 2)
	sconces(id, 5.0)
	p(id, &"rug_large", 6, 6, 90)
	p(id, &"rug_large", 8, 14)
	p(id, &"sofa", 4, 6, -90)
	p(id, &"armchair", 6.5, 3.8, 200)
	p(id, &"armchair", 6.5, 8.2, -20)
	p(id, &"table_tea", 5.5, 6, 90)
	p(id, &"cake_stand", 5.5, 6, 0, 0.5)
	p(id, &"sofa", 8, 15.5, 0)
	p(id, &"chaise_longue", 11.5, 12, 90)
	p(id, &"table_tea", 8, 13.8)
	p(id, &"vase_roses", 8, 13.8, 0, 0.5)
	p(id, &"window_seat", 4, 19.25, 0)
	p(id, &"window_seat", 12, 19.25, 0)
	p(id, &"cabinet_curio", 15.5, 3.5, 90)
	p(id, &"birdcage_gilt", 14.5, 17.5)
	p(id, &"pianoforte", 12.5, 4.5, 30)
	corners(id, &"potted_roses", 0.7)
	wall_line(id, &"painting_medium", "e", 3, 1.6, 1.0, 12.0, 19.0)
	p(id, &"mirror_gilt", 0.3, 6, -90, 2.8)

	id = &"music_room"
	hang(id, &"chandelier_crystal", 2)
	sconces(id, 5.0)
	p(id, &"rug_round", 9, 6.5)
	for row in 2:
		for c in 4:
			p(id, &"chair_dining", 6 + c * 1.2, 8.5 + row * 1.2, 180)
	p(id, &"music_stand", 3.5, 3.5, 150)
	p(id, &"music_stand", 12.5, 3.5, 200)
	p(id, &"music_stand", 9, 2.6, 180)
	p(id, &"lute_on_stand", 1.2, 9.5, -60)
	p(id, &"lute_on_stand", 18.8, 9.5, 60)
	p(id, &"sofa", 17, 10.9, 0)
	corners(id, &"potted_palm")
	p(id, &"vase_tall", 19.2, 4)
	p(id, &"bust_pedestal", 0.8, 4)
	wall_line(id, &"painting_medium", "s", 3, 1.6)

	id = &"morning_room"
	hang(id, &"chandelier_small", 1)
	sconces(id, 4.0)
	p(id, &"rug_round", 6, 5)
	p(id, &"table_round", 6, 5)
	for a in [0.0, 90.0, 180.0, 270.0]:
		var v := Vector2(0, 1.1).rotated(deg_to_rad(a))
		p(id, &"chair_dining", 6 + v.x, 5 + v.y, a)
	p(id, &"cake_stand", 6, 5, 0, 0.75)
	p(id, &"vase_roses", 6.4, 4.6, 0, 0.75)
	p(id, &"window_seat", 6, 0.75, 180)
	p(id, &"cushion_pile", 5.5, 0.8, 0, 0.6)
	p(id, &"sofa", 6, 10.9, 0)
	p(id, &"table_tea", 6, 9.6)
	p(id, &"birdcage_gilt", 11, 1.2)
	p(id, &"fern_pot", 1, 1)
	p(id, &"fern_pot", 11, 11)
	p(id, &"sideboard", 11.4, 6, 90)
	p(id, &"painting_medium", 11.7, 6, 90, 1.8)

	id = &"gallery"
	hang(id, &"chandelier_crystal", 3)
	wall_line(id, &"painting_large", "n", 8, 1.3)
	wall_line(id, &"painting_large", "s", 7, 1.3)
	wall_line(id, &"painting_medium", "w", 2, 1.5)
	wall_line(id, &"portrait_masked", "e", 2, 1.3)
	wall_line(id, &"painting_small", "n", 7, 3.3, 3.0)
	wall_line(id, &"candle_sconce", "n", 6, 2.0, 2.0)
	wall_line(id, &"candle_sconce", "s", 6, 2.0, 2.0)
	for x in [6.0, 16.0, 26.0]:
		p(id, &"statue_maiden", x, 4)
	for x in [11.0, 21.0]:
		p(id, &"bust_pedestal", x, 4)
		p(id, &"pouf_stool", x, 2.6)
		p(id, &"pouf_stool", x, 5.4)
	for x in [6.0, 16.0, 26.0]:
		p(id, &"rug_runner", x, 4, 90)
	p(id, &"statue_stag", 30, 4, 90)
	p(id, &"urn_flowers", 1.0, 1.0)
	p(id, &"urn_flowers", 1.0, 7.0)
	R[id].notes += " East-wall masked portraits are sombre (tag: amarantha_curse)."

	id = &"dining_hall"
	for x in [6.0, 11.0, 16.0]:
		p(id, &"chandelier_crystal", x, 10, 0, _ceiling(id) - 1.85)
	sconces(id, 5.0)
	p(id, &"rug_large", 8, 10, 90)
	p(id, &"rug_large", 14, 10, 90)
	p(id, &"table_dining_long", 11, 10)
	for i in 7:
		var x := 7.6 + i * 1.13
		p(id, &"chair_dining", x, 8.9, 0)
		p(id, &"chair_dining", x, 11.1, 180)
	p(id, &"chair_dining", 6.6, 10, 90)
	p(id, &"chair_dining", 15.4, 10, -90)
	for x in [8.0, 11.0, 14.0]:
		p(id, &"candelabra", x, 10, 0, 0.8)
	p(id, &"vase_roses", 9.5, 10, 0, 0.8)
	p(id, &"vase_roses", 12.5, 10, 0, 0.8)
	p(id, &"sideboard", 5, 0.6, 180)
	p(id, &"sideboard", 17, 0.6, 180)
	p(id, &"cake_stand", 5, 0.6, 0, 1.0)
	p(id, &"tapestry_roses", 11, 19.7, 0, 1.0)
	p(id, &"flower_garland", 11, 0.35, 180, 3.3)
	corners(id, &"potted_palm")
	wall_line(id, &"painting_large", "w", 2, 1.4, 1.0, 1.0, 8.0)
	wall_line(id, &"painting_large", "w", 2, 1.4, 1.0, 12.0, 19.0)

	id = &"butlers_pantry"
	hang(id, &"chandelier_small", 1)
	sconces(id, 4.0)
	p(id, &"dresser_crockery", 9.5, 2.5, 90)
	p(id, &"linen_press", 9.4, 6.2, 90)
	p(id, &"sideboard", 1.1, 3, -90)
	p(id, &"cake_stand", 1.1, 3, 0, 1.0)
	p(id, &"table_side", 7, 9)
	p(id, &"basket_produce", 7, 9, 0, 0.7)
	p(id, &"crate", 9.2, 9.2)
	p(id, &"copper_pots", 9.6, 2.5, 90, 2.4)
	p(id, &"vase_roses", 1.1, 7.5, 0, 0)

	id = &"china_room"
	hang(id, &"chandelier_small", 1)
	sconces(id, 4.0)
	wall_line(id, &"cabinet_curio", "w", 3)
	wall_line(id, &"cabinet_curio", "n", 2, 0.0, 0.8, 1.0, 6.0)
	p(id, &"table_work", 5.5, 5.5)
	p(id, &"candelabra", 5, 5.5, 0, 0.9)
	p(id, &"candelabra", 6, 5.5, 0, 0.9)
	p(id, &"chest_trunk", 8.5, 8.6)
	p(id, &"vase_tall", 9.2, 1)
	p(id, &"sideboard", 9.4, 5, 90)
	p(id, &"rug_round", 5.5, 5.5)


# --- furnishing: west wing --------------------------------------------------------

func _furnish_west_wing() -> void:
	var id := &"rose_corridor"
	hang(id, &"chandelier_small", 4)
	wall_line(id, &"candle_sconce", "n", 6, 1.9)
	wall_line(id, &"candle_sconce", "s", 6, 1.9)
	for x in [5.0, 16.0, 27.0]:
		p(id, &"rug_runner", x, 2, 90)
	wall_line(id, &"flower_garland", "n", 4, 3.4)
	wall_line(id, &"painting_medium", "n", 4, 1.5)
	p(id, &"potted_roses", 0.8, 0.8)
	p(id, &"potted_roses", 0.8, 3.2)

	id = &"ballroom"
	for c in [Vector2(6, 5), Vector2(16, 5), Vector2(6, 11), Vector2(16, 11)]:
		p(id, &"chandelier_crystal", c.x, c.y, 0, _ceiling(id) - 1.85)
	wall_line(id, &"mirror_gilt", "w", 4, 1.0)
	wall_line(id, &"mirror_gilt", "e", 3, 1.0)
	wall_line(id, &"pilaster", "n", 6)
	wall_line(id, &"candle_sconce", "n", 5, 2.2, 2.0)
	wall_line(id, &"chair_dining", "w", 6, 0.0, 1.5)
	wall_line(id, &"flower_garland", "s", 3, 3.4)
	corners(id, &"potted_palm")
	p(id, &"harp_gilt", 3, 2.5, 150)
	p(id, &"music_stand", 5, 2.2, 180)
	p(id, &"music_stand", 6.5, 2.2, 180)
	p(id, &"music_stand", 8, 2.2, 180)
	p(id, &"sofa", 20.4, 13, 90)
	p(id, &"sofa", 20.4, 3, 90)
	for c in [Vector2(2, 14.5), Vector2(20, 8)]:
		p(id, &"floor_candlestand", c.x, c.y)
	p(id, &"urn_flowers", 11, 1.0)
	p(id, &"statue_maiden", 11, 14.8)

	id = &"shrine"
	hang(id, &"chandelier_small", 2)
	sconces(id, 4.0)
	p(id, &"altar_marble", 5, 1.0, 180)
	p(id, &"candle_bank", 2.4, 0.6, 180)
	p(id, &"candle_bank", 7.6, 0.6, 180)
	p(id, &"statue_maiden", 5, 0.6, 180, 0.0, 0.8)
	p(id, &"vase_roses", 4.2, 1.0, 0, 1.1)
	p(id, &"vase_roses", 5.8, 1.0, 0, 1.1)
	for z in [5.0, 7.0, 9.0, 11.0]:
		p(id, &"pew", 2.4, z, 180)
		p(id, &"pew", 7.6, z, 180)
	p(id, &"rug_runner", 5, 8)
	p(id, &"potted_roses", 0.8, 15.2)
	p(id, &"potted_roses", 9.2, 15.2)
	p(id, &"tapestry_roses", 9.7, 4, 90, 1.0)

	id = &"conservatory"
	for x in [4.0, 9.0, 14.0]:
		p(id, &"lantern_hanging", x, 7, 0, _ceiling(id) - 0.75)
	p(id, &"fountain_small", 9, 7)
	for c in [Vector2(2, 2), Vector2(16, 2), Vector2(2, 12), Vector2(16, 12)]:
		p(id, &"orange_tree_tub", c.x, c.y)
	for c in [Vector2(5, 1.5), Vector2(13, 1.5), Vector2(5, 12.5), Vector2(13, 12.5)]:
		p(id, &"potted_palm", c.x, c.y)
	for c in [Vector2(1.2, 5), Vector2(1.2, 9), Vector2(16.8, 9.5), Vector2(9, 12.8)]:
		p(id, &"fern_pot", c.x, c.y)
	p(id, &"planter_box", 9, 3.5)
	p(id, &"planter_box", 9, 10.5)
	p(id, &"planter_box", 4.5, 7, 90)
	p(id, &"planter_box", 13.5, 7, 90)
	p(id, &"garden_bench", 6.5, 9, 30)
	p(id, &"garden_bench", 11.5, 5, 210)
	p(id, &"birdcage_gilt", 16.8, 4.5)
	p(id, &"potted_roses", 7, 12.8)
	p(id, &"potted_roses", 11, 12.8)
	p(id, &"arch_trellis", 9, 13.4)

	id = &"flower_room"
	hang(id, &"lantern_hanging", 2)
	sconces(id, 4.0)
	p(id, &"table_work", 4, 12.8)
	for x in [3.0, 4.0, 5.0]:
		p(id, &"vase_roses", x, 12.8, 0, 0.9)
	p(id, &"basket_produce", 1.2, 11.5)
	p(id, &"basket_produce", 6.8, 11.5)
	p(id, &"drying_rack_herbs", 7.45, 2.5, 90)
	p(id, &"herb_bundle_hanging", 7.6, 6, 90, 2.4)
	p(id, &"potted_roses", 1.2, 2)
	p(id, &"fern_pot", 1.2, 4.5)
	p(id, &"sink_stone", 1.1, 8, -90)
	p(id, &"urn_flowers", 7.2, 9.2)

	id = &"card_room"
	hang(id, &"chandelier_small", 1)
	sconces(id, 3.0)
	p(id, &"rug_round", 3, 4)
	p(id, &"table_round", 3, 4.2)
	for a in [0.0, 90.0, 180.0, 270.0]:
		var v := Vector2(0, 1.1).rotated(deg_to_rad(a))
		p(id, &"chair_dining", 3 + v.x, 4.2 + v.y, a)
	p(id, &"candelabra", 3, 4.2, 0, 0.75)
	p(id, &"cabinet_curio", 0.6, 4, -90)
	p(id, &"painting_small", 5.7, 3, 90, 1.6)
	p(id, &"painting_small", 5.7, 5.5, 90, 1.6)
	p(id, &"vase_roses", 5.2, 7.3)

	id = &"powder_room"
	hang(id, &"chandelier_small", 1)
	sconces(id, 3.0)
	p(id, &"vanity_table", 3.5, 5.4, 0)
	p(id, &"vanity_mirror", 3.5, 5.7, 0, 0.8)
	p(id, &"pouf_stool", 3.5, 4.5)
	p(id, &"perfume_tray", 3.1, 5.4, 0, 0.8)
	p(id, &"makeup_palette", 3.9, 5.4, 0, 0.8)
	p(id, &"jewelry_box", 4.5, 5.4, 0, 0.8)
	p(id, &"washstand", 5.5, 1.5, 90)
	p(id, &"towel_rack", 5.7, 3.2, 90)
	p(id, &"potted_roses", 1, 5.2)
	p(id, &"mirror_gilt", 0.3, 2.5, -90, 1.0)


# --- furnishing: cellars ------------------------------------------------------------

func _furnish_cellars() -> void:
	var id := &"wine_vault"
	hang(id, &"lantern_hanging", 4)
	sconces(id, 5.0)
	wall_line(id, &"wine_rack", "s", 9)
	wall_line(id, &"wine_rack", "e", 3, 0.0, 0.8, 9.6, 16.4)
	wall_line(id, &"wine_rack", "n", 3, 0.0, 0.8, 7.5, 15.0)
	for c in [Vector2(5, 6), Vector2(5, 11), Vector2(11, 6), Vector2(11, 11)]:
		p(id, &"barrel_rack", c.x, c.y)
	for c in [Vector2(1, 1), Vector2(1.9, 1), Vector2(1, 15.9), Vector2(16, 6), Vector2(16, 11), Vector2(17, 8.5)]:
		p(id, &"barrel", c.x, c.y)
	p(id, &"table_work", 15.5, 13.5)
	p(id, &"candelabra", 15.5, 13.5, 0, 0.9)
	p(id, &"stool", 14.5, 14.5)
	p(id, &"stool", 16.5, 14.5)
	p(id, &"crate", 23.5, 1.0)

	id = &"undercroft"
	hang(id, &"lantern_hanging", 3)
	sconces(id, 6.0)
	for x in [4.0, 10.0, 16.0, 22.0]:
		p(id, &"column_marble", x, 2.0, 0, 0, 0.8)
		p(id, &"column_marble", x, 7.0, 0, 0, 0.8)
	p(id, &"rug_runner", 7, 4.5, 90)
	p(id, &"rug_runner", 17, 4.5, 90)
	p(id, &"bench_settle", 1.2, 6.8, -90)
	p(id, &"urn_flowers", 12, 8.3)
	p(id, &"barrel", 22.8, 8.2)
	p(id, &"crate", 1.0, 1.0)

	id = &"preserves_cellar"
	hang(id, &"lantern_hanging", 2)
	sconces(id, 5.0)
	wall_line(id, &"pantry_shelf", "s", 4)
	wall_line(id, &"pantry_shelf", "w", 2, 0.0, 0.8, 2.5, 7.5)
	p(id, &"table_work", 6, 4)
	p(id, &"basket_produce", 5.4, 4, 0, 0.9)
	p(id, &"basket_produce", 6.6, 4, 0, 0.9)
	p(id, &"barrel", 10.8, 1.2)
	p(id, &"barrel", 10.8, 2.2)
	p(id, &"sack_flour", 2.5, 1.0)
	p(id, &"sack_flour", 3.2, 1.0)

	id = &"cheese_cellar"
	hang(id, &"lantern_hanging", 2)
	sconces(id, 5.0)
	wall_line(id, &"cheese_shelf", "s", 4)
	wall_line(id, &"cheese_shelf", "n", 2, 0.0, 0.8, 0.8, 4.5)
	p(id, &"table_kitchen", 6, 4)
	p(id, &"basket_produce", 6, 4, 0, 0.9)
	p(id, &"barrel", 1.2, 6)
	p(id, &"barrel", 11, 1.2)
	p(id, &"crate", 9.5, 1.2)

	id = &"old_storerooms"
	hang(id, &"lantern_hanging", 3)
	sconces(id, 6.0)
	wall_line(id, &"pantry_shelf", "s", 3, 0.0, 0.8, 4.0, 15.2)
	for c in [Vector2(3, 3), Vector2(3.9, 3.2), Vector2(3.4, 4), Vector2(12, 12), Vector2(12.9, 12.2), Vector2(2, 15.5)]:
		p(id, &"crate", c.x, c.y, c.x * 37.0)
	for c in [Vector2(7, 8), Vector2(9, 8), Vector2(14, 6)]:
		p(id, &"chest_trunk", c.x, c.y, 15)
	p(id, &"wardrobe_tall", 15.3, 9, 90)
	p(id, &"dressing_screen", 8, 11.5, 10)
	p(id, &"mirror_gilt", 8, 12, 190)
	p(id, &"statue_stag", 6, 4, 30)
	p(id, &"coat_rack", 1.2, 9)
	p(id, &"barrel", 1.2, 12)
	p(id, &"sack_flour", 14.8, 2)
	p(id, &"armchair", 11, 4, 200)

	id = &"old_tunnel"
	hang(id, &"lantern_hanging", 6)
	for z in [3.0, 9.0, 15.0, 33.0]:
		p(id, &"candle_sconce", 0.4, z, -90, 1.7)
	for z in [3.0, 15.0, 19.0, 36.0]:
		p(id, &"candle_sconce", 5.6, z, 90, 1.7)
	for z in [6.0, 12.0, 31.0, 35.0]:
		p(id, &"faelight_orb", 3, z, 0, 2.6)
	p(id, &"crate", 1.0, 1.0)
	p(id, &"crate", 1.0, 1.8)
	p(id, &"barrel", 5.0, 10.0)
	p(id, &"crate", 1.2, 31)

	id = &"well_chamber"
	hang(id, &"lantern_hanging", 3)
	sconces(id, 6.0)
	p(id, &"fountain_small", 3.5, 13)
	p(id, &"bench_settle", 1.0, 13, -90)
	p(id, &"barrel", 6, 2)
	p(id, &"barrel", 6, 24)
	p(id, &"crate", 1, 24.5)
	for z in [5.0, 13.0, 21.0]:
		p(id, &"faelight_orb", 3.5, z, 0, 2.4)
	p(id, &"fern_pot", 1.0, 9)
	p(id, &"fern_pot", 6.0, 17)

	id = &"strongroom"
	hang(id, &"lantern_hanging", 2)
	sconces(id, 4.0)
	for c in [Vector2(1.2, 2), Vector2(1.2, 4), Vector2(1.2, 8), Vector2(1.2, 10), Vector2(5.5, 1)]:
		p(id, &"chest_trunk", c.x, c.y, 90)
	p(id, &"cabinet_curio", 3.5, 11.5, 0)
	p(id, &"jewelry_box", 1.2, 2, 0, 0.7)
	p(id, &"jewelry_box", 1.2, 8, 0, 0.7)
	p(id, &"candelabra", 5.5, 1, 0, 0.7)
	p(id, &"rug_round", 3.5, 6)

	id = &"candle_store"
	hang(id, &"lantern_hanging", 3)
	sconces(id, 6.0)
	wall_line(id, &"pantry_shelf", "n", 4)
	wall_line(id, &"pantry_shelf", "e", 2, 0.0, 0.8, 14.0, 20.0)
	p(id, &"candle_bank", 6, 6)
	p(id, &"candle_bank", 10, 6)
	for c in [Vector2(3, 10), Vector2(4, 10), Vector2(13, 16)]:
		p(id, &"candelabra", c.x, c.y)
	p(id, &"floor_candlestand", 2, 16)
	p(id, &"floor_candlestand", 3, 16)
	p(id, &"chandelier_small", 9, 14)
	p(id, &"table_work", 8, 10)
	for c in [Vector2(14, 2.5), Vector2(14.6, 3.3), Vector2(6, 19.8), Vector2(10, 19.8)]:
		p(id, &"crate", c.x, c.y)
	p(id, &"barrel", 1.2, 20)

	id = &"cider_cellar"
	hang(id, &"lantern_hanging", 3)
	sconces(id, 6.0)
	wall_line(id, &"barrel_rack", "e", 4, 0.0, 0.8, 0.8, 9.0)
	wall_line(id, &"barrel_rack", "n", 2)
	for c in [Vector2(3, 6), Vector2(3.8, 6), Vector2(3.4, 6.7), Vector2(10, 16), Vector2(10.8, 16), Vector2(2, 19.5)]:
		p(id, &"barrel", c.x, c.y)
	p(id, &"table_work", 6.5, 12)
	p(id, &"stool", 5.5, 13.1)
	p(id, &"stool", 7.5, 13.1)
	for x in [5.8, 6.5, 7.2]:
		p(id, &"basket_produce", x, 12, 0, 0.9)
	p(id, &"crate", 12.5, 19.8)

	id = &"mask_vault"
	hang(id, &"lantern_hanging", 2)
	wall_line(id, &"mask_display", "w", 6, 1.5)
	wall_line(id, &"mask_display", "n", 2, 1.5)
	wall_line(id, &"candle_sconce", "e", 3, 1.7, 2.0, 1.0, 9.0)
	p(id, &"portrait_masked", 9.7, 16, 90, 1.2)
	p(id, &"portrait_masked", 9.7, 4, 90, 1.2)
	for z in [5.0, 10.5, 16.0]:
		p(id, &"cabinet_curio", 5, z, 90)
	p(id, &"candle_bank", 5, 1.0, 180)
	p(id, &"statue_maiden", 5, 19.5)
	p(id, &"chest_trunk", 8.4, 19.6)
	p(id, &"chest_trunk", 1.6, 19.6)

	id = &"painting_store"
	hang(id, &"lantern_hanging", 3)
	sconces(id, 6.0)
	for c in [Vector2(2, 2), Vector2(2, 5), Vector2(10, 14), Vector2(10, 17), Vector2(6, 19.8), Vector2(3, 19.8)]:
		p(id, &"canvas_stack", c.x, c.y)
	wall_line(id, &"painting_large", "n", 3, 0.0, 1.0)
	wall_line(id, &"painting_medium", "e", 3, 0.2, 1.0, 1.0, 9.0)
	wall_line(id, &"painting_medium", "w", 2, 0.2, 1.0, 13.0, 20.0)
	p(id, &"easel", 6, 9, 200)
	p(id, &"easel", 8, 12, 160)
	p(id, &"dressing_screen", 4, 14, 20)
	p(id, &"paint_table", 6, 5.5)
	p(id, &"pigment_jars", 6, 5.5, 0, 0.85)
	p(id, &"chest_trunk", 10.5, 8)

	id = &"cold_store"
	hang(id, &"lantern_hanging", 3)
	sconces(id, 6.0)
	wall_line(id, &"pantry_shelf", "n", 4)
	wall_line(id, &"cheese_shelf", "e", 3, 0.0, 0.8, 4.0, 20.0)
	for c in [Vector2(2, 16), Vector2(2.8, 16), Vector2(2.4, 16.7)]:
		p(id, &"barrel", c.x, c.y)
	for c in [Vector2(6, 8), Vector2(6.8, 8), Vector2(6.4, 8.6), Vector2(9, 19.6)]:
		p(id, &"crate", c.x, c.y)
	for x in [5.0, 5.6, 6.2]:
		p(id, &"sack_flour", x, 19.6)
	for c in [Vector2(8, 12), Vector2(8.7, 12), Vector2(8.3, 12.5)]:
		p(id, &"basket_produce", c.x, c.y)
	p(id, &"herb_bundle_hanging", 6, 0.4, 180, 2.4)
	p(id, &"herb_bundle_hanging", 9, 0.4, 180, 2.4)

	id = &"west_undercroft"
	hang(id, &"lantern_hanging", 2)
	sconces(id, 5.0)
	p(id, &"column_marble", 2.5, 2.5, 0, 0, 0.8)
	p(id, &"column_marble", 10.5, 6.5, 0, 0, 0.8)
	p(id, &"bench_settle", 1.2, 10, -90)
	p(id, &"crate", 11.8, 12)
	p(id, &"barrel", 11.8, 1.2)
	p(id, &"pantry_shelf", 9.5, 12.5, 0)
	p(id, &"urn_flowers", 2.5, 12)

	id = &"seed_cellar"
	hang(id, &"lantern_hanging", 2)
	sconces(id, 5.0)
	wall_line(id, &"pantry_shelf", "w", 3)
	p(id, &"planter_box", 6.5, 4)
	p(id, &"planter_box", 6.5, 9)
	p(id, &"planter_box", 10, 6.5, 90)
	for c in [Vector2(3, 12), Vector2(3.7, 12), Vector2(4.4, 12)]:
		p(id, &"basket_produce", c.x, c.y)
	p(id, &"sack_flour", 11.8, 12)
	p(id, &"sack_flour", 11.2, 12.2)
	p(id, &"herb_bundle_hanging", 6.5, 0.4, 180, 2.4)
	p(id, &"drying_rack_herbs", 12.4, 2.5, 90)
	p(id, &"table_work", 8, 11.8)
	p(id, &"faelight_orb", 6.5, 6.5, 0, 2.5)
	p(id, &"fern_pot", 1.2, 1.2)

	id = &"ancestral_crypt"
	sconces(id, 4.0)
	for c in [Vector2(3.5, 4), Vector2(9.5, 4), Vector2(3.5, 9), Vector2(9.5, 9)]:
		p(id, &"altar_marble", c.x, c.y, 90)
		p(id, &"vase_roses", c.x, c.y, 0, 1.1)
	p(id, &"statue_maiden", 6.5, 0.8, 180)
	p(id, &"statue_maiden", 0.8, 13.5, -90)
	p(id, &"candle_bank", 6.5, 1.6, 180)
	p(id, &"candle_bank", 12.4, 12, 90)
	p(id, &"bust_pedestal", 12.3, 3)
	for z in [3.0, 7.0, 11.0]:
		p(id, &"faelight_orb", 6.5, z, 0, 2.5)
	p(id, &"rug_runner", 6.5, 9)

	id = &"costume_store"
	hang(id, &"lantern_hanging", 3)
	sconces(id, 5.0)
	wall_line(id, &"gown_rack", "n", 3)
	for x in [3.0, 6.0, 9.0]:
		p(id, &"mannequin_gown", x, 6)
	for c in [Vector2(1.2, 9), Vector2(1.2, 12), Vector2(11.8, 13.6)]:
		p(id, &"chest_trunk", c.x, c.y, 90)
	p(id, &"hat_stand", 11.5, 4)
	p(id, &"hat_stand", 11.5, 7)
	p(id, &"mask_display", 12.7, 10, 90, 1.5)
	p(id, &"mask_display", 0.3, 5, -90, 1.5)
	p(id, &"dressing_screen", 6, 11)
	p(id, &"mirror_gilt", 7, 14.6, 0, 0.5)
	p(id, &"shoe_shelf", 3.5, 14.5, 0)


# --- exterior dressing ----------------------------------------------------------------

## A flight of `n` stone steps from the floor (0.9 m above ground) down to the
## ground, leaving the facade at world z `z_edge` and running in `dir` (+1 south,
## -1 north), `width` wide around world x `cx`, after a `landing` deep top platform.
func flight(id: StringName, cx: float, z_edge: float, dir: float, width: float, landing: float, n: int = 6) -> void:
	var tiles := int(ceil(width / 4.0))
	for k in range(-1, n):
		var front: float = landing + (k + 1) * 0.35 if k >= 0 else 3.0
		var top := -0.15 * maxi(k, 0)
		var cz := z_edge + dir * (front - 1.5)
		for t in tiles:
			var x := cx - width * 0.5 + 2.0 + t * 4.0
			pw(id, &"stone_steps", x, cz, 0.0, top - 1.8)


func _exterior() -> void:
	var id := &"front_portico"
	flight(id, 0.0, -28.0, 1.0, 12.0, 3.6)
	for x in [-5.0, -3.0, 3.0, 5.0]:
		pw(id, &"column_marble", x, -25.2)
	pw(id, &"flower_garland", 0, -28.15, 0, 3.6)
	pw(id, &"garden_urn", -5.5, -27.2)
	pw(id, &"garden_urn", 5.5, -27.2)
	pw(id, &"balustrade", -6.6, -26, 90)
	pw(id, &"balustrade", 6.6, -26, 90)
	for x in [-7.5, 7.5]:
		pw(id, &"lamp_post", x, -23, 0, -0.9)
		pw(id, &"urn_flowers", x, -21.5, 0, -0.9)
	for x in [-38.0, -30.0, -22.0, -14.0, 14.0, 22.0, 30.0, 38.0]:
		pw(id, &"potted_roses", x, -27.4, 0, -0.9)
		pw(id, &"flower_garland", x, -27.9, 0, 3.6)
	for x in [-41.0, 41.0]:
		pw(id, &"pilaster", x, -27.85, 0, -0.9)
		pw(id, &"orange_tree_tub", x, -26.5, 0, -0.9)

	id = &"garden_facade"
	for x in [0.0, -24.0, 24.0]:
		flight(id, x, -72.0, -1.0, 4.0, 1.2)
		pw(id, &"orange_tree_tub", x - 3.2, -73.0, 0, -0.9)
		pw(id, &"orange_tree_tub", x + 3.2, -73.0, 0, -0.9)
		pw(id, &"flower_garland", x, -71.85, 180, 3.4)
	for x in [-36.0, -12.0, 12.0, 36.0]:
		pw(id, &"potted_roses", x, -72.6, 0, -0.9)

	id = &"west_facade"
	for z in [-64.0, -56.0, -44.0, -38.0]:
		pw(id, &"orange_tree_tub", -75.0, z, 0, -0.9)
		pw(id, &"flower_garland", -74.15, z, 90, 3.4)
	for z in [-60.0, -50.0, -41.0]:
		pw(id, &"potted_roses", -74.8, z, 0, -0.9)

	id = &"west_south_facade"
	for x in [-70.0, -62.0, -54.0, -46.0]:
		pw(id, &"garden_urn", x, -33.2, 0, -0.9)
		pw(id, &"flower_garland", x + 4.0, -33.85, 0, 3.4)
	for x in [-66.0, -58.0, -50.0]:
		pw(id, &"potted_roses", x, -33.3, 0, -0.9)


# --- stations and secrets -----------------------------------------------------------

func _stations() -> void:
	dsl.station(&"hearth", "Dining Hall Hearth", 0, Vector3(31.3, 0, -38), &"fireplace_grand", 90, "C")
	dsl.station(&"hearth", "Drawing Room Hearth", 0, Vector3(-25.3, 0, -42), &"fireplace_grand", -90, "C?")
	dsl.station(&"hearth", "Study Hearth", 0, Vector3(-15, 0, -71.3), &"fireplace_small", 180, "C")
	dsl.station(&"hearth", "Library Hearth", 0, Vector3(-20.75, 0, -60), &"fireplace_grand", 90, "C?")
	dsl.station(&"library_desk", "Library Writing Desk", 0, Vector3(-31, 0, -66), &"desk_writing", 180, "C?")
	dsl.station(&"harp", "Gilt Harp", 0, Vector3(23, 0, -68), &"harp_gilt", 200)
	dsl.station(&"pianoforte", "Pearl Pianoforte", 0, Vector3(15, 0, -68), &"pianoforte", 160)
	dsl.station(&"armory_rack", "Yew Longbow Rack", 0, Vector3(-41.45, 0, -33), &"bow_rack", -90, "C?")


func _secrets() -> void:
	dsl.secret(&"library_bookcase", &"lever", 0, Vector3(-20.6, 1.6, -57.4), &"", &"book_stack",
			"A tilting rose-red book; opens the bookcase passage to the hidden reading nook.")
	dsl.secret(&"study_hearth", &"lever", 0, Vector3(-13.6, 1.4, -58.5), &"", &"secret_lever",
			"A carved rose on the cold fireplace's mantel; the fireplace swings into the hidden nook.")
	dsl.secret(&"map_panel", &"lever", 0, Vector3(-41.6, 1.6, -43.4), &"", &"secret_lever",
			"A gold pin in the Spring Court on the wall map; opens the east panel to the hidden stairwell.")
	dsl.secret(&"map_panel", &"lever", 0, Vector3(-29.6, 1.3, -38.6), &"", &"loose_panel",
			"Inside the stairwell: the same panel from behind.")
	dsl.secret(&"mask_vault", &"lever", 0, Vector3(41.6, 1.2, -56), &"", &"secret_lever",
			"Behind the masked portrait at the gallery's east end; unseals the false wall in the cellar painting store (mask vault).")
	dsl.secret(&"nook_violet", &"keepsake", 0, Vector3(-17.2, 0.1, -53.0), &"col_pressed_violet", &"",
			"Pressed in a book in the hidden nook.")
	dsl.secret(&"conservatory_pebble", &"keepsake", 0, Vector3(-72.8, 0.1, -43), &"col_painted_pebble", &"",
			"Under the fern by the conservatory's west windows.")
	dsl.secret(&"costume_thimble", &"keepsake", -1, Vector3(-46.5, 0.6, -56), &"col_silver_thimble", &"",
			"On a costume chest in the masquerade store.")
	dsl.secret(&"ballroom_brooch", &"keepsake", 0, Vector3(-73.2, 0.1, -67.2), &"col_rose_brooch", &"",
			"Lost behind a ballroom palm.")
	dsl.secret(&"strongroom_coin", &"keepsake", -1, Vector3(-37.8, 0.75, -61), &"col_old_gold_coin", &"",
			"In an open chest in the old strongroom.")
	dsl.secret(&"crypt_rose", &"discovery", -1, Vector3(-64.5, 0.0, -57.5), &"", &"",
			"The ancestral crypt: white roses for Tamlin's mother.")
