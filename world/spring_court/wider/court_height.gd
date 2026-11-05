## The Spring Court beyond the estate: one height function for the nine
## wider-court regions and the court's edge (docs/lanes/wider-court-terrain.md).
##
## Drawn from the book, not from a noise preset: "a land of rolling green hills
## and lush forests and clear, bottomless lakes" (ch 19), knolls marked by a
## single tree, clear streams and tiny brooks, a sunken hollow ringed by steep
## knolls round the starlight pool, the trench between two hills that ends in a
## cave mouth, the plateau above a vast low meadow, the pathless ancient woods
## of the west on moss that swallows sound, and the ground lifting into rougher
## hills toward the Autumn border.
##
## Layers, in order (each is code, nothing is baked into git):
##   1. a smooth design field on a 16 m grid (DESIGN_GRID): each region's base
##      level and character, the big hills and the court's rising rim;
##   2. noise for the bumps and hollows ("magic grew there"), scaled by region;
##   3. exact landforms, bucketed: knolls, hollows, pads, the trench, the
##      bonfire terraces, the Autumn scarp, the western gorge, rim fronts;
##   4. the Thornwater's valley and channel at designed levels; brooks that
##      only ever run downhill; lakes that find their own level; paths graded
##      into sunken lanes where the ground is steep;
##   5. a 140 m blend back to MacroHeight at every other lane's edge, so the
##      estate, the woods and the human realm keep their ground exactly.
##
## Public API (stable): height_at, texture_at, lakes, river_level_at,
## RIVER_WATER_DEPTH, prewarm; plus brooks, distance_to_brook, sites, gates,
## paths and the provider rectangles (DOMAIN).
class_name CourtHeight
extends RefCounted

const RIVER_WATER_DEPTH := 0.5
## Metres over which our ground eases back to MacroHeight at another lane's edge.
const BLEND := 140.0
const GRID := 16.0
const MAP_X0 := -2048.0
const MAP_Z0 := -2048.0
const MAP_X1 := 2048.0
const MAP_Z1 := 1400.0
const BUCKET := 128.0

## The rectangles this provider owns ([min_x, min_z, max_x, max_z]): the map
## south of nothing and north of the Wall, minus every other lane's ground.
## Registered with fade 0: we blend to MacroHeight ourselves (FOREIGN), so the
## seams between our own rectangles never pinch down to the macro height.
const DOMAIN := [
	[-2048.0, -2048.0, -950.0, 1400.0],
	[-950.0, -2048.0, -700.0, 450.0],
	[-950.0, 800.0, -700.0, 1400.0],
	[-700.0, -2048.0, -600.0, 300.0],
	[-600.0, -2048.0, 650.0, -500.0],
	[650.0, -2048.0, 2048.0, -650.0],
	[1850.0, -650.0, 2048.0, 550.0],
	[500.0, 550.0, 2048.0, 1400.0],
	[500.0, 500.0, 650.0, 550.0],
]

## Other lanes' ground (and the unowned seam beside the estate): we meet
## MacroHeight at these edges.
const FOREIGN := [
	[-600.0, -500.0, 650.0, 300.0],   # manor estate + the manor/eastern-woods seam
	[500.0, 300.0, 650.0, 500.0],     # estate's south-east corner (no provider)
	[-700.0, 300.0, 500.0, 1400.0],   # border woods
	[650.0, -650.0, 1850.0, 550.0],   # eastern woods
	[-950.0, 450.0, -700.0, 800.0],   # suriel glade
	[-4096.0, 1400.0, 4096.0, 4096.0], # human realm, beyond the Wall
]

# --- design: region character -------------------------------------------------
## Region classes (texture and noise character).
enum Kind { ROSE, MEADOW, HILL, BLIGHT, AUTUMN, VILLAGE, GLEN, WOODS, VALE, RIM }

## [kind, rects, base level, roll amp, hummock amp, root-ridge amp]. Rects are
## soft (ZONE_SOFT wide transitions); map-border edges reach far past the map
## so they never count as a boundary, and a zone's rects overlap each other by
## more than half the transition so their shared edges never dip.
const ZONE_SOFT := 150.0
const ZONES := [
	[Kind.WOODS, [[-4000.0, -900.0, -1500.0, 4000.0], [-1600.0, 600.0, -700.0, 4000.0]], 36.0, 3.5, 1.4, 1.8],
	[Kind.GLEN, [[-1500.0, -500.0, -600.0, 600.0]], 36.0, 12.0, 2.6, 0.3],
	[Kind.VILLAGE, [[-1500.0, -1250.0, -600.0, -500.0]], 46.0, 9.0, 1.1, 0.3],
	[Kind.AUTUMN, [[-4000.0, -4000.0, -600.0, -1250.0], [-4000.0, -1350.0, -1500.0, -900.0]], 50.0, 24.0, 4.5, 7.0],
	[Kind.ROSE, [[-600.0, -800.0, 500.0, -500.0], [400.0, -700.0, 650.0, -500.0]], 18.0, 5.5, 3.6, 0.0],
	[Kind.MEADOW, [[-600.0, -1350.0, 300.0, -800.0]], 26.0, 6.0, 1.4, 0.0],
	[Kind.HILL, [[300.0, -1500.0, 1300.0, -800.0], [500.0, -900.0, 1300.0, -700.0], [650.0, -800.0, 1300.0, -650.0]], 34.0, 11.0, 2.2, 0.4],
	[Kind.BLIGHT, [[-600.0, -4000.0, 1745.0, -1500.0], [-600.0, -1600.0, 300.0, -1350.0], [1300.0, -1600.0, 1745.0, -650.0]], 28.0, 17.0, 3.2, 1.0],
	[Kind.VALE, [[500.0, 500.0, 1585.0, 4000.0]], 0.0, 5.5, 1.6, 0.0],
	[Kind.RIM, [[1745.0, -4000.0, 4000.0, -560.0], [1880.0, -760.0, 4000.0, 660.0], [1585.0, 540.0, 4000.0, 4000.0]], 40.0, 14.0, 3.0, 6.0],
]

## Big smooth hills folded into the design grid: [cx, cz, radius, height, power].
const HILLS := [
	[-1630.0, -640.0, 340.0, 138.0, 1.7],   # the towering hill (North Watchtower)
	[-1250.0, -1560.0, 260.0, 110.0, 1.5],  # the Ember Crown
	[-1660.0, -1440.0, 300.0, 80.0, 1.5],   # the autumn shoulder
	[-850.0, -1520.0, 220.0, 54.0, 1.5],    # the rust hills east of the crown
	[870.0, -1140.0, 380.0, 104.0, 1.3],    # the Hill of the Rite's crown (the east's weenie)
	[1120.0, -860.0, 160.0, 26.0, 1.6],     # the rite's eastern foothill
	[1080.0, -1360.0, 150.0, 22.0, 1.6],    # the rite's northern foothill
	[440.0, -1260.0, 140.0, 20.0, 1.6],     # the rite's western foothill
	[-150.0, -1060.0, 200.0, 34.0, 1.4],    # the solstice plateau's hill
	[150.0, -890.0, 120.0, 18.0, 1.6],      # meadow hill (east)
	[-320.0, -880.0, 95.0, 14.0, 1.6],      # meadow hill (west)
	[-760.0, -70.0, 170.0, 22.0, 1.6],      # the glen brae: "down the hill" from the manor
	[-930.0, -930.0, 170.0, 26.0, 1.5],     # the lantern brae behind the village green
	[-1250.0, -700.0, 200.0, 24.0, 1.5],    # the village's west bank
	[-1380.0, 0.0, 220.0, 18.0, 1.5],       # the glen's west swell
	[1000.0, -1650.0, 180.0, 14.0, 1.4],    # blight: the long hill over the heart
	[300.0, -1560.0, 160.0, 12.0, 1.4],     # blight: the pass road's shoulder
]

# --- exact landforms (bucketed) ----------------------------------------------
## Knolls and hollows: [kind 0 knoll / 1 hollow, cx, cz, radius, height, power].
const FORMS := [
	# Starlight Glen: the sunken hollow ringed by steep knolls (ch 18).
	[1, -1300.0, 262.0, 95.0, 12.0, 1.2],
	[0, -1208.0, 270.0, 30.0, 21.0, 0.9],   # the mound: "we stopped atop a mound"
	[0, -1236.0, 196.0, 30.0, 16.0, 1.6],
	[0, -1300.0, 166.0, 32.0, 18.0, 1.6],
	[0, -1366.0, 194.0, 30.0, 17.0, 1.6],
	[0, -1394.0, 262.0, 34.0, 24.0, 2.2],   # the glimmer crag: the rainbow falls leave its lip
	[0, -1364.0, 330.0, 30.0, 16.0, 1.6],
	[0, -1300.0, 360.0, 32.0, 18.0, 1.6],
	[0, -1234.0, 336.0, 28.0, 14.0, 1.6],
	# Knolls of the glen: "clambered up steep knolls".
	[0, -1080.0, 40.0, 26.0, 10.0, 1.6], [0, -1130.0, 140.0, 30.0, 12.0, 1.6],
	[0, -1160.0, 215.0, 22.0, 8.0, 1.6], [0, -1030.0, 190.0, 22.0, 8.0, 1.6],
	[0, -1200.0, -300.0, 30.0, 12.0, 1.6], [0, -1350.0, -280.0, 36.0, 14.0, 1.6],
	[0, -1430.0, 120.0, 30.0, 11.0, 1.6], [0, -1000.0, -420.0, 28.0, 10.0, 1.6],
	[0, -865.0, -255.0, 46.0, 15.0, 1.4],   # the oak knoll (the picnic, ch 18)
	[1, -1250.0, -140.0, 150.0, 8.0, 1.0],  # Looking Lake's dish
	[1, -1150.0, 430.0, 60.0, 4.0, 1.0],    # Willow Mere's dish
	# The western woods: root cradles and dark dips, one towering hill.
	[1, -1520.0, -400.0, 90.0, 6.0, 1.0],   # dish for the pond of watchers
	[0, -1650.0, 300.0, 70.0, 10.0, 1.4],   # the middle rise
	[0, -1150.0, 1150.0, 55.0, 12.0, 1.5],  # the foot knoll
	[1, -1300.0, 900.0, 28.0, 5.0, 1.3], [1, -1000.0, 1100.0, 22.0, 4.0, 1.3],
	[1, -1700.0, 820.0, 30.0, 6.0, 1.3], [1, -1600.0, 1150.0, 26.0, 5.0, 1.3],
	[1, -1250.0, 1250.0, 24.0, 4.0, 1.3], [1, -1450.0, 1000.0, 40.0, 3.0, 1.1],
	[1, -1720.0, -100.0, 34.0, 5.0, 1.3], [1, -1560.0, 120.0, 26.0, 4.0, 1.3],
	# The Hill of the Rite: the first foothill, the trench's other hill, the
	# soft hillside the cave is cut into, the solitary sycamore's knoll (ch 20).
	[0, 620.0, -1055.0, 95.0, 24.0, 1.3],
	[0, 640.0, -905.0, 85.0, 18.0, 1.3],
	[0, 752.0, -985.0, 75.0, 20.0, 1.2],
	[0, 520.0, -880.0, 34.0, 12.0, 1.6],
	# The village: the bank the potion house stands on, and the two knolls the
	# road threads between (they hide the green until the pinch: a triangle).
	[0, -1007.0, -886.0, 70.0, 12.5, 1.2],
	[0, -770.0, -835.0, 70.0, 20.0, 1.5],
	[0, -805.0, -660.0, 60.0, 16.0, 1.5],
	# The glen brae's southern partner: the way west crosses the saddle between.
	[0, -790.0, 110.0, 85.0, 18.0, 1.5],
	# The Rosewild: hummocks and shallow hollows, nothing steep.
	[0, -320.0, -660.0, 40.0, 8.0, 1.5],    # the rose spire's knoll
	[0, 240.0, -700.0, 50.0, 6.0, 1.4],     # the gardener's folly rise
	[1, -480.0, -560.0, 30.0, 4.0, 1.2],    # the briar dell
	[1, 150.0, -615.0, 45.0, 3.0, 1.0],     # the hollow pool's dish
	[0, -100.0, -590.0, 26.0, 4.0, 1.5], [0, 60.0, -720.0, 30.0, 5.0, 1.5],
	[0, 420.0, -560.0, 34.0, 5.0, 1.5], [1, 330.0, -760.0, 34.0, 3.0, 1.2],
	# The Solstice Meadow: the wisp hollow in the vast meadow.
	[1, -420.0, -1250.0, 60.0, 2.5, 1.0],
	# Blossom Vale: the bee knoll, the spring at the head, the mill pond's dish.
	[0, 760.0, 820.0, 55.0, 13.0, 1.5],
	[1, 1010.0, 578.0, 35.0, 3.0, 1.0],
	[1, 1040.0, 875.0, 35.0, 3.0, 1.0],
	[0, 1300.0, 1300.0, 60.0, 9.0, 1.4],
	# The Blighted Reaches: ordinary rolling hills; one hollow where it is quietest.
	[1, 1500.0, -1100.0, 60.0, 6.0, 1.2],
	[0, 640.0, -1580.0, 70.0, 12.0, 1.4], [0, 1420.0, -1520.0, 80.0, 14.0, 1.4],
]

