## One of Feyre's little drawings in the sketchbook (L54): a loose charcoal
## sketch over a soft watercolour wash, drawn from a few strokes so it never
## needs an image file. Each stroke is laid twice, a hair apart, the way a
## quick hand goes over a line. Colours come from SatchelTheme only.
class_name JournalSketch
extends Control

const MOTIFS: Array[StringName] = [
	&"bow", &"coin", &"house", &"moon", &"door", &"wave", &"flame", &"tree",
	&"brush", &"feather", &"star", &"rose", &"mask", &"mountain",
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
			s.append(_arc(Vector2(0.18, 0.5), 0.42, -1.25, 1.25))
			s.append(PackedVector2Array([Vector2(0.33, 0.12), Vector2(0.33, 0.88)]))
			s.append(PackedVector2Array([Vector2(0.12, 0.5), Vector2(0.9, 0.5)]))
			s.append(PackedVector2Array([Vector2(0.8, 0.42), Vector2(0.9, 0.5), Vector2(0.8, 0.58)]))
		&"coin":
			s.append(_arc(Vector2(0.45, 0.55), 0.3, 0.0, TAU))
			s.append(_arc(Vector2(0.45, 0.55), 0.22, 0.4, TAU - 0.4))
			s.append(_arc(Vector2(0.68, 0.36), 0.2, 0.0, TAU))
		&"house":
			s.append(PackedVector2Array([Vector2(0.18, 0.5), Vector2(0.18, 0.88), Vector2(0.82, 0.88), Vector2(0.82, 0.5)]))
			s.append(PackedVector2Array([Vector2(0.1, 0.54), Vector2(0.5, 0.2), Vector2(0.9, 0.54)]))
			s.append(PackedVector2Array([Vector2(0.43, 0.88), Vector2(0.43, 0.66), Vector2(0.57, 0.66), Vector2(0.57, 0.88)]))
			s.append(PackedVector2Array([Vector2(0.68, 0.34), Vector2(0.68, 0.2), Vector2(0.76, 0.2), Vector2(0.76, 0.4)]))
			s.append(_wiggle(Vector2(0.72, 0.16), Vector2(0.86, 0.02), 0.03, 3))
		&"moon":
			s.append(_arc(Vector2(0.45, 0.5), 0.32, 0.6, TAU - 0.6))
			s.append(_arc(Vector2(0.6, 0.42), 0.26, 1.2, TAU - 1.9))
			for p: Vector2 in [Vector2(0.82, 0.2), Vector2(0.86, 0.66), Vector2(0.2, 0.16)]:
				s.append(PackedVector2Array([p + Vector2(-0.04, 0), p + Vector2(0.04, 0)]))
				s.append(PackedVector2Array([p + Vector2(0, -0.04), p + Vector2(0, 0.04)]))
		&"door":
			var d := PackedVector2Array([Vector2(0.26, 0.9), Vector2(0.26, 0.4)])
			d.append_array(_arc(Vector2(0.5, 0.4), 0.24, PI, TAU))
			d.append_array(PackedVector2Array([Vector2(0.74, 0.4), Vector2(0.74, 0.9)]))
			s.append(d)
			s.append(PackedVector2Array([Vector2(0.5, 0.18), Vector2(0.5, 0.9)]))
			s.append(_arc(Vector2(0.62, 0.62), 0.03, 0.0, TAU))
			s.append(PackedVector2Array([Vector2(0.14, 0.9), Vector2(0.86, 0.9)]))
		&"wave":
			for i in 3:
				s.append(_wiggle(Vector2(0.1, 0.5 + i * 0.14), Vector2(0.9, 0.5 + i * 0.14), 0.05, 3))
			s.append(_arc(Vector2(0.5, 0.3), 0.08, 0.0, PI))
			s.append(PackedVector2Array([Vector2(0.42, 0.3), Vector2(0.5, 0.12), Vector2(0.58, 0.3)]))
		&"flame":
			var f := PackedVector2Array()
			for i in 25:
				var t := float(i) / 24.0 * TAU
				var r := 0.22 * (1.0 - 0.75 * pow(maxf(0.0, -sin(t)), 3.0))
				f.append(Vector2(0.5 + r * cos(t), 0.55 + 0.2 * sin(t) - 0.28 * pow(maxf(0.0, -sin(t)), 2.0)))
			s.append(f)
			s.append(PackedVector2Array([Vector2(0.18, 0.88), Vector2(0.8, 0.74)]))
			s.append(PackedVector2Array([Vector2(0.2, 0.74), Vector2(0.82, 0.88)]))
		&"tree":
			s.append(PackedVector2Array([Vector2(0.46, 0.9), Vector2(0.47, 0.55), Vector2(0.4, 0.42)]))
			s.append(PackedVector2Array([Vector2(0.54, 0.9), Vector2(0.53, 0.55), Vector2(0.62, 0.44)]))
			s.append(_arc(Vector2(0.36, 0.4), 0.16, PI * 0.5, PI * 1.9))
			s.append(_arc(Vector2(0.55, 0.26), 0.18, PI * 0.9, PI * 2.2))
			s.append(_arc(Vector2(0.68, 0.44), 0.15, PI * 1.4, PI * 2.6))
			s.append(PackedVector2Array([Vector2(0.12, 0.9), Vector2(0.88, 0.9)]))
		&"brush":
			s.append(PackedVector2Array([Vector2(0.2, 0.84), Vector2(0.62, 0.36)]))
			s.append(PackedVector2Array([Vector2(0.62, 0.36), Vector2(0.72, 0.2), Vector2(0.8, 0.28), Vector2(0.66, 0.4)]))
			s.append(_wiggle(Vector2(0.14, 0.4), Vector2(0.56, 0.18), 0.04, 2))
		&"feather":
			s.append(PackedVector2Array([Vector2(0.24, 0.86), Vector2(0.74, 0.16)]))
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for i in 9:
				var t := float(i) / 8.0
				var c := Vector2(0.3, 0.78).lerp(Vector2(0.72, 0.18), t)
				var w := 0.16 * sin(t * PI)
				left.append(c + Vector2(-w, -w * 0.5))
				right.append(c + Vector2(w, w * 0.5))
			s.append(left)
			s.append(right)
		&"star":
			var st := PackedVector2Array()
			for i in 11:
				var a := -PI * 0.5 + float(i) * TAU / 10.0
				var r := 0.36 if i % 2 == 0 else 0.15
				st.append(Vector2(0.5, 0.52) + Vector2(cos(a), sin(a)) * r)
			s.append(st)
			s.append(PackedVector2Array([Vector2(0.14, 0.18), Vector2(0.2, 0.18)]))
			s.append(PackedVector2Array([Vector2(0.84, 0.84), Vector2(0.9, 0.84)]))
		&"rose":
			var sp := PackedVector2Array()
			for i in 30:
				var t := float(i) / 29.0
				var a := t * TAU * 2.2
				sp.append(Vector2(0.5, 0.34) + Vector2(cos(a), sin(a)) * (0.02 + 0.16 * t))
			s.append(sp)
			s.append(_arc(Vector2(0.5, 0.36), 0.22, 0.2, PI - 0.2))
			s.append(PackedVector2Array([Vector2(0.5, 0.58), Vector2(0.48, 0.92)]))
			s.append(PackedVector2Array([Vector2(0.49, 0.76), Vector2(0.56, 0.66), Vector2(0.7, 0.64), Vector2(0.62, 0.74), Vector2(0.49, 0.76)]))
			s.append(PackedVector2Array([Vector2(0.49, 0.76), Vector2(0.62, 0.68)]))
		&"mask":
			var m := PackedVector2Array([Vector2(0.08, 0.42)])
			m.append_array(PackedVector2Array([Vector2(0.3, 0.3), Vector2(0.5, 0.4), Vector2(0.7, 0.3), Vector2(0.92, 0.42),
					Vector2(0.84, 0.62), Vector2(0.62, 0.66), Vector2(0.5, 0.56), Vector2(0.38, 0.66), Vector2(0.16, 0.62), Vector2(0.08, 0.42)]))
			s.append(m)
			s.append(_arc(Vector2(0.32, 0.48), 0.07, 0.0, TAU))
			s.append(_arc(Vector2(0.68, 0.48), 0.07, 0.0, TAU))
			s.append(_wiggle(Vector2(0.9, 0.44), Vector2(0.98, 0.8), 0.02, 2))
		&"mountain":
			s.append(PackedVector2Array([Vector2(0.06, 0.86), Vector2(0.4, 0.24), Vector2(0.56, 0.5), Vector2(0.68, 0.36), Vector2(0.94, 0.86)]))
			s.append(PackedVector2Array([Vector2(0.32, 0.4), Vector2(0.4, 0.46), Vector2(0.46, 0.36)]))
			s.append(PackedVector2Array([Vector2(0.06, 0.86), Vector2(0.94, 0.86)]))
	return s


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


func _draw() -> void:
	var side := minf(size.x, size.y)
	var origin := (size - Vector2(side, side)) * 0.5
	if _wash:
		var tint := SatchelTheme.color(wash_tint)
		draw_texture_rect(_wash, Rect2(origin - Vector2.ONE * side * 0.08, Vector2.ONE * side * 1.16), false, Color(tint, 0.38 * reveal))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ink := SatchelTheme.color(&"ink")
	var all := strokes(motif)
	var total := all.size()
	for si in total:
		var line := all[si]
		# The draw-in: strokes appear in order as reveal runs 0..1.
		var share := clampf(reveal * total - si, 0.0, 1.0)
		if share <= 0.0 or line.size() < 2:
			continue
		var count := maxi(2, int(ceil(line.size() * share)))
		for pass_i in 2:
			var pts := PackedVector2Array()
			var off := Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
			for i in count:
				var j := Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
				pts.append(origin + line[i] * side + off + j)
			var width := maxf(1.2, side / 52.0) * (1.0 if pass_i == 0 else 0.6)
			draw_polyline(pts, Color(ink, 0.85 if pass_i == 0 else 0.4), width, true)
