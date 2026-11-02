## Contract test for P6 "The blight tightens" (lane L46, docs/contracts/blight.md):
## the scenes hang on their anchors, each writes its fact only through play,
## the fountain waits for the morning after Alis, Alis's true form swaps on
## the glamour flag, the grade reads richer after it, and the data moments
## (L33's gen_moments.py) gate their deeds on these facts.
extends GutTest

const STEP := 0.1

var root: Node3D
var feyre: Node3D
var hall: Marker3D
var glade: Marker3D
var bedroom: Marker3D
var fountain: Marker3D


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	Clock.paused = true
	Clock.from_dict({"time_of_day": 0.4, "day": 10})
	root = Node3D.new()
	add_child_autofree(root)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	hall = _anchor("hall_mark_1", Vector3(4, 0.9, -31))
	glade = _anchor("glamour_lift_glade", Vector3(-1100, 30, 420))
	bedroom = _anchor("feyre_bedroom_window", Vector3(23, 5.7, -70.4))
	fountain = _anchor("manor_fountain", Vector3(0, 6.2, -139.5))
	for s in _spaces():
		s.auto_tick = false
		s.instant_fades = true


func after_each() -> void:
	StoryControl.release()
	Clock.paused = false


func _anchor(id: String, at: Vector3) -> Marker3D:
	var a := Marker3D.new()
	a.name = id
	a.set_meta(&"anchor_id", StringName(id))
	a.add_to_group(&"story_anchor")
	a.position = at
	root.add_child(a)
	Act6Spaces.attach(a)
	return a


func _spaces() -> Array[Act6Space]:
	var out: Array[Act6Space] = []
	for a in [hall, glade, bedroom, fountain]:
		for c in a.get_children():
			if c is Act6Space:
				out.append(c as Act6Space)
	return out


func _space(a: Node3D, n: String) -> Act6Space:
	return a.get_node(NodePath(n)) as Act6Space


## Ticks every P6 scene the way _physics_process would.
func _tick_all(seconds: float, until: Callable) -> bool:
	for _i in int(seconds / STEP):
		for s in _spaces():
			if s.running:
				s.tick(STEP)
			elif s._player_here() and s.can_start():
				s.arrive()
		if until.call():
			return true
	return bool(until.call())


func _press(s: Act6Space, at: Vector3) -> void:
	feyre.global_position = at
	s.press_interact()


func test_rows_hang_on_their_anchors() -> void:
	assert_not_null(_space(hall, "GlenInvite"))
	assert_not_null(_space(glade, "GlenPicnic"))
	assert_not_null(_space(glade, "EyesOpenWonders"))
	assert_not_null(_space(bedroom, "AlisTrueMorning"))
	assert_not_null(_space(fountain, "FountainHead"))
	var again := Act6Spaces.attach(glade)
	assert_eq(again.size(), 2, "attach is safe to call twice")
	assert_eq(glade.get_children().filter(func(c: Node) -> bool: return c is GlenPicnic).size(), 1)


func test_glamour_arc_by_deeds() -> void:
	var invite := _space(hall, "GlenInvite")
	feyre.global_position = invite.mark(&"feyre_door")
	assert_false(invite.can_start(), "no invitation before paintings_shown")
	WorldState.raise_deed("paintings_shown")
	assert_true(_tick_all(2.0, func() -> bool: return invite.running))
	_tick_all(3.0, func() -> bool: return false)
	assert_false(WorldState.has_flag("fact.glen_ride_taken"), "walking out is not going")
	feyre.global_position = invite.ground_mark(&"tamlin_steps")
	_tick_all(6.0, func() -> bool: return invite.current_beat_label() == "E: go with him")
	_press(invite, invite.ground_mark(&"tamlin_steps"))
	assert_true(_tick_all(10.0, func() -> bool: return WorldState.has_flag("fact.glen_ride_taken")))
	_tick_all(8.0, func() -> bool: return not invite.running)
	assert_lt(feyre.global_position.distance_to(glade.global_position), 6.0, "the ride ends in the glen")

	var picnic := _space(glade, "GlenPicnic")
	assert_true(_tick_all(2.0, func() -> bool: return picnic.running))
	_tick_all(6.0, func() -> bool: return picnic.current_beat_label() == "E: sit beside him")
	_press(picnic, picnic._blanket())
	assert_true(_tick_all(2.0, func() -> bool: return WorldState.has_flag("fact.glen_picnic_shared")))
	assert_false(WorldState.has_flag("glamour_lifted"), "the film's moment raises the deed, not the picnic")
	assert_not_null(get_tree().get_first_node_in_group(&"story_actor_tamlin"), "the film reuses this Tamlin")

	# L33's film: its moment raises the deed, the film writes its seen fact.
	WorldState.raise_deed("glamour_lifted")
	WorldState.set_flag("fact.film_eyes_open_seen")
	var wonders := _space(glade, "EyesOpenWonders")
	var t := get_tree().get_first_node_in_group(&"story_actor_tamlin") as Node3D
	assert_true(_tick_all(2.0, func() -> bool: return wonders.running))
	wonders.gaze_override = func() -> Array:
		var w: Vector3 = wonders.local(EyesOpenWonders.WILLOW_TOP)
		return [w + Vector3(0, 0, 8), Vector3(0, 0, -1)]
	feyre.global_position = wonders.local(EyesOpenWonders.WILLOW_TOP) + Vector3(0, -4, 8)
	_tick_all(3.0, func() -> bool: return wonders.found.has(&"willow"))
	feyre.global_position = t.global_position + Vector3(1, 0, 0)
	_tick_all(1.0, func() -> bool: return wonders.found.has(&"scent"))
	wonders.gaze_override = func() -> Array:
		var b: Vector3 = wonders.local(EyesOpenWonders.BROOK_MID)
		return [b + Vector3(0, 1, 6), (Vector3(0, -1, -6)).normalized()]
	feyre.global_position = wonders.local(EyesOpenWonders.BROOK_MID) + Vector3(0, 0, 6)
	_tick_all(3.0, func() -> bool: return wonders.found.size() == 3)
	assert_eq(wonders.found.size(), 3, "willow, brook and his scent")
	assert_true(_tick_all(20.0, func() -> bool: return WorldState.has_flag("fact.eyes_open_wonders")))
	assert_eq(Clock.day, 11, "she wakes the next morning")
	assert_lt(feyre.global_position.distance_to(bedroom.global_position), 14.0, "in her own room")


