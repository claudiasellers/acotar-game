extends GutTest
## The cast lane's models stand in for the main cast wherever a placeholder was.


func test_family_members_wear_their_cast_models() -> void:
	for id in [&"nesta", &"elain", &"father"]:
		var member := FamilyMember.new()
		member.member_id = id
		add_child_autofree(member)
		var body := member.get_node_or_null(^"Body")
		assert_not_null(body)
		assert_true(body.has_method(&"play_locomotion"), "%s is the cast model, not a capsule" % id)
		member.go_to(member.global_position + Vector3(0, 0, -3))
		member._process(0.1)
		var anim: AnimationPlayer = body.get(&"anim")
		assert_not_null(anim, "%s has clips" % id)


func test_story_figures_use_cast_models_and_others_stay_capsules() -> void:
	var lucien := StandIns.figure("lucien")
	assert_true(lucien.has_method(&"play_locomotion"))
	var alis := StandIns.figure("alis")
	assert_false(alis.has_method(&"play_locomotion"), "no model for Alis yet")
	lucien.free()
	alis.free()


func test_the_beast_roars_as_the_door_breaks() -> void:
	var beast := BeastActor.new()
	add_child_autofree(beast)
	var model := beast.get_node(^"Model")
	assert_true(model.has_method(&"play"), "the cast beast, not the composite")
	beast.break_door()
	var anim: AnimationPlayer = model.get(&"anim")
	assert_eq(anim.current_animation, "roar")
	var standin := StandIns.beast()
	assert_true(standin.has_method(&"play"))
	standin.free()


func test_the_beast_is_solid_while_seen() -> void:
	var beast := BeastActor.new()
	add_child_autofree(beast)
	assert_not_null(beast.body)
	var box := (beast.body.get_child(0) as CollisionShape3D).shape as BoxShape3D
	assert_between(box.size.y, 1.2, 2.1, "about withers height, horns left out")
	assert_gt(box.size.z, box.size.x, "longer than wide, like a horse")
	assert_eq(beast.body.collision_layer, 1, "the world layer Feyre collides with")