## Flattened ground: [cx, cz, inner radius, outer radius, level (NAN = the
## ground there before any pad)], applied in order.
const PADS := [
	[-1630.0, -640.0, 60.0, 90.0, NAN],    # the towering hill's crown: tower + sentry range
	[-150.0, -1060.0, 60.0, 95.0, NAN],    # the solstice plateau
	[620.0, -1055.0, 22.0, 40.0, NAN],     # the first giant bonfire
	[870.0, -1140.0, 75.0, 120.0, NAN],    # the broad bald crown
	[-930.0, -800.0, 56.0, 70.0, 44.5],    # the village green
	[-1300.0, 262.0, 34.0, 52.0, NAN],     # the starlight clearing
	[-960.0, -245.0, 55.0, 85.0, NAN],     # the oak glade below the knoll
	[1150.0, 660.0, 28.0, 45.0, NAN],      # the glamour glade (anchor glamour_lift_glade)
	[-1210.0, -985.0, 18.0, 30.0, NAN],    # the village mill yard
	[1000.0, 880.0, 16.0, 28.0, NAN],      # the old cider mill's yard
	[300.0, -1680.0, 7.0, 12.0, NAN],      # the pass road (anchor the_pass_road)
	[-1650.0, 300.0, 20.0, 34.0, NAN],     # the middle watchtower
	[-1150.0, 1150.0, 14.0, 26.0, NAN],    # the foot watchtower
	[760.0, 820.0, 12.0, 22.0, NAN],       # the bee tower
	[-320.0, -660.0, 10.0, 20.0, NAN],     # the rose spire
	[240.0, -700.0, 16.0, 30.0, NAN],      # the gardener's folly
	[-1250.0, -1560.0, 30.0, 55.0, NAN],   # the Ember Crown's top (seen, never reached)
]

## Flats: [cx, cz, radius x, radius z, edge, level], ellipses with a wandering
## rim. The vast low meadow (ch 25): "the high grasses moved like water".
const FLATS := [
	[-170.0, -1272.0, 410.0, 80.0, 70.0, 21.0],
	[-470.0, -1090.0, 100.0, 220.0, 70.0, 21.0],
	[60.0, -1240.0, 170.0, 95.0, 60.0, 21.0],
]

## The trench between two hills, ending in the cave mouth (ch 20):
## [ax, az, bx, bz, floor at a, floor at b, floor half-width, bank slope].
const TRENCH := [470.0, -990.0, 690.0, -982.0, 46.0, 49.5, 4.0, 1.0]

## The bonfire terraces on the crown's south-west flank (ch 20: "dozens of
## bonfires that popped up along the far hills"): [cx, cz, angle (deg, x->z),
## half-angle, inner r, outer r, step, strength].
const TERRACES := [870.0, -1140.0, 140.5, 38.0, 115.0, 235.0, 7.0, 0.9]

## The Autumn border is sealed in this build: its ground lifts into rougher
## hills and stands on a crag band (the Rust Scarp) along every edge it shares.
const SCARP_IN := 14.0
const SCARP_WIDTH := 6.0
const SCARP_RISE := 26.0

## The court's edge: west, the woods end at a lip over a misty gorge with
## mountains beyond; north and east, the land climbs into steep hills.
const WEST_LIP := -1788.0
const GORGE_DEPTH := 72.0
const NORTH_RIM := -1742.0
## Where the rim's front comes south to take the pass gate (the_pass, z -1694)
## into its notch: [x, how far south, half-width].
const PASS_BULGE := [300.0, 56.0, 110.0]
## The pass road's canyon through the rim: [floor half-width, wall foot].
const PASS_CANYON := [3.5, 8.0]
const EAST_RIM_N := 1745.0
const EAST_RIM_S := 1585.0
const EAST_RIM_WOODS := 1882.0

# --- water --------------------------------------------------------------------
## The Thornwater's water level along MacroHeight.THORNWATER ([arclength m,
## level m]); levels are only used where we own the ground. The falls where it
## leaves the Autumn hills follow the scarp line itself (FALLS).
const RIVER_PROFILE := [
	[0.0, 112.0], [377.5, 68.0], [378.5, 47.0], [531.0, 44.0], [955.0, 40.0],
	[1015.0, 39.6], [1457.0, 33.0], [1979.0, 26.0], [2148.0, 22.0], [2371.0, 19.1],
	[3929.0, -1.1], [4439.0, -2.6], [4924.0, -4.0], [5390.0, -6.0],
]
## [arclength of the crossing, level above, level below, reach either side].
const FALLS := [378.0, 68.0, 47.0, 140.0]
## Valley shape along the river: [arclength, flat half-width beyond the channel, side slope].
const VALLEY := [
	[0.0, 6.0, 0.6], [360.0, 6.0, 0.7], [420.0, 22.0, 0.2], [900.0, 30.0, 0.16],
	[1100.0, 26.0, 0.16], [1500.0, 45.0, 0.1], [2100.0, 30.0, 0.14], [2400.0, 20.0, 0.2],
	[3929.0, 40.0, 0.1], [4924.0, 50.0, 0.08], [5100.0, 10.0, 0.6], [5390.0, 8.0, 0.7],
]
const CHANNEL := 7.0  # MacroHeight.RIVER_HALF_WIDTH

## Brooks: [id, half-width, points]. Their levels are worked out from the
## ground (only ever downhill) when the terrain warms up.
const BROOKS := [
	[&"brae_brook", 1.4, [[-800.0, -430.0], [-850.0, -300.0], [-878.0, -170.0], [-892.0, -40.0], [-905.0, 80.0], [-938.0, 148.0]]],
	[&"glimmer_brook", 1.6, [[-1180.0, 432.0], [-1260.0, 424.0], [-1318.0, 400.0], [-1332.0, 345.0], [-1316.0, 306.0], [-1303.0, 281.0]]],
	[&"mere_run", 1.8, [[-1116.0, 430.0], [-1040.0, 418.0], [-960.0, 405.0], [-872.0, 400.0]]],
	[&"lake_run", 1.8, [[-1172.0, -140.0], [-1120.0, -132.0], [-1070.0, -126.0], [-1042.0, -122.0]]],
	[&"briar_brook", 1.2, [[-180.0, -880.0], [-140.0, -790.0], [-80.0, -710.0], [0.0, -660.0], [80.0, -628.0], [133.0, -616.0]]],
	[&"vale_stream", 2.2, [[1010.0, 590.0], [1005.0, 700.0], [995.0, 800.0], [990.0, 900.0], [992.0, 990.0]]],
	[&"mill_brook", 1.4, [[-1150.0, -1236.0], [-1172.0, -1150.0], [-1192.0, -1060.0], [-1203.0, -1012.0]]],
	[&"watchers_run", 1.2, [[-1474.0, -398.0], [-1420.0, -380.0], [-1330.0, -372.0], [-1230.0, -350.0], [-1130.0, -352.0], [-1097.0, -360.0]]],
]
const BROOK_DEPTH := 0.25  # water over the brook bed

## Lakes: [id, cx, cz, radius, depth (clear, bottomless: a shelf then a steep
## drop-off), islet dx, dz, radius]. Levels are found from the shore.
const LAKES := [
	[&"looking_lake", -1250.0, -140.0, 85.0, 28.0, -20.0, -15.0, 14.0],
	[&"pond_of_watchers", -1520.0, -400.0, 46.0, 22.0, 0.0, 0.0, 0.0],
	[&"starlight_pool", -1300.0, 262.0, 18.0, 7.0, 0.0, 0.0, 0.0],
	[&"willow_mere", -1150.0, 430.0, 32.0, 12.0, 0.0, 0.0, 0.0],
	[&"hollow_pool", 150.0, -615.0, 20.0, 6.0, 0.0, 0.0, 0.0],
	[&"mill_pond", 1040.0, 875.0, 18.0, 5.0, 0.0, 0.0, 0.0],
]

