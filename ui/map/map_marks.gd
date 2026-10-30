## The little painted marks drawn over the map: Feyre's rose-gold arrow and
## the landmark icons (house, tree, water, stones, tower, flower, star).
## Only things she is or has seen: never a destination (R2).
class_name MapMarks
extends RefCounted

const GOLD := Color(0.93, 0.74, 0.38)
const GOLD_LIGHT := Color(1.0, 0.90, 0.62)
const PEARL := Color(1.0, 0.97, 0.98)
const ROSE := Color(0.95, 0.50, 0.68)
const PLUM := Color(0.42, 0.26, 0.42)
const MINT := Color(0.50, 0.80, 0.66)
const WATER := Color(0.55, 0.68, 0.98)
const LILAC := Color(0.72, 0.62, 0.92)

## Label words -> icon kind, first match wins.
const KIND_WORDS := [
	["water", ["fall", "pool", "pond", "spring", "weir", "well", "creek", "river", "lake", "bridge"]],
	["tree", ["oak", "tree", "grove", "willow", "birch", "orchard", "yew", "wood"]],
	["stones", ["stone", "ring", "cairn", "menhir", "rock", "cave"]],
	["tower", ["tower", "spire", "belvedere", "folly", "gate", "arch"]],
	["flower", ["rose", "garden", "briar", "bower", "blossom", "glass", "meadow"]],
	["house", ["house", "cottage", "manor", "mill", "tavern", "hall", "barn", "smithy", "shop",
		"shrine", "estate", "stable", "steading", "chapel", "workshop", "shed", "hut", "square", "row", "market"]],
]


static func kind_for(label: String) -> StringName:
	var l := label.to_lower()
	for pair: Array in KIND_WORDS:
		for word: String in pair[1]:
			if l.contains(word):
				return StringName(pair[0])
	return &"star"


## Feyre: a rose-gold arrowhead pointing along `angle` (screen radians, 0 =
## up/north), on a pearl disc with a slow soft pulse.
static func draw_feyre(ci: CanvasItem, at: Vector2, angle: float, s: float, t: float) -> void:
	var pulse := fmod(t * 0.8, 1.0)
	ci.draw_circle(at, s * (1.0 + pulse * 1.4), Color(ROSE, 0.30 * (1.0 - pulse)))
	ci.draw_circle(at, s * 0.95, Color(PEARL, 0.95))
	var dir := Vector2(sin(angle), -cos(angle))
	var side := Vector2(-dir.y, dir.x)
	var tip := at + dir * s * 1.25
	var back := at - dir * s * 0.55
	var pts := PackedVector2Array([tip, at - dir * s * 0.75 + side * s * 0.8, back, at - dir * s * 0.75 - side * s * 0.8])
	ci.draw_colored_polygon(pts, ROSE)
	pts.append(tip)
	ci.draw_polyline(pts, GOLD, maxf(1.5, s * 0.14), true)
	ci.draw_circle(at + dir * s * 0.2, s * 0.16, GOLD_LIGHT)


## A landmark icon on a small pearl coin with a gold rim.
static func draw_landmark(ci: CanvasItem, at: Vector2, kind: StringName, s: float, glow: float = 0.0) -> void:
	if glow > 0.0:
		ci.draw_circle(at, s * (1.3 + glow * 0.6), Color(GOLD_LIGHT, 0.45 * glow))
	ci.draw_circle(at, s + 1.5, GOLD)
	ci.draw_circle(at, s, PEARL)
	var k := s * 0.62
	match kind:
		&"house":
			ci.draw_rect(Rect2(at + Vector2(-k * 0.6, -k * 0.1), Vector2(k * 1.2, k * 0.8)), ROSE)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-k * 0.85, -k * 0.05),
				at + Vector2(0, -k * 0.85), at + Vector2(k * 0.85, -k * 0.05)]), PLUM)
		&"tree":
			ci.draw_rect(Rect2(at + Vector2(-k * 0.12, k * 0.1), Vector2(k * 0.24, k * 0.65)), PLUM)
			ci.draw_circle(at + Vector2(0, -k * 0.2), k * 0.6, MINT)
			ci.draw_circle(at + Vector2(-k * 0.2, -k * 0.4), k * 0.18, Color(1, 1, 1, 0.6))
		&"water":
			ci.draw_circle(at + Vector2(0, k * 0.2), k * 0.5, WATER)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-k * 0.47, k * 0.05),
				at + Vector2(0, -k * 0.8), at + Vector2(k * 0.47, k * 0.05)]), WATER)
			ci.draw_circle(at + Vector2(-k * 0.15, k * 0.1), k * 0.13, Color(1, 1, 1, 0.8))
		&"stones":
			for i in 3:
				var x := (i - 1) * k * 0.55
				ci.draw_rect(Rect2(at + Vector2(x - k * 0.17, -k * (0.55 if i == 1 else 0.35)),
					Vector2(k * 0.34, k * (1.1 if i == 1 else 0.9))), LILAC)
		&"tower":
			ci.draw_rect(Rect2(at + Vector2(-k * 0.28, -k * 0.35), Vector2(k * 0.56, k * 1.1)), LILAC)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-k * 0.42, -k * 0.3),
				at + Vector2(0, -k * 1.0), at + Vector2(k * 0.42, -k * 0.3)]), ROSE)
		&"flower":
			for i in 5:
				var a := TAU * i / 5.0
				ci.draw_circle(at + Vector2(sin(a), -cos(a)) * k * 0.42, k * 0.3, ROSE.lightened(0.25))
			ci.draw_circle(at, k * 0.24, GOLD_LIGHT)
		_:
			var pts := PackedVector2Array()
			for i in 10:
				var a := TAU * i / 10.0
				var r := k * (0.85 if i % 2 == 0 else 0.38)
				pts.append(at + Vector2(sin(a), -cos(a)) * r)
			ci.draw_colored_polygon(pts, GOLD)
