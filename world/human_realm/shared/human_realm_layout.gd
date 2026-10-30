## The human realm's layout in world coordinates: where the sites, roads, the
## frozen creek and every region sit. The height provider, the region
## generators and the region scenes all read this, so moving a site here moves
## it everywhere. Lore: lore/01-world/human-realm-regions.md, 02-locations/*.
class_name HumanRealmLayout
extends RefCounted

const RECT := WorldMap.HUMAN_REALM_RECT  # x -900..700, z 1400..2500

## Streamed regions (ids match data/phases and data/regions/human_realm).
const REGION_RECTS := {
	&"wall_seam": Rect2(-900.0, 1400.0, 1600.0, 80.0),
	&"hunting_forest": Rect2(-900.0, 1480.0, 1600.0, 570.0),
	&"cottage": Rect2(-350.0, 2050.0, 400.0, 250.0),
	&"village": Rect2(50.0, 2050.0, 650.0, 450.0),
	&"workshop": Rect2(-900.0, 2050.0, 550.0, 450.0),
}
## The rest of the human realm south of the cottage (fields, hedges) belongs
## to the cottage region's generator.
const COTTAGE_FIELDS := Rect2(-350.0, 2300.0, 400.0, 200.0)

# --- Sites (x, z). Heights come from WorldHeight. ---

## The Archeron cottage: on the forest edge, west of the village.
const COTTAGE := Vector2(-150.0, 2160.0)
## Cottage faces north-east, toward the forest path. Yaw in radians.
const COTTAGE_YAW := 0.6
## Flattened pad around the cottage (radius, metres).
const COTTAGE_PAD := 22.0
const ELAIN_GARDEN := Vector2(-132.0, 2182.0)

## Village: market square with a well, tavern, the Children's meeting hall,
## the debt family's house, the abandoned barn on the outskirts, the mill.
const VILLAGE_SQUARE := Vector2(380.0, 2250.0)
const VILLAGE_PLATEAU := 120.0
const TAVERN := Vector2(415.0, 2215.0)
const MEETING_HALL := Vector2(330.0, 2300.0)
const DEBT_FAMILY_HOUSE := Vector2(460.0, 2320.0)
const ABANDONED_BARN := Vector2(600.0, 2150.0)
const MILL := Vector2(560.0, 2420.0)

## Father's workshop and the burnt estate (the family's old life), on a hill.
const BURNT_ESTATE := Vector2(-640.0, 2330.0)
const WORKSHOP := Vector2(-560.0, 2240.0)
const ESTATE_HILL_HEIGHT := 22.0
const ESTATE_HILL_RADIUS := 230.0

## Winter hunting forest landmarks.
const WAITING_OAK := Vector2(-420.0, 1720.0)
const DOE_CLEARING := Vector2(-360.0, 1660.0)
## A human noble's walled, guarded ash grove: ash is near-extinct (Keeper, book-verified).
const ASH_GROVE := Vector2(-700.0, 1580.0)
const HUNTING_LODGE := Vector2(480.0, 1650.0)  # old noble hunting grounds [X]

## The ride north passes through the gap here.
const WALL_GAP := Vector2(WorldMap.WALL_GAP_X, WorldMap.WALL_Z)

## The frozen creek, upstream to downstream: out of the north-west forest,
## past the oak, under the cottage road, by the village to the mill pond.
static var CREEK := PackedVector2Array([
	Vector2(-880.0, 1500.0), Vector2(-700.0, 1620.0), Vector2(-520.0, 1690.0),
	Vector2(-330.0, 1780.0), Vector2(-150.0, 1900.0), Vector2(60.0, 2000.0),
	Vector2(250.0, 2100.0), Vector2(470.0, 2260.0), Vector2(560.0, 2400.0),
	Vector2(690.0, 2490.0),
])
const CREEK_HALF_WIDTH := 3.0
const CREEK_DEPTH := 1.4
const CREEK_BANK := 7.0
const MILL_POND := Vector2(545.0, 2395.0)
const MILL_POND_RADIUS := 28.0

## Roads and paths (polylines). Roads are rutted and flattened; paths are trodden snow.
static var ROADS: Array[PackedVector2Array] = [
	# Cottage to the village square.
	PackedVector2Array([Vector2(-150.0, 2160.0), Vector2(-20.0, 2200.0), Vector2(150.0, 2230.0), Vector2(380.0, 2250.0)]),
	# Village north road, then the ride north to the gap in the Wall.
	PackedVector2Array([Vector2(380.0, 2250.0), Vector2(300.0, 2120.0), Vector2(150.0, 1950.0), Vector2(0.0, 1700.0), Vector2(-80.0, 1500.0), Vector2(-100.0, 1400.0)]),
	# Village to the burnt estate and workshop.
	PackedVector2Array([Vector2(-150.0, 2160.0), Vector2(-330.0, 2230.0), Vector2(-560.0, 2240.0), Vector2(-640.0, 2330.0)]),
	# Village to the mill and the barn.
	PackedVector2Array([Vector2(380.0, 2250.0), Vector2(470.0, 2330.0), Vector2(560.0, 2420.0)]),
	PackedVector2Array([Vector2(380.0, 2250.0), Vector2(500.0, 2190.0), Vector2(600.0, 2150.0)]),
]
const ROAD_HALF_WIDTH := 2.5
static var PATHS: Array[PackedVector2Array] = [
	# Feyre's path from the cottage into the forest, to the oak.
	PackedVector2Array([Vector2(-150.0, 2160.0), Vector2(-200.0, 2050.0), Vector2(-300.0, 1900.0), Vector2(-380.0, 1780.0), Vector2(-420.0, 1720.0)]),
	# Deer trails.
	PackedVector2Array([Vector2(-880.0, 1700.0), Vector2(-650.0, 1720.0), Vector2(-420.0, 1720.0), Vector2(-200.0, 1640.0), Vector2(100.0, 1600.0), Vector2(450.0, 1650.0)]),
	PackedVector2Array([Vector2(-600.0, 2000.0), Vector2(-500.0, 1850.0), Vector2(-360.0, 1660.0), Vector2(-300.0, 1520.0)]),
	PackedVector2Array([Vector2(200.0, 2000.0), Vector2(300.0, 1820.0), Vector2(480.0, 1650.0), Vector2(650.0, 1500.0)]),
]
const PATH_HALF_WIDTH := 1.0


static func distance_to_polyline(p: Vector2, line: PackedVector2Array) -> float:
	var best := INF
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		# Cheap reject on the segment's padded bounding box.
		if p.x < minf(a.x, b.x) - best or p.x > maxf(a.x, b.x) + best or p.y < minf(a.y, b.y) - best or p.y > maxf(a.y, b.y) + best:
			continue
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


static func distance_to_creek(p: Vector2) -> float:
	return distance_to_polyline(p, CREEK)


static func distance_to_road(p: Vector2) -> float:
	var best := INF
	for r in ROADS:
		best = minf(best, distance_to_polyline(p, r))
	return best


static func distance_to_path(p: Vector2) -> float:
	var best := INF
	for r in PATHS:
		best = minf(best, distance_to_polyline(p, r))
	return best


static func region_at(p: Vector2) -> StringName:
	for id: StringName in REGION_RECTS:
		if (REGION_RECTS[id] as Rect2).has_point(p):
			return id
	if COTTAGE_FIELDS.has_point(p):
		return &"cottage"
	return &""
