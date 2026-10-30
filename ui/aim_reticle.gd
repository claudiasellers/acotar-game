## The bow reticle (F5): a small gold ring where the arrow would actually land
## at the current draw, with a faint line down from the screen centre so the
## drop reads at a glance. Shown while aiming or drawing.
class_name AimReticle
extends Control

const RING := Color(1.0, 0.86, 0.5, 0.95)
const RING_MISS := Color(1.0, 1.0, 1.0, 0.45)
const LINE := Color(1.0, 0.8, 0.9, 0.35)
## Seconds between predictions (the path is ~180 short ray casts).
const REFRESH := 1.0 / 30.0

var bow: BowController
var impact: Dictionary = {}
var _screen := Vector2.ZERO
var _since := 0.0


func _init(controller: BowController = null) -> void:
	bow = controller
	name = "Reticle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var feyre := bow.feyre if bow else null
	var show := feyre != null and (feyre.is_aiming or bow.is_drawing) and feyre.camera != null
	visible = show
	if not show:
		return
	_since += delta / maxf(Engine.time_scale, 0.01)
	if _since < REFRESH and not impact.is_empty():
		return
	_since = 0.0
	impact = bow.predict_impact()
	var cam := feyre.camera
	if cam.is_position_behind(impact.point):
		visible = false
		return
	_screen = cam.unproject_position(impact.point)
	queue_redraw()


func _draw() -> void:
	if impact.is_empty():
		return
	var centre := size * 0.5
	if _screen.distance_to(centre) > 6.0:
		draw_dashed_line(centre, _screen, LINE, 1.5, 5.0, true)
	var hit: bool = impact.hit
	draw_arc(_screen, 9.0, 0.0, TAU, 28, RING if hit else RING_MISS, 2.0, true)
	draw_circle(_screen, 2.0, RING if hit else RING_MISS)
