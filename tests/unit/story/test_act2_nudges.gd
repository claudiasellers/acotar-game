## Act II never leaves the player wondering what a scene wants (L34-6). Every
## beat that waits on her press, and every wait on her in the manor's first
## evening (a place to reach, someone to follow), carries an idle nudge: a
## stage line said as an aside if she hasn't managed it after a while. The
## bath steams and shows "E   step in", the forage card's look; Alis tells
## her to go on if she stands there.
extends GutTest

const STEP := 0.1
## The manor's first evening: every wait on her has a nudge, not just presses.
const EVENING := ["res://story/act2/manor_arrival.gd", "res://story/act2/alis_welcome.gd",
	"res://story/act2/first_dinner.gd", "res://story/act2/curtain_trap.gd",
	# L34-8: Lucien's invitation, the Bogge, the puca.
	"res://story/act2/lucien_invite.gd", "res://story/act2/bogge_hunt.gd", "res://story/act2/puca_lure.gd"]
## Waits that move on by themselves (her temper rises on a timer; the Bogge's pass).
const SELF_ENDING := ["until she rises", "it passes behind her", "she knows him"]

var root: Node3D
var feyre: Node3D
var dining: Marker3D
var bedroom: Marker3D
var heard: Array = []


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	Clock.paused = true
	Clock.from_dict({"time_of_day": 0.55, "day": 3})
	heard.clear()
	root = Node3D.new()
	add_child_autofree(root)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	dining = _anchor("manor_dining_table", Vector3(21, 0.9, -31.5))
	bedroom = _anchor("feyre_bedroom_window", Vector3(23, 5.7, -70.4))
	for space in _spaces():
		space.auto_tick = false
		space.instant_fades = true


func after_each() -> void:
	StoryControl.release()
	Clock.paused = false
	Act2Caption.clear_all(get_tree())


func _anchor(id: String, at: Vector3) -> Marker3D:
	var a := Marker3D.new()
	a.name = id
	a.set_meta(&"anchor_id", StringName(id))
	a.add_to_group(&"story_anchor")
	a.position = at
	root.add_child(a)
	StoryDirector.attach_anchor(a)
	return a


func _spaces() -> Array[Act2Space]:
	return [arrival(), welcome(), dinner()]


func arrival() -> ManorArrival:
	return dining.get_node(^"ManorArrival") as ManorArrival


func welcome() -> AlisWelcome:
	return bedroom.get_node(^"AlisWelcome") as AlisWelcome


func dinner() -> FirstDinner:
	return dining.get_node(^"Moment_first_dinner") as FirstDinner


func _caption() -> String:
	var c := get_tree().get_first_node_in_group(Act2Caption.GROUP) as Act2Caption
	return c.showing if c else ""


func _tick_all(seconds: float, until: Callable = Callable()) -> bool:
	for _i in int(seconds / STEP):
		for space in _spaces():
			if space.running:
				space.tick(STEP)
			elif space._player_here() and space.can_start():
				space.arrive()
		var now := _caption()
		if now != "" and (heard.is_empty() or heard.back() != now):
			heard.append(now)
		if until.is_valid() and until.call():
			return true
	return until.is_valid() and bool(until.call())


func _line(space: Act2Space, id: StringName) -> String:
	return String(space.stage.line(id).get("text", ""))


func _start_arrival() -> void:
	WorldState.set_flag("wall_crossed")
	feyre.global_position = arrival().mark(&"front_door") + Vector3(0, 0, 3)
	assert_true(_tick_all(1.0, func() -> bool: return arrival().running))
	assert_true(_tick_all(5.0, func() -> bool: return arrival().current_beat_label().begins_with("lead")))


func test_every_press_wait_and_every_evening_wait_has_a_nudge() -> void:
	var press_wait := RegEx.create_from_string("Beats\\.until\\(func\\(\\) -> bool: return [^\\n]*(presses\\(\\)|bites|torte_gone)")
	var raw_until := RegEx.create_from_string("Beats\\.until\\([^\\n]*\"([^\"]+)\"\\)")
	var raw_reach := RegEx.create_from_string("(?<![_a-z])reach\\(&")
	var checked := 0
	for entry: Dictionary in _act2_entries():
		var path: String = entry["script"]
		var src := FileAccess.get_file_as_string(path)
		assert_null(press_wait.search(src), "%s waits on a press with no nudge (use wait_press or nudged)" % path)
		if path in EVENING:
			for m in raw_until.search_all(src):
				assert_true(m.get_string(1) in SELF_ENDING, "%s: '%s' waits on her with no nudge" % [path, m.get_string(1)])
			assert_null(raw_reach.search(src), "%s: a reach() with no nudge (use reach_nudged)" % path)
		var space := (load(path) as GDScript).new() as Act2Space
		space.stage = load(entry["stage"]) as Act2Stage
		for beat: SceneBeat in space._build_beats():
			var nudge := &""
			if beat is Act2Space.NudgeBeat:
				nudge = (beat as Act2Space.NudgeBeat).nudge
			elif beat is Act2Space.LeadBeat and (beat as Act2Space.LeadBeat).wait_for > 0.0:
				nudge = (beat as Act2Space.LeadBeat).nudge
				if path in EVENING:
					assert_ne(nudge, &"", "%s: %s waits on her with no nudge" % [path, beat.label])
			else:
				continue
			if nudge != &"":
				checked += 1
				assert_ne(_line(space, nudge), "", "%s: nudge line '%s' is in the stage" % [path, nudge])
				assert_true(space.stage.invented.has(String(nudge)) or space.stage.canon != "", "%s marked" % nudge)
		space.free()
	assert_gt(checked, 8, "the evening's waits all carry nudges")
	# The window's pull before the curtain trap (L34-7) speaks stage lines too.
	var trap_stage := load("res://data/story/act2/curtain_trap_stage.tres") as Act2Stage
	for id in ["pull_draught", "pull_growl", "pull_lock", "pull_curtains"]:
		assert_false(trap_stage.line(StringName(id)).is_empty(), "the window pull's %s is in the stage" % id)


