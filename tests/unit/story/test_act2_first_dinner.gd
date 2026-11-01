## The first dinner (ch7) contract: she walks to her chair, the magic holds
## her there (a move press shoves her back), three bites clear her plate in
## book order (chicken first), reaching for the torte makes the food vanish,
## and only then first_dinner_eaten, through an ActionTrigger.
extends GutTest

const STEP := 0.1

var root: Node3D
var feyre: Node3D
var space: FirstDinner


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	root = Node3D.new()
	add_child_autofree(root)
	feyre = Node3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	var anchor := Marker3D.new()
	anchor.name = "manor_dining_table"
	anchor.add_to_group(&"story_anchor")
	anchor.position = Vector3(21, 0.9, -31.5)
	root.add_child(anchor)
	StoryDirector.attach_anchor(anchor)
	space = anchor.get_node(^"Moment_first_dinner") as FirstDinner
	space.auto_tick = false
	feyre.global_position = anchor.global_position


func after_each() -> void:
	StoryControl.release()


func _run(seconds: float) -> void:
	for _i in int(seconds / STEP):
		space.tick(STEP)


func _until(label_prefix: String, seconds: float = 30.0) -> bool:
	for _i in int(seconds / STEP):
		if space.current_beat_label().begins_with(label_prefix):
			return true
		space.tick(STEP)
	return space.current_beat_label().begins_with(label_prefix)


func _seat() -> void:
	WorldState.set_flag("wall_crossed")
	assert_true(space.start())
	assert_true(WorldState.has_flag("fact.first_dinner_seen"))
	assert_not_null(space.actor(&"tamlin"), "Tamlin at the head of the table")
	assert_not_null(space.actor(&"lucien"))
	assert_true(_until("reach feyre_chair"))
	feyre.global_position = space.mark(&"feyre_chair")
	assert_true(_until("until her first bite"))


func test_the_director_hangs_the_coded_dinner() -> void:
	assert_true(space is FirstDinner)
	assert_false(space.can_start(), "not before the wall")
	WorldState.set_flag("wall_crossed")
	assert_true(space.can_start())


func test_she_is_held_until_she_eats() -> void:
	_seat()
	assert_true(space.held)
	assert_eq(StoryControl.mode, StoryControl.Mode.LOOK)
	assert_true(StoryControl.can_interact(), "E takes a bite")
	var seat := space.mark(&"feyre_chair")
	for _i in 3:
		feyre.global_position += Vector3(1.5, 0, 0)
		space.nudge()
		space.tick(STEP)
	assert_eq(space.shoves, 3, "every try to rise is a shove")
	assert_almost_eq(Vector2(feyre.global_position.x, feyre.global_position.z).distance_to(Vector2(seat.x, seat.z)), 0.0, 0.01,
			"shoved back into the seat")
	_run(20.0)
	assert_false(WorldState.has_flag("first_dinner_eaten"), "no deed without eating")
	assert_true(space.running)


func test_three_bites_then_the_torte_vanishes_and_the_deed() -> void:
	_seat()
	assert_not_null(space.table.dish(&"chicken"))
	for mark_name: StringName in [&"plate", &"chicken", &"torte", &"tamlin_goblet"]:
		assert_false((space.table.dish(mark_name) as MeshInstance3D).mesh is SphereMesh, "%s is the Blender model" % mark_name)
	space.press_interact()
	space.tick(STEP)
	assert_eq(space.bites, 1)
	assert_null(space.table.dish(&"chicken"), "chicken first")
	assert_not_null(space.table.dish(&"bread"))
	assert_true(_until("until a second bite"), "Lucien's tease plays out")
	space.press_interact()
	assert_true(_until("until the plate is clear"))
	space.press_interact()
	space.tick(STEP)
	assert_eq(space.bites, 3)
	assert_false(WorldState.has_flag("first_dinner_eaten"), "the torte comes first")
	space.press_interact()
	space.tick(STEP)
	assert_true(space.torte_gone)
	assert_null(space.table.dish(&"torte"))
	assert_true(_until("until she leaves the table"))
	assert_true(WorldState.has_flag("first_dinner_eaten"))
	assert_not_null(space.get_node_or_null(^"Raise_first_dinner_eaten") as ActionTrigger)
	assert_false(space.held)
	assert_eq(StoryControl.mode, StoryControl.Mode.FULL, "free again")
	feyre.global_position = space.mark(&"table") + Vector3(0, 0, 20)
	space.tick(STEP)
	assert_false(space.running)
	assert_null(space.actor(&"tamlin"), "the table empties once she leaves")
	assert_false(space.can_start(), "never replays")


func test_lines_come_from_the_stage_and_tag_inventions() -> void:
	for id in [&"sit", &"no_slaves", &"held", &"sniff", &"lucien_tunic", &"feyre_dress", &"lucien_andras", &"vanished"]:
		assert_false(space.stage.line(id).is_empty(), "line %s" % id)
	for id in space.stage.invented:
		assert_true(space.stage.lines.has(id), "invented %s is a real line" % id)
