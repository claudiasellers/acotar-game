## StoryDirector hangs scenes on story anchors that enter the tree after
## their region's region_loaded (the woods build anchors in deferred jobs):
## exactly once, with the coded Act II scene where there is one.
extends GutTest

var root: Node3D


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)


func _anchor(id: StringName) -> Marker3D:
	var m := Marker3D.new()
	m.name = String(id)
	m.add_to_group(&"story_anchor")
	return m


func test_a_late_anchor_gets_its_scene_once() -> void:
	var region := Node3D.new()
	root.add_child(region)
	StoryDirector._on_region_loaded(&"border_woods", region)
	# The region's build job places the anchor later.
	var anchor := _anchor(&"bogge_hunt_path")
	region.add_child(anchor)
	await wait_frames(2)
	var spaces := anchor.get_children().filter(func(c: Node) -> bool: return c is SceneSpace)
	assert_eq(spaces.size(), 1, "one scene on the late anchor")
	assert_true(anchor.get_node_or_null(^"Moment_bogge") is BoggeHunt, "the coded Bogge scene")
	# A region_loaded or a second attach afterwards adds nothing.
	StoryDirector._on_region_loaded(&"border_woods", region)
	StoryDirector.attach_anchor(anchor)
	await wait_frames(2)
	assert_eq(anchor.get_children().filter(func(c: Node) -> bool: return c is SceneSpace).size(), 1, "still once")


func test_other_nodes_are_left_alone() -> void:
	var plain := Node3D.new()
	plain.name = "bogge_hunt_path"
	root.add_child(plain)
	await wait_frames(2)
	assert_eq(plain.get_child_count(), 0, "not a story anchor: nothing hung")
