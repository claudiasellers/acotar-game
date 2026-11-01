## Brings a scene's hour to Feyre: a soft fade to dark, the Clock moves forward
## to `to` (a fraction of the day), a short hold, and the fade back. The Clock
## only ever advances (day_started and everything time-driven still fire).
## Control is held for the fade; `then` runs while the screen comes back.
class_name TimeShift
extends RefCounted

## 21:30, just after Clock.is_night() turns true.
const NIGHT := 21.5 / 24.0
## 08:00, a winter morning in full daylight.
const MORNING := 8.0 / 24.0
const FADE := 0.9
const HOLD := 0.7


static func fade_to(owner: Node, to: float, then: Callable = Callable()) -> void:
	StoryControl.set_mode(StoryControl.Mode.NONE)
	var layer := CanvasLayer.new()
	layer.name = "TimeShift"
	layer.layer = 30
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.02, 0.05)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.modulate.a = 0.0
	layer.add_child(veil)
	owner.get_tree().root.add_child(layer)
	var tween := layer.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(veil, ^"modulate:a", 1.0, FADE)
	tween.tween_callback(func() -> void: advance_to(to))
	tween.tween_interval(HOLD)
	tween.tween_callback(func() -> void:
		StoryControl.release()
		if then.is_valid():
			then.call())
	tween.tween_property(veil, ^"modulate:a", 0.0, FADE * 1.4)
	tween.tween_callback(layer.queue_free)


## Moves the Clock forward to `to` (today if still ahead, else tomorrow).
static func advance_to(to: float) -> void:
	var gap := to - Clock.time_of_day
	if gap < 0.0:
		gap += 1.0
	Clock.advance(gap * Clock.DAY_LENGTH_SECONDS)
