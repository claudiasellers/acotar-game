## A gloamer of a pack on a wood edge (bestiary §16; docs/contracts/hostiles.md).
## Long-armed, knuckle-loping scavengers, greedy and not clever: they hunt from
## dusk to dawn and lie up in hollow logs by day; the first to see her calls
## the rest; half the pack down and the rest scatter (rout_share); a light
## arrow's glow thrown the other way pulls two of them off to grab at it and
## squabble (glint_drawn). The shared brain is HostileRoamer's; its values are
## on gloamer_roamer.tscn and in its rows. Canon "X": invented for the common
## tier.
class_name GloamerRoamer
extends HostileRoamer

## The gloamer's rows (data/combat/attacks). The scene names the rake; the
## shove comes every SHOVE_EVERY strikes.
const RAKE := &"gloamer_rake"
const SHOVE := &"gloamer_shove"
const SHOVE_EVERY := 3
## Lying up by day it holds the `sleep` pose at home; anything that moves it,
## or sets it on her, lets the pose go (`wake` plays as it gets up).
const SLEEP_CLIP := &"sleep"
const WAKE_CLIP := &"wake"

var _strikes: int = 0


## Hunt from 18:00 to 06:00; lie up the rest of the day.
static func routine_for(hour: float) -> StringName:
	var h := fposmod(hour, 24.0)
	return &"hunt" if h >= 18.0 or h < 6.0 else &"rest"


func routine_at(hour: float) -> StringName:
	return GloamerRoamer.routine_for(hour)


## Lying up in a log it half sees and half hears.
func sight_scale() -> float:
	return 0.5 if routine == &"rest" else 1.0


func hearing_scale() -> float:
	return 0.7 if routine == &"rest" else 1.0


## The rake, and every third blow the two-armed shove.
func pick_strike(_player: Node3D) -> StringName:
	_strikes += 1
	return SHOVE if _strikes % SHOVE_EVERY == 0 else attack_id


func _think(delta: float) -> void:
	super._think(delta)
	if animator == null or not alive:
		return
	var lying := animator.action_clip() == SLEEP_CLIP
	var still := routine == &"rest" and move_speed == 0.0 and not ladder.is_hostile() \
			and not is_distracted()
	if still and not lying and not animator.is_acting():
		animator.hold(SLEEP_CLIP)
	elif lying and not still:
		animator.play_oneshot(WAKE_CLIP)


## True while it lies up asleep in its pose.
func is_lying_up() -> bool:
	return animator != null and animator.action_clip() == SLEEP_CLIP
