## A small illustrated icon drawn in code: an item's shape (flower, berry,
## feather, gem...) in its own colour on a pearl disc. Unfound entries draw
## the same shape as a lilac silhouette; shiny ones glint in gold.
class_name ItemIcon
extends Control

const SILHOUETTE := Color(0.549, 0.498, 0.769, 0.6)
const DISC := Color(0.984, 0.969, 0.949)
const GOLD := Color(0.949, 0.824, 0.478)

var shape: StringName = &"leaf"
var color: Color = Color(0.8, 0.8, 0.8)
var silhouette: bool = false
var shiny: bool = false
var _t: float = 0.0


static func make(icon_shape: StringName, icon_color: Color, unfound: bool = false, is_shiny: bool = false,
		px: float = 56.0) -> ItemIcon:
	var i := ItemIcon.new()
	i.shape = icon_shape
	i.color = icon_color
	i.silhouette = unfound
	i.shiny = is_shiny and not unfound
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


## The icon shape for any book entry: items carry their own; other tabs have one.
static func shape_for(entry_id: StringName, tab: StringName) -> StringName:
	match tab:
		&"recipes":
			return &"bowl"
		&"truths":
			return &"scroll"
		&"sketches", &"paintings":
			return &"frame"
		&"wardrobe":
			var p := WardrobeCatalog.piece(entry_id)
			if p and (p.slots.has(&"head") or p.slots.has(&"ears") or p.slots.has(&"neck") or p.slots.has(&"wrist")):
				return &"trinket"
			return &"dress"
	var item := ItemCatalog.get_item(entry_id)
	return item.icon if item else &"leaf"


