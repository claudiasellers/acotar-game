## One of Feyre's little drawings in the sketchbook (L54): charcoal on paper
## over a soft watercolour wash. A quick hand, not clip art: every line is
## laid with uneven pressure (heavy in the middle, lifting at the ends), runs
## a little past where it should stop, wobbles, and is gone over once more
## lightly; shadows are hatched. Drawn from a few strokes, so no image files.
## Colours from SatchelTheme only.
class_name JournalSketch
extends Control

const MOTIFS: Array[StringName] = [
	&"bow", &"coin", &"house", &"moon", &"door", &"wave", &"flame", &"tree",
	&"brush", &"feather", &"sun", &"rose", &"mask", &"mountain",
]
const WASH_PATH := "res://ui/satchel/crafted/wash_bloom.png"

var motif: StringName = &"rose"
var seed_value: int = 1
## 0..1: how much of the drawing is laid down (the draw-in on reveal).
var reveal: float = 1.0:
	set(v):
		reveal = clampf(v, 0.0, 1.0)
		queue_redraw()
var wash_tint: StringName = &"accent"

var _wash: Texture2D


func _init(kind: StringName = &"rose", size_px: float = 96.0) -> void:
	set_motif(kind)
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_wash = SatchelTheme.texture(WASH_PATH)


func set_motif(kind: StringName) -> void:
	motif = kind if kind in MOTIFS else &"rose"
	seed_value = hash(String(motif))
	queue_redraw()