# --- ways ---------------------------------------------------------------------
## Paths: [id, half-width, points]. Graded at PATH_GRADE, cut-only: on steep
## ground they sink into hollow-ways, through a scarp they cut a notch.
const PATH_GRADE := 0.28
const PATHS := [
	[&"briar_lane", 2.5, [[0.0, -496.0], [-25.0, -580.0], [-60.0, -650.0], [-110.0, -740.0], [-142.0, -822.0], [-150.0, -930.0], [-150.0, -1010.0]]],
	[&"wisp_way", 1.5, [[-170.0, -1080.0], [-220.0, -1130.0], [-280.0, -1195.0], [-340.0, -1255.0]]],
	[&"village_road", 2.5, [[-470.0, -496.0], [-560.0, -600.0], [-680.0, -700.0], [-790.0, -748.0], [-880.0, -775.0], [-930.0, -790.0]]],
	[&"glen_way", 2.0, [[-596.0, -90.0], [-700.0, -40.0], [-790.0, 12.0], [-880.0, 40.0], [-960.0, 70.0], [-995.0, 105.0], [-1060.0, 170.0], [-1130.0, 228.0], [-1192.0, 268.0]]],
	[&"west_bank", 1.8, [[-1076.0, -760.0], [-1200.0, -720.0], [-1300.0, -600.0], [-1400.0, -500.0], [-1440.0, -455.0]]],
	[&"river_road", 2.5, [[-930.0, -790.0], [-1000.0, -768.0], [-1030.0, -680.0], [-1040.0, -560.0], [-1030.0, -420.0], [-990.0, -300.0], [-930.0, -200.0], [-900.0, -60.0], [-890.0, 0.0], [-880.0, 40.0]]],
	[&"lake_walk", 1.5, [[-1000.0, -300.0], [-1100.0, -228.0], [-1150.0, -200.0]]],
	[&"rite_way", 2.5, [[450.0, -496.0], [540.0, -560.0], [572.0, -640.0], [562.0, -720.0], [555.0, -790.0], [548.0, -830.0], [545.0, -920.0], [560.0, -990.0], [600.0, -1035.0], [620.0, -1050.0]]],
	[&"crown_way", 2.5, [[620.0, -1050.0], [680.0, -1090.0], [740.0, -1120.0], [800.0, -1138.0], [860.0, -1140.0]]],
	[&"vale_lane", 2.5, [[560.0, 302.0], [565.0, 420.0], [575.0, 500.0], [620.0, 580.0], [670.0, 645.0], [720.0, 700.0], [800.0, 740.0], [900.0, 780.0], [970.0, 840.0], [1000.0, 880.0]]],
	[&"glade_track", 1.5, [[900.0, 780.0], [1010.0, 710.0], [1100.0, 672.0], [1150.0, 660.0]]],
	[&"sealed_road", 2.0, [[-930.0, -790.0], [-905.0, -900.0], [-893.0, -1050.0], [-896.0, -1180.0], [-900.0, -1240.0], [-900.0, -1300.0]]],
	[&"reaches_road", 2.5, [[1500.0, -640.0], [1520.0, -800.0], [1480.0, -1000.0], [1450.0, -1250.0], [1350.0, -1450.0], [1100.0, -1580.0], [800.0, -1610.0], [500.0, -1640.0], [300.0, -1665.0], [300.0, -1700.0], [300.0, -1820.0], [300.0, -2040.0]]],
]
## The towering hill's path winds up round it (built in _ensure).
const TOWER_SPIRAL := [-1630.0, -640.0, 312.0, 52.0, 1.55, 1.25]  # cx, cz, r0, r1, turns, start angle (rad)
## The climb keeps this far south of the Autumn border (z), off the scarp.
const TOWER_NORTH_LIMIT := -868.0

## Gates on the ways out (RegionGate locks, built by CourtRegion from content).
## Each stands in a chokepoint: two steep knolls pinch the way (GATE_PINCH),
## except the Sealed Pass, which is a notch through the Rust Scarp.
## [owner region, the region whose CourtMap.UNLOCK_PHASE opens it, x, z, width].
## Yaw follows the path at the gate.
const GATES := [
	[&"rosewild", &"rosewild", -60.0, -650.0, 12.0],              # the Briar Gate (p2_grounds)
	[&"starlight_glen", &"starlight_glen", -790.0, 12.0, 12.0],   # the brae saddle
	[&"fae_village", &"fae_village", -790.0, -748.0, 12.0],       # between the village knolls
	[&"hill_of_the_rite", &"hill_of_the_rite", 555.0, -790.0, 12.0], # the rite way
	[&"blossom_vale", &"blossom_vale", 720.0, 700.0, 12.0],       # the vale's rim
	[&"solstice_meadow", &"solstice_meadow", -142.0, -822.0, 12.0], # the plateau's foot
	[&"autumn_foothills", &"autumn_foothills", -900.0, -1278.0, 12.0], # the Sealed Pass notch
]

## Sites that keep their natural slope (no clearing of their own).
const NO_PAD := [&"potion_house", &"lantern_bridge", &"thornwater_falls", &"sealed_pass", &"calanmai_cave_mouth",
	&"cave_of_the_rite", &"west_brink", &"glimmerfall", &"rainbow_cascade", &"looking_lake_isle", &"briar_gate",
	&"rite_trench", &"bonfire_terraces", &"the_mound", &"arch_avenue", &"vale_weir", &"thornwater_ford", &"summers_window"]

## Pinch knolls either side of each gate: [radius, height, power, gap beyond
## the gate's half-width].
const GATE_PINCH := [30.0, 15.0, 1.9, 3.0]

## Named ground the terrain was shaped for (landmarks, anchors, nooks):
## id -> [x, z, region, kind]. Kinds: landmark, anchor, nook, water.
const SITES := {
	# Western Woods (region id western_fells)
	&"north_watchtower": [-1630.0, -650.0, &"western_fells", &"landmark"],
	&"fells_sentry_range": [-1616.0, -650.0, &"western_fells", &"anchor"],
	&"pond_of_watchers": [-1520.0, -400.0, &"western_fells", &"water"],
	&"middle_watchtower": [-1650.0, 300.0, &"western_fells", &"landmark"],
	&"foot_watchtower": [-1150.0, 1150.0, &"western_fells", &"landmark"],
	&"summers_window": [-1762.0, 700.0, &"western_fells", &"landmark"],
	&"silent_hollow": [-1300.0, 900.0, &"western_fells", &"landmark"],
	&"rainbow_cascade": [-1786.0, 560.0, &"western_fells", &"landmark"],
	&"old_shrines": [-1640.0, 120.0, &"western_fells", &"landmark"],
	&"west_brink": [-1770.0, 180.0, &"western_fells", &"nook"],
	&"root_cradle": [-1450.0, 1000.0, &"western_fells", &"nook"],
	&"black_dip": [-1700.0, 820.0, &"western_fells", &"nook"],
	&"fern_cleft": [-1000.0, 1100.0, &"western_fells", &"nook"],
	&"watchers_ledge": [-1520.0, -470.0, &"western_fells", &"nook"],
	# Starlight Glen
	&"starlight_pool": [-1300.0, 262.0, &"starlight_glen", &"water"],
	&"glimmerfall": [-1374.0, 262.0, &"starlight_glen", &"landmark"],
	&"the_mound": [-1208.0, 270.0, &"starlight_glen", &"nook"],
	&"oak_knoll": [-865.0, -255.0, &"starlight_glen", &"nook"],
	&"oak_glade": [-960.0, -245.0, &"starlight_glen", &"landmark"],
	&"looking_lake": [-1250.0, -140.0, &"starlight_glen", &"water"],
	&"looking_lake_isle": [-1270.0, -155.0, &"starlight_glen", &"nook"],
	&"willow_mere": [-1150.0, 430.0, &"starlight_glen", &"water"],
	&"weeping_lady": [-1125.0, 456.0, &"starlight_glen", &"landmark"],
	&"heron_stones": [-1105.0, -40.0, &"starlight_glen", &"landmark"],
	&"brae_top": [-760.0, -70.0, &"starlight_glen", &"nook"],
	&"knoll_steps": [-1130.0, 140.0, &"starlight_glen", &"nook"],
	&"thornwater_ford": [-995.0, 105.0, &"starlight_glen", &"nook"],
	# Village of the Lesser Fae
	&"village_green": [-930.0, -800.0, &"fae_village", &"landmark"],
	&"great_lantern_tree": [-925.0, -792.0, &"fae_village", &"landmark"],
	&"potion_house": [-977.0, -853.0, &"fae_village", &"landmark"],
	&"lantern_bridge": [-1060.0, -762.0, &"fae_village", &"landmark"],
	&"village_mill": [-1210.0, -985.0, &"fae_village", &"landmark"],
	&"seamstress": [-890.0, -835.0, &"fae_village", &"landmark"],
	&"market": [-895.0, -778.0, &"fae_village", &"landmark"],
	&"cottages": [-968.0, -760.0, &"fae_village", &"landmark"],
	&"thornwater_falls": [-1440.0, -1262.0, &"fae_village", &"landmark"],
	&"lantern_brae_top": [-930.0, -930.0, &"fae_village", &"nook"],
	&"orchard_bank": [-1320.0, -700.0, &"fae_village", &"nook"],
	&"sealed_road_bend": [-893.0, -1050.0, &"fae_village", &"nook"],
	# The Autumn border (sealed)
	&"sealed_pass": [-900.0, -1292.0, &"autumn_foothills", &"landmark"],
	&"ember_crown": [-1250.0, -1560.0, &"autumn_foothills", &"landmark"],
	&"thornwater_spring": [-1690.0, -1545.0, &"autumn_foothills", &"landmark"],
	&"border_markers": [-1000.0, -1258.0, &"autumn_foothills", &"landmark"],
	# Rosewild
	&"briar_gate": [-60.0, -650.0, &"rosewild", &"landmark"],
	&"rose_spire": [-320.0, -660.0, &"rosewild", &"landmark"],
	&"gardeners_folly": [240.0, -700.0, &"rosewild", &"landmark"],
	&"hollow_pool": [150.0, -615.0, &"rosewild", &"water"],
	&"briar_dell": [-480.0, -560.0, &"rosewild", &"nook"],
	&"thorn_hollow": [330.0, -760.0, &"rosewild", &"nook"],
	&"hummock_seat": [420.0, -560.0, &"rosewild", &"nook"],
	# Solstice Meadow
	&"solstice_dance_floor": [-150.0, -1060.0, &"solstice_meadow", &"anchor"],
	&"dance_ring": [-150.0, -1080.0, &"solstice_meadow", &"landmark"],
	&"musicians_bower": [-112.0, -1100.0, &"solstice_meadow", &"landmark"],
	&"long_tables": [-100.0, -1035.0, &"solstice_meadow", &"landmark"],
	&"arch_avenue": [-150.0, -1000.0, &"solstice_meadow", &"landmark"],
	&"crown_oak": [40.0, -1235.0, &"solstice_meadow", &"landmark"],
	&"vast_meadow": [-250.0, -1270.0, &"solstice_meadow", &"landmark"],
	&"wisp_hollow": [-420.0, -1250.0, &"solstice_meadow", &"nook"],
	&"meadow_hill_east": [150.0, -890.0, &"solstice_meadow", &"nook"],
	&"meadow_hill_west": [-320.0, -880.0, &"solstice_meadow", &"nook"],
	# Hill of the Rite
	&"stone_ring": [870.0, -1140.0, &"hill_of_the_rite", &"landmark"],
	&"calanmai_bonfires": [620.0, -1055.0, &"hill_of_the_rite", &"anchor"],
	&"calanmai_cave_mouth": [690.0, -982.0, &"hill_of_the_rite", &"anchor"],
	&"cave_of_the_rite": [692.0, -982.0, &"hill_of_the_rite", &"landmark"],
	&"bonfire_terraces": [735.0, -1029.0, &"hill_of_the_rite", &"landmark"],
	&"drum_field": [585.0, -845.0, &"hill_of_the_rite", &"landmark"],
	&"rite_trench": [600.0, -985.0, &"hill_of_the_rite", &"nook"],
	&"sycamore_knoll": [520.0, -880.0, &"hill_of_the_rite", &"nook"],
	&"north_foothill": [1080.0, -1360.0, &"hill_of_the_rite", &"nook"],
	# Blighted Reaches
	&"the_pass_road": [300.0, -1680.0, &"blighted_reaches", &"anchor"],
	&"hollow_steading": [300.0, -1600.0, &"blighted_reaches", &"landmark"],
	&"dead_sentinel": [900.0, -1600.0, &"blighted_reaches", &"landmark"],
	&"grey_briar_wall": [-200.0, -1550.0, &"blighted_reaches", &"landmark"],
	&"blight_heart": [1500.0, -1600.0, &"blighted_reaches", &"landmark"],
	&"still_hollow": [1500.0, -1100.0, &"blighted_reaches", &"nook"],
	&"the_long_hill": [1000.0, -1650.0, &"blighted_reaches", &"nook"],
	&"quiet_knoll": [640.0, -1580.0, &"blighted_reaches", &"nook"],
	# Blossom Vale
	&"glamour_lift_glade": [1150.0, 660.0, &"blossom_vale", &"anchor"],
	&"bee_tower": [760.0, 820.0, &"blossom_vale", &"landmark"],
	&"cider_mill": [1000.0, 880.0, &"blossom_vale", &"landmark"],
	&"mill_pond": [1040.0, 875.0, &"blossom_vale", &"water"],
	&"blossom_cathedral": [900.0, 750.0, &"blossom_vale", &"landmark"],
	&"vale_weir": [1350.0, 1140.0, &"blossom_vale", &"landmark"],
	&"vale_head_spring": [1010.0, 578.0, &"blossom_vale", &"nook"],
	&"orchard_knoll": [1300.0, 1300.0, &"blossom_vale", &"nook"],
	&"south_meadow": [1100.0, 1300.0, &"blossom_vale", &"nook"],
}

