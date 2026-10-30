## Fixed facts about the shared world map. Every lane places content in this
## frame: metres, +X east, -Z north, +Y up, origin at the manor courtyard.
## See docs/contracts/world.md.
class_name WorldMap
extends RefCounted

## The Wall runs east-west along this line. North (smaller z) is Prythian.
const WALL_Z := 1400.0
## Where the ride north passes through the gap in the Wall.
const WALL_GAP_X := -100.0
## Half-width of the shimmer strip either side of WALL_Z.
const WALL_SEAM_HALF_DEPTH := 5.0

## The whole playable map in XZ (position = min x, min z). Terrain3D covers
## exactly this rectangle in 1024 m regions.
const MAP_RECT := Rect2(-2048.0, -2048.0, 4096.0, 5120.0)
## Terrain3D settings shared by the bake and the runtime World scene.
const TERRAIN_REGION_SIZE := 1024
const TERRAIN_VERTEX_SPACING := 1.0

## The human realm (world lane), south of the Wall.
const HUMAN_REALM_RECT := Rect2(-900.0, 1400.0, 1600.0, 1100.0)


static func is_in_prythian(world_pos: Vector3) -> bool:
	return world_pos.z < WALL_Z


static func distance_to_wall(world_pos: Vector3) -> float:
	return absf(world_pos.z - WALL_Z)
