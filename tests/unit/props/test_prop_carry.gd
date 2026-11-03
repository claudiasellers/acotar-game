## Contract: PropData content, carry/throw/place, shove, and PropField pooling (T5).
extends GutTest

const KINDS := [&"crate", &"crate_village", &"barrel", &"pot_clay", &"pot_glazed", &"bucket", &"firewood_log"]

var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	col.shape = box
	col.position.y = -0.5
	floor_body.add_child(col)
	_root.add_child(floor_body)


func test_every_kind_has_data_and_a_model() -> void:
	for id: StringName in KINDS:
		var d := PropPlacements.prop_data(id)
		assert_not_null(d, "data/props/%s.tres" % id)
		if d == null:
			continue
		assert_eq(d.id, id)
		assert_true(ResourceLoader.exists(d.mesh_path), "%s model %s" % [id, d.mesh_path])
		assert_gt(d.mass, 0.0)
		assert_not_null(Prop.mesh_for(d), "%s mesh" % id)


func test_pick_up_then_throw_lands_three_metres_away() -> void:
	var holder := _holder()
	var pot := _prop(&"pot_glazed", Vector3(0, 0, -0.8))
	await wait_physics_frames(5)
	var carrier := PropCarrier.for_body(holder)
	assert_true(carrier.pick_up(pot))
	assert_true(pot.carried and pot.freeze, "held kinematic")
	assert_false(carrier.pick_up(_prop(&"crate", Vector3(2, 0, 0))), "one at a time")
	await wait_physics_frames(10)
	assert_almost_eq(pot.global_position.y, 1.05 - pot.data.half_height(), 0.2, "held at the chest")
	carrier.throw()
	assert_false(pot.carried)
	await wait_seconds(2.0)
	var flat := Vector2(pot.global_position.x, pot.global_position.z)
	assert_gt(flat.length(), 3.0, "a tossed pot lands >= 3 m away (got %.2f)" % flat.length())


func test_place_sets_it_down_on_top_of_another() -> void:
	var holder := _holder()
	var below := _prop(&"crate", Vector3(0, 0, -1.2))
	var top := _prop(&"crate", Vector3(3, 0, 0))
	await wait_seconds(0.5)
	var carrier := PropCarrier.for_body(holder)
	carrier.pick_up(top)
	carrier.place()
	await wait_seconds(1.0)
	assert_gt(top.global_position.y, below.global_position.y + 0.4, "stacked, not inside")


func test_push_moves_a_crate() -> void:
	var crate := _prop(&"crate", Vector3.ZERO)
	await wait_physics_frames(5)
	for i in 60:
		PropCarrier.push(crate, Vector3.FORWARD, 1.0 / 60.0)
		await wait_physics_frames(1)
	assert_gt(-crate.global_position.z, 0.5, "a second of shoving moves a crate >= 0.5 m")


func test_field_wakes_near_and_sleeps_far() -> void:
	var placements := PropPlacements.new()
	var layer := ScatterLayer.new()
	layer.id = &"bucket"
	for x in [0.0, 2.0, 4.0, 60.0]:
		layer.add(Vector3(x, 0, 0), 0.0, 1.0)
	placements.layers.append(layer)
	var field := PropField.new()
	field.player = _root
	field.placements = placements
	_root.add_child(field)
	field.set_physics_process(false)
	assert_eq(field.count(), 4)
	field.update_for(Vector3.ZERO)
	assert_eq(field.active_count(), 3, "only the near ones are bodies")
	assert_eq(field.draw_calls(), 1 + 3)
	field.update_for(Vector3(0, 0, 500))
	assert_eq(field.active_count(), 0, "far away they go back to the MultiMesh")


func _holder() -> CharacterBody3D:
	var b := CharacterBody3D.new()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	col.shape = cap
	col.position.y = 0.8
	b.add_child(col)
	b.collision_layer = 1 << 1
	_root.add_child(b)
	return b


func _prop(id: StringName, at: Vector3) -> Prop:
	var p := Prop.make(PropPlacements.prop_data(id))
	_root.add_child(p)
	p.global_position = at
	return p