## What you see from where (the weenies and the triangles): [from site or
## [x, z], to site, how tall the thing standing there is (m), true = seen /
## false = hidden]. Eye height 1.7 m. tests/unit/landscape/test_court_terrain.gd
## holds the court to it.
const SIGHTLINES := [
	# The North Watchtower on the towering hill is the west's weenie.
	[[-850.0, 30.0], &"north_watchtower", 28.0, true],
	[&"brae_top", &"north_watchtower", 28.0, true],
	[&"village_green", &"north_watchtower", 28.0, true],
	[&"the_mound", &"north_watchtower", 28.0, true],
	# The Rite's crown is the east's; the Ember Crown lures from the north-west.
	[[0.0, -496.0], &"stone_ring", 12.0, true],
	[&"solstice_dance_floor", &"stone_ring", 12.0, true],
	[&"sycamore_knoll", &"calanmai_bonfires", 10.0, true],
	[&"lantern_brae_top", &"ember_crown", 14.0, true],
	[&"solstice_dance_floor", &"ember_crown", 14.0, true],
	# The Rose Spire calls you north out of the gardens.
	[[0.0, -496.0], &"rose_spire", 24.0, true],
	# Triangles: the brae hides the glen and its pool; the plateau hides the
	# vast meadow; the village knolls hide the green; the vale's rim hides the vale.
	[[-596.0, -90.0], &"starlight_pool", 0.0, false],
	[[-596.0, -90.0], &"looking_lake", 0.0, false],
	[[0.0, -496.0], &"vast_meadow", 0.0, false],
	[[-180.0, -1112.0], &"vast_meadow", 0.0, true],
	[[-596.0, -90.0], &"village_green", 0.0, false],
	# The village knolls frame the Great Lantern Tree through their pinch.
	[[-640.0, -690.0], &"great_lantern_tree", 30.0, true],
	[[575.0, 480.0], &"bee_tower", 4.0, false],
	[[760.0, 720.0], &"bee_tower", 16.0, true],
	[[500.0, -660.0], &"rite_trench", 0.0, false],
	# The mound overlooks the clearing; the pool is hidden until you top it.
	[&"the_mound", &"starlight_pool", 0.0, true],
	[[-1100.0, 228.0], &"starlight_pool", 0.0, false],
	# The heart of the blight shows itself from the reaches road.
	[[1450.0, -1250.0], &"blight_heart", 20.0, true],
]

# --- state (built once, read from any thread) ---------------------------------
static var _mutex := Mutex.new()
static var _ready := false
static var _warp: FastNoiseLite
static var _roll: FastNoiseLite
static var _hum: FastNoiseLite
static var _ridge: FastNoiseLite
static var _dip: FastNoiseLite
static var _crag: FastNoiseLite
static var _wobble: FastNoiseLite
## FORMS plus the knoll fields generated in _build.
static var _forms: Array = []
## PADS plus a small clearing at every named site that has none.
static var _pads: Array = []
static var _gw := 0
static var _gh := 0
static var _g_level := PackedFloat32Array()
static var _g_roll := PackedFloat32Array()
static var _g_hum := PackedFloat32Array()
static var _g_ridge := PackedFloat32Array()
static var _g_kind := PackedByteArray()
static var _bw := 0
static var _bh := 0
static var _b_forms: Array[PackedInt32Array] = []
static var _b_pads: Array[PackedInt32Array] = []
static var _b_river: Array[PackedInt32Array] = []
static var _b_brooks: Array[PackedInt32Array] = []
static var _b_paths: Array[PackedInt32Array] = []
static var _pad_levels := PackedFloat32Array()
static var _river_s0 := PackedFloat32Array()
## Lines (brooks, paths): flat arrays of densified points with a level each.
static var _brook_pts: Array[PackedVector2Array] = []
static var _brook_lvl: Array[PackedFloat32Array] = []
static var _brook_hw := PackedFloat32Array()
static var _path_pts: Array[PackedVector2Array] = []
static var _path_lvl: Array[PackedFloat32Array] = []
static var _path_hw := PackedFloat32Array()
static var _path_ids: Array[StringName] = []
## Segment index -> (line, point index) for brooks and paths.
static var _brook_seg := PackedInt32Array()
static var _path_seg := PackedInt32Array()
static var _lakes: Array[Dictionary] = []
static var _lake_level := PackedFloat32Array()

## Build stages: how much of the land _land() applies (for precomputing).
enum Stage { BASE, RIVER, BROOKS, LAKES, PATHS }
static var _stage_cap: int = Stage.PATHS


# ==============================================================================
# Public API
# ==============================================================================

static func height_at(x: float, z: float) -> float:
	_ensure()
	var w := _own_weight(x, z)
	if w <= 0.0:
		return MacroHeight.height_at(x, z)
	var h := _land(x, z, Stage.PATHS)
	if w < 1.0:
		h = lerpf(MacroHeight.height_at(x, z), h, w)
	return h + _edge(x, z)


## (base slot, overlay slot, blend 0-255): emerald grass in the open, moss on
## the earth of the woods and the shaded banks, forest floor in the western
## dips and under the Autumn hills, rock on crags, withered grass where the
## blight has the land recoiling, path and stream bed where they are.
static func texture_at(x: float, z: float) -> Vector3i:
	_ensure()
	const ROCK := 2
	const WINTER := 3
	const GRASS := 4
	const MOSS := 5
	const FOREST := 6
	const PATH := 7
	const BED := 8
	const BLIGHT := 9
	var h := height_at(x, z)
	var hx := height_at(x + 1.5, z)
	var hz := height_at(x, z + 1.5)
	var gx := (hx - h) / 1.5
	var gz := (hz - h) / 1.5
	var slope := rad_to_deg(atan(sqrt(gx * gx + gz * gz)))
	# Water beds.
	if MacroHeight.distance_to_river(x, z) < CHANNEL + 0.5:
		return Vector3i(BED, BED, 0)
	for i in _lakes.size():
		var c: Vector2 = _lakes[i]["center"]
		var r: float = _lakes[i]["radius"]
		var d := Vector2(x, z).distance_to(c)
		if d < r * 1.08:
			return Vector3i(BED, MOSS, int(clampf((d - r * 0.9) / (r * 0.18), 0.0, 1.0) * 200.0)) if d > r * 0.9 else Vector3i(BED, BED, 0)
	var bd := distance_to_brook(x, z)
	if bd < 2.0:
		return Vector3i(BED, MOSS, int(clampf(bd / 2.0, 0.0, 1.0) * 160.0))
	# Paths.
	var pd := _path_distance(x, z)
	if pd.x < pd.y + 1.2:
		var edge := clampf((pd.x - (pd.y - 0.8)) / 2.0, 0.0, 1.0)
		return Vector3i(PATH, GRASS, int(edge * 200.0))
	var kind := _kind_at(x, z)
	if slope > 42.0:
		return Vector3i(ROCK, MOSS, 60)
	var rocky := int(remap(clampf(slope, 30.0, 42.0), 30.0, 42.0, 0.0, 255.0)) if slope > 30.0 else 0
	var shade := _dip.get_noise_2d(x * 1.7, z * 1.7)
	match kind:
		Kind.WOODS:
			# Moss-covered earth; the dark dips go to bare forest floor.
			if rocky > 0:
				return Vector3i(MOSS, ROCK, rocky)
			return Vector3i(MOSS, FOREST, int(clampf(shade * 1.6 + 0.2, 0.0, 1.0) * 255.0))
		Kind.AUTUMN, Kind.RIM:
			if rocky > 0 or slope > 24.0:
				return Vector3i(FOREST, ROCK, maxi(rocky, int(remap(clampf(slope, 24.0, 30.0), 24.0, 30.0, 40.0, 120.0))))
			return Vector3i(FOREST, MOSS, int(clampf(shade + 0.4, 0.0, 1.0) * 200.0))
		Kind.BLIGHT:
			# Ordinary hills where the spring has recoiled: withered grass, a
			# sick patchiness in the hollows. Never a painted-on wasteland.
			if rocky > 0:
				return Vector3i(WINTER, ROCK, rocky)
			return Vector3i(WINTER, BLIGHT if shade > 0.25 else GRASS, int(clampf(absf(shade) * 1.2, 0.0, 1.0) * 170.0))
		Kind.GLEN, Kind.VILLAGE:
			if rocky > 0:
				return Vector3i(GRASS, ROCK, rocky)
			# Moss on the steep knoll flanks and the north faces.
			var north := clampf(-gz * 2.5 + slope / 30.0 - 0.3, 0.0, 1.0)
			return Vector3i(GRASS, MOSS, int(north * 220.0))
		_:
			if rocky > 0:
				return Vector3i(GRASS, ROCK, rocky)
			return Vector3i(GRASS, MOSS, int(clampf(shade - 0.2, 0.0, 0.6) * 255.0))


