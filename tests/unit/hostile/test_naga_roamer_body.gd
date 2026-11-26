## A NagaRoamer in the tree: throat arrows, frost, a wound that engages it,
## the camp alert. The canon naga scene is untouched (separate file).
extends GutTest

const ROAMER := preload("res://creatures/hostile/naga_roamer.tscn")


func _roamer() -> NagaRoamer:
	var n := ROAMER.instantiate() as NagaRoamer
	add_child_autofree(n)
	return n


func _arrow_at(height: float, arrow_id: StringName = &"wood") -> Node3D:
	var a := Node3D.new()
	a.set_meta(&"arrow_id", arrow_id)
	add_child_autofree(a)
	a.global_position = Vector3(0, height, 0)
	return a


func test_two_throat_arrows_kill() -> void:
	var n := _roamer()
	var throat := _arrow_at(n.global_position.y + n.data.body_height * 0.9)
	n.on_arrow_hit(throat)
	assert_true(n.alive)
	n.on_arrow_hit(throat)
	assert_false(n.alive, "two to the throat")


func test_six_body_arrows_kill() -> void:
	var n := _roamer()
	var body := _arrow_at(n.global_position.y + 0.8)
	for i in 5:
		n.on_arrow_hit(body)
	assert_true(n.alive)
	n.on_arrow_hit(body)
	assert_false(n.alive)


func test_frost_slows_for_ten_seconds_times_its_row() -> void:
	var n := _roamer()
	n.on_arrow_effect(&"frost", _arrow_at(1.0, &"frost"))
	assert_almost_eq(n.slowed_left, 10.0 * HostileElements.WEAK, 0.5, "the naga is weak to rime (plan §7)")


func test_a_wound_wakes_it_fully() -> void:
	var n := _roamer()
	n.on_arrow_hit(_arrow_at(0.8))
	assert_gte(n.senses.awareness, HostileLadder.ENGAGE_AT)


func test_camp_alert_sends_it_searching() -> void:
	var n := _roamer()
	n.on_camp_alert(Vector3(10, 0, 0))
	assert_gte(n.senses.awareness, HostileLadder.SEARCH_AT)
	assert_lt(n.senses.awareness, HostileLadder.ENGAGE_AT)


func test_death_takes_its_dread_with_it() -> void:
	var n := _roamer()
	assert_not_null(n.get_node_or_null(^"DreadField"))
	n.die(&"arrow_ash")
	await get_tree().process_frame
	assert_null(n.get_node_or_null(^"DreadField"))
