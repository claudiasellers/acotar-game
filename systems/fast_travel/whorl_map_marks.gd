## The whorl stones on her map (minimap and full map): a small spiral
## pictogram on a pearl coin, the way she sketches them on the travel card.
## A pair shows once its ground is sketched on the map (MapReveal) or she has
## painted her mark there; it never shows unexplored land (R2: no markers to
## places she hasn't been). Unmarked: a thin plum whorl on a lilac rim.
## Marked: a rose whorl on a gold rim with her little rose beside it.
class_name WhorlMapMarks
extends RefCounted

const PEARL := Color(1.0, 0.97, 0.98)
const PLUM := Color(0.42, 0.26, 0.42)
const LILAC := Color(0.72, 0.62, 0.92)
const GOLD := Color(0.93, 0.74, 0.38)
const GOLD_LIGHT := Color(1.0, 0.90, 0.62)
const ROSE := Color(0.88, 0.36, 0.56)
const ROSE_LIGHT := Color(0.97, 0.62, 0.76)
const LABEL := "Whorl stones"


## The pairs her map shows: sketched ground, or her mark painted there.
static func shown(reveal: MapReveal) -> Array[WhorlStoneDef]:
	var out: Array[WhorlStoneDef] = []
	for d in WhorlStones.defs():
		if WhorlStones.is_marked(d.id) or (reveal != null and reveal.is_seen(d.position.x, d.position.y)):
			out.append(d)
	return out


## One pair's pictogram, centred on `at`, coin radius `s`. `t` drives the
## marked pair's soft shimmer.
static func draw(ci: CanvasItem, at: Vector2, s: float, marked: bool, t: float = 0.0) -> void:
	if marked:
		var glow := 0.5 + 0.5 * sin(t * 2.2)
		ci.draw_circle(at, s * (1.35 + 0.1 * glow), Color(GOLD_LIGHT, 0.28 + 0.12 * glow))
	ci.draw_circle(at, s + 1.5, GOLD if marked else LILAC)
	ci.draw_circle(at, s, PEARL)
	WhorlInk.ink_whorl(ci, at, s * 0.7, ROSE if marked else PLUM, maxf(1.5, s * (0.2 if marked else 0.14)))
	if marked:
		var r := at + Vector2(s * 0.78, s * 0.62)
		for i in 5:
			var a := TAU * i / 5.0
			ci.draw_circle(r + Vector2(sin(a), -cos(a)) * s * 0.17, s * 0.15, ROSE_LIGHT)
		ci.draw_circle(r, s * 0.12, GOLD_LIGHT)


## Draws every shown pair through `to_point` (world XZ -> canvas point),
## skipping those `keep` rejects (outside the view). With a `font`, names each
## pair below it the way the map names landmarks. Returns how many it drew.
static func draw_all(ci: CanvasItem, reveal: MapReveal, to_point: Callable, keep: Callable, s: float, t: float,
		font: Font = null) -> int:
	var n := 0
	for d in shown(reveal):
		var p: Vector2 = to_point.call(d.position)
		if not keep.call(p):
			continue
		draw(ci, p, s, WhorlStones.is_marked(d.id), t)
		if font:
			var w := font.get_string_size(LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var at := p + Vector2(-w * 0.5, s + 20.0)
			ci.draw_string_outline(font, at, LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, Color(PEARL, 0.95))
			ci.draw_string(font, at, LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PLUM)
		n += 1
	return n
