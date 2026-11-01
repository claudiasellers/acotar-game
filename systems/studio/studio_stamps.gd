## Brush footprints for the studio canvas (L30). Image.blend_rect_mask only
## gates on mask alpha, so a soft brush is a few nested hard masks: each level
## blends the paint once, which builds a soft, slightly stepped, painterly edge.
class_name StudioStamps
extends RefCounted

const LEVELS := 3
const ANGLES := 12

## key -> Array[Image] (one mask per level)
static var _cache: Dictionary = {}


static func masks(brush: StudioBrushData, radius: int, angle: float) -> Array:
	var bucket := 0
	if brush.oriented or brush.shape == StudioBrushData.Shape.SPARKLE:
		bucket = posmod(roundi(angle / PI * ANGLES), ANGLES)
	var key := "%s/%d/%d" % [brush.id, radius, bucket]
	if _cache.has(key):
		return _cache[key]
	var out := _build(brush, radius, float(bucket) / ANGLES * PI)
	_cache[key] = out
	return out


static func _build(brush: StudioBrushData, radius: int, angle: float) -> Array:
	var size := radius * 2 + 1
	var imgs: Array = []
	for i in LEVELS:
		imgs.append(Image.create(size, size, false, Image.FORMAT_RGBA8))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(brush.id) + radius
	var streaks := PackedFloat32Array()
	streaks.resize(size)
	for i in size:
		streaks[i] = 0.35 + 0.65 * rng.randf() if rng.randf() > 0.18 else 0.0
	var specks := []
	if brush.shape == StudioBrushData.Shape.SPARKLE:
		for i in maxi(radius / 2, 4):
			specks.append([Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * radius * 0.85, rng.randf_range(1.0, maxf(radius * 0.18, 1.5))])
	var c := cos(-angle)
	var s := sin(-angle)
	var r := float(radius)
	for y in size:
		for x in size:
			var dx := x - r
			var dy := y - r
			# Brush space: u along the stroke, v across it.
			var u := dx * c - dy * s
			var v := dx * s + dy * c
			var a := _alpha(brush.shape, u / r, v / r, streaks, size, r, specks, u, v)
			for l in LEVELS:
				if a > float(l) / LEVELS + 0.001:
					(imgs[l] as Image).set_pixel(x, y, Color(1, 1, 1, 1))
	return imgs


static func _alpha(shape: int, u: float, v: float, streaks: PackedFloat32Array, size: int, r: float,
		specks: Array, dx: float, dy: float) -> float:
	match shape:
		StudioBrushData.Shape.FLAT:
			# Wide across the stroke, thin along it.
			if absf(u) > 0.42 or absf(v) > 1.0:
				return 0.0
			return (1.0 - pow(absf(v), 6.0)) * (1.0 - absf(u) / 0.42 * 0.3)
		StudioBrushData.Shape.BRISTLE:
			if absf(u) > 0.55 or absf(v) > 1.0:
				return 0.0
			var row := clampi(int((v * 0.5 + 0.5) * (size - 1)), 0, size - 1)
			return streaks[row] * (1.0 - absf(u) / 0.55 * 0.5) * (1.0 - pow(absf(v), 4.0))
		StudioBrushData.Shape.WASH:
			var d := sqrt(u * u + v * v)
			return clampf(1.0 - d, 0.0, 1.0)
		StudioBrushData.Shape.SPARKLE:
			for sp in specks:
				var p: Vector2 = sp[0]
				var arm: float = sp[1]
				var ax := absf(dx - p.x)
				var ay := absf(dy - p.y)
				# Four-point star: a cross with a bright heart.
				if (ax <= 0.6 and ay <= arm) or (ay <= 0.6 and ax <= arm) or (ax + ay <= arm * 0.45):
					return 1.0
			return 0.0
		_:
			var d2 := u * u + v * v
			return clampf(1.0 - d2, 0.0, 1.0) if d2 <= 1.0 else 0.0
