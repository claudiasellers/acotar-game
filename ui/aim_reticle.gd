## The bow reticle (F5): a small gold ring where the arrow would actually land,
## sway and all, with a faint line down from the screen centre so the drop
## reads at a glance. The ring wanders with the sway and tightens as her aim
## settles: what you see is where it goes. Shown while the bow is raised.
## BowController puts it in HudLayout's WORLD zone.
class_name AimReticle
extends Control

## How strongly the ring shows where the arrow lands, and where it won't;
## and the line down to it.
const RING := 0.95
const RING_MISS := 0.45
const LINE := 0.35
## Seconds between predictions (the path is ~180 short ray casts).
const REFRESH := 1.0 / 30.0
const RING_RADIUS := 9.0

var bow: BowController
var impact: Dictionary = {}
var _screen := Vector2.ZERO
var _since := 0.0
## The shot direction and muzzle the last prediction was made with: between
## predictions the ring is turned by how far the sway has moved since.
var _predicted_dir := Vector3.ZERO
var _predicted_from := Vector3.ZERO
## Where in the world the ring sits this frame: the predicted impact, moved
## with the sway since that prediction.
var point := Vector3.ZERO


func _init(controller: BowController = null) -> void:
	bow = controller
	name = "Reticle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var feyre := bow.feyre if bow else null
	var show := feyre != null and feyre.is_aiming and feyre.camera != null
	visible = show
	if not show:
		return
	_since += TimeScale.real(delta)
	var dir := bow.shot_direction()
	if _since >= REFRESH or impact.is_empty():
		_since = 0.0
		impact = bow.predict_impact()
		_predicted_dir = dir
		_predicted_from = bow.muzzle()
	# The camera on screen: a staged lens (Cine, the wolf hunt's tighter lens)
	# rides hers with another fov, so projecting through hers would put the
	# ring short of where the arrow lands. Every frame, so it never lags a turn.
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		cam = feyre.camera
	# The sway since the last prediction, as a turn about the muzzle.
	point = impact.point
	if _predicted_dir != Vector3.ZERO and not _predicted_dir.is_equal_approx(dir):
		point = _predicted_from + Quaternion(_predicted_dir, dir) * (point - _predicted_from)
	if cam.is_position_behind(point):
		visible = false
		return
	_screen = cam.unproject_position(point)
	queue_redraw()


func _draw() -> void:
	if impact.is_empty():
		return
	var centre := size * 0.5
	if _screen.distance_to(centre) > 6.0:
		draw_dashed_line(centre, _screen, Color(JournalTheme.wash(0), LINE), 1.5, 5.0, true)
	var ring := Color(JournalTheme.color(&"glow"), RING) if impact.hit else Color(JournalTheme.color(&"paper"), RING_MISS)
	var radius := RING_RADIUS * (1.0 + bow.tuning.ring_unsettled_grow * bow.unsettled())
	draw_arc(_screen, radius, 0.0, TAU, 28, ring, 2.0, true)
	draw_circle(_screen, 2.0, ring)
