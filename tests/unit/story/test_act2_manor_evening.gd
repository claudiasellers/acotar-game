## Act II's first evening at the manor, end to end on the two real anchors:
## the arrival (the beast leads her in and becomes Tamlin), Alis's bath and
## the tunic, the first dinner, and the curtain trap with Alis at dawn. Each
## scene opens only after the one before; deeds come from ActionTriggers.
extends GutTest

const STEP := 0.1

var root: Node3D
var feyre: Node3D
var dining: Marker3D
var bedroom: Marker3D


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	Clock.paused = true
	Clock.from_dict({"time_of_day": 0.55, "day": 3})
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
	return [arrival(), welcome(), dinner(), trap()]


func arrival() -> ManorArrival:
	return dining.get_node(^"ManorArrival") as ManorArrival


func welcome() -> AlisWelcome:
	return bedroom.get_node(^"AlisWelcome") as AlisWelcome


func dinner() -> FirstDinner:
	return dining.get_node(^"Moment_first_dinner") as FirstDinner


func trap() -> CurtainTrap:
	return bedroom.get_node(^"Moment_curtain_trap") as CurtainTrap


## Ticks every scene the way _physics_process would (arrival checks included).
func _tick_all(seconds: float, until: Callable = Callable()) -> bool:
	for _i in int(seconds / STEP):
		for space in _spaces():
			if space.running:
				space.tick(STEP)
			elif space._player_here() and space.can_start():
				space.arrive()
		if until.is_valid() and until.call():
			return true
	return until.is_valid() and bool(until.call())


## Feyre follows whoever is leading, as a player would.
func _follow(space: Act2Space, actor_id: StringName, seconds: float) -> void:
	for _i in int(seconds / STEP):
		var who := space.actor(actor_id)
		if who:
			feyre.global_position = who.global_position + Vector3(0, 0, 1.0)
		_tick_all(STEP)
		if not space.current_beat_label().begins_with("lead"):
			return


func _arrive() -> void:
	WorldState.set_flag("wall_crossed")
	feyre.global_position = arrival().mark(&"front_door") + Vector3(0, 0, 3)
	assert_true(_tick_all(1.0, func() -> bool: return arrival().running), "the doors open as she comes up the steps")
	assert_true(_tick_all(5.0, func() -> bool: return arrival().current_beat_label().begins_with("lead")))
	assert_not_null(arrival().actor(&"tamlin_beast"), "the beast waits in the hall")
	_follow(arrival(), &"tamlin_beast", 60.0)
	feyre.global_position = arrival().mark(&"dining_inside")
	assert_true(_tick_all(5.0, func() -> bool: return arrival().actor(&"tamlin") != null), "he becomes Tamlin")
	assert_null(arrival().actor(&"tamlin_beast"), "the beast is gone")
	assert_true(_tick_all(60.0, func() -> bool: return not arrival().running))


func test_the_arrival_leads_her_to_the_table_and_up_to_alis() -> void:
	assert_false(arrival().can_start(), "nothing before the wall")
	_arrive()
	assert_true(WorldState.has_flag("fact.manor_arrived"))
	assert_true(Clock.time_of_day > 0.7, "late afternoon by the bath")
	assert_true(welcome().player_within(3.0, welcome().mark(&"feyre_start")), "Alis has taken her up to her room")
	assert_null(arrival().actor(&"lucien"), "the dining room empties")
	assert_false(dinner().can_start(), "no dinner before the bath")


