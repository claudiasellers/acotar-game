## Supper on the evening after the sale (Keeper, ch2 rows 9-12): she sits,
## the family gather, Nesta announces Tomas Mandray and the fight ends in
## A1_03/A1_04; then her father at the table (A1_05) and "Rest, Feyre", the
## only nudge toward bed (X). Starts when she sits (fact.evening.sat_down,
## CottageEvening's chair) and raises fact.evening.supper_eaten. Feyre can
## only look while they talk; each beat waits until it is said.
class_name CottageSupper
extends SceneSpace

const SCENE := &"cottage_evening"


func _init() -> void:
	space_id = &"cottage_supper"
	require_flags = PackedStringArray(["pelt_sold", CottageEvening.SAT])
	done_flags = PackedStringArray([CottageEvening.SUPPER])
	auto_start = true
	shift_time_on_arrival = false


func _build_beats() -> Array:
	return [
		Beats.cue(&"family", &"gather"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.hold(self, StoryControl.Mode.LOOK)
			StoryControl.set_focus(CottageEvening.family(get_tree(), &"nesta")), "supper"),
		Beats.wait(1.0),
	] + _line(&"supper", &"nesta") + [
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_focus(CottageEvening.family(get_tree(), &"father")), "her father"),
	] + _line(&"father", &"father") + _line(&"rest", &"father") + [
		Beats.cue(&"family", &"release"),
		Beats.raise(CottageEvening.SUPPER),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.release(self), "free"),
	]


## A beat of the evening's lines, then held until it is said.
func _line(beat: StringName, speaker: StringName) -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			var d := DialogueDirector.of(get_tree())
			if d:
				d.say_beat(SCENE, beat, CottageEvening.family(get_tree(), speaker)), "say %s" % beat),
		Beats.until(func() -> bool:
			var d := DialogueDirector.of(get_tree())
			return d == null or not d.beat_speaking(), "until %s is said" % beat),
	]
