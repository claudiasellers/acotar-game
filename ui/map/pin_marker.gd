## The player's pin on screen, the way most open-world games show a waypoint:
## a small pin sketched in charcoal, like the marks in her sketchbook, over
## the spot in the world with how far it is in her hand, sliding to the edge of the screen and pointing there when the spot is
## off screen or behind her. Player-placed only (the story never sets one, R2).
## Lives under WorldMapHud; drawn every frame from its MapPin and the camera.
extends Control

## Float the icon this far above the ground at the pin (metres).
const LIFT := 4.0
## Screen margin for the edge-clamped icon (pixels).
const EDGE := 64.0
const SIZE := 15.0
## Hidden this close (she is there; the arrival sparkles take over).
const NEAR := 12.0
## Her sketchbook's charcoal, its paper, and a blush watercolour wash.
const CHARCOAL := Color(0.19, 0.16, 0.18)
const PAPER := Color(0.99, 0.96, 0.93)
const WASH := Color(0.95, 0.66, 0.74)
const HAND := preload("res://ui/title/fonts/EBGaramond-MediumItalic.ttf")

var hud: Node
var _t: float = 0.0
## Where the icon was drawn last (for tests): screen point and whether it is on the edge.
var shown_at: Vector2 = Vector2.ZERO
var on_edge: bool = false
var shown: bool = false


func _init(owner_hud: Node) -> void:
	hud = owner_hud
	name = "PinMarker"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Where the icon goes for a world point, given the camera and the screen:
## [point, on_edge, edge_angle]. The angle (0 = up, clockwise) points from the
## screen centre towards the spot when it is clamped.
static func place_on_screen(cam: Camera3D, world: Vector3, screen: Vector2, edge: float = EDGE) -> Array:
	var centre := screen * 0.5
	var behind := cam.is_position_behind(world)
	var p := cam.unproject_position(world)
	var inner := Rect2(Vector2(edge, edge), screen - Vector2(edge, edge) * 2.0)
	if not behind and inner.has_point(p):
		return [p, false, 0.0]
	# Off screen or behind: the direction in the camera's own plane.
	var local := cam.global_transform.affine_inverse() * world
	var dir := Vector2(local.x, -local.y)
	if behind:
		# Behind her: push it to the bottom edge on the side it lies.
		dir = Vector2(local.x, maxf(absf(local.y), absf(local.z)) * 0.6)
	if dir.length() < 0.001:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var half := inner.size * 0.5
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	return [centre + dir * k, true, atan2(dir.x, -dir.y)]


func _draw() -> void:
	shown = false
	if not hud.pin.active or not visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d: float = hud.player_xz.distance_to(hud.pin.xz)
	if d < NEAR:
		return
	var ground := WorldHeight.height_at(hud.pin.xz.x, hud.pin.xz.y)
	var world := Vector3(hud.pin.xz.x, ground + LIFT, hud.pin.xz.y)
	var placed := place_on_screen(cam, world, get_viewport_rect().size)
	var at: Vector2 = placed[0]
	on_edge = placed[1]
	shown_at = at
	shown = true
	modulate.a = clampf((d - NEAR) / 10.0, 0.0, 1.0)
	if on_edge:
		var a: float = placed[2]
		var dir := Vector2(sin(a), -cos(a))
		_draw_chevron(at + dir * (SIZE * 2.3 + sin(_t * 3.0) * 2.0), dir)
	_draw_pin(at)
	_draw_distance(at + Vector2(0, SIZE * 1.6 + 16.0), d)


## Like a mark in her sketchbook: a few loose charcoal strokes, each a little
## off the last. Fixed offsets (no flicker), a slow breath in the wobble.
func _stroke(points: PackedVector2Array, width: float) -> void:
	for pass_i in 3:
		var o := Vector2(cos(pass_i * 2.1 + 0.4), sin(pass_i * 1.7 + 1.1)) * (0.9 + pass_i * 0.35)
		var line := PackedVector2Array()
		for i in points.size():
			var j := Vector2(sin(i * 3.7 + pass_i * 1.3), cos(i * 2.9 + pass_i)) * 0.7
			line.append(points[i] + o + j)
		var c := Color(CHARCOAL, 0.85 - pass_i * 0.22)
		draw_polyline(line, c, width * (1.0 - pass_i * 0.25), true)


## A paper halo so the charcoal reads on dark ground as well as on snow.
func _halo(points: PackedVector2Array, width: float) -> void:
	draw_polyline(points, Color(PAPER, 0.75), width + 5.0, true)


func _draw_chevron(tip: Vector2, dir: Vector2) -> void:
	var side := Vector2(-dir.y, dir.x)
	for k in 2:
		var t := tip - dir * (k * 8.0)
		var pts := PackedVector2Array([t - dir * 11.0 + side * 10.0, t, t - dir * 11.0 - side * 10.0])
		_halo(pts, 2.6)
		_stroke(pts, 2.6 - k * 0.6)


## The pin: a teardrop sketched in charcoal over a blush wash, a dot for its
## head, and a short tick where it meets the ground.
func _draw_pin(at: Vector2) -> void:
	var s := SIZE
	var head := at + Vector2(0, -s * 0.35)
	var tipp := at + Vector2(0, s * 1.15)
	var outline := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var a := lerpf(-PI * 0.18, PI * 1.18, float(i) / n)
		outline.append(head + Vector2(cos(a), -sin(a)) * s * 0.72)
	outline.append(tipp)
	outline.append(outline[0])
	var fill := PackedVector2Array(outline)
	fill.remove_at(fill.size() - 1)
	draw_colored_polygon(fill, Color(PAPER, 0.9))
	draw_circle(head + Vector2(1.5, 1.0), s * 0.55, Color(WASH, 0.55))
	_stroke(outline, 2.2)
	draw_circle(head, s * 0.18, Color(CHARCOAL, 0.85))
	_stroke(PackedVector2Array([tipp + Vector2(-s * 0.45, 2.0), tipp + Vector2(s * 0.45, 1.0)]), 1.6)


## How far, in her hand: small charcoal italic on a paper smudge.
func _draw_distance(centre: Vector2, d: float) -> void:
	var label := "%d m" % roundi(d)
	var fs := 17
	var w := HAND.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lp := Vector2(-w * 0.5, fs * 0.3)
	draw_set_transform(centre, -0.04, Vector2.ONE)
	draw_string_outline(HAND, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(PAPER, 0.8))
	draw_string(HAND, lp + Vector2(0.6, 0.4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(CHARCOAL, 0.35))
	draw_string(HAND, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(CHARCOAL, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