func test_alis_bathes_her_and_dresses_her_in_the_tunic() -> void:
	_arrive()
	assert_true(_tick_all(2.0, func() -> bool: return welcome().running), "Alis is waiting in her room")
	assert_not_null(welcome().actor(&"alis"))
	assert_true(_tick_all(10.0, func() -> bool: return welcome().current_beat_label() == "reach bath"))
	feyre.global_position = welcome().mark(&"bath")
	assert_true(_tick_all(2.0, func() -> bool: return welcome().current_beat_label() == "until she steps in"))
	welcome().press_interact()
	assert_true(_tick_all(60.0, func() -> bool: return not welcome().running))
	assert_true(welcome().bathed)
	assert_true(WorldState.has_flag("fact.alis_bathed"))
	assert_true(Gameplay.wardrobe.equipped().values().has(AlisWelcome.TUNIC), "the tunic, not the dress")
	assert_eq(Gameplay.wardrobe.equipped_in(&"outer"), &"", "Alis has taken the hunting cloak")
	assert_true(dinner().player_within(1.0, dining.global_position), "down to dinner")
	assert_true(dinner().running or dinner().can_start(), "the dinner opens")


## T091: at the rig step the rope is tied at a real door: shut, solid, filling
## her doorway on the bedroom's south wall, with visible meshes.
func _assert_door_at_rig_step() -> void:
	var door := trap().door
	assert_true(trap().door_closed(), "her door is shut at the rig step")
	if door == null:
		return
	var at := door.global_position
	assert_almost_eq(at.x, 23.0, 0.05, "in her doorway (x)")
	assert_almost_eq(at.z, -52.0, 0.05, "in her doorway, on the south wall line (z)")
	assert_lt(at.distance_to(trap().mark(&"door_inside")), 2.0, "where she rigs the rope")
	var meshes := door.find_children("*", "MeshInstance3D", true, false).filter(
			func(m: Node) -> bool: return (m as MeshInstance3D).is_visible_in_tree())
	assert_gte(meshes.size(), 3, "a leaf you can see, with panels and a knob")
	var shape := door.get_node(^"Hinge/Leaf/Shape") as CollisionShape3D
	assert_false(shape.disabled, "solid while shut")
	assert_almost_eq((shape.shape as BoxShape3D).size.x, trap().DOOR_SIZE.x, 0.1, "fills the 1.6 m doorway")


func test_the_curtain_trap_rigs_at_night_and_trips_alis_at_dawn() -> void:
	WorldState.set_flag("wall_crossed")
	WorldState.set_flag("first_dinner_eaten")
	Clock.from_dict({"time_of_day": 0.95, "day": 3})
	assert_true(trap().can_start())
	assert_null(trap().get_node_or_null(^"BedroomDoor"), "no door in her doorway before the scene")
	feyre.global_position = bedroom.global_position
	assert_true(trap().start())
	assert_true(trap().door_closed(), "her door hangs shut from the start of the night")
	assert_true(_tick_all(5.0, func() -> bool: return trap().coil != null), "a coil of rope from the trimmings")
	assert_true(_tick_all(2.0, func() -> bool: return trap().current_beat_label() == "reach door_inside"))
	feyre.global_position = trap().mark(&"door_inside")
	assert_true(_tick_all(2.0, func() -> bool: return trap().current_beat_label() == "until she rigs it"))
	assert_false(WorldState.has_flag("curtain_trap_set"))
	_assert_door_at_rig_step()
	trap().press_interact()
	assert_true(_tick_all(2.0, func() -> bool: return WorldState.has_flag("curtain_trap_set")))
	assert_true(trap().rigged)
	assert_not_null(trap().get_node_or_null(^"Raise_curtain_trap_set") as ActionTrigger)
	assert_true(_tick_all(5.0, func() -> bool: return trap().actor(&"alis") != null), "dawn: Alis at the door")
	assert_true(Clock.time_of_day < 0.3, "before dawn")
	assert_true(trap().door_closed(), "locked all night, until Alis opens it")
	assert_true(_tick_all(5.0, func() -> bool: return not trap().door_closed()), "Alis opens it: it swings in")
	assert_true(_tick_all(90.0, func() -> bool: return not trap().running))
	assert_null(trap().door, "the scene's door goes with the scene")
	assert_true(WorldState.has_flag("fact.alis_tripped"))
	assert_null(trap().actor(&"alis"))
	assert_false(trap().can_start(), "never replays")
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL)
