## Contract: streamed in, the manor builds across frames and ends up the very
## same as a whole build, and is in BUSY_GROUP (WorldStreamer.is_ready false)
## until every wall and floor is there.
extends GutTest

const MANOR := "res://world/spring_court/manor_estate/manor_estate.tscn"
## Headless on a busy gate. One-frame builds were 3400 to 6700 ms.
const MAX_FRAME_MSEC := 400
const MAX_BUILD_SECONDS := 60.0


func _manor(stream_id: StringName) -> ManorEstate:
	var manor := (load(MANOR) as PackedScene).instantiate() as ManorEstate
	manor.build_terrain = false
	manor.stream_id = stream_id
	add_child_autofree(manor)
	return manor


## Every node's path, class, transform and geometry, in tree order.
func _signature(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var auto_names := RegEx.create_from_string("@\\d+")
	for node in root.find_children("*", "", true, false):
		if String(root.get_path_to(node)).begins_with("CreatureSpawner/"):
			continue  # creatures wander
		# Engine-picked names carry a running number.
		var line := "%s %s" % [auto_names.sub(String(root.get_path_to(node)), "@", true), node.get_class()]
		if node is Node3D:
			line += " %s" % str((node as Node3D).transform)
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh := (node as MeshInstance3D).mesh
			line += " mesh %d/%d" % [mesh.get_surface_count(), mesh.get_faces().size()]
		if node is CollisionShape3D and (node as CollisionShape3D).shape != null:
			line += " %s" % (node as CollisionShape3D).shape.get_class()
		out.append(line)
	return out


func test_builds_across_frames_into_the_same_manor() -> void:
	var manor := _manor(&"manor_estate")
	assert_true(manor.is_in_group(ManorEstate.BUSY_GROUP), "busy from the start")
	assert_null(manor.get_node_or_null(^"House"), "nothing is in the tree yet")
	var started := Time.get_ticks_msec()
	var frame_at := started
	var longest := 0
	var frames := 0
	while manor.is_in_group(ManorEstate.BUSY_GROUP) and (Time.get_ticks_msec() - started) / 1000.0 < MAX_BUILD_SECONDS:
		await wait_frames(1)
		longest = maxi(longest, Time.get_ticks_msec() - frame_at)
		frame_at = Time.get_ticks_msec()
		frames += 1
	gut.p("built in %d ms over %d frames, longest frame %d ms" % [Time.get_ticks_msec() - started, frames, longest])
	assert_false(manor.is_in_group(ManorEstate.BUSY_GROUP), "finishes")
	assert_lt(longest, MAX_FRAME_MSEC, "no frame pays for the build")
	assert_not_null(manor.house, "the estate has its parts")
	assert_not_null(manor.scatter)
	var built := _signature(manor)
	manor.free()  # scenes hung on anchors look for the ground under them
	var whole := _manor(&"")
	await wait_frames(5)  # the story hangs its scenes on anchors a frame later
	var again := _signature(whole)
	built.sort()  # scene-added children land in a different order
	again.sort()
	assert_eq(built, again, "the same manor as a whole build")


## What the merge and the batches take without reading the GPU has to be what
## a read would have given.
func test_reads_saved_give_the_same_geometry() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 0.4, 2.7)
	var xform := Transform3D(Basis(Vector3.UP, 0.6), Vector3(3.0, 1.0, -2.0))
	var read := SurfaceTool.new()
	read.begin(Mesh.PRIMITIVE_TRIANGLES)
	read.append_from(box, 0, xform)
	var saved := SurfaceTool.new()
	saved.begin(Mesh.PRIMITIVE_TRIANGLES)
	ManorMeshMerger.append(saved, box, xform)
	var want: PackedVector3Array = read.commit().get_faces()
	var got: PackedVector3Array = saved.commit().get_faces()
	assert_eq(got.size(), want.size())
	for i in mini(got.size(), want.size()):
		assert_true(got[i].is_equal_approx(want[i]), "corner %d" % i)


func test_streamed_out_mid_build_it_cleans_up() -> void:
	var manor := _manor(&"manor_estate")
	await wait_frames(3)
	manor.free()
	await wait_seconds(12.0)
	assert_eq(get_tree().get_nodes_in_group(ManorEstate.BUSY_GROUP), [] as Array[Node], "nothing left building")
