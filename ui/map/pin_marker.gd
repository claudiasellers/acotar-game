## The player's pin on screen, the way most open-world games show a waypoint:
## a small rose-gold pin floating over the spot in the world with how far it
## is, sliding to the edge of the screen and pointing there when the spot is
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
	var fade := clampf((d - NEAR) / 10.0, 0.0, 1.0)
	modulate.a = fade
	var colours := MapMarks.pin_colours()
	if on_edge:
		var a: float = placed[2]
		var dir := Vector2(sin(a), -cos(a))
		var side := Vector2(-dir.y, dir.x)
		# A gold chevron outside the pin, pointing the way.
		var tip := at + dir * (SIZE * 2.4 + sin(_t * 4.0) * 2.0)
		var back := tip - dir * 10.0
		draw_colored_polygon(PackedVector2Array([tip, back + side * 8.0, back - dir * -2.0, back - side * 8.0]), colours.line)
		draw_polyline(PackedVector2Array([back + side * 8.0, tip, back - side * 8.0]), Color(1, 0.97, 0.98), 1.5, true)
	MapMarks.draw_pin(self, at + Vector2(0, SIZE * 0.4), SIZE, _t)
	var font := PauseStyle.body_font(700)
	var label := "%d m" % roundi(d)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var lp := at + Vector2(-w * 0.5, SIZE * 0.4 + 20.0)
	draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, Color(1.0, 0.97, 0.99, 0.95))
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PauseStyle.PLUM)
