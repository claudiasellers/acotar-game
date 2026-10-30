## The unpainted ironwood bed. Like any keepsake it raises fact.mother_bed_seen;
## once the pelt is sold (and before the beast has come) it is also where
## Feyre sleeps the day away: a soft fade to black, the Clock jumps to night,
## and the beast can come to the door.
class_name CottageBed
extends KeepsakeStation

## 21:30, just after Clock.is_night() turns true.
const NIGHT := 21.5 / 24.0

@export var fade_seconds: float = 0.9
@export var hold_seconds: float = 0.8

var sleeping: bool = false


func can_sleep() -> bool:
	return not sleeping and WorldState.has_flag("pelt_sold") \
			and not WorldState.has_flag("beast_claim_accepted") and not Clock.is_night()


func use(user: Node) -> void:
	super.use(user)
	if can_sleep():
		sleep()


func sleep() -> void:
	sleeping = true
	StoryControl.set_mode(StoryControl.Mode.NONE)
	var layer := CanvasLayer.new()
	layer.layer = 30
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.02, 0.05)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.modulate.a = 0.0
	layer.add_child(veil)
	get_tree().root.add_child(layer)
	var tween := layer.create_tween()
	tween.tween_property(veil, ^"modulate:a", 1.0, fade_seconds)
	tween.tween_callback(skip_to_night)
	tween.tween_interval(hold_seconds)
	tween.tween_property(veil, ^"modulate:a", 0.0, fade_seconds * 1.4)
	tween.tween_callback(func() -> void:
		layer.queue_free()
		StoryControl.release()
		sleeping = false)


## Advances the Clock (so day_started and everything time-driven still fire).
static func skip_to_night() -> void:
	var t := Clock.time_of_day
	if t < NIGHT:
		Clock.advance((NIGHT - t) * Clock.DAY_LENGTH_SECONDS)