## Every stroke of a motif as polylines in a unit square (0..1).
static func strokes(kind: StringName) -> Array[PackedVector2Array]:
	var s: Array[PackedVector2Array] = []
	match kind:
		&"bow":
			# A recurved hunting bow, strung, an arrow nocked.
			var limb := PackedVector2Array()
			for i in 21:
				var t := float(i) / 20.0
				var y := lerpf(0.1, 0.9, t)
				var x := 0.3 - 0.16 * sin(t * PI) + 0.05 * pow(absf(t - 0.5) * 2.0, 6.0)
				limb.append(Vector2(x, y))
			s.append(limb)
			s.append(PackedVector2Array([Vector2(0.34, 0.11), Vector2(0.37, 0.5), Vector2(0.34, 0.89)]))
			s.append(PackedVector2Array([Vector2(0.37, 0.5), Vector2(0.9, 0.46)]))
			s.append(PackedVector2Array([Vector2(0.82, 0.41), Vector2(0.92, 0.46), Vector2(0.83, 0.52)]))
			s.append(PackedVector2Array([Vector2(0.4, 0.5), Vector2(0.46, 0.43)]))
			s.append(PackedVector2Array([Vector2(0.44, 0.5), Vector2(0.5, 0.43)]))
		&"coin":
			s.append(_arc(Vector2(0.42, 0.58), 0.27, -0.3, TAU - 0.1))
			s.append(_arc(Vector2(0.42, 0.58), 0.19, 0.6, TAU - 0.6))
			s.append(_arc(Vector2(0.66, 0.38), 0.2, -0.4, TAU))
			s.append(PackedVector2Array([Vector2(0.62, 0.3), Vector2(0.62, 0.46)]))
		&"house":
			s.append(PackedVector2Array([Vector2(0.2, 0.5), Vector2(0.19, 0.88), Vector2(0.82, 0.87), Vector2(0.81, 0.5)]))
			s.append(PackedVector2Array([Vector2(0.1, 0.55), Vector2(0.5, 0.2), Vector2(0.9, 0.54)]))
			s.append(PackedVector2Array([Vector2(0.43, 0.87), Vector2(0.43, 0.66), Vector2(0.57, 0.66), Vector2(0.57, 0.87)]))
			s.append(PackedVector2Array([Vector2(0.27, 0.6), Vector2(0.36, 0.6), Vector2(0.36, 0.7), Vector2(0.27, 0.7), Vector2(0.27, 0.6)]))
			s.append(PackedVector2Array([Vector2(0.68, 0.34), Vector2(0.68, 0.2), Vector2(0.76, 0.2), Vector2(0.76, 0.41)]))
			s.append(_wiggle(Vector2(0.72, 0.16), Vector2(0.9, 0.02), 0.03, 3))
		&"moon":
			s.append(_arc(Vector2(0.45, 0.5), 0.32, 0.5, TAU - 0.6))
			s.append(_arc(Vector2(0.6, 0.42), 0.26, 1.1, TAU - 1.9))
			s.append(_wiggle(Vector2(0.08, 0.86), Vector2(0.92, 0.84), 0.015, 4))
		&"door":
			var d := PackedVector2Array([Vector2(0.27, 0.9), Vector2(0.26, 0.4)])
			d.append_array(_arc(Vector2(0.5, 0.4), 0.24, PI, TAU))
			d.append_array(PackedVector2Array([Vector2(0.74, 0.4), Vector2(0.75, 0.9)]))
			s.append(d)
			s.append(PackedVector2Array([Vector2(0.5, 0.17), Vector2(0.5, 0.9)]))
			s.append(_arc(Vector2(0.6, 0.6), 0.025, 0.0, TAU))
			s.append(_arc(Vector2(0.4, 0.6), 0.025, 0.0, TAU))
			s.append(PackedVector2Array([Vector2(0.12, 0.9), Vector2(0.88, 0.91)]))
		&"wave":
			for i in 3:
				s.append(_wiggle(Vector2(0.08, 0.48 + i * 0.15), Vector2(0.92, 0.5 + i * 0.15), 0.05, 3))
			s.append(_arc(Vector2(0.5, 0.3), 0.08, 0.1, PI - 0.1))
			s.append(PackedVector2Array([Vector2(0.42, 0.3), Vector2(0.5, 0.12), Vector2(0.58, 0.3)]))
		&"flame":
			var f := PackedVector2Array()
			for i in 25:
				var t := float(i) / 24.0 * TAU
				var r := 0.22 * (1.0 - 0.75 * pow(maxf(0.0, -sin(t)), 3.0))
				f.append(Vector2(0.5 + r * cos(t), 0.55 + 0.2 * sin(t) - 0.28 * pow(maxf(0.0, -sin(t)), 2.0)))
			s.append(f)
			s.append(PackedVector2Array([Vector2(0.5, 0.7), Vector2(0.44, 0.58), Vector2(0.5, 0.42), Vector2(0.56, 0.58), Vector2(0.5, 0.7)]))
			s.append(PackedVector2Array([Vector2(0.16, 0.88), Vector2(0.82, 0.74)]))
			s.append(PackedVector2Array([Vector2(0.18, 0.74), Vector2(0.84, 0.88)]))
		&"tree":
			# Trunk and limbs, then a loose scribbled crown.
			s.append(PackedVector2Array([Vector2(0.45, 0.9), Vector2(0.47, 0.66), Vector2(0.44, 0.5), Vector2(0.34, 0.38)]))
			s.append(PackedVector2Array([Vector2(0.56, 0.9), Vector2(0.53, 0.66), Vector2(0.57, 0.52), Vector2(0.7, 0.42)]))
			s.append(PackedVector2Array([Vector2(0.48, 0.6), Vector2(0.5, 0.36)]))
			var crown := PackedVector2Array()
			for i in 90:
				var t := float(i) / 89.0 * TAU * 1.15
				crown.append(Vector2(0.5, 0.33) + Vector2(cos(t) * 0.34, sin(t) * 0.22) \
						+ Vector2(cos(t * 9.0), sin(t * 9.0)) * 0.045)
			s.append(crown)
			s.append(_wiggle(Vector2(0.1, 0.9), Vector2(0.9, 0.91), 0.01, 3))
		&"brush":
			s.append(PackedVector2Array([Vector2(0.18, 0.86), Vector2(0.62, 0.37)]))
			s.append(PackedVector2Array([Vector2(0.21, 0.88), Vector2(0.64, 0.4)]))
			s.append(PackedVector2Array([Vector2(0.62, 0.36), Vector2(0.73, 0.19), Vector2(0.8, 0.27), Vector2(0.66, 0.41)]))
			s.append(_wiggle(Vector2(0.12, 0.42), Vector2(0.56, 0.16), 0.04, 2))
		&"feather":
			s.append(PackedVector2Array([Vector2(0.22, 0.9), Vector2(0.5, 0.5), Vector2(0.76, 0.14)]))
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for i in 9:
				var t := float(i) / 8.0
				var c := Vector2(0.3, 0.78).lerp(Vector2(0.74, 0.17), t)
				var w := 0.17 * sin(t * PI)
				left.append(c + Vector2(-w, -w * 0.5))
				right.append(c + Vector2(w, w * 0.5))
			s.append(left)
			s.append(right)
			s.append(PackedVector2Array([Vector2(0.44, 0.6), Vector2(0.36, 0.5)]))
		&"sun":
			# Midsummer: a sun with uneven rays over a swag of ribbon pennants.
			s.append(_arc(Vector2(0.5, 0.42), 0.16, -0.2, TAU + 0.1))
			for i in 12:
				var a := float(i) / 12.0 * TAU + 0.1
				var r0 := 0.21
				var r1 := 0.3 if i % 2 == 0 else 0.26
				s.append(PackedVector2Array([Vector2(0.5, 0.42) + Vector2(cos(a), sin(a)) * r0,
						Vector2(0.5, 0.42) + Vector2(cos(a), sin(a)) * r1]))
			# A ribbon garland swagged beneath it, little pennants hanging off.
			s.append(_arc(Vector2(0.5, 0.42), 0.46, PI * 0.22, PI * 0.78))
			for x in [0.3, 0.5, 0.7]:
				var top := Vector2(0.5, 0.42) + Vector2(x - 0.5, sqrt(maxf(0.0, 0.2116 - pow(x - 0.5, 2.0))))
				s.append(PackedVector2Array([top, top + Vector2(-0.035, 0.08), top + Vector2(0.035, 0.08), top]))
		&"rose":
			var sp := PackedVector2Array()
			for i in 30:
				var t := float(i) / 29.0
				var a := t * TAU * 2.2
				sp.append(Vector2(0.5, 0.34) + Vector2(cos(a), sin(a)) * (0.02 + 0.16 * t))
			s.append(sp)
			s.append(_arc(Vector2(0.5, 0.36), 0.22, 0.2, PI - 0.2))
			s.append(PackedVector2Array([Vector2(0.5, 0.58), Vector2(0.47, 0.75), Vector2(0.49, 0.93)]))
			s.append(PackedVector2Array([Vector2(0.49, 0.76), Vector2(0.56, 0.66), Vector2(0.7, 0.64), Vector2(0.62, 0.74), Vector2(0.49, 0.76)]))
			s.append(PackedVector2Array([Vector2(0.48, 0.84), Vector2(0.4, 0.8)]))
		&"mask":
			# A court half-mask, leaves curling at the temples, a ribbon tie.
			var m := PackedVector2Array([Vector2(0.14, 0.44), Vector2(0.3, 0.34), Vector2(0.5, 0.42),
					Vector2(0.7, 0.34), Vector2(0.86, 0.44), Vector2(0.8, 0.6), Vector2(0.62, 0.64),
					Vector2(0.5, 0.56), Vector2(0.38, 0.64), Vector2(0.2, 0.6), Vector2(0.14, 0.44)])
			s.append(m)
			s.append(_arc(Vector2(0.33, 0.49), 0.065, 0.3, TAU + 0.2))
			s.append(_arc(Vector2(0.67, 0.49), 0.065, 0.3, TAU + 0.2))
			for side in [-1.0, 1.0]:
				var base := Vector2(0.5 + 0.36 * side, 0.4)
				s.append(PackedVector2Array([base, base + Vector2(0.06 * side, -0.14), base + Vector2(0.12 * side, -0.1), base]))
				s.append(PackedVector2Array([base, base + Vector2(0.1 * side, -0.02), base + Vector2(0.14 * side, 0.06), base]))
			s.append(_wiggle(Vector2(0.86, 0.5), Vector2(0.95, 0.86), 0.025, 2))
		&"mountain":
			s.append(PackedVector2Array([Vector2(0.05, 0.86), Vector2(0.4, 0.24), Vector2(0.56, 0.5), Vector2(0.68, 0.36), Vector2(0.95, 0.86)]))
			s.append(PackedVector2Array([Vector2(0.31, 0.41), Vector2(0.4, 0.47), Vector2(0.47, 0.36)]))
			s.append(PackedVector2Array([Vector2(0.05, 0.86), Vector2(0.95, 0.87)]))
	return s


