## Linear features of a region (roads, paths, streams) with a bucketed
## spatial index, so terrain providers can ask "how far am I from the brook?"
## quickly enough to call per height sample.
class_name WoodsFeatures
extends RefCounted

const BUCKET := 32.0

## kind -> Array of [a: Vector2, b: Vector2, half_width: float, depth: float]
var _segments: Dictionary = {}
## kind -> { Vector2i: PackedInt32Array of segment indices }
var _buckets: Dictionary = {}
var _reach: float


## `lines` is an Array of Dictionaries:
## { kind: StringName, points: PackedVector2Array, width: float, depth: float }
## `reach` is the farthest distance any query cares about (metres).
func _init(lines: Array, reach: float = 40.0) -> void:
	_reach = reach
	for line in lines:
		var kind: StringName = line["kind"]
		if not _segments.has(kind):
			_segments[kind] = []
			_buckets[kind] = {}
		var pts: PackedVector2Array = line["points"]
		for i in pts.size() - 1:
			var seg := [pts[i], pts[i + 1], float(line.get("width", 4.0)) * 0.5, float(line.get("depth", 0.0))]
			var index: int = _segments[kind].size()
			_segments[kind].append(seg)
			var lo := Vector2(minf(pts[i].x, pts[i + 1].x), minf(pts[i].y, pts[i + 1].y)) - Vector2.ONE * reach
			var hi := Vector2(maxf(pts[i].x, pts[i + 1].x), maxf(pts[i].y, pts[i + 1].y)) + Vector2.ONE * reach
			for bx in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
				for bz in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
					var key := Vector2i(bx, bz)
					if not _buckets[kind].has(key):
						_buckets[kind][key] = PackedInt32Array()
					_buckets[kind][key].append(index)


## Distance from (x, z) to the nearest feature edge of this kind, negative
## inside it. Returns `reach` when nothing is within reach.
## The second element is that feature's depth.
func query(kind: StringName, x: float, z: float) -> Vector2:
	if not _buckets.has(kind):
		return Vector2(_reach, 0.0)
	var list: Variant = _buckets[kind].get(Vector2i(floori(x / BUCKET), floori(z / BUCKET)))
	if list == null:
		return Vector2(_reach, 0.0)
	var p := Vector2(x, z)
	var best := _reach
	var depth := 0.0
	var segs: Array = _segments[kind]
	for index in list:
		var seg: Array = segs[index]
		var a: Vector2 = seg[0]
		var ab: Vector2 = seg[1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t) - float(seg[2])
		if d < best:
			best = d
			depth = seg[3]
	return Vector2(best, depth)


func distance(kind: StringName, x: float, z: float) -> float:
	return query(kind, x, z).x


## All polylines' points of a kind, flattened into segments (for meshes).
func segments(kind: StringName) -> Array:
	return _segments.get(kind, [])


## Smooths a coarse control polyline into a natural meander (Catmull-Rom),
## with a little seeded wobble so streams and paths don't look drawn.
static func meander(control: PackedVector2Array, step: float = 6.0, wobble: float = 3.0, seed_value: int = 1) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in control.size() - 1:
		var p0 := control[maxi(i - 1, 0)]
		var p1 := control[i]
		var p2 := control[i + 1]
		var p3 := control[mini(i + 2, control.size() - 1)]
		var steps := maxi(2, ceili(p1.distance_to(p2) / step))
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			var p := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			var dir := (p2 - p1).normalized()
			p += Vector2(-dir.y, dir.x) * sin(t * PI) * rng.randf_range(-wobble, wobble)
			out.append(p)
	out.append(control[control.size() - 1])
	return out