## Lakes and pools: {id, center: Vector2, radius, level}.
static func lakes() -> Array[Dictionary]:
	_ensure()
	return _lakes


## Initialise every lazily-built table before sampling from threads.
static func prewarm() -> void:
	_ensure()


## The Thornwater's surface over the point's nearest centreline point. Where
## another lane owns the river it stands RIVER_WATER_DEPTH over their bed.
static func river_level_at(x: float, z: float) -> float:
	_ensure()
	var near := _river_nearest(x, z)
	var c := Vector2(near.y, near.z)
	if _own_weight(c.x, c.y) >= 1.0:
		return _river_level(near.x, x, z)
	return WorldHeight.height_at(c.x, c.y) + RIVER_WATER_DEPTH


## Brooks for the water ribbons: {id, points: PackedVector2Array, levels:
## PackedFloat32Array (water surface), half_width}.
static func brooks() -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for i in _brook_pts.size():
		var lv := PackedFloat32Array()
		for v in _brook_lvl[i]:
			lv.append(v + BROOK_DEPTH)
		out.append({"id": BROOKS[i][0], "points": _brook_pts[i], "levels": lv, "half_width": _brook_hw[i]})
	return out


static func distance_to_brook(x: float, z: float) -> float:
	_ensure()
	var r := _brook_query(x, z)
	return r.x - r.w


## Paths: {id, points: PackedVector2Array, levels, half_width}.
static func paths() -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for i in _path_pts.size():
		out.append({"id": _path_ids[i], "points": _path_pts[i], "levels": _path_lvl[i], "half_width": _path_hw[i]})
	return out


## Named sites: id -> {position: Vector2, region, kind}.
static func sites() -> Dictionary:
	var out := {}
	for id: StringName in SITES:
		var s: Array = SITES[id]
		out[id] = {"position": Vector2(s[0], s[1]), "region": s[2], "kind": s[3]}
	return out


static func site(id: StringName) -> Vector2:
	var s: Array = SITES.get(id, [])
	return Vector2(s[0], s[1]) if not s.is_empty() else Vector2(NAN, NAN)


## Gates for one region's content: {target, position: Vector2, width, yaw_degrees}.
static func gates_for(region_id: StringName) -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for g: Array in GATES:
		if g[0] != region_id:
			continue
		var p := Vector2(g[2], g[3])
		var yaw := 0.0
		var best := INF
		for i in _path_pts.size():
			var pts := _path_pts[i]
			for k in pts.size() - 1:
				var q := Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])
				if q.distance_to(p) < best:
					best = q.distance_to(p)
					var dir := (pts[k + 1] - pts[k]).normalized()
					yaw = rad_to_deg(atan2(dir.x, dir.y))
		out.append({"target": g[1], "position": p, "width": g[4], "yaw_degrees": yaw})
	return out


## 0 on other lanes' ground, 1 a BLEND's width inside ours.
static func own_weight(x: float, z: float) -> float:
	return _own_weight(x, z)


static func domain_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Array in DOMAIN:
		out.append(Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]))
	return out


# ==============================================================================
# The land
# ==============================================================================

static func _land(x: float, z: float, stage: int) -> float:
	stage = mini(stage, _stage_cap)
	var g := _grid4(x, z)
	# Bumps and hollows, scaled by the region's character.
	var wx := x + _warp.get_noise_2d(x, z) * 55.0
	var wz := z + _warp.get_noise_2d(x + 913.0, z - 377.0) * 55.0
	var h := g.x + _roll.get_noise_2d(wx, wz) * g.y + _hum.get_noise_2d(wx, wz) * g.z
	if g.w > 0.01:
		# Root ridges (thin crests) and dark dips under the old trees.
		var rr := 1.0 - absf(_ridge.get_noise_2d(wx, wz))
		h += (rr * rr * rr * rr - 0.2) * g.w * 1.6
		var dip := _dip.get_noise_2d(wx, wz)
		if dip > 0.3:
			h -= pow((dip - 0.3) / 0.7, 1.4) * g.w * 2.4
	var ci := _bucket(x, z)
	# Knolls and hollows.
	if ci >= 0:
		for i in _b_forms[ci]:
			var f: Array = _forms[i]
			var dx: float = x - f[1]
			var dz: float = z - f[2]
			var r: float = f[3]
			var d2 := dx * dx + dz * dz
			if d2 >= r * r:
				continue
			var t := 1.0 - d2 / (r * r)
			var v: float = f[4] * pow(t, f[5])
			h += v if f[0] == 0 else -v
	# Pads (in order) and the flats.
	if ci >= 0:
		for i in _b_pads[ci]:
			var p: Array = _pads[i]
			var d := Vector2(x - p[0], z - p[1]).length()
			if d >= p[3]:
				continue
			var m := 1.0 if d <= p[2] else 1.0 - smoothstep(p[2], p[3], d)
			h = lerpf(h, _pad_levels[i], m)
	for fl: Array in FLATS:
		var ex: float = (x - fl[0]) / fl[2]
		var ez: float = (z - fl[1]) / fl[3]
		var e: float = fl[4]
		var rr := sqrt(ex * ex + ez * ez)
		var reach: float = 1.0 + e / minf(fl[2], fl[3])
		if rr < reach + 0.3:
			rr += _warp.get_noise_2d(x * 3.0, z * 3.0) * 0.22
			var m := 1.0 - smoothstep(1.0, reach, rr)
			if m > 0.0:
				h = lerpf(h, fl[5] + _hum.get_noise_2d(x * 0.5, z * 0.5) * 0.6, m)
	# The hard edges go on last, so no clearing can soften a seal.
	h = _features(x, z, h)
	if stage >= Stage.RIVER:
		h = _river_carve(x, z, h, ci)
	if stage >= Stage.BROOKS:
		h = _brook_carve(x, z, h)
	if stage >= Stage.LAKES:
		h = _lake_carve(x, z, h)
	if stage >= Stage.PATHS:
		h = _path_flatten(x, z, h)
	return h


## The sharp, hand-placed shapes: the trench, the terraces, the Autumn scarp,
## the court's rising rim and the western gorge.
static func _features(x: float, z: float, h: float) -> float:
	# The trench between two hills, ending in the cave mouth.
	var a := Vector2(TRENCH[0], TRENCH[1])
	var b := Vector2(TRENCH[2], TRENCH[3])
	var p := Vector2(x, z)
	if absf(z - a.y) < 60.0 and x > a.x - 60.0 and x < b.x + 60.0:
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var floor_y := lerpf(TRENCH[4], TRENCH[5], t)
		var d := p.distance_to(q)
		var cut := floor_y + maxf(0.0, d - TRENCH[6]) * TRENCH[7]
		h = minf(h, cut)
	# The bonfire terraces.
	var tc := Vector2(TERRACES[0], TERRACES[1])
	var td := p.distance_to(tc)
	if td > TERRACES[4] - 20.0 and td < TERRACES[5] + 20.0:
		var ang := rad_to_deg(atan2(z - tc.y, x - tc.x))
		var da := absf(wrapf(ang - TERRACES[2], -180.0, 180.0))
		if da < TERRACES[3] + 12.0:
			var m: float = (1.0 - smoothstep(TERRACES[3], TERRACES[3] + 12.0, da)) \
					* smoothstep(TERRACES[4] - 20.0, TERRACES[4], td) * (1.0 - smoothstep(TERRACES[5], TERRACES[5] + 20.0, td))
			var step: float = TERRACES[6]
			var k := h / step
			var fr := k - floorf(k)
			var stepped := (floorf(k) + smoothstep(0.72, 1.0, fr)) * step
			h = lerpf(h, stepped, m * TERRACES[7])
	# The Rust Scarp: the Autumn border stands on a crag band.
	if x < -560.0 and z < -860.0:
		var din := _autumn_depth(x, z)
		if din > 0.0:
			var rise := SCARP_RISE + _crag.get_noise_2d(x, z) * 4.0
			h += rise * smoothstep(SCARP_IN, SCARP_IN + SCARP_WIDTH, din)
	return h


## The court's edge, added after the blend to other lanes' ground (its lines
## stand clear of every other lane, so it is never softened): to the north and
## east the land climbs away in stacked crag bands, each face taller than
## Feyre's whole jump chain; to the west the woods end at a mossy lip over a
## misty gorge with mountains beyond. The pass road's canyon is cut through
## the north rim. All of it eases out where the court meets the Wall.
static func _edge(x: float, z: float) -> float:
	var e := 0.0
	var zr := north_rim_z(x)
	if z < zr + 4.0:
		var cut := smoothstep(PASS_CANYON[0], PASS_CANYON[1], absf(x - PASS_BULGE[0]))
		e += _rim(zr - z, x, z) * cut
	var xe := east_rim_x(z)
	if x > xe - 4.0:
		# The Thornwater leaves the vale through a canyon in the rim.
		var canyon := smoothstep(CHANNEL + 8.0, CHANNEL + 34.0, MacroHeight.distance_to_river(x, z))
		e += _rim(x - xe, x, z) * canyon
	var xl := west_lip_x(z)
	if x < xl + 8.0:
		# The gorge runs from the Autumn border (a rock rib closes it there: the
		# sealed hills meet the mountains directly) to the woods near the Wall.
		var fade := (1.0 - smoothstep(900.0, 1250.0, z)) * smoothstep(-905.0, -860.0, z)
		e += 2.5 * maxf(0.0, 1.0 - absf(x - xl) / 4.0)
		e -= GORGE_DEPTH * fade * smoothstep(xl - 3.0, xl - 22.0, x)
		e += GORGE_DEPTH * fade * smoothstep(xl - 92.0, xl - 100.0, x) + _rim((xl - 100.0) - x, x, z)
	return e * (1.0 - smoothstep(1250.0, 1395.0, z))


