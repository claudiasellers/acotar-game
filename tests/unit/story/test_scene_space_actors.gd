## SceneSpace casting (L44-2): a scene never borrows a stand-in another live
## scene owns (that scene, or its region unloading, frees it mid-scene), and
## Act2Space.actor() reads a freed actor as gone instead of erroring.
extends GutTest

var root: Node3D


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)


func _stand_in(owner_space: Node, id: StringName) -> Node3D:
	var n := Node3D.new()
	n.name = "StandIn_%s" % id
	n.add_to_group(StringName("story_actor_%s" % id))
	owner_space.add_child(n)
	return n


func test_request_actor_never_lends_another_scenes_stand_in() -> void:
	var theirs_space := SceneSpace.new()
	root.add_child(theirs_space)
	var theirs := _stand_in(theirs_space, &"tamlin")
	var mine_space := SceneSpace.new()
	root.add_child(mine_space)
	var got := mine_space.request_actor(&"tamlin", Transform3D.IDENTITY, func() -> Node3D: return Node3D.new())
	assert_ne(got, theirs, "another scene's stand-in is not lent")
	assert_eq(got.get_parent(), mine_space, "a stand-in of its own instead")
	var again := mine_space.request_actor(&"tamlin", Transform3D.IDENTITY, func() -> Node3D: return Node3D.new())
	assert_true(again == got or again == theirs or again.get_parent() == mine_space, "its own (or a spawner's) on asking again")
	assert_ne(again, theirs)


func test_request_actor_takes_a_spawners_actor() -> void:
	var spawned := _stand_in(root, &"lucien")  # parented outside any scene: a spawner's actor
	var space := SceneSpace.new()
	root.add_child(space)
	var got := space.request_actor(&"lucien", Transform3D.IDENTITY, func() -> Node3D: return Node3D.new())
	assert_eq(got, spawned, "a spawner's actor is shared")


func test_act2_actor_reads_freed_as_gone() -> void:
	var space := Act2Space.new()
	root.add_child(space)
	var who := Node3D.new()
	root.add_child(who)
	space.actors[&"lucien"] = who
	assert_eq(space.actor(&"lucien"), who)
	who.free()
	assert_null(space.actor(&"lucien"), "freed: null, no error")
	assert_false(space.actors.has(&"lucien"), "and forgotten")
