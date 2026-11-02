## How a bridge sits on the world: square across its water, its ends on the
## ground, its deck one smooth walkable surface. Every bridge reads its place
## from here, computed from the water line and the height field, so moving the
## water or the ground moves the bridge. tests/unit/world/test_bridges.gd holds
## every bridge in the game to the limits below.
class_name BridgeSpan
extends RefCounted

## How far off square to the water a bridge may sit.
const MAX_SKEW_DEGREES := 3.0
## How far a deck end may sit from the ground under it.
const MAX_END_GAP := 0.08
## How much a deck may tilt to meet banks of different heights.
const MAX_PITCH_DEGREES := 8.0
## The collider runs on past each deck end and eases under the ground, so
## there is no lip to catch a running foot.
const TIP_LENGTH := 1.6
const TIP_DROP := 0.14


## {centre, along, across}: the point on the water `line` nearest `near`, the
## water's direction there and the unit direction square to it, turned to run
## away from `from`.
static func square_across(line: PackedVector2Array, near: Vector2, from: Vector2) -> Dictionary:
	var best := INF
	var centre := near
	var along := Vector2.RIGHT
	for i in line.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(near, line[i], line[i + 1])
		if q.distance_to(near) < best:
			best = q.distance_to(near)
			centre = q
			along = (line[i + 1] - line[i]).normalized()
	var across := along.orthogonal()
	if across.dot(centre - from) < 0.0:
		across = -across
	return {centre = centre, along = along, across = across}


## The two waypoints that bring a road or path in line with the bridge:
## `run` metres either side of the centre, on its axis.
static func run_in(span: Dictionary, run: float) -> PackedVector2Array:
	var c: Vector2 = span.centre
	var d: Vector2 = span.across
	return PackedVector2Array([c - d * run, c + d * run])


## Both deck ends at ground height, `half` metres either side of the centre.
static func ends_on_ground(span: Dictionary, half: float) -> Array[Vector3]:
	var c: Vector2 = span.centre
	var d: Vector2 = span.across
	var a := c - d * half
	var b := c + d * half
	return [Vector3(a.x, WorldHeight.height_at(a.x, a.y), a.y), Vector3(b.x, WorldHeight.height_at(b.x, b.y), b.y)]


## Local +Z runs end to end, centred between them, upright apart from the tilt.
static func frame(a: Vector3, b: Vector3) -> Transform3D:
	var z := (b - a).normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, z.cross(x), z), (a + b) * 0.5)


## The walking surface: `profile` is (distance along local +Z, height), first
## to last. One sheet, so nothing steps between planks.
static func deck_shape(profile: PackedVector2Array, half_width: float) -> ConcavePolygonShape3D:
	var line := PackedVector2Array()
	line.append(profile[0] + Vector2(-TIP_LENGTH, -TIP_DROP))
	line.append_array(profile)
	line.append(profile[profile.size() - 1] + Vector2(TIP_LENGTH, -TIP_DROP))
	var faces := PackedVector3Array()
	for i in line.size() - 1:
		var p := line[i]
		var q := line[i + 1]
		var l0 := Vector3(-half_width, p.y, p.x)
		var r0 := Vector3(half_width, p.y, p.x)
		var l1 := Vector3(-half_width, q.y, q.x)
		var r1 := Vector3(half_width, q.y, q.x)
		faces.append_array(PackedVector3Array([l0, l1, r0, r0, l1, r1]))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	return shape


## An arch of `length`: sin-shaped, `rise` high at the middle, 0 at the ends.
static func arch_profile(length: float, rise: float, steps := 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		out.append(Vector2((t - 0.5) * length, rise * sin(PI * t)))
	return out
