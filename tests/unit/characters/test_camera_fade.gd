## Contract: a small mesh with no collision within CameraFade.RADIUS of the drawing
## camera fades see-through and comes back once the lens leaves; big meshes (room
## shells, terrain) and Feyre herself never fade.
extends GutTest

const FEYRE := preload("res://characters/feyre/feyre.tscn")


func _box(size: Vector3, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	add_child_autofree(m)
	m.global_position = at
	return m


func _feyre() -> Feyre:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(60, 1, 60)
	shape.shape = floor_box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child_autofree(body)
	var f := FEYRE.instantiate() as Feyre
	add_child_autofree(f)
	f.global_position = Vector3(0, 0.05, 0)
	return f


func _in_front_of_lens(f: Feyre, gap: float, half: float) -> Vector3:
	var cam := f.camera
	return cam.global_position - cam.global_basis.z * (gap + half)


func test_a_prop_against_the_lens_fades_and_comes_back() -> void:
	var f := _feyre()
	await wait_seconds(1.0)
	var prop := _box(Vector3(0.6, 0.6, 0.6), _in_front_of_lens(f, 0.2, 0.3))
	await wait_seconds(0.4)
	assert_gt(prop.transparency, 0.5, "a table edge 0.2 m from the lens is see-through")
	prop.global_position += Vector3(0, 0, 10)
	await wait_seconds(0.4)
	assert_almost_eq(prop.transparency, 0.0, 0.001, "and solid again once the lens leaves")


func test_a_prop_further_off_stays_solid() -> void:
	var f := _feyre()
	await wait_seconds(1.0)
	var prop := _box(Vector3(0.6, 0.6, 0.6), _in_front_of_lens(f, 1.2, 0.3))
	await wait_seconds(0.4)
	assert_eq(prop.transparency, 0.0)


func test_big_meshes_and_feyre_never_fade() -> void:
	var f := _feyre()
	await wait_seconds(1.0)
	var wall := _box(Vector3(8, 4, 0.3), _in_front_of_lens(f, 0.1, 0.15))
	var fade := f.get_node("CameraFade") as CameraFade
	await wait_seconds(0.4)
	assert_eq(wall.transparency, 0.0, "a room shell is never faded")
	for g in fade.near_meshes(f.global_position + Vector3.UP):
		assert_false(f.is_ancestor_of(g), "Feyre's own mesh %s is never faded" % g.name)
