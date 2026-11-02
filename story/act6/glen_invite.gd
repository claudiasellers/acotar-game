## Ch23 [C]: "another beautiful place on his land". The morning after he keeps
## her snowy-forest painting, Tamlin waits on the front steps with the horses'
## reins in his hand; she walks out to him and presses E to go (the deed), and
## after a fade they are in the glen, where GlenPicnic and L33's "Eyes Open"
## take over. Hangs on hall_mark_1 (the entrance hall, by the front doors).
## Fact: fact.glen_ride_taken (day-stamped).
class_name GlenInvite
extends Act6Space

## Late morning: the film itself sets noon.
const RIDE_HOUR := 11.0 / 24.0


func _init() -> void:
	space_id = &"glen_invite"
	require_flags = PackedStringArray(["paintings_shown"])
	done_flags = PackedStringArray(["fact.glen_ride_taken"])
	day_only = true
	arrive_radius = 16.0


func _build_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			var t := cast(&"tamlin", &"tamlin_steps", &"feyre_door")
			if t:
				t.global_position = ground_mark(&"tamlin_steps")
			StoryControl.release(), "Tamlin on the steps"),
		Beats.until(func() -> bool: return player_within(4.0, ground_mark(&"tamlin_steps")), "she walks out to him"),
		say(&"tamlin_come"),
		Beats.run(func(_s: SceneSpace) -> void: aside(&"press_go"), "her answer is to go"),
		press_near(func() -> Vector3: return ground_mark(&"tamlin_steps"), 4.0, "E: go with him"),
		Beats.run(func(_s: SceneSpace) -> void: stamp("fact.glen_ride_taken"), "the ride"),
	] + fade_time(RIDE_HOUR, _ride, "the ride") + [
		say(&"ride_thought"),
	]


func _ride() -> void:
	dismiss(&"tamlin")
	go_to(&"blossom_vale", &"glamour_lift_glade", stage.mark(&"glen_arrive") if stage else Vector3.ZERO)
