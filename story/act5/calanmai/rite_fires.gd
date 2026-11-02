## Ch20, Fire Night (Keeper 2026-11-02 [C]), L45: the moment calanmai_fires,
## coded (Act2Spaces.CODED), at the calanmai_bonfires anchor.
## Her deed is going: told to lock herself in, she comes to "the first giant
## bonfire atop the hill" at night (by ten o'clock; arriving earlier, the hour
## comes to her). The hill turns to the Calanmai night grade; hundreds of
## masked High Fae, faces blurring into colour; the crowd drifts toward the
## trench where the flowered cave opens (CavePath). Raises calanmai_attended.
class_name RiteFires
extends CalanmaiSpace

const ORDER_FACT := "fact.calanmai_ordered_inside"
const DEED := "calanmai_attended"


func _ready() -> void:
	super._ready()
	space_id = &"calanmai_fires"
	require_flags = PackedStringArray(["attor_evaded", ORDER_FACT])
	done_flags = PackedStringArray([DEED])
	night_only = true
	arrive_radius = 26.0
	arrive_height = 0.0


func _build_beats() -> Array:
	var b: Array = []
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		CalanmaiKit.night_grade(get_tree(), true, 4.0), "the Calanmai night grade"))
	b.append(Beats.control(StoryControl.Mode.LOOK, null))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		var pyre := mark(&"pyre_0")
		var focus := Node3D.new()
		focus.name = "PyreFocus"
		add_child(focus)
		focus.global_position = CalanmaiKit.ground(pyre.x, pyre.z) + Vector3.UP * 3.0
		StoryControl.set_focus(focus), "look at the fire"))
	b.append(say(&"masks"))
	b.append(Beats.raise(DEED))
	b.append(Beats.control(StoryControl.Mode.FULL, null))
	b.append(say(&"trench"))
	return b
