## Ch28 [C] (Keeper): downstairs Lucien says "I thought you were smarter than
## this" and storms off. Tamlin waits in front of a gilded carriage with six
## horses at the front of the house. "My paintings, they're yours." He says
## "Remember what I told you." She gets in; the carriage's magic sleep takes
## her. Deeds: give him the paintings (E at Tamlin), then board (E at the
## carriage door) -> fact.carriage_boarded; the sent_home moment raises
## sent_home. Then the sleep, the human realm's spring grade, and the road
## south (EventBus.travel_requested; P7's lane owns where she wakes).
## Hangs on hall_mark_1 (the entrance hall by the front doors).
class_name CarriageFarewell
extends Act6Space

const CARRIAGE := "res://world/spring_court/manor_estate/props/models/carriage_gilt.glb"
const HORSE := "res://creatures/fae/white_horse.tscn"
## Where the carriage takes her (P7: the family's new house). Until a human
## realm region for it exists, the village, where she goes in ch29.
const DESTINATIONS := [[&"archeron_estate", &"arrival_archeron_estate"], [&"village", &""]]

var carriage: Node3D
var horses: Array[Node3D] = []
var given: bool = false


func _init() -> void:
	space_id = &"carriage_farewell"
	require_flags = PackedStringArray(["fact.travel_dressed"])
	done_flags = PackedStringArray(["fact.carriage_boarded"])
	day_only = true
	arrive_radius = 14.0


func _build_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			given = false
			_build_carriage()
			var l := cast(&"lucien", &"lucien_hall", &"feyre_door")
			EventBus.face_requested.emit(&"lucien", &"angry", 0.8, 5.0)
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(l), "Lucien in the hall"),
		say(&"lucien_smarter"),
		lead_along(&"lucien", [&"lucien_storms"], 0.0, 3.2),
		Beats.run(func(_s: SceneSpace) -> void:
			dismiss(&"lucien")
			var t := cast(&"tamlin", &"tamlin_carriage", &"feyre_door")
			t.global_position = ground_mark(&"tamlin_carriage")
			StoryControl.release(), "out to the carriage"),
		Beats.until(func() -> bool: return player_within(4.0, ground_mark(&"tamlin_carriage")), "she walks out to him"),
		Beats.run(func(_s: SceneSpace) -> void: aside(&"give_prompt"), "the paintings"),
		press_near(func() -> Vector3: return ground_mark(&"tamlin_carriage"), 3.0, "E: give him the paintings"),
		Beats.run(_give, "given"),
		say(&"feyre_paintings"),
		say(&"tamlin_remember"),
		Beats.run(func(_s: SceneSpace) -> void: aside(&"board_prompt"), "the carriage door"),
		press_near(func() -> Vector3: return ground_mark(&"carriage_door"), 2.8, "E: get in"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.NONE)
			note_mood()
			EventBus.mood_requested.emit(&"enchanted_sleep", 1.0, 3.0, 0.0)
			stamp("fact.carriage_boarded"), "she gets in"),
		say(&"sleep_thought"),
		Beats.wait(3.0),
		Beats.run(_away, "the road south"),
		Beats.wait(1.5),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.mood_requested.emit(&"calm", 0.0, 3.0, 0.0)
			StoryControl.release(), "she wakes"),
	]


func _build_carriage() -> void:
	if carriage != null:
		return
	var at := ground_mark(&"carriage")
	var scene := load(CARRIAGE) as PackedScene if ResourceLoader.exists(CARRIAGE) else null
	if scene:
		carriage = scene.instantiate() as Node3D
		carriage.name = "GildedCarriage"
		add_child(carriage)
		carriage.global_position = at
		carriage.rotation.y = global_rotation.y + PI * 0.5
	var horse_scene := load(HORSE) as PackedScene if ResourceLoader.exists(HORSE) else null
	if horse_scene == null:
		return
	# Six horses in three pairs ahead of the carriage (canon: six).
	for i in 6:
		var h := horse_scene.instantiate() as Node3D
		h.name = "CarriageHorse%d" % i
		add_child(h)
		var ahead := 3.6 + 2.4 * float(i / 2)
		var side := -0.75 if i % 2 == 0 else 0.75
		h.global_position = snap(at + global_transform.basis.x * -ahead + global_transform.basis.z * side)
		h.rotation.y = global_rotation.y - PI * 0.5
		horses.append(h)


func _give(_s: SceneSpace) -> void:
	given = true
	var t := actor(&"tamlin")
	for b in get_tree().get_nodes_in_group(&"p6_carried_paintings"):
		var n := b as Node3D
		if t and n:
			Juice.burst(n, &"craft")
			n.reparent(t)
			n.position = Vector3(0.0, 1.05, 0.3)
	EventBus.face_requested.emit(&"tamlin", &"tender", 0.9, 6.0)
	StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
	StoryControl.set_focus(t)


func _away(_s: SceneSpace) -> void:
	dismiss(&"tamlin")
	EventBus.grade_swap_requested.emit(&"human_spring", 2.0)
	for d: Array in DESTINATIONS:
		if WorldStreamer.get_region(d[0]) != null:
			EventBus.travel_requested.emit(d[0], d[1])
			return
