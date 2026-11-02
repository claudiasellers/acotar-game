## Act2Space.dismiss (L46-3): a dismissed stand-in leaves its story_actor group
## at once, so a scene casting the same character in the same frame (before
## queue_free lands) gets a fresh actor, not the dying one.
extends GutTest


func _space() -> Act2Space:
	var s := Act2Space.new()
	add_child_autofree(s)
	return s


func test_dismissed_actor_leaves_its_group_at_once() -> void:
	var a := _space()
	var who := a.request_actor(&"dismiss_probe", Transform3D.IDENTITY, func() -> Node3D: return Node3D.new())
	a.actors[&"dismiss_probe"] = who
	assert_true(who.is_in_group(&"story_actor_dismiss_probe"))
	a.dismiss(&"dismiss_probe")
	assert_false(who.is_in_group(&"story_actor_dismiss_probe"), "out of the group before it is freed")
	assert_null(a.actor(&"dismiss_probe"))
	var b := _space()
	var next := b.request_actor(&"dismiss_probe", Transform3D.IDENTITY, func() -> Node3D: return Node3D.new())
	assert_ne(next, who, "the next scene casts a fresh actor")
	await wait_physics_frames(2)
	assert_false(is_instance_valid(who), "the dismissed stand-in is freed")


func test_dismiss_leaves_actors_it_does_not_own() -> void:
	var a := _space()
	var other := Node3D.new()
	add_child_autofree(other)
	other.add_to_group(&"story_actor_dismiss_guest")
	a.actors[&"dismiss_guest"] = other
	a.dismiss(&"dismiss_guest")
	assert_true(is_instance_valid(other))
	assert_true(other.is_in_group(&"story_actor_dismiss_guest"), "a spawner's actor keeps its group")
