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


## Through the one sleep fade (SleepFade): the Clock jumps to night while it
## is dark, and the sleep rests her (VitalsState.rest; a day's sleep in the
## cold cottage, so not Well rested).
func sleep() -> void:
	sleeping = true
	var at_dark := func() -> void:
		skip_to_night()
		var vitals := Vitals.of(get_tree().get_first_node_in_group(&"player"))
		if vitals:
			vitals.rest(false)
	var woke := func() -> void:
		sleeping = false
	SleepFade.run(self, at_dark, woke, fade_seconds, hold_seconds)


## Advances the Clock (so day_started and everything time-driven still fire).
static func skip_to_night() -> void:
	var t := Clock.time_of_day
	if t < NIGHT:
		Clock.advance((NIGHT - t) * Clock.DAY_LENGTH_SECONDS)
