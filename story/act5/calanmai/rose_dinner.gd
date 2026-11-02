## Ch22 dinner (Keeper 2026-11-02 [C]), L45: "We apologized at dinner. He even
## brought me a bouquet of white roses from his parents' garden." Tamlin is
## waiting by her chair with them; they go into her satchel (obj_white_roses)
## and Alis puts them in her painting room (WhiteRosesVase). Hung on the
## dining table's anchor (Act2Spaces.EXTRA); the hour comes to dinner.
## Fact: fact.white_roses_given.
class_name RoseDinner
extends CalanmaiSpace

const AFTER := "bite_endured"
const FACT := "fact.white_roses_given"
const ITEM := &"obj_white_roses"

var _bouquet: Node3D


func _ready() -> void:
	space_id = &"calanmai_rose_dinner"
	super._ready()
	require_flags = PackedStringArray([AFTER])
	done_flags = PackedStringArray([FACT])
	arrive_radius = 9.0
	arrive_offset = CalanmaiKit.DINING_TABLE_LOCAL
	window(18.5, 22.5, 19.5)
	fresh_entry = true


func _build_beats() -> Array:
	var b: Array = []
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		cast(&"tamlin", &"tamlin", &"feyre_chair")
		_bouquet = CalanmaiKit.prop(&"white_roses_vase")
		if _bouquet:
			add_child(_bouquet)
			_bouquet.global_position = mark(&"roses"), "Tamlin, and white roses"))
	b.append(Beats.control(StoryControl.Mode.LOOK, null))
	b.append(Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"tamlin")), "him"))
	b.append_array(speak(&"sorry", &"tender"))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		if _bouquet:
			Juice.burst(_bouquet, &"unlock")
		EventBus.story_item_granted.emit(ITEM, 1), "the roses are hers"))
	b.append(say(&"roses"))
	b.append(say(&"alis"))
	b.append(Beats.raise(FACT))
	b.append(Beats.control(StoryControl.Mode.FULL, null))
	b.append(Beats.wait(1.5))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		dismiss(&"tamlin")
		if _bouquet:
			_bouquet.queue_free()
			_bouquet = null, "Alis takes them up"))
	return b
