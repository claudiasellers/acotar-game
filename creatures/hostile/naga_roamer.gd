## A roaming naga of a hostile camp (docs/contracts/hostiles.md). Not the canon
## ambush naga (creatures/fae/naga.gd): this one lives at a site, keeps a day
## (bask at noon, hunt at dusk, nest at night with one on watch), and coils
## only from behind her. The shared brain (ladder, leash, fight, tell) is
## HostileRoamer's; its values are on naga_roamer.tscn and in its rows.
## Canon "X": the naga are canon, their camps and routines are invented.
class_name NagaRoamer
extends HostileRoamer

## The naga's three rows (data/combat/attacks; bestiary §2). The scene names
## them; these are for tests and story.
const CLAW := &"naga_claw"
const LUNGE_ATTACK := &"naga_lunge"
const COIL := &"naga_coil"


## What the day asks of it: bask 10-15, hunt 17-21, nest otherwise.
static func routine_for(hour: float) -> StringName:
	var h := fposmod(hour, 24.0)
	if h >= 10.0 and h < 15.0:
		return &"bask"
	if h >= 17.0 and h < 21.0:
		return &"hunt"
	return &"nest"


## Sight multiplier for a routine; one nesting member keeps watch at full senses.
static func sight_mult(routine_name: StringName, on_watch: bool) -> float:
	match routine_name:
		&"bask":
			return 0.7
		&"nest":
			return 1.0 if on_watch else 0.5
	return 1.0


func routine_at(hour: float) -> StringName:
	return NagaRoamer.routine_for(hour)


func is_on_watch() -> bool:
	return member_index == 0


## A basker squints, a sleeper half hears; the one on watch doesn't.
func sight_scale() -> float:
	return NagaRoamer.sight_mult(routine, is_on_watch())


func hearing_scale() -> float:
	return 1.0 if routine != &"nest" or is_on_watch() else 0.6


## The coil only from behind her (and not on someone already held); the claw otherwise.
func pick_strike(player: Node3D) -> StringName:
	var behind := StrikeController.is_behind(HostileRoamer.facing_node(player), global_position) \
			and not _is_held(player)
	return grab_attack if behind else attack_id


func _routine(delta: float) -> void:
	match routine:
		&"bask":
			_go_to(home, data.walk_speed * 0.6, 2.0)
			gait_hint = &"graze" if move_speed == 0.0 else &""
		&"nest":
			_go_to(home, data.walk_speed, 1.5)
			gait_hint = &""
			if move_speed == 0.0 and is_on_watch():
				rotation.y += delta * 0.25
		_:
			super._routine(delta)
