## Paint-like colour mixing (L30): blue and yellow make green, not grey.
## Mixes reflectances geometrically (a cheap stand-in for Kubelka-Munk), then
## gives back most of the saturation that averaging loses.
class_name PigmentMix
extends RefCounted

const FLOOR := 0.02


## t = share of b in the mix (0 = all a, 1 = all b).
static func mix(a: Color, b: Color, t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	if t <= 0.0:
		return Color(a, 1.0)
	if t >= 1.0:
		return Color(b, 1.0)
	var out := Color(
		_geo(a.r, b.r, t), _geo(a.g, b.g, t), _geo(a.b, b.b, t), 1.0)
	# Keep pigments vivid: lift saturation towards the inputs' weighted mean.
	var want := lerpf(a.s, b.s, t) * 0.9
	if out.s < want and out.s > 0.001:
		out = Color.from_hsv(out.h, want, out.v)
	# Mixing with white lightens like paint does (tints, not mud).
	var light := lerpf(a.v, b.v, t)
	if out.v < light * 0.85:
		out = Color.from_hsv(out.h, out.s, lerpf(out.v, light, 0.5))
	return out


static func _geo(x: float, y: float, t: float) -> float:
	return exp(lerpf(log(maxf(x, FLOOR)), log(maxf(y, FLOOR)), t))


## Distance between two colours, roughly perceptual (0..~1.7).
static func distance(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	var rm := (a.r + b.r) * 0.5
	return sqrt((2.0 + rm) * dr * dr + 4.0 * dg * dg + (3.0 - rm) * db * db) / 3.0