func _act2_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in Act2Spaces.CODED:
		var e: Dictionary = Act2Spaces.CODED[id]
		if String(e["script"]).begins_with("res://story/act2/"):
			out.append(e)
	for anchor_id: StringName in Act2Spaces.EXTRA:
		for e: Dictionary in Act2Spaces.EXTRA[anchor_id]:
			if String(e["script"]).begins_with("res://story/act2/"):
				out.append(e)
	return out


func test_the_beast_waits_for_her_and_she_notices() -> void:
	_start_arrival()
	# She stays on the steps: he waits, and after a while she notices.
	_tick_all(ManorArrival.FOLLOW_NUDGE_AFTER + 4.0)
	assert_true(heard.has(_line(arrival(), &"beast_waits")), "the beast waits for her: %s" % [heard])


func test_the_bath_steams_shows_e_and_alis_tells_her_to_go_on() -> void:
	_start_arrival()
	for _i in 600:
		var who := arrival().actor(&"tamlin_beast")
		if who:
			feyre.global_position = who.global_position + Vector3(0, 0, 1.0)
		_tick_all(STEP)
		if not arrival().current_beat_label().begins_with("lead"):
			break
	feyre.global_position = arrival().mark(&"dining_inside")
	assert_true(_tick_all(90.0, func() -> bool: return welcome().current_beat_label() == "reach bath"))
	assert_not_null(welcome().steam, "the bath steams")
	assert_eq(welcome().steam.draw_pass_1.surface_get_material(0).get(&"emission_enabled"), false, "steam, not a glow")
	_tick_all(AlisWelcome.WHERE_AFTER + 3.0)
	assert_true(heard.has(_line(welcome(), &"alis_bath_where")), "Alis points the way: %s" % [heard])
	feyre.global_position = welcome().mark(&"bath")
	assert_true(_tick_all(3.0, func() -> bool: return welcome().current_beat_label() == "until she steps in"))
	_tick_all(0.3)
	var card := welcome().get_node_or_null(^"PressCard") as PressCard
	assert_not_null(card)
	assert_eq(card.text() if card else "", "E   step in")
	_tick_all(AlisWelcome.GO_ON_AFTER + 3.0)
	assert_true(heard.has("Go on, it won't bite."), "Alis: go on: %s" % [heard])
	welcome().press_interact()
	assert_true(_tick_all(3.0, func() -> bool: return welcome().bathed))
	assert_eq(card.text() if card else "", "", "the card goes once she's in")
	assert_null(welcome().steam, "and the steam with it")


func trap() -> CurtainTrap:
	return bedroom.get_node(^"Moment_curtain_trap") as CurtainTrap


func _pull(seconds: float) -> void:
	trap().auto_tick = false
	for _i in int(seconds / STEP):
		trap().pull(STEP)
		var now := _caption()
		if now != "" and (heard.is_empty() or heard.back() != now):
			heard.append(now)


func test_at_night_the_window_pulls_her_to_the_curtains() -> void:
	WorldState.set_flag("wall_crossed")
	WorldState.set_flag("first_dinner_eaten")
	Clock.from_dict({"time_of_day": 0.55, "day": 3})
	feyre.global_position = bedroom.global_position + Vector3(0, 0, 8)
	_pull(30.0)
	assert_true(heard.is_empty(), "nothing by day: %s" % [heard])
	Clock.from_dict({"time_of_day": 0.95, "day": 3})
	assert_true(trap().can_start())
	feyre.global_position = bedroom.global_position + Vector3(0, 30, 8)
	_pull(30.0)
	assert_true(heard.is_empty(), "nothing from elsewhere in the house")
	feyre.global_position = bedroom.global_position + Vector3(0, 0, 8)
	_pull(CurtainTrap.CURTAINS_AT + 2.0)
	for id: StringName in [&"pull_draught", &"pull_growl", &"pull_lock", &"pull_curtains"]:
		assert_true(heard.has(_line(trap(), id)), "%s: %s" % [id, heard])
	assert_eq(heard.find(_line(trap(), &"pull_draught")), 0, "the draught first")
	var far := trap().get_node_or_null(^"PressCard") as PressCard
	assert_eq(far.text() if far else "", "", "no card across the room")
	feyre.global_position = bedroom.global_position + Vector3(0, 0, 1.0)
	_pull(0.5)
	var card := trap().get_node_or_null(^"PressCard") as PressCard
	assert_eq(card.text() if card else "", "E   the curtains", "the card by the window")
	_pull(120.0)
	assert_eq(Array(trap().pulled), ["draught", "growl", "lock", "curtains0", "curtains1"],
		"the curtain thought once more at most")
	WorldState.set_flag("curtain_trap_set")
	_pull(0.5)
	assert_eq(card.text(), "", "gone once the night's done")


