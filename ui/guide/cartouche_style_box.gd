## The thought card's plaque: a pearl cartouche with concave cut corners, a
## gold outer line, an inset gold hairline and a rose in a gold swag on top.
## The plaque starts `medal_inset` px in from the left so the cameo medallion
## (the row's first child) sits over its left edge.
class_name CartoucheStyleBox
extends StyleBox

const GOLD_LIGHT := Color(0.98, 0.89, 0.64)
const GOLD := Color(0.83, 0.64, 0.30)
const PEARL: Array[Color] = [Color(0.99, 0.95, 0.97), Color(0.95, 0.90, 0.98), Color(0.99, 0.91, 0.94), Color(0.91, 0.96, 0.95)]
const ROSE := Color(0.95, 0.65, 0.76)
const SHADOW := Color(0.35, 0.14, 0.31)

@export var medal_inset: float = 42.0
@export var corner: float = 18.0
@export var opacity: float = 0.95


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var r := Rect2(rect.position + Vector2(medal_inset, 0), rect.size - Vector2(medal_inset, 0))
	var rs := RenderingServer
	for g in [9.0, 5.0, 2.0]:
		var sh := _shape(r.grow(g), corner + g)
		for i in sh.size():
			sh[i] += Vector2(0, 6.0 - g * 0.3)
		rs.canvas_item_add_polygon(to_canvas_item, sh, PackedColorArray([Color(SHADOW, 0.05)]))
	var fill := _shape(r, corner)
	rs.canvas_item_add_polygon(to_canvas_item, fill, _colors(fill, r, true))
	var outer := _shape(r.grow(-1.2), corner - 0.6)
	outer.append(outer[0])
	rs.canvas_item_add_polyline(to_canvas_item, outer, _colors(outer, r, false), 2.4, true)
	var inner := _shape(r.grow(-8.0), corner - 4.0)
	inner.append(inner[0])
	rs.canvas_item_add_polyline(to_canvas_item, inner, PackedColorArray([Color(GOLD, 0.75)]), 1.0, true)
	# The rose in its swag, a touch right of centre.
	var top := Vector2(r.position.x + r.size.x * 0.5 + 10.0, r.position.y)
	var swag := PackedVector2Array()
	for i in 21:
		var t := i / 20.0
		swag.append(top + Vector2(-30.0 + 60.0 * t, -9.0 * absf(sin(t * TAU))))
	rs.canvas_item_add_polyline(to_canvas_item, swag, PackedColorArray([GOLD]), 2.0, true)
	rs.canvas_item_add_circle(to_canvas_item, top + Vector2(0, -1), 5.6, GOLD)
	rs.canvas_item_add_circle(to_canvas_item, top + Vector2(0, -1), 4.2, ROSE)


## Rectangle whose four corners are quarter circles cut inward.
func _shape(r: Rect2, rad: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var corners := [[Vector2(x1, y0), PI, PI * 0.5], [Vector2(x1, y1), PI * 1.5, PI],
		[Vector2(x0, y1), 0.0, -PI * 0.5], [Vector2(x0, y0), PI * 0.5, 0.0]]
	for c in corners:
		for i in 9:
			var a: float = lerpf(c[1], c[2], i / 8.0)
			p.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return p


## Diagonal pearl gradient for the fill; light-dark-light gold for the line.
func _colors(pts: PackedVector2Array, r: Rect2, pearl: bool) -> PackedColorArray:
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf(((p.x - r.position.x) / r.size.x + (p.y - r.position.y) / r.size.y) * 0.5, 0.0, 1.0)
		if pearl:
			var f := t * (PEARL.size() - 1)
			var i := mini(int(f), PEARL.size() - 2)
			cols.append(Color(PEARL[i].lerp(PEARL[i + 1], f - i), opacity))
		else:
			cols.append(GOLD_LIGHT.lerp(GOLD, 0.5 + 0.5 * sin(t * TAU * 1.5)))
	return cols