func test_alis_then_the_head_the_morning_after() -> void:
	for f in ["paintings_shown", "glamour_lifted"]:
		WorldState.raise_deed(f)
	for f in ["fact.glen_ride_taken", "fact.glen_picnic_shared", "fact.film_eyes_open_seen", "fact.eyes_open_wonders"]:
		WorldState.set_flag(f)
	var morning := _space(bedroom, "AlisTrueMorning")
	feyre.global_position = morning.mark(&"bed_side")
	assert_true(_tick_all(2.0, func() -> bool: return morning.running))
	morning.gaze_override = func() -> Array:
		var face: Vector3 = morning._alis_face()
		return [face + Vector3(0, 0, 2), Vector3(0, 0, -1)]
	assert_true(_tick_all(30.0, func() -> bool: return morning._true_form() != null and morning._true_form().fright > 0.5),
			"her bark bleaches when Feyre stares")
	assert_true(_tick_all(40.0, func() -> bool: return WorldState.has_flag("fact.alis_true_seen")))

	var head := _space(fountain, "FountainHead")
	feyre.global_position = head.center() + Vector3(0, 0, 6)
	assert_false(head.can_start(), "the head is found the next morning, not the same day")
	Clock.from_dict({"time_of_day": 0.35, "day": 11})
	assert_true(head.can_start())
	feyre.global_position = head.center() + Vector3(0, 0, 20)
	assert_true(_tick_all(2.0, func() -> bool: return head.running))
	assert_false(_tick_all(2.0, func() -> bool: return head.current_beat_label() != "the quiet garden"), "she has to walk up")
	feyre.global_position = head.center() + Vector3(0, 0, 6.5)
	head.gaze_override = func() -> Array: return [head.head_point() + Vector3(0, -3, 6), (Vector3(0, 3, -6)).normalized()]
	assert_true(_tick_all(15.0, func() -> bool: return head.actor(&"tamlin") != null), "she backs into Tamlin")
	assert_true(_tick_all(90.0, func() -> bool: return WorldState.has_flag("fact.fountain_head_seen")))
	assert_false(WorldState.has_flag("fountain_head_found"), "the moment raises the deed")


func test_true_form_and_true_sight() -> void:
	var alis := (load("res://characters/alis/alis_model.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(alis)
	await wait_physics_frames(2)
	var tf := alis.find_child("TrueForm", true, false) as AlisTrueForm
	assert_not_null(tf)
	assert_false(tf.lifted)
	var glamoured_hair := String(alis.get(&"hair_path"))
	WorldState.raise_deed(GlamourLayer.FLAG)
	assert_true(tf.lifted)
	var body_mat := alis.get(&"skin_body_material") as ShaderMaterial
	assert_eq(body_mat.shader.resource_path, "res://characters/alis/true_form/bark_skin.gdshader")
	assert_eq(String(alis.get(&"hair_path")), AlisTrueForm.WILD_HAIR)
	tf.frighten(1.0)
	assert_almost_eq(float(body_mat.get_shader_parameter(&"fright")), 1.0, 0.01)
	WorldState.clear()
	EventBus.flag_changed.emit(GlamourLayer.FLAG, null)
	assert_false(tf.lifted, "an earlier save shows the glamour again")
	assert_eq(String(alis.get(&"hair_path")), glamoured_hair)

	var base := GradeDirector.load_preset(&"spring")
	var seen := GradeDirector.with_true_sight(base, 1.0)
	assert_gt(seen.saturation, base.saturation * 1.1, "richer")
	assert_gt(seen.magic, base.magic + 0.15, "magic shimmers")
	assert_eq(GradeDirector.with_true_sight(base, 0.0), base, "no change under the glamour")


func test_moments_gate_on_p6_facts() -> void:
	var gates := {
		"glamour_lift": "fact.glen_picnic_shared", "fountain_head": "fact.fountain_head_seen",
		"solstice": "fact.solstice_sunrise_watched", "rhysand_visit": "fact.lunch_sat_down",
		"sent_home": "fact.carriage_boarded",
	}
	for id: String in gates:
		var m := load("res://data/story/moments/%s.tres" % id) as StoryMoment
		assert_true(m.require_flags.has(gates[id]), "%s waits for %s" % [id, gates[id]])