## The court's rim at d metres past its front line: three crag bands of
## 16-26 m (steeper than any floor, taller than the jump chain), then hills.
static func _rim(d: float, x: float, z: float) -> float:
	if d < -4.0:
		return 0.0
	var n := _crag.get_noise_2d(x * 0.5, z * 0.5)
	return (24.0 + n * 3.0) * smoothstep(0.0, 6.0, d) \
			+ (26.0 - n * 3.0) * smoothstep(40.0, 46.0, d) \
			+ (28.0 + n * 3.0) * smoothstep(88.0, 94.0, d) \
			+ 90.0 * smoothstep(130.0, 330.0, d) \
			+ absf(_crag.get_noise_2d(x * 0.6, z * 0.6)) * 10.0 * smoothstep(0.0, 60.0, d)


## The z of the north rim's front at x.
static func north_rim_z(x: float) -> float:
	var t: float = (x - PASS_BULGE[0]) / PASS_BULGE[2]
	var bulge := exp(-t * t)
	var wob := _wobble.get_noise_1d(x) * 46.0 if _wobble != null else 0.0
	return NORTH_RIM + PASS_BULGE[1] * bulge + wob * (1.0 - bulge)


## The east rim's front: 1745 by the Blighted Reaches, past the Eastern Woods'
## edge (x 1850) beside them, 1585 east of Blossom Vale.
static func east_rim_x(z: float) -> float:
	var wob := _wobble.get_noise_1d(z + 5000.0) if _wobble != null else 0.0
	var reaches := EAST_RIM_N + wob * 44.0
	var woods := EAST_RIM_WOODS + absf(wob) * 30.0
	var vale := EAST_RIM_S + wob * 44.0
	if z < -640.0:
		return lerpf(reaches, woods, smoothstep(-720.0, -660.0, z))
	if z < 560.0:
		return woods
	return lerpf(woods, vale, smoothstep(560.0, 640.0, z))


static func west_lip_x(z: float) -> float:
	return WEST_LIP + (_wobble.get_noise_1d(z - 9000.0) * 22.0 if _wobble != null else 0.0)


## Signed depth (m) inside the Autumn hills' L (positive inside).
## The line wanders (_wobble) except at the Sealed Pass and the falls, which
## must sit exactly where the gate and the river's step are.
static func _autumn_depth(x: float, z: float) -> float:
	var a := minf(-600.0 - x, -1250.0 - z)
	var b := minf(-1500.0 - x, minf(-900.0 - z, z + 1250.0 + 400.0))
	var d := maxf(a, b)
	if d > -90.0 and d < 90.0 and _wobble != null:
		var keep := minf(Vector2(x + 900.0, z + 1278.0).length(), Vector2(x + 1440.0, z + 1265.0).length())
		d += _wobble.get_noise_2d(x, z) * 44.0 * smoothstep(40.0, 140.0, keep)
	return d


# --- the Thornwater -----------------------------------------------------------

## (arclength, nearest x, nearest z, distance) for the river centreline.
static func _river_nearest(x: float, z: float) -> Vector4:
	var pts := MacroHeight.THORNWATER
	var p := Vector2(x, z)
	var best := INF
	var out := Vector4(0, pts[0].x, pts[0].y, INF)
	for i in pts.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
			out = Vector4(_river_s0[i] + pts[i].distance_to(q), q.x, q.y, 0.0)
	out.w = sqrt(best)
	return out


static func _profile(table: Array, s: float, col: int) -> float:
	if s <= table[0][0]:
		return table[0][col]
	for i in table.size() - 1:
		var b: Array = table[i + 1]
		if s <= b[0]:
			var a: Array = table[i]
			return lerpf(a[col], b[col], (s - a[0]) / (b[0] - a[0]))
	return table[-1][col]


## The water level for a point near arclength s: at the Autumn falls the step
## follows the scarp line, so the falls are as sealed as the crag beside them.
static func _river_level(s: float, x: float, z: float) -> float:
	var lv := _profile(RIVER_PROFILE, s, 1)
	if absf(s - FALLS[0]) < FALLS[3]:
		var high := _autumn_depth(x, z) > SCARP_IN + SCARP_WIDTH * 0.5
		lv = maxf(lv, FALLS[1]) if high else minf(lv, FALLS[2])
	return lv


static func _river_carve(x: float, z: float, h: float, ci: int) -> float:
	if ci < 0 or _b_river[ci].is_empty():
		return h
	var near := _river_nearest(x, z)
	var d := near.w
	var vw := _profile(VALLEY, near.x, 1)
	var k := _profile(VALLEY, near.x, 2)
	if d > CHANNEL + vw + 160.0:
		return h
	var lv := _river_level(near.x, x, z)
	if d < CHANNEL:
		var t := d / CHANNEL
		return lv - RIVER_WATER_DEPTH + RIVER_WATER_DEPTH * t * t
	var bank := lv + 1.0 * smoothstep(CHANNEL, CHANNEL + 2.0, d)
	if d < CHANNEL + 2.0:
		return bank
	var e := d - CHANNEL - 2.0
	var valley := lv + 1.0 + k * e + 0.02 * pow(maxf(0.0, e - vw), 2.0)
	var out := minf(h, valley)
	if d < CHANNEL + 22.0:
		out = maxf(out, lv + 0.9)
	return out


# --- brooks -------------------------------------------------------------------