func test_the_morning_after_lucien_asks_her_to_hunt() -> void:
	for f in ["wall_crossed", "first_dinner_eaten", "curtain_trap_set", "fact.alis_tripped"]:
		WorldState.set_flag(f)
	Clock.from_dict({"time_of_day": 0.4, "day": 4})
	var invite := dining.get_node(^"LucienInvite") as LucienInvite
	invite.auto_tick = false
	assert_true(invite.can_start())
	# About the house, not at the steps: she remembers him after a while.
	feyre.global_position = invite.mark(&"lucien_steps") + Vector3(60, 0, -20)
	for _i in int((LucienInvite.PULL_AFTER + 2.0) / STEP):
		invite.pull(STEP)
		var now := _caption()
		if now != "" and (heard.is_empty() or heard.back() != now):
			heard.append(now)
	assert_true(heard.has(_line(invite, &"invite_pull")), "she remembers Lucien: %s" % [heard])
	feyre.global_position = invite.mark(&"lucien_steps") + Vector3(0, 0, -4)
	for _i in 20:
		if invite._player_here() and invite.can_start():
			invite.arrive()
		if invite.running:
			break
	assert_true(invite.running, "he calls to her on the steps")
	assert_not_null(invite.actor(&"lucien"))
	var ok := false
	for _i in 400:
		invite.tick(STEP)
		if invite.current_beat_label() == "until she goes with him":
			ok = true
			break
	assert_true(ok, "he waits for her answer")
	for _i in int((LucienInvite.NUDGE_AFTER + 2.0) / STEP):
		invite.tick(STEP)
		var now := _caption()
		if now != "" and (heard.is_empty() or heard.back() != now):
			heard.append(now)
	var card := invite.get_node_or_null(^"PressCard") as PressCard
	assert_eq(card.text() if card else "", "E   go with Lucien")
	assert_true(heard.has(_line(invite, &"lucien_light")), "Lucien: the light won't wait")
	invite.press_interact()
	for _i in 20:
		invite.tick(STEP)
	assert_true(WorldState.has_flag("fact.hunt_invited"))
	assert_false(invite.running)
	assert_not_null(invite.travel, "dark, and out to the oaks")
	if invite.travel:
		invite.travel.queue_free()
	assert_false(invite.can_start(), "asked once")


func test_the_puca_shows_himself_under_her_window() -> void:
	WorldState.set_flag("bogge_survived")
	Clock.from_dict({"time_of_day": 0.95, "day": 5})
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = false
	var puca := Act2Spaces.space_for(StoryDirector.get_moment(&"puca")) as PucaLure
	puca.auto_tick = false
	puca.position = Vector3(0, 0, -194)
	root.add_child(puca)
	feyre.global_position = bedroom.global_position + Vector3(0, 0, 6)
	assert_true(puca.in_her_room())
	assert_true(puca._player_here(), "at night her room counts: she sees him from the window")
	assert_true(puca.can_start())
	puca.arrive()
	var ok := false
	for _i in 100:
		puca.tick(STEP)
		var now := _caption()
		if now != "" and (heard.is_empty() or heard.back() != now):
			heard.append(now)
		if puca.current_beat_label() == "she goes down to him":
			ok = true
			break
	assert_true(ok, "he waits for her below")
	var p := puca.puca()
	assert_not_null(p)
	if p == null:
		return
	assert_lt(Vector2(p.global_position.x, p.global_position.z).distance_to(
		Vector2(puca.below_her_window().x, puca.below_her_window().z)), 0.5, "under her window")
	assert_true(heard.has(_line(puca, &"puca_window")))
	for _i in int((PucaLure.NUDGE_AFTER + 2.0) / STEP):
		puca.tick(STEP)
		var now := _caption()
		if now != "" and (heard.is_empty() or heard.back() != now):
			heard.append(now)
	assert_true(heard.has(_line(puca, &"puca_come_down")), "she has to go down to him: %s" % [heard])
	assert_eq(puca.current_beat_label(), "she goes down to him", "he doesn't wander off while she's upstairs")
	feyre.global_position = p.global_position + Vector3(0, 0, 3)
	for _i in 5:
		puca.tick(STEP)
	assert_eq(puca.current_beat_label(), "follow him to the gate")
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = true
