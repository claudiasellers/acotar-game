## The Manor Estate's site plan: where every part of the estate sits.
##
## Shared contract for everyone building the estate. Coordinates are WORLD
## coordinates in metres (World lane frame: +X east, -Z north, +Y up, origin at
## the centre of the manor's forecourt). Areas are Rect2 in the XZ plane:
## Rect2(x, z, width, depth). Pad heights are fixed: builders read the ground
## from ManorTerrain.height_at() and never assume a value of their own.
class_name ManorSitePlan
extends RefCounted

const REGION_GROUNDS := &"manor_grounds"
const REGION_HOUSE := &"manor_house"

## Whole estate (docs/contracts/world.md §1). The Border Woods own z > +300,
## the Rosewild z < -500, the Eastern Woods x > 650.
const BOUNDS := Rect2(-600.0, -500.0, 1200.0, 800.0)
## Outer band that fades into the World lane's macro height.
const EDGE_FADE := 64.0

## Feyre arrives up the drive from the Border Woods and first sees the house.
const SPAWN := Vector3(0.0, 0.0, 120.0)
const SPAWN_FACING_DEG := 180.0

# --- The house -------------------------------------------------------------
const FORECOURT_CENTER := Vector2(0.0, 0.0)
const FORECOURT_RADIUS := 26.0
## Main block: the front facade faces south onto the forecourt at z = -28.
const HOUSE_MAIN := Rect2(-42.0, -72.0, 84.0, 44.0)
## Service wing (kitchens, servants' hall, stillroom) off the east side.
const HOUSE_SERVICE := Rect2(42.0, -68.0, 32.0, 34.0)
## West wing (ballroom, conservatory, chapel) off the west side, mirroring the service wing.
const HOUSE_WEST := Rect2(-74.0, -68.0, 32.0, 34.0)
## Cellar rooms must stay inside these (3 m in from the outer walls), so the
## ground-floor slab hides where the terrain drops into the cellar pit.
const CELLAR_ZONES: Array[Rect2] = [Rect2(-39.0, -69.0, 78.0, 38.0), Rect2(45.0, -65.0, 26.0, 28.0), Rect2(-71.0, -65.0, 26.0, 28.0)]
## Garden terrace along the north facade, steps down into the rose garden.
const TERRACE := Rect2(-48.0, -88.0, 96.0, 16.0)
const FRONT_DOOR := Vector3(0.0, 0.0, -28.0)
## Ground floor level (top of the plinth) relative to the house pad.
const HOUSE_FLOOR_Y := 0.9
const HOUSE_STOREY := 4.8
const CELLAR_DEPTH := 4.0

# --- Gardens (gardens lane) ------------------------------------------------
const ROSE_GARDEN := Rect2(-80.0, -200.0, 160.0, 108.0)
const HEDGE_MAZE := Rect2(-260.0, -250.0, 84.0, 84.0)
const GLASS_HOUSES := Rect2(105.0, -200.0, 70.0, 104.0)
const KITCHEN_GARDEN := Rect2(90.0, -80.0, 72.0, 62.0)

# --- Grounds (grounds lane) ------------------------------------------------
const STABLES := Rect2(-165.0, -62.0, 70.0, 62.0)
const PADDOCK := Rect2(-310.0, -90.0, 125.0, 130.0)
const POND_CENTER := Vector2(190.0, 110.0)
const POND_RADII := Vector2(58.0, 40.0)
const POND_DEPTH := 2.6
## Pad height of the ground round the pond (relative to base_y).
const POND_PAD := -0.6
const WALLED_ORCHARD := Rect2(-300.0, 95.0, 115.0, 115.0)
## The drive runs from the forecourt south to the Border Woods road.
const DRIVE_START := Vector2(0.0, 26.0)
const DRIVE_END := Vector2(0.0, 300.0)
const DRIVE_WIDTH := 7.0

# --- Wider estate (grounds lane fills, life lane scatters) -----------------
const SOUTH_LAWNS := Rect2(-330.0, 40.0, 660.0, 250.0)
const EAST_MEADOW := Rect2(240.0, -330.0, 300.0, 310.0)
const WEST_DOWNS := Rect2(-540.0, -330.0, 220.0, 310.0)
const DEER_PARK := Rect2(-170.0, -440.0, 340.0, 230.0)
## Wooded hills along the north edge, toward the Rosewild region.
const NORTH_HILLS := Rect2(-540.0, -495.0, 1080.0, 150.0)
const BELVEDERE_HILL := Vector2(400.0, -400.0)


## Flat building pads: [Rect2 area, pad height, blend distance in metres].
## The terrain eases from the natural ground to the pad height over the blend.
static var _base_y: float = NAN


## Height of the estate's reference level (pad height 0) above world zero:
## the macro land height at the forecourt, so the estate sits in the shared map.
static func base_y() -> float:
	if is_nan(_base_y):
		_base_y = MacroHeight.land_height_at(FORECOURT_CENTER.x, FORECOURT_CENTER.y)
	return _base_y