## (distance, level at the nearest point, line index, half-width).
static func _brook_query(x: float, z: float) -> Vector4:
	var best := Vector4(INF, 0.0, -1.0, 0.0)
	var ci := _bucket(x, z)
	if ci < 0:
		return best
	var p := Vector2(x, z)
	for seg in _b_brooks[ci]:
		var line := _brook_seg[seg * 2]
		var k := _brook_seg[seg * 2 + 1]
		var a := _brook_pts[line][k]
		var b := _brook_pts[line][k + 1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		if d < best.x:
			var t := q.distance_to(a) / maxf(a.distance_to(b), 0.001)
			best = Vector4(d, lerpf(_brook_lvl[line][k], _brook_lvl[line][k + 1], t), line, _brook_hw[line])
	return best


static func _brook_carve(x: float, z: float, h: float) -> float:
	var r := _brook_query(x, z)
	if r.z < 0.0 or r.x > r.w + 40.0:
		return h
	var d := r.x
	var hw := r.w
	var lv := r.y
	if d < hw:
		var t := d / hw
		return lv - 0.3 + 0.3 * t * t
	var valley := lv + 0.35 + 0.22 * (d - hw) + 0.01 * pow(maxf(0.0, d - hw - 10.0), 2.0)
	var out := minf(h, valley)
	if d < hw + 2.5:
		out = maxf(out, lv + 0.3)
	return out


# --- lakes --------------------------------------------------------------------

static func _lake_carve(x: float, z: float, h: float) -> float:
	for i in LAKES.size():
		var l: Array = LAKES[i]
		var dx: float = x - l[1]
		var dz: float = z - l[2]
		var r: float = l[3]
		var d2 := dx * dx + dz * dz
		if d2 >= r * r:
			continue
		var t := sqrt(d2) / r
		var lv := _lake_level[i]
		var depth: float = l[4]
		var under: float
		if t > 0.85:
			under = lerpf(0.4, 1.6, (1.0 - t) / 0.15)
		elif t > 0.55:
			under = lerpf(1.6, depth, smoothstep(0.85, 0.55, t))
		else:
			under = depth * (1.0 + 0.05 * (1.0 - t / 0.55))
		h = minf(h, lv - under)
		var ir: float = l[7]
		if ir > 0.0:
			var di := Vector2(x - l[1] - l[5], z - l[2] - l[6]).length()
			if di < ir:
				var u := 1.0 - (di / ir) * (di / ir)
				h = maxf(h, lv - 3.0 + 5.5 * pow(u, 0.6))
	return h


# --- paths --------------------------------------------------------------------

## (distance, half-width) to the nearest path.
static func _path_distance(x: float, z: float) -> Vector2:
	var ci := _bucket(x, z)
	if ci < 0:
		return Vector2(INF, 0.0)
	var p := Vector2(x, z)
	var best := Vector2(INF, 0.0)
	for seg in _b_paths[ci]:
		var line := _path_seg[seg * 2]
		var k := _path_seg[seg * 2 + 1]
		var q := Geometry2D.get_closest_point_to_segment(p, _path_pts[line][k], _path_pts[line][k + 1])
		var d := p.distance_to(q)
		if d < best.x:
			best = Vector2(d, _path_hw[line])
	return best


static func _path_flatten(x: float, z: float, h: float) -> float:
	var ci := _bucket(x, z)
	if ci < 0 or _b_paths[ci].is_empty():
		return h
	var p := Vector2(x, z)
	var best := INF
	var lv := 0.0
	var hw := 0.0
	for seg in _b_paths[ci]:
		var line := _path_seg[seg * 2]
		var k := _path_seg[seg * 2 + 1]
		var a := _path_pts[line][k]
		var b := _path_pts[line][k + 1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		if d < best:
			best = d
			var t := q.distance_to(a) / maxf(a.distance_to(b), 0.001)
			lv = lerpf(_path_lvl[line][k], _path_lvl[line][k + 1], t)
			hw = _path_hw[line]
	if best > hw + 4.0:
		return h
	# Clearings are already level: the path runs onto them, not into them.
	for i in _b_pads[ci]:
		var pd: Array = _pads[i]
		if Vector2(x - pd[0], z - pd[1]).length() < float(pd[2]):
			return h
	# Fords: the path meets the water as the stream made it.
	if MacroHeight.distance_to_river(x, z) < CHANNEL + 3.0:
		return h
	var bq := _brook_query(x, z)
	if bq.x < bq.w + 2.5:
		return h
	var m := 1.0 if best <= hw else 1.0 - smoothstep(hw, hw + 4.0, best)
	return lerpf(h, lv, m)


# ==============================================================================
# Ownership and the design grid
# ==============================================================================

static func _own_weight(x: float, z: float) -> float:
	if x < MAP_X0 or x > MAP_X1 or z < MAP_Z0 or z >= MAP_Z1:
		return 0.0
	var d := INF
	for r: Array in FOREIGN:
		var dx := maxf(maxf(r[0] - x, x - r[2]), 0.0)
		var dz := maxf(maxf(r[1] - z, z - r[3]), 0.0)
		if dx == 0.0 and dz == 0.0:
			return 0.0
		d = minf(d, sqrt(dx * dx + dz * dz))
	return smoothstep(0.0, BLEND, d)


## (level, roll amp, hummock amp, root-ridge amp), bilinear.
static func _grid4(x: float, z: float) -> Vector4:
	var fx := clampf((x - MAP_X0) / GRID, 0.0, _gw - 1.001)
	var fz := clampf((z - MAP_Z0) / GRID, 0.0, _gh - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * _gw + ix
	var j := i + _gw
	var w00 := (1.0 - tx) * (1.0 - tz)
	var w10 := tx * (1.0 - tz)
	var w01 := (1.0 - tx) * tz
	var w11 := tx * tz
	return Vector4(
		_g_level[i] * w00 + _g_level[i + 1] * w10 + _g_level[j] * w01 + _g_level[j + 1] * w11,
		_g_roll[i] * w00 + _g_roll[i + 1] * w10 + _g_roll[j] * w01 + _g_roll[j + 1] * w11,
		_g_hum[i] * w00 + _g_hum[i + 1] * w10 + _g_hum[j] * w01 + _g_hum[j + 1] * w11,
		_g_ridge[i] * w00 + _g_ridge[i + 1] * w10 + _g_ridge[j] * w01 + _g_ridge[j + 1] * w11)


static func _kind_at(x: float, z: float) -> int:
	var ix := clampi(roundi((x - MAP_X0) / GRID), 0, _gw - 1)
	var iz := clampi(roundi((z - MAP_Z0) / GRID), 0, _gh - 1)
	return _g_kind[iz * _gw + ix]


static func kind_at(x: float, z: float) -> int:
	_ensure()
	return _kind_at(x, z)


static func _bucket(x: float, z: float) -> int:
	var bx := int(floorf((x - MAP_X0) / BUCKET))
	var bz := int(floorf((z - MAP_Z0) / BUCKET))
	if bx < 0 or bz < 0 or bx >= _bw or bz >= _bh:
		return -1
	return bz * _bw + bx


## Soft membership of a point in a zone's rectangles (max over them).
static func _zone_weight(zone: Array, x: float, z: float) -> float:
	var best := 0.0
	var half := ZONE_SOFT * 0.5
	for r: Array in zone[1]:
		var ix := minf(x - r[0], r[2] - x)
		var iz := minf(z - r[1], r[3] - z)
		var m := smoothstep(-half, half, ix) * smoothstep(-half, half, iz)
		best = maxf(best, m)
	return best


## A zone's own base level at a point (most are flat; the Autumn hills rise
## toward the far border, the vale falls south between soft sides, the western
## woods climb to the Wall where the human realm's ground is high).
static func _zone_level(zone: Array, x: float, z: float) -> float:
	match zone[0]:
		Kind.AUTUMN:
			return zone[2] + 150.0 * smoothstep(0.0, 620.0, _autumn_depth(x, z))
		Kind.VALE:
			var fl := _profile([[500.0, 34.0], [650.0, 28.0], [900.0, 14.0], [1050.0, 4.0], [1250.0, 4.0], [1400.0, 3.0]], z, 1)
			return fl + 26.0 * smoothstep(260.0, 540.0, absf(x - 1010.0))
		Kind.WOODS:
			var m := MacroHeight.land_height_at(x, z)
			return zone[2] + smoothstep(1100.0, 1400.0, z) * maxf(0.0, m - zone[2]) * 0.6
		Kind.RIM:
			return zone[2]
	return zone[2]


static func _design_cell(x: float, z: float) -> Array:
	var sw := 0.0
	var lv := 0.0
	var ro := 0.0
	var hu := 0.0
	var ri := 0.0
	var kind := 0
	var kw := -1.0
	for zone: Array in ZONES:
		var w := _zone_weight(zone, x, z)
		if w <= 0.0001:
			continue
		sw += w
		lv += w * _zone_level(zone, x, z)
		ro += w * float(zone[3])
		hu += w * float(zone[4])
		ri += w * float(zone[5])
		if w > kw:
			kw = w
			kind = zone[0]
	if sw < 0.0001:
		return [MacroHeight.land_height_at(x, z), 4.0, 1.0, 0.0, Kind.ROSE]
	lv /= sw
	ro /= sw
	hu /= sw
	ri /= sw
	if sw < 1.0:
		# Toward ground no zone claims (inside other lanes): the macro land.
		lv = lerpf(MacroHeight.land_height_at(x, z), lv, sw)
	for hl: Array in HILLS:
		var dx: float = x - hl[0]
		var dz: float = z - hl[1]
		var r: float = hl[2]
		var d2 := dx * dx + dz * dz
		if d2 < r * r:
			lv += hl[3] * pow(1.0 - d2 / (r * r), hl[4])
	return [lv, ro, hu, ri, kind]


# ==============================================================================
# Building the tables
# ==============================================================================

static func _ensure() -> void:
	if _ready:
		return
	_mutex.lock()
	if not _ready:
		_build()
		_ready = true
	_mutex.unlock()


static func _noise(seed_value: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	return n


static func _build() -> void:
	_warp = _noise(4101, 1.0 / 620.0, 2)
	_roll = _noise(4102, 1.0 / 380.0, 3)
	_hum = _noise(4103, 1.0 / 46.0, 2)
	_ridge = _noise(4104, 1.0 / 42.0, 2)
	_dip = _noise(4105, 1.0 / 70.0, 2)
	_crag = _noise(4106, 1.0 / 38.0, 3)
	_wobble = _noise(4107, 1.0 / 260.0, 2)
	# Design grid.
	_gw = int((MAP_X1 - MAP_X0) / GRID) + 2
	_gh = int((MAP_Z1 + 64.0 - MAP_Z0) / GRID) + 2
	var n := _gw * _gh
	_g_level.resize(n)
	_g_roll.resize(n)
	_g_hum.resize(n)
	_g_ridge.resize(n)
	_g_kind.resize(n)
	for iz in _gh:
		for ix in _gw:
			var c := _design_cell(MAP_X0 + ix * GRID, MAP_Z0 + iz * GRID)
			var i := iz * _gw + ix
			_g_level[i] = c[0]
			_g_roll[i] = c[1]
			_g_hum[i] = c[2]
			_g_ridge[i] = c[3]
			_g_kind[i] = c[4]
	# River arclengths.
	var pts := MacroHeight.THORNWATER
	_river_s0.resize(pts.size())
	var s := 0.0
	for i in pts.size():
		_river_s0[i] = s
		if i < pts.size() - 1:
			s += pts[i].distance_to(pts[i + 1])
	# Buckets.
	_bw = int(ceilf((MAP_X1 - MAP_X0) / BUCKET))
	_bh = int(ceilf((MAP_Z1 + 64.0 - MAP_Z0) / BUCKET))
	_b_forms = _empty_buckets()
	_b_pads = _empty_buckets()
	_b_river = _empty_buckets()
	_b_brooks = _empty_buckets()
	_b_paths = _empty_buckets()
	_forms = FORMS.duplicate()
	_forms.append_array(_knoll_fields())
	_forms.append_array(_pinch_knolls())
	for i in _forms.size():
		_add_disc(_b_forms, i, Vector2(_forms[i][1], _forms[i][2]), _forms[i][3])
	_pads = PADS.duplicate()
	for id: StringName in SITES:
		var st: Array = SITES[id]
		if st[3] == &"water" or id in NO_PAD:
			continue
		var c := Vector2(st[0], st[1])
		var covered := false
		for pd: Array in PADS:
			covered = covered or c.distance_to(Vector2(pd[0], pd[1])) < float(pd[2])
		if not covered:
			_pads.append([c.x, c.y, 6.0, 14.0, NAN])
	for i in _pads.size():
		_add_disc(_b_pads, i, Vector2(_pads[i][0], _pads[i][1]), _pads[i][3])
	for i in pts.size() - 1:
		_add_capsule(_b_river, i, pts[i], pts[i + 1], CHANNEL + 220.0)
	# Pad levels from the ground before any pad.
	_stage_cap = Stage.BASE
	_pad_levels.resize(_pads.size())
	for i in _pads.size():
		_pad_levels[i] = 0.0
	var saved: Array[PackedInt32Array] = _b_pads
	_b_pads = _empty_buckets()
	for i in _pads.size():
		var lv: float = _pads[i][4]
		_pad_levels[i] = lv if not is_nan(lv) else _land(_pads[i][0], _pads[i][1], Stage.BASE)
	_b_pads = saved
	# Lakes find their level from their shore (after the river has its valley).
	_stage_cap = Stage.RIVER
	_lake_level.resize(LAKES.size())
	_lakes.clear()
	for i in LAKES.size():
		var l: Array = LAKES[i]
		var c := Vector2(l[1], l[2])
		var lowest := INF
		for ring: float in [1.0, 1.25, 1.6]:
			for k in 32:
				var q := c + Vector2.from_angle(k * TAU / 32.0) * float(l[3]) * ring
				if MacroHeight.distance_to_river(q.x, q.y) < CHANNEL + 22.0:
					continue
				lowest = minf(lowest, _land(q.x, q.y, Stage.RIVER))
		_lake_level[i] = lowest - 0.7
		_lakes.append({"id": l[0], "center": c, "radius": float(l[3]), "level": _lake_level[i]})
	# Brooks: downhill only, never above a lake they leave or enter.
	_brook_pts.clear()
	_brook_lvl.clear()
	_brook_hw.clear()
	var bseg: Array[int] = []
	for bi in BROOKS.size():
		var line := _densify(BROOKS[bi][2], 3.0)
		var lv := PackedFloat32Array()
		lv.resize(line.size())
		for k in line.size():
			lv[k] = _land(line[k].x, line[k].y, Stage.RIVER) - 0.7
		lv = _smooth(lv, 3)
		for k in line.size():
			for li in LAKES.size():
				if line[k].distance_to(_lakes[li]["center"]) < float(_lakes[li]["radius"]) * 1.7:
					lv[k] = minf(lv[k], _lake_level[li] - 0.05)
		for k in range(1, line.size()):
			lv[k] = minf(lv[k], lv[k - 1])
		# Where it meets the Thornwater it stands at least at the river's level.
		var end := line[line.size() - 1]
		var near := _river_nearest(end.x, end.y)
		if near.w < CHANNEL + 30.0:
			var rl := _river_level(near.x, end.x, end.y)
			for k in line.size():
				lv[k] = maxf(lv[k], rl)
		_brook_pts.append(line)
		_brook_lvl.append(lv)
		_brook_hw.append(BROOKS[bi][1])
		for k in line.size() - 1:
			bseg.append(bi)
			bseg.append(k)
	_brook_seg = PackedInt32Array(bseg)
	for seg in bseg.size() / 2:
		var line := _brook_pts[bseg[seg * 2]]
		var k := bseg[seg * 2 + 1]
		_add_capsule(_b_brooks, seg, line[k], line[k + 1], _brook_hw[bseg[seg * 2]] + 42.0)
	# Paths: graded after the water has shaped the ground.
	_stage_cap = Stage.LAKES
	_path_pts.clear()
	_path_lvl.clear()
	_path_hw.clear()
	_path_ids.clear()
	var pseg: Array[int] = []
	var specs: Array = PATHS.duplicate()
	specs.append([&"tower_climb", 1.6, _spiral()])
	for pi in specs.size():
		var line := _densify(specs[pi][2], 4.0)
		var raw := PackedFloat32Array()
		raw.resize(line.size())
		for k in line.size():
			raw[k] = _land(line[k].x, line[k].y, Stage.LAKES)
		var lv := _grade(_smooth(raw, 3), raw, 4.0)
		_path_pts.append(line)
		_path_lvl.append(lv)
		_path_hw.append(specs[pi][1])
		_path_ids.append(specs[pi][0])
		for k in line.size() - 1:
			pseg.append(pi)
			pseg.append(k)
	_path_seg = PackedInt32Array(pseg)
	for seg in pseg.size() / 2:
		var line := _path_pts[pseg[seg * 2]]
		var k := pseg[seg * 2 + 1]
		_add_capsule(_b_paths, seg, line[k], line[k + 1], _path_hw[pseg[seg * 2]] + 6.0)
	_stage_cap = Stage.PATHS


## Knolls "marked by single trees": a deterministic scatter per region, kept off
## the named sites, the lakes, the paths' lines and the Thornwater.
## [region kind, rect, count, radius range, height range, chance of a hollow].
const KNOLL_FIELDS := [
	[Kind.ROSE, [-560.0, -790.0, 630.0, -520.0], 22, [18.0, 34.0], [2.5, 5.5], 0.35],
	[Kind.GLEN, [-1480.0, -480.0, -680.0, 580.0], 26, [20.0, 38.0], [6.0, 14.0], 0.2],
	[Kind.VILLAGE, [-1480.0, -1220.0, -640.0, -520.0], 14, [22.0, 40.0], [6.0, 12.0], 0.2],
	[Kind.MEADOW, [-580.0, -1180.0, 280.0, -820.0], 10, [24.0, 40.0], [4.0, 9.0], 0.2],
	[Kind.HILL, [320.0, -1480.0, 1280.0, -720.0], 18, [26.0, 46.0], [6.0, 14.0], 0.15],
	[Kind.BLIGHT, [-580.0, -1720.0, 1720.0, -1360.0], 24, [30.0, 60.0], [6.0, 14.0], 0.3],
	[Kind.BLIGHT, [1320.0, -1480.0, 1720.0, -680.0], 10, [30.0, 55.0], [6.0, 12.0], 0.3],
	[Kind.VALE, [560.0, 580.0, 1500.0, 1380.0], 16, [24.0, 44.0], [3.0, 8.0], 0.15],
	[Kind.WOODS, [-1780.0, -860.0, -720.0, 1380.0], 30, [14.0, 30.0], [1.5, 4.0], 0.55],
]


## Two steep knolls either side of every open-country gate, square to its path.
static func _pinch_knolls() -> Array:
	var out: Array = []
	for g: Array in GATES:
		if g[0] == &"autumn_foothills":
			continue
		var p := Vector2(g[2], g[3])
		var dir := Vector2(0, 1)
		var best := INF
		for path: Array in PATHS:
			var pts: Array = path[2]
			for k in pts.size() - 1:
				var a := Vector2(pts[k][0], pts[k][1])
				var b := Vector2(pts[k + 1][0], pts[k + 1][1])
				var q := Geometry2D.get_closest_point_to_segment(p, a, b)
				if q.distance_to(p) < best:
					best = q.distance_to(p)
					dir = (b - a).normalized()
		var across := dir.orthogonal()
		var r: float = GATE_PINCH[0]
		var off: float = float(g[4]) * 0.5 + GATE_PINCH[3] + r * 0.55
		for side: float in [-1.0, 1.0]:
			var c := p + across * off * side
			out.append([0, c.x, c.y, r, GATE_PINCH[1], GATE_PINCH[2]])
	return out


static func _knoll_fields() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 18040
	var keep_off: Array[Vector2] = []
	for id: StringName in SITES:
		keep_off.append(Vector2(SITES[id][0], SITES[id][1]))
	var out: Array = []
	for f: Array in KNOLL_FIELDS:
		var r: Array = f[1]
		var placed := 0
		var tries := 0
		while placed < int(f[2]) and tries < int(f[2]) * 30:
			tries += 1
			var p := Vector2(rng.randf_range(r[0], r[2]), rng.randf_range(r[1], r[3]))
			var rad := rng.randf_range(f[3][0], f[3][1])
			var hgt := rng.randf_range(f[4][0], f[4][1])
			var hollow := rng.randf() < float(f[5])
			if _own_weight(p.x, p.y) < 0.6 or MacroHeight.distance_to_river(p.x, p.y) < rad + 40.0:
				continue
			var ok := true
			for q in keep_off:
				ok = ok and q.distance_to(p) > rad + 45.0
			for l: Array in LAKES:
				ok = ok and Vector2(l[1], l[2]).distance_to(p) > float(l[3]) * 1.7 + rad
			for fl: Array in FLATS:
				ok = ok and (Vector2((p.x - fl[0]) / fl[2], (p.y - fl[1]) / fl[3]).length() > 1.4)
			for path: Array in PATHS:
				var pts: Array = path[2]
				for k in pts.size() - 1:
					var q := Geometry2D.get_closest_point_to_segment(p, Vector2(pts[k][0], pts[k][1]), Vector2(pts[k + 1][0], pts[k + 1][1]))
					ok = ok and q.distance_to(p) > rad + 8.0
			for o: Array in out:
				ok = ok and Vector2(o[1], o[2]).distance_to(p) > rad + float(o[3]) * 0.8
			if not ok:
				continue
			out.append([1 if hollow else 0, p.x, p.y, rad, hgt * (0.5 if hollow else 1.0), 1.5])
			placed += 1
	return out


## Cut-only, grade-limited level profile: never above the ground, never
## steeper than PATH_GRADE. Through a crag it cuts a notch into the high side.
static func _grade(smooth: PackedFloat32Array, raw: PackedFloat32Array, step: float) -> PackedFloat32Array:
	var lv := PackedFloat32Array()
	lv.resize(smooth.size())
	for k in smooth.size():
		lv[k] = minf(smooth[k], raw[k])
	var g := PATH_GRADE * step
	for k in range(1, lv.size()):
		lv[k] = minf(lv[k], lv[k - 1] + g)
	for k in range(lv.size() - 2, -1, -1):
		lv[k] = minf(lv[k], lv[k + 1] + g)
	return lv


static func _smooth(v: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(v.size())
	for i in v.size():
		var acc := 0.0
		var n := 0
		for k in range(maxi(0, i - radius), mini(v.size(), i + radius + 1)):
			acc += v[k]
			n += 1
		out[i] = acc / n
	return out


static func _densify(points: Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var a := Vector2(points[i][0], points[i][1])
		var b := Vector2(points[i + 1][0], points[i + 1][1])
		var n := maxi(1, int(ceilf(a.distance_to(b) / step)))
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	out.append(Vector2(points[-1][0], points[-1][1]))
	return out


## The winding climb up the towering hill, from the pond of watchers' side.
static func _spiral() -> Array:
	var cx: float = TOWER_SPIRAL[0]
	var cz: float = TOWER_SPIRAL[1]
	var out: Array = []
	var n := 90
	for i in n + 1:
		var t := float(i) / n
		var r: float = lerpf(TOWER_SPIRAL[2], TOWER_SPIRAL[3], t)
		var a: float = TOWER_SPIRAL[5] + t * TOWER_SPIRAL[4] * TAU
		out.append([cx + cos(a) * r, maxf(cz + sin(a) * r, TOWER_NORTH_LIMIT)])
	out.append([cx + 14.0, cz - 10.0])
	return out


static func _empty_buckets() -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	out.resize(_bw * _bh)
	for i in out.size():
		out[i] = PackedInt32Array()
	return out


static func _add_disc(b: Array[PackedInt32Array], idx: int, c: Vector2, r: float) -> void:
	_add_box(b, idx, c - Vector2(r, r), c + Vector2(r, r))


static func _add_capsule(b: Array[PackedInt32Array], idx: int, a: Vector2, c: Vector2, r: float) -> void:
	# Cells whose centre lies within r + half a cell diagonal of the segment.
	var lo := Vector2(minf(a.x, c.x), minf(a.y, c.y)) - Vector2(r, r)
	var hi := Vector2(maxf(a.x, c.x), maxf(a.y, c.y)) + Vector2(r, r)
	var x0 := maxi(0, int(floorf((lo.x - MAP_X0) / BUCKET)))
	var x1 := mini(_bw - 1, int(floorf((hi.x - MAP_X0) / BUCKET)))
	var z0 := maxi(0, int(floorf((lo.y - MAP_Z0) / BUCKET)))
	var z1 := mini(_bh - 1, int(floorf((hi.y - MAP_Z0) / BUCKET)))
	var reach := r + BUCKET * 0.7072
	for bz in range(z0, z1 + 1):
		for bx in range(x0, x1 + 1):
			var cc := Vector2(MAP_X0 + (bx + 0.5) * BUCKET, MAP_Z0 + (bz + 0.5) * BUCKET)
			var q := Geometry2D.get_closest_point_to_segment(cc, a, c)
			if q.distance_to(cc) <= reach:
				b[bz * _bw + bx].append(idx)


static func _add_box(b: Array[PackedInt32Array], idx: int, lo: Vector2, hi: Vector2) -> void:
	var x0 := maxi(0, int(floorf((lo.x - MAP_X0) / BUCKET)))
	var x1 := mini(_bw - 1, int(floorf((hi.x - MAP_X0) / BUCKET)))
	var z0 := maxi(0, int(floorf((lo.y - MAP_Z0) / BUCKET)))
	var z1 := mini(_bh - 1, int(floorf((hi.y - MAP_Z0) / BUCKET)))
	for bz in range(z0, z1 + 1):
		for bx in range(x0, x1 + 1):
			b[bz * _bw + bx].append(idx)