## Where each motif's shadow is hatched: [centre, half-size, slope] in unit space.
static func hatches(kind: StringName) -> Array:
	match kind:
		&"bow": return [[Vector2(0.22, 0.5), Vector2(0.04, 0.22), 1.0]]
		&"coin": return [[Vector2(0.5, 0.7), Vector2(0.12, 0.08), 1.0]]
		&"house": return [[Vector2(0.66, 0.42), Vector2(0.12, 0.07), -1.0], [Vector2(0.5, 0.77), Vector2(0.05, 0.09), 1.0]]
		&"moon": return [[Vector2(0.3, 0.55), Vector2(0.07, 0.14), 1.0]]
		&"door": return [[Vector2(0.63, 0.62), Vector2(0.09, 0.22), 1.0]]
		&"wave": return [[Vector2(0.5, 0.9), Vector2(0.3, 0.04), 1.0]]
		&"flame": return [[Vector2(0.5, 0.82), Vector2(0.2, 0.05), -1.0]]
		&"tree": return [[Vector2(0.53, 0.76), Vector2(0.03, 0.12), 1.0], [Vector2(0.6, 0.45), Vector2(0.14, 0.06), 1.0]]
		&"brush": return [[Vector2(0.4, 0.62), Vector2(0.07, 0.07), -1.0]]
		&"feather": return [[Vector2(0.58, 0.42), Vector2(0.08, 0.08), 1.0]]
		&"sun": return [[Vector2(0.55, 0.47), Vector2(0.07, 0.07), 1.0]]
		&"rose": return [[Vector2(0.56, 0.42), Vector2(0.08, 0.07), 1.0]]
		&"mask": return [[Vector2(0.5, 0.5), Vector2(0.06, 0.04), 1.0], [Vector2(0.72, 0.58), Vector2(0.06, 0.03), 1.0]]
		&"mountain": return [[Vector2(0.7, 0.66), Vector2(0.12, 0.16), 1.0], [Vector2(0.48, 0.48), Vector2(0.05, 0.1), 1.0]]
	return []


