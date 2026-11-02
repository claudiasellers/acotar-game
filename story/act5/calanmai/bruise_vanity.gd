## Ch22 morning (Keeper 2026-11-02 [C]), L45: the servants sleep in; at her
## vanity, "an enormous bruise". A scarf would hide it. Her deed: E, and she
## opens the collar of her tunic farther instead. Hung on the
## feyre_bedroom_window anchor (Act2Spaces.EXTRA); starts when she comes to
## the vanity mirror by day after the hallway. Fact: fact.bruise_shown.
class_name BruiseVanity
extends CalanmaiSpace

const AFTER := "fact.bite_held_off"
const FACT := "fact.bruise_shown"


func _ready() -> void:
	space_id = &"calanmai_bruise_vanity"
	super._ready()
	require_flags = PackedStringArray([AFTER])
	done_flags = PackedStringArray([FACT])
	day_only = true
	arrive_radius = 1.8
	arrive_offset = stage.mark(&"vanity") if stage else Vector3.ZERO


func _build_beats() -> Array:
	var b: Array = []
	# Her E is the scene's (Act2Space counts it); not the mirror, easel or a forage spot.
	b.append(Beats.control(StoryControl.Mode.LOOK, null))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		var f := Node3D.new()
		f.name = "MirrorFocus"
		add_child(f)
		f.global_position = mark(&"mirror")
		StoryControl.set_focus(f), "her face in the glass"))
	b.append(say(&"bruise"))
	b.append(say(&"scarf"))
	b.append(Beats.run(func(_s: SceneSpace) -> void: _presses = 0, "her hands at her collar"))
	b.append(Beats.until(func() -> bool: return presses() > 0, "she opens her collar (E)"))
	b.append(say(&"open"))
	b.append(Beats.raise(FACT))
	return b
