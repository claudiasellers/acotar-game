## Ch24 [C]: the morning after the glen, in her bedroom, she wakes to "the
## squat woman with skin made from tree bark" fussing with her breakfast
## dishes, in the same brass bird mask: "I am Alis." Then Alis goes to run
## her bath. The deed is looking: hold your gaze on her and her bark
## bleaches birch-white with fright (AlisTrueForm.frighten), then colours
## back. Hangs on feyre_bedroom_window. Fact: fact.alis_true_seen (stamped,
## so FountainHead waits for the next morning).
class_name AlisTrueMorning
extends Act6Space

const STARE := 1.4


func _init() -> void:
	space_id = &"alis_true_morning"
	require_flags = PackedStringArray(["glamour_lifted", "fact.eyes_open_wonders"])
	done_flags = PackedStringArray(["fact.alis_true_seen"])
	day_only = true
	arrive_radius = 7.0


func _ready() -> void:
	super._ready()
	# The middle of her room (the anchor is at the garden window).
	arrive_offset = Vector3(2.5, 0.0, 11.0)


func _build_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			var alis := cast(&"alis", &"alis_tray", &"bed_side")
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(alis), "Alis at the breakfast tray"),
		Beats.wait(1.5),
		say(&"bark_thought"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
			StoryControl.set_focus(null), "free to look"),
		gaze_hold(func() -> Vector3: return _alis_face(), STARE, 16.0, "she stares at Alis"),
		Beats.run(func(_s: SceneSpace) -> void:
			var tf := _true_form()
			if tf:
				tf.frighten(1.0)
			EventBus.face_requested.emit(&"alis", &"startled", 0.8, 1.5)
			# Close on her face while the bark bleaches and colours back.
			insert_shot(_alis_face(), 1.9, 1.15, -0.05, 3.2, 40.0), "Alis pales"),
		say(&"birch_thought"),
		say(&"alis_i_am"),
		lead_along(&"alis", [&"bath"], 0.0, 1.4),
		Beats.run(func(_s: SceneSpace) -> void:
			dismiss(&"alis")
			stamp("fact.alis_true_seen")
			StoryControl.release(), "Alis runs the bath"),
		say(&"halls_thought"),
	]


func _alis_face() -> Vector3:
	var a := actor(&"alis")
	return a.global_position + Vector3.UP * 1.45 if a else mark(&"alis_tray")


func _true_form() -> AlisTrueForm:
	var a := actor(&"alis")
	return a.find_child("TrueForm", true, false) as AlisTrueForm if a else null
