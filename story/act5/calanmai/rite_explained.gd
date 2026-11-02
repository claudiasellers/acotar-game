## Ch21 (Keeper 2026-11-02 [C]), L45: Lucien drops her "on the floor of the
## manor hallway" and explains the Rite there: the Hunter, the white stag,
## the Maiden in the cave, and what his scent-blind magic could have done to
## her. "Stay in your room tonight, Feyre." He goes. Hung on the entrance
## hall's manor_window_hide anchor (Act2Spaces.EXTRA); starts by itself once
## CavePath has carried her home. Fact: fact.calanmai_rite_explained.
class_name RiteExplained
extends CalanmaiSpace

const CARRIED_FACT := "fact.calanmai_carried"
const FACT := "fact.calanmai_rite_explained"


func _ready() -> void:
	space_id = &"calanmai_rite_explained"
	super._ready()
	require_flags = PackedStringArray([CARRIED_FACT])
	done_flags = PackedStringArray([FACT])
	auto_start = true


## Only once she's actually in the house (the travel sets her down here).
func can_start() -> bool:
	return super.can_start() and player_within(14.0)


func _build_beats() -> Array:
	var b: Array = []
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		place_feyre(mark(&"feyre_floor"))
		cast(&"lucien", &"lucien", &"feyre_floor"), "dropped in the hallway"))
	b.append(Beats.control(StoryControl.Mode.LOOK, null))
	b.append(Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"lucien")), "look up at him"))
	b.append(say(&"floor"))
	b.append_array(speak(&"hunter", &"guarded"))
	b.append_array(speak(&"scent", &"weary"))
	b.append_array(speak(&"stay", &"guarded"))
	b.append(Beats.control(StoryControl.Mode.FULL, null))
	b.append(walk(&"lucien", [&"lucien_exit"], 1.8))
	b.append(Beats.run(func(_s: SceneSpace) -> void: dismiss(&"lucien"), "he's gone"))
	b.append(Beats.raise(FACT))
	return b