func _process(delta: float) -> void:
	if shiny:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var pale := color.get_luminance() > 0.8
	draw_circle(c, r * 0.96, Color(1.0, 0.9, 0.94, 0.55) if silhouette else (Color(0.97, 0.82, 0.88) if pale else DISC))
	if shiny:
		draw_arc(c, r * 0.93, 0.0, TAU, 40, GOLD, 2.5, true)
	var fill := SILHOUETTE if silhouette else color
	var line := SILHOUETTE.darkened(0.15) if silhouette else color.darkened(0.35)
	var s := r * 0.62
	match shape:
		&"flower":
			for k in 5:
				var a := TAU * k / 5.0 - PI / 2.0
				draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.5, s * 0.42, fill)
			draw_circle(c, s * 0.3, SILHOUETTE.darkened(0.2) if silhouette else Color(1.0, 0.87, 0.45))
		&"berry":
			for o in [Vector2(-0.35, 0.2), Vector2(0.35, 0.2), Vector2(0.0, -0.25)]:
				draw_circle(c + o * s, s * 0.42, fill)
				if not silhouette:
					draw_circle(c + o * s + Vector2(-0.12, -0.12) * s, s * 0.1, Color(1, 1, 1, 0.7))
			draw_line(c + Vector2(0, -0.6) * s, c + Vector2(0.35, -0.95) * s, line, 2.0, true)
		&"leaf", &"feather":
			var tilt := 0.6 if shape == &"feather" else 0.0
			var stretch := 0.38 if shape == &"feather" else 0.55
			var pts := PackedVector2Array()
			for k in 20:
				var a := TAU * k / 20.0
				pts.append(c + Vector2(sin(a) * stretch * pow(absf(cos(a * 0.5)), 0.6), -cos(a)).rotated(tilt) * s)
			draw_colored_polygon(pts, fill)
			draw_line(c + Vector2(0, 1.25).rotated(tilt) * s, c + Vector2(0, -0.9).rotated(tilt) * s, line, 2.0, true)
		&"mushroom":
			var cap := PackedVector2Array()
			for k in 17:
				var a := PI * k / 16.0
				cap.append(c + Vector2(-cos(a) * 0.95, -sin(a) * 0.75 - 0.05) * s)
			draw_colored_polygon(cap, fill)
			draw_rect(Rect2(c + Vector2(-0.2, -0.05) * s, Vector2(0.4, 0.8) * s), SILHOUETTE if silhouette else Color(0.98, 0.94, 0.86))
			if not silhouette:
				for o in [Vector2(-0.4, -0.35), Vector2(0.15, -0.55), Vector2(0.5, -0.25)]:
					draw_circle(c + o * s, s * 0.09, Color(1, 1, 1, 0.85))
		&"gem":
			var g := PackedVector2Array([c + Vector2(-0.55, -0.35) * s, c + Vector2(0.55, -0.35) * s,
				c + Vector2(0.8, -0.05) * s, c + Vector2(0, 0.9) * s, c + Vector2(-0.8, -0.05) * s])
			draw_colored_polygon(g, fill)
			draw_polyline(g + PackedVector2Array([g[0]]), line, 1.5, true)
			if not silhouette:
				draw_colored_polygon(PackedVector2Array([c + Vector2(-0.35, -0.3) * s, c + Vector2(0.05, -0.3) * s,
					c + Vector2(-0.2, 0.15) * s]), Color(1, 1, 1, 0.55))
		&"drop":
			var d := PackedVector2Array()
			for k in 24:
				var a := TAU * k / 24.0
				var rr := 0.62 * (1.0 - 0.75 * maxf(0.0, -cos(a)) * absf(cos(a)))
				d.append(c + Vector2(sin(a) * rr, -cos(a) * 0.95 + 0.2) * s)
			draw_colored_polygon(d, fill)
			if not silhouette:
				draw_circle(c + Vector2(-0.2, 0.25) * s, s * 0.12, Color(1, 1, 1, 0.7))
		&"twig":
			draw_line(c + Vector2(-0.8, 0.7) * s, c + Vector2(0.8, -0.7) * s, fill, s * 0.22, true)
			draw_line(c + Vector2(-0.1, 0.1) * s, c + Vector2(-0.6, -0.4) * s, fill, s * 0.14, true)
			draw_line(c + Vector2(0.3, -0.25) * s, c + Vector2(0.65, 0.05) * s, fill, s * 0.12, true)
		&"shell":
			draw_circle(c, s * 0.85, fill)
			var spiral := PackedVector2Array()
			for k in 40:
				var a := k * 0.35
				spiral.append(c + Vector2(cos(a), sin(a)) * s * (0.08 + k * 0.018))
			draw_polyline(spiral, line, 2.0, true)
		&"meat", &"bowl":
			var bowl := PackedVector2Array()
			for k in 17:
				var a := PI * k / 16.0
				bowl.append(c + Vector2(cos(a) * 0.95, sin(a) * 0.7 - 0.05) * s)
			draw_colored_polygon(bowl, fill)
			draw_line(c + Vector2(-1.0, -0.05) * s, c + Vector2(1.0, -0.05) * s, line, 2.5, true)
			for x in [-0.35, 0.0, 0.35]:
				draw_arc(c + Vector2(x, -0.45) * s, s * 0.18, PI * 0.5, PI * 1.5, 8, line, 1.5, true)
		&"pelt":
			var p := PackedVector2Array()
			for k in 24:
				var a := TAU * k / 24.0
				var rr := 0.8 + 0.12 * sin(a * 5.0)
				p.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.8) * s)
			draw_colored_polygon(p, fill)
		&"dress":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.3, -0.9) * s, c + Vector2(0.3, -0.9) * s,
				c + Vector2(0.25, -0.2) * s, c + Vector2(0.95, 0.9) * s, c + Vector2(-0.95, 0.9) * s,
				c + Vector2(-0.25, -0.2) * s]), fill)
			draw_line(c + Vector2(-0.3, -0.2) * s, c + Vector2(0.3, -0.2) * s, line, 2.0, true)
		&"scroll":
			draw_rect(Rect2(c + Vector2(-0.6, -0.75) * s, Vector2(1.2, 1.5) * s), fill)
			for y in [-0.4, -0.1, 0.2, 0.5]:
				draw_line(c + Vector2(-0.4, y) * s, c + Vector2(0.4, y) * s, line, 1.5, true)
		&"frame":
			draw_rect(Rect2(c + Vector2(-0.85, -0.7) * s, Vector2(1.7, 1.4) * s), GOLD if not silhouette else fill)
			draw_rect(Rect2(c + Vector2(-0.65, -0.5) * s, Vector2(1.3, 1.0) * s), DISC if not silhouette else SILHOUETTE.lightened(0.3))
		_:
			_star(c, s * 0.9, fill)
	if shiny:
		for k in 3:
			var a := _t * 0.8 + TAU * k / 3.0
			var twinkle := 0.5 + 0.5 * sin(_t * 4.0 + k * 2.1)
			_star(c + Vector2(cos(a), sin(a)) * r * 0.78, r * 0.16 * (0.6 + 0.4 * twinkle), Color(GOLD, 0.6 + 0.4 * twinkle))


func _star(at: Vector2, radius: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := TAU * k / 10.0 - PI / 2.0
		pts.append(at + Vector2(cos(a), sin(a)) * (radius if k % 2 == 0 else radius * 0.42))
	draw_colored_polygon(pts, col)
