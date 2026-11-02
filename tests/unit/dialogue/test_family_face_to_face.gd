## Nesta, Elain and their father speak only face to face (lane L34-5): Feyre
## inside the cottage with them, within TALK_RADIUS, and them on her camera
## with no wall between. Not from the yard through the wall, not across the
## room, not behind her back. Everyone else is as before.
extends GutTest

var director: DialogueDirector
var cottage: Marker3D
var shown: Array = []
## What the camera sees: [origin, forward], or [] for no camera.
var view: Array = []


func before_each() -> void:
	WorldState.clear()
	PhaseManager.current_phase = &"p0_winter"
	shown.clear()
	view = []
	cottage = Marker3D.new()
	cottage.name = "act1_cottage_interior"
	cottage.add_to_group(&"story_anchor")
	add_child_autofree(cottage)
	director = DialogueDirector.new()
	director.books_dir = ""
	director.auto_tick = false
	director.show_fn = func(_who: String, text: String) -> float:
		shown.append(text)
		return 2.0
	director.view_fn = func() -> Array: return view
	add_child_autofree(director)


func _line(id: StringName, speaker: StringName, trigger: DialogueLine.Trigger, deed: StringName = &"") -> DialogueLine:
	var line := DialogueLine.new()
	line.id = id
	line.speaker = speaker
	line.trigger = trigger
	line.deed = deed
	line.text = "%s says %s." % [speaker, id]
	var book := DialogueBook.new()
	book.lines.append(line)
	director.add_book(book)
	return line


func _person(speaker: StringName, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.set_meta(&"speaker", String(speaker))
	n.add_to_group(DialogueDirector.PRESENCE_GROUP)
	add_child_autofree(n)
	n.global_position = at
	return n


## Her camera at eye height where she stands, looking at `point`.
func _look(from: Vector3, point: Vector3) -> void:
	var eye := from + Vector3.UP * 1.6
	view = [eye, (point + Vector3.UP * 1.5 - eye).normalized()]


func _step(at: Vector3, seconds: float = 30.0) -> DialogueLine:
	director._now += seconds
	return director.step(at)


func test_her_inside_and_looking_hears_them() -> void:
	_line(&"n_hello", &"nesta", DialogueLine.Trigger.NEAR_SPEAKER)
	var nesta := _person(&"nesta", Vector3(0, 0, 0))
	var at := Vector3(2, 0, 0)
	_look(at, nesta.global_position)
	var line := _step(at)
	assert_not_null(line)
	assert_eq(line.id if line else &"", &"n_hello")


func test_not_through_the_wall_from_outside() -> void:
	_line(&"n_hello", &"nesta", DialogueLine.Trigger.NEAR_SPEAKER)
	var nesta := _person(&"nesta", Vector3(0, 0, -2.4))
	var at := Vector3(0, 0, -3.6)  # in the yard, a step from her through the wall
	assert_false(director.in_cottage(at))
	assert_true(director.in_cottage(nesta.global_position))
	_look(at, nesta.global_position)
	assert_null(_step(at), "the yard is not the cottage")
	# She comes in and turns to her: now Nesta speaks.
	at = Vector3(0, 0, -0.5)
	_look(at, nesta.global_position)
	assert_not_null(_step(at), "inside with her and looking: she speaks")


func test_not_across_the_room() -> void:
	_line(&"e_hello", &"elain", DialogueLine.Trigger.NEAR_SPEAKER)
	var elain := _person(&"elain", Vector3(-3.2, 0, 0))
	var at := Vector3(4.2, 0, 0)  # the far wall, 7 m away
	_look(at, elain.global_position)
	assert_null(_step(at))


func test_not_behind_her_back() -> void:
	_line(&"f_hello", &"father", DialogueLine.Trigger.NEAR_SPEAKER)
	var father := _person(&"father", Vector3(0, 0, 0))
	var at := Vector3(2, 0, 0)
	_look(at, Vector3(4, 0, 0))  # facing away from him
	assert_null(_step(at), "he's behind her: not yet")
	assert_null(_step(at), "and not greeted, so it still waits")
	_look(at, father.global_position)
	assert_not_null(_step(at), "the moment she turns to him")


func test_not_with_no_camera() -> void:
	_line(&"n_hello", &"nesta", DialogueLine.Trigger.NEAR_SPEAKER)
	_person(&"nesta", Vector3(0, 0, 0))
	view = []
	assert_null(_step(Vector3(1.5, 0, 0)))


func test_not_with_a_wall_between_camera_and_them() -> void:
	_line(&"n_hello", &"nesta", DialogueLine.Trigger.NEAR_SPEAKER)
	var nesta := _person(&"nesta", Vector3(0, 0, 0))
	var at := Vector3(3, 0, 0)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 4, 4)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.global_position = Vector3(1.5, 1, 0)
	await wait_physics_frames(3)
	_look(at, nesta.global_position)
	assert_false(director.on_camera(nesta), "the wall hides her")
	assert_null(_step(at))
	wall.global_position = Vector3(1.5, 1, 10)
	await wait_physics_frames(3)
	assert_true(director.on_camera(nesta))
	assert_not_null(_step(at))


func test_a_deed_line_waits_until_she_is_with_them() -> void:
	_line(&"n_deed", &"nesta", DialogueLine.Trigger.DEED, &"wolf_killed")
	var nesta := _person(&"nesta", Vector3(0, 0, -2.4))
	var at := Vector3(0, 0, -6.0)  # coming up the path
	WorldState.set_flag("wolf_killed", true)
	_look(at, nesta.global_position)
	assert_null(_step(at), "outside: waits")
	assert_null(_step(at), "still waits")
	at = Vector3(0, 0, -0.8)
	_look(at, nesta.global_position)
	var line := _step(at)
	assert_eq(line.id if line else &"", &"n_deed", "said once they're face to face")


func test_a_family_follow_up_waits_too() -> void:
	var first := _line(&"f_first", &"feyre", DialogueLine.Trigger.DEED, &"wolf_killed")
	first.follow_up = &"n_answer"
	_line(&"n_answer", &"nesta", DialogueLine.Trigger.FOLLOW_UP)
	var nesta := _person(&"nesta", Vector3(0, 0, -2.4))
	var at := Vector3(0, 0, -4.0)
	WorldState.set_flag("wolf_killed", true)
	var line := _step(at)
	assert_eq(line.id if line else &"", &"f_first", "her own thought, anywhere")
	director._now += 3.0
	assert_null(director.step(at), "Nesta's answer waits for her to come in")
	at = Vector3(0, 0, -1.0)
	_look(at, nesta.global_position)
	director._now += 1.0
	line = director.step(at)
	assert_eq(line.id if line else &"", &"n_answer")


func test_others_are_as_before() -> void:
	_line(&"l_hello", &"lucien", DialogueLine.Trigger.NEAR_SPEAKER)
	_person(&"lucien", Vector3(30, 0, 0))
	view = []
	assert_not_null(_step(Vector3(32, 0, 0)), "no cottage, no camera needed")