## Pad heights below are relative to base_y().
static func pads() -> Array:
	# Later pads win where blends overlap, so the house pad comes last.
	return [
		[ROSE_GARDEN.grow(2.0), -1.8, 30.0],               # rose garden sits one flight below the terrace
		[HEDGE_MAZE.grow(8.0), -1.0, 30.0],
		[GLASS_HOUSES.grow(6.0), -1.2, 26.0],
		[STABLES.grow(10.0), 0.4, 30.0],
		[WALLED_ORCHARD.grow(6.0), 1.6, 34.0],
		[Rect2(POND_CENTER - POND_RADII * 1.45, POND_RADII * 2.9), POND_PAD, 40.0],   # level ground round the pond
		[Rect2(-30.0, -30.0, 60.0, 60.0), 0.0, 20.0],      # forecourt
		[Rect2(-100.0, -90.0, 270.0, 126.0), 0.0, 12.0],    # house, terrace, service yard, kitchen garden
		[HOUSE_MAIN.grow(-1.0), -CELLAR_DEPTH - 0.6, 1.0],  # cellar pit under the house (hidden by its floor)
		[HOUSE_SERVICE.grow(-1.0), -CELLAR_DEPTH - 0.6, 1.0],
		[HOUSE_WEST.grow(-1.0), -CELLAR_DEPTH - 0.6, 1.0],
	]


## Forage and collectible conventions (agreed with the gameplay lane):
## - nodes in group "forage" with harvest() -> StringName (empty = nothing to take);
## - dense scatter nodes in group "forage_field" with pick_nearest(world_pos, radius) -> StringName;
## - ing_ ids for anything in the lore ingredient catalogue (feathers, shells too),
##   col_ ids for keepsakes (col_pressed_violet, col_painted_pebble, ...).
const FORAGE_GROUP := &"forage"
const FORAGE_FIELD_GROUP := &"forage_field"

## Named zones used for forage and life scatter. Each entry: zone id -> [Rect2, biome].
## Biomes: formal_garden, rose_beds, hedge, glasshouse, kitchen_garden, lawn,
## meadow, orchard, pond_edge, stable_yard, paddock, woodland_edge, interior.
static func zones() -> Dictionary:
	return {
		&"rose_garden": [ROSE_GARDEN, &"rose_beds"],
		&"hedge_maze": [HEDGE_MAZE, &"hedge"],
		&"glass_houses": [GLASS_HOUSES, &"glasshouse"],
		&"kitchen_garden": [KITCHEN_GARDEN, &"kitchen_garden"],
		&"stables": [STABLES, &"stable_yard"],
		&"paddock": [PADDOCK, &"paddock"],
		&"pond": [Rect2(POND_CENTER - POND_RADII * 1.35, POND_RADII * 2.7), &"pond_edge"],
		&"walled_orchard": [WALLED_ORCHARD, &"orchard"],
		&"south_lawns": [SOUTH_LAWNS, &"lawn"],
		&"east_meadow": [EAST_MEADOW, &"meadow"],
		&"west_downs": [WEST_DOWNS, &"meadow"],
		&"deer_park": [DEER_PARK, &"lawn"],
		&"north_hills": [NORTH_HILLS, &"woodland_edge"],
		&"east_woods_edge": [Rect2(540.0, -495.0, 58.0, 790.0), &"woodland_edge"],
		&"west_woods_edge": [Rect2(-598.0, -495.0, 58.0, 790.0), &"woodland_edge"],
	}


## Areas where scatter (trees, forage, life) must not land: buildings, paths, water.
static func keep_out() -> Array[Rect2]:
	return [
		HOUSE_MAIN.grow(4.0), HOUSE_SERVICE.grow(4.0), HOUSE_WEST.grow(4.0), TERRACE,
		Rect2(FORECOURT_CENTER - Vector2.ONE * FORECOURT_RADIUS, Vector2.ONE * FORECOURT_RADIUS * 2.0),
		STABLES, Rect2(DRIVE_START.x - DRIVE_WIDTH, DRIVE_START.y, DRIVE_WIDTH * 2.0, DRIVE_END.y - DRIVE_START.y),
	]


static func is_kept_out(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for area in keep_out():
		if area.has_point(p):
			return true
	return in_pond(x, z, 1.0)


## Gravel: the drive, the forecourt and the terrace. Garden paths are meshes.
static func is_on_path(x: float, z: float) -> bool:
	if absf(x - DRIVE_START.x) < DRIVE_WIDTH * 0.5 and z > DRIVE_START.y and z < DRIVE_END.y:
		return true
	if Vector2(x, z).distance_to(FORECOURT_CENTER) < FORECOURT_RADIUS:
		return true
	return TERRACE.has_point(Vector2(x, z))


## True inside the pond's water ellipse (scale > 1 grows it).
static func in_pond(x: float, z: float, scale: float = 1.0) -> bool:
	var d := (Vector2(x, z) - POND_CENTER) / (POND_RADII * scale)
	return d.length_squared() < 1.0
