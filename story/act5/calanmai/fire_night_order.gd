## Ch20, dusk on Fire Night (Keeper 2026-11-02 [C]), L45. Hung on the
## manor_window_hide anchor (the entrance hall) by Act2Spaces.EXTRA.
## After the Attor (attor_evaded), the next time she comes into the hall the
## hour comes to dusk: Tamlin alone, bare to the waist but for the baldric,
## tells her it's Calanmai and to lock herself in, and goes out through the
## front doors. Far off, the drums begin. Whether she stays in is hers: the
## deed is going to the fires (RiteFires, calanmai_attended).
## Fact: fact.calanmai_ordered_inside (the hill's night dressing keys on it).
class_name FireNightOrder
extends CalanmaiSpace

const FACT := "fact.calanmai_ordered_inside"


func _ready() -> void:
	space_id = &"calanmai_order"
	arrive_radius = 9.0
	super._ready()
	require_flags = PackedStringArray(["attor_evaded"])
	done_flags = PackedStringArray([FACT])
	window(18.5, 21.0, 19.25)


func _build_beats() -> Array:
	var b: Array = []
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		var t := cast(&"tamlin", &"tamlin", &"feyre_look")
		CalanmaiKit.dress_hunter(t, false), "tamlin, dressed for the Rite"))
	b.append(Beats.control(StoryControl.Mode.LOOK, null))
	b.append(Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"tamlin")), "look at him"))
	b.append(say(&"dusk"))
	b.append_array(speak(&"calanmai", &"weary"))
	b.append_array(speak(&"rite", &"guarded"))
	b.append_array(speak(&"lock", &"pleading"))
	b.append(Beats.control(StoryControl.Mode.WALK, null))
	b.append(walk(&"tamlin", [&"door"], 1.7))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		dismiss(&"tamlin")
		FarDrums.ensure(get_tree()), "he's gone; drums"))
	b.append(say(&"drums"))
	b.append(Beats.raise(FACT))
	return b