static func _arc(c: Vector2, r: float, a0: float, a1: float, n: int = 20) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func _wiggle(a: Vector2, b: Vector2, amp: float, waves: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := waves * 8
	for i in n + 1:
		var t := float(i) / n
		out.append(a.lerp(b, t) + Vector2(0, sin(t * TAU * waves) * amp))
	return out


## A polyline resampled every `step` px (pressure needs even spacing).
static func _resample(line: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([line[0]])
	for i in range(1, line.size()):
		var a := line[i - 1]
		var b := line[i]
		var n := maxi(1, int(a.distance_to(b) / step))
		for k in range(1, n + 1):
			out.append(a.lerp(b, float(k) / n))
	return out


func _draw() -> void:
	var side := minf(size.x, size.y)
	var origin := (size - Vector2(side, side)) * 0.5
	if _wash:
		var tint := SatchelTheme.color(wash_tint)
		draw_texture_rect(_wash, Rect2(origin - Vector2.ONE * side * 0.08, Vector2.ONE * side * 1.16), false, Color(tint, 0.38 * reveal))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ink := SatchelTheme.color(&"ink")
	var base := maxf(1.1, side / 46.0)
	var all := strokes(motif)
	var total := all.size() + 1
	for si in all.size():
		var share := clampf(reveal * total - si, 0.0, 1.0)
		if share > 0.0 and all[si].size() >= 2:
			var pts := PackedVector2Array()
			for p in all[si]:
				pts.append(origin + p * side)
			_charcoal(pts, share, base, ink, rng, side * rng.randf_range(0.03, 0.08))
	# Hatching last, lighter, once the lines are down.
	var hatch_share := clampf(reveal * total - all.size(), 0.0, 1.0)
	if hatch_share <= 0.0:
		return
	for h: Array in hatches(motif):
		var c: Vector2 = origin + (h[0] as Vector2) * side
		var half: Vector2 = (h[1] as Vector2) * side
		var slope: float = h[2]
		var n := maxi(3, int(half.x * 2.0 / maxf(3.0, side / 24.0)))
		for k in int(n * hatch_share):
			var x := lerpf(-half.x, half.x, (float(k) + 0.5) / n)
			var a := c + Vector2(x - half.y * 0.5 * slope, -half.y)
			var b := c + Vector2(x + half.y * 0.5 * slope, half.y)
			_charcoal(PackedVector2Array([a, b]), 1.0, base * 0.55, Color(ink, 0.55), rng, side * 0.015)


## One charcoal line: wobbling, heavy in the middle and lifting at the ends,
## running `overrun` px past both ends, then gone over once more lightly.
func _charcoal(line: PackedVector2Array, share: float, base: float, ink: Color,
		rng: RandomNumberGenerator, overrun: float) -> void:
	var pts := _resample(line, 3.0)
	if pts.size() < 2:
		return
	var d0 := (pts[0] - pts[1]).normalized()
	var d1 := (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	pts.insert(0, pts[0] + d0 * overrun * rng.randf_range(0.2, 1.0))
	pts.append(pts[pts.size() - 1] + d1 * overrun * rng.randf_range(0.4, 1.2))
	var count := maxi(2, int(ceil(pts.size() * share)))
	var phase := rng.randf() * TAU
	var freq := rng.randf_range(2.0, 5.0)
	for pass_i in 2:
		var off := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * (0.0 if pass_i == 0 else 1.4)
		var prev := Vector2.INF
		for i in count:
			var t := float(i) / float(pts.size() - 1)
			var n := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized().orthogonal()
			var wob := sin(t * TAU * freq + phase) * 0.9 + rng.randf_range(-0.35, 0.35)
			var p := pts[i] + n * wob + off
			if prev != Vector2.INF:
				var press := pow(sin(t * PI), 0.7) * (0.75 + 0.25 * sin(t * 11.0 + phase))
				var w := base * lerpf(0.35, 1.25, press) * (1.0 if pass_i == 0 else 0.45)
				var a := lerpf(0.35, 0.92, press) * (1.0 if pass_i == 0 else 0.4)
				draw_line(prev, p, Color(ink, ink.a * a), w, true)
			prev = p
