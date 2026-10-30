## One streamed region of the world: a scene of terrain, scatter, spawns and
## story volumes, placed at world coordinates (root design doc §2).
class_name RegionDef
extends Resource

@export var id: StringName
## The region's root scene (a Node3D authored at world coordinates).
@export_file("*.tscn") var scene_path: String
## Rough centre and radius of the region's footprint, in metres (x/z only).
@export var center: Vector3
@export var radius: float = 200.0
## Regions to keep loaded while Feyre is in this one.
@export var neighbors: PackedStringArray = []
## JSON coverage report written by the region's generator (engineering rules
## R1/R9), read by tools/world_smoke.gd. Keys: types, placements_per_km2,
## empty_cells, landmarks, draw_calls.
@export_file("*.json") var report_path: String


## Horizontal distance from a point to this region's edge (negative inside).
func edge_distance(point: Vector3) -> float:
	return Vector2(point.x - center.x, point.z - center.z).length() - radius
