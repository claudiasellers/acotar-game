## Pause menu "Wriggle free": finds open ground near Feyre when she is wedged
## between rocks, sunk into a mesh or stuck on a ledge. Searches rings around
## her for a floor her capsule fits on, then falls back to the places she
## recently stood.
class_name WriggleFree
extends RefCounted

const RINGS: Array[float] = [1.0, 1.75, 2.75, 4.0, 6.0, 9.0]
const STEPS := 12
const CAPSULE_RADIUS := 0.3
const CAPSULE_HEIGHT := 1.7
## Downward floor probes start at waist height (so indoors finds the floor,
## not the roof), then this far above her, and reach this far below.
const PROBE_STARTS: Array[float] = [1.0, 3.0]
const PROBE_DOWN := 8.0
const MIN_FLOOR_Y := 0.7


## A free standing position, or null if nowhere nearby fits.
static func find_spot(body: CharacterBody3D, safe_spots: Array[Vector3] = []) -> Variant:
	var space := body.get_world_3d().direct_space_state
	var mask := body.collision_mask
	var origin := body.global_position
	for radius in RINGS:
		for i in STEPS:
			var angle := TAU * float(i) / float(STEPS)
			var xz := origin + Vector3(sin(angle), 0.0, cos(angle)) * radius
			var spot: Variant = _standing_spot(space, xz, mask, body.get_rid())
			if spot != null:
				return spot
	for i in range(safe_spots.size() - 1, -1, -1):
		var safe := safe_spots[i]
		if safe.distance_to(origin) < 1.0:
			continue
		if fits(space, safe + Vector3.UP * 0.05, mask, body.get_rid()):
			return safe + Vector3.UP * 0.05
	return null


## Floor under `at` (probing from above) with room for her capsule, or null.
static func _standing_spot(space: PhysicsDirectSpaceState3D, at: Vector3, mask: int, exclude: RID) -> Variant:
	for start in PROBE_STARTS:
		var query := PhysicsRayQueryParameters3D.create(
				at + Vector3.UP * start, at + Vector3.DOWN * PROBE_DOWN, mask, [exclude])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).y < MIN_FLOOR_Y:
			continue
		var feet: Vector3 = hit.position + Vector3.UP * 0.05
		if fits(space, feet, mask, exclude):
			return feet
	return null


## True if her capsule standing with its feet at `feet` touches nothing.
static func fits(space: PhysicsDirectSpaceState3D, feet: Vector3, mask: int, exclude: RID) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = capsule
	params.collision_mask = mask
	params.exclude = [exclude]
	# Lift a hair so the floor itself doesn't count as an overlap.
	params.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (CAPSULE_HEIGHT * 0.5 + 0.02))
	return space.intersect_shape(params, 1).is_empty()
