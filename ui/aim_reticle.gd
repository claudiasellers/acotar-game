## The bow's crosshair: a small gold ring and dot in the middle of the screen,
## shown while the bow is raised. The arrow goes to what is under it
## (BowController.shot_direction), so it does not move when she draws or
## looses. The ring closes in and brightens as the string comes back and
## catches bright for a moment at full draw. It moves only with her sway, when
## her body is failing her, and by exactly as much as the shot does. It dims
## when the arrow can't reach what it is on (something in the way of the bow,
## or no arrow), and past the bow's true range a short bar under it marks how
## far the arrow will have dropped. When her arrow finds a creature the ring
## pulses once in the act's accent (GameSettings' hit_marks; never a different
## mark for a weak spot). BowController puts it in HudLayout's WORLD zone.
class_name AimReticle
extends Control

## The ring before the draw and at full draw (px), and how strongly each shows.
const RADIUS_OPEN := 13.0
const RADIUS_DRAWN := 7.0
const RING_OPEN := 0.6
const RING_DRAWN := 0.95
## The ring when the arrow can't get there.
const RING_BLOCKED := 0.35
## The drop bar is drawn once the drop is this many px or more.
const DROP_FROM := 3.0
const DROP_BAR := 5.0
## The hit pulse at its start.
const PULSE := 0.9
const PULSE_GROW := 1.9

var bow: BowController
## Where the crosshair sits on screen this frame: the centre, moved by the sway.
var at := Vector2.ZERO
## Px below the crosshair the arrow will have dropped at what it is on (0
## inside the bow's true range).
var drop := 0.0
var blocked := false
## Real seconds left of the full-draw catch and of the hit pulse.
var catch_left := 0.0
var pulse_left := 0.0


func _init(controller: BowController) -> void:
	bow = controller
	name = "Reticle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	bow.full_draw.connect(func() -> void: catch_left = bow.tuning.full_draw_catch_s)
	EventBus.creature_hit.connect(_on_creature_hit)


func _on_creature_hit(_id: StringName, _kind: StringName, cause: StringName, _part: StringName) -> void:
	if String(cause).begins_with("arrow") and bool(GameSettings.get_value(&"hit_marks")):
		pulse_left = bow.tuning.hit_pulse_s


func _process(delta: float) -> void:
	var feyre := bow.feyre
	var show := feyre != null and bow.is_up() and feyre.camera != null
	visible = show
	if not show:
		return
	var real := TimeScale.real(delta)
	catch_left = maxf(catch_left - real, 0.0)
	pulse_left = maxf(pulse_left - real, 0.0)
	# Px per radian at the middle of her lens.
	var scale := size.y * 0.5 / tan(deg_to_rad(feyre.camera.fov) * 0.5)
	var on := feyre.aim_point()
	var reach := bow.muzzle().distance_to(on)
	# The sway turns the shot about the bow, not the lens: seen from the lens
	# the same miss is smaller when what she is on is nearer the bow than it.
	var seen := reach / maxf(feyre.camera.global_position.distance_to(on), 0.01)
	var sway := bow.sway_angles()
	at = size * 0.5 + Vector2(-tan(sway.x), -tan(sway.y)) * scale * seen
	blocked = not bow.is_nocked or bow.line_blocked()
	drop = 0.0
	if reach > bow.bow.true_range:
		var after := (reach - bow.bow.true_range) / maxf(bow.bow.max_speed, 0.001)
		drop = atan2(Ballistics.drop_after(after, bow.tuning.gravity_blend_s), reach) * scale
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(bow):
		return
	var t := bow.tuning
	var held := catch_left / maxf(t.full_draw_catch_s, 0.001)
	var radius := lerpf(RADIUS_OPEN, RADIUS_DRAWN, bow.draw_amount)
	var ring := Color(JournalTheme.color(&"glow"), lerpf(RING_OPEN, RING_DRAWN, bow.draw_amount))
	if blocked:
		ring = Color(JournalTheme.color(&"paper"), RING_BLOCKED)
	draw_arc(at, radius, 0.0, TAU, 28, ring, 2.0 + 1.5 * held, true)
	draw_circle(at, 2.0, ring)
	if drop >= DROP_FROM:
		var low := at + Vector2(0.0, drop)
		draw_line(low - Vector2(DROP_BAR, 0.0), low + Vector2(DROP_BAR, 0.0), ring, 2.0, true)
	if pulse_left > 0.0:
		var p := 1.0 - pulse_left / maxf(t.hit_pulse_s, 0.001)
		draw_arc(at, RADIUS_OPEN * lerpf(1.0, PULSE_GROW, p), 0.0, TAU, 32,
			Color(JournalTheme.color(&"accent"), PULSE * (1.0 - p)), 2.5, true)
