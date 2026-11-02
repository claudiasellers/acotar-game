## Ch22 lunch (Keeper 2026-11-02 [C]), L45: she goes down to the dining room
## with the bruise showing. Lucien grins; Tamlin: "You should have stayed in
## your room." She: "Faerie pig!" Lucien howls; even Tamlin laughs. Going
## down with it bared is the deed: bite_endured. Hung on the dining table's
## anchor (Act2Spaces.EXTRA); the hour comes to lunch when she arrives.
class_name BruiseLunch
extends CalanmaiSpace

const AFTER := "fact.bruise_shown"
const DEED := "bite_endured"


func _ready() -> void:
	space_id = &"calanmai_bruise_lunch"
	super._ready()
	require_flags = PackedStringArray([AFTER])
	done_flags = PackedStringArray([DEED])
	arrive_radius = 9.0
	arrive_offset = CalanmaiKit.DINING_TABLE_LOCAL
	window(11.5, 15.0, 12.5)


func _build_beats() -> Array:
	var b: Array = []
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		cast(&"tamlin", &"tamlin_seat", &"feyre_chair")
		cast(&"lucien", &"lucien_seat", &"lucien_face")
		sit(&"tamlin", &"chair_head_dining")
		sit(&"lucien"), "at the table"))
	b.append(Beats.control(StoryControl.Mode.LOOK, null))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		StoryControl.set_focus(actor(&"lucien"))
		EventBus.face_requested.emit(&"lucien", &"smirk", 0.9, 3.0), "Lucien sees it"))
	b.append(say(&"look"))
	b.append(Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"tamlin")), "Tamlin"))
	b.append_array(speak(&"stayed", &"guarded"))
	b.append_array(speak(&"pig"))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		EventBus.face_requested.emit(&"lucien", &"laugh", 1.0, 3.0)
		EventBus.face_requested.emit(&"tamlin", &"laugh", 0.8, 3.0)
		Juice.burst(actor(&"lucien"), &"pickup"), "they laugh"))
	b.append(say(&"laugh"))
	b.append(Beats.raise(DEED))
	b.append(Beats.control(StoryControl.Mode.FULL, null))
	b.append(Beats.wait(2.0))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		dismiss(&"tamlin")
		dismiss(&"lucien"), "lunch is over"))
	return b
