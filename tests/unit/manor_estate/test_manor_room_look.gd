## The château pass (experience bar §2.6) and the dread response (§1.5):
## boiserie in state rooms, painted skies in grand ones, one lit hero per room,
## a mirrored dressing room, and lights that dim and cool under dread.
extends GutTest

static var _rooms: Dictionary = {}


func before_all() -> void:
	if not _rooms.is_empty():
		return
	for layout in ManorHouseBuilder.load_layouts():
		for r: ManorRoomDef in layout.rooms:
			_rooms["%s@%d" % [r.id, r.level]] = r


func _find(id: StringName) -> Array:
	return _rooms.values().filter(func(r: ManorRoomDef) -> bool: return r.id == id)


func test_every_hero_names_a_placed_prop() -> void:
	var bad := []
	for id: StringName in ManorRoomLook.HERO:
		var found := _find(id)
		if found.is_empty():
			bad.append("%s: no such room" % id)
			continue
		if found.all(func(r: ManorRoomDef) -> bool: return ManorRoomLook.hero_of(r) == null):
			bad.append("%s: %s not placed" % [id, ManorRoomLook.HERO[id]])
	assert_eq(bad.size(), 0, "%s" % [bad])


func test_every_state_room_has_one_hero() -> void:
	var missing := []
	for r: ManorRoomDef in _rooms.values():
		if ManorRoomLook.is_state_room(r) and r.kind == &"room" and r.props.size() >= 4 and ManorRoomLook.hero_of(r) == null:
			missing.append(r.id)
	assert_eq(missing.size(), 0, "state rooms without a hero: %s" % [missing])


func test_walls_and_ceilings_follow_the_room() -> void:
	var states := 0
	for r: ManorRoomDef in _rooms.values():
		var m := ManorRoomLook.wall_material(r)
		if ManorRoomLook.is_state_room(r):
			states += 1
			assert_true(m is ShaderMaterial and (m as ShaderMaterial).shader == ManorRoomLook.BOISERIE, "%s boiserie" % r.id)
		else:
			assert_true(m is StandardMaterial3D, "%s plain plaster" % r.id)
	assert_gte(states, 30, "state rooms")
	for id: StringName in ManorRoomLook.SKY_ROOMS:
		var found := _find(id)
		assert_false(found.is_empty(), "sky room %s exists" % id)
		var plain := StandardMaterial3D.new()
		var m := ManorRoomLook.ceiling_material(found[0], plain)
		assert_ne(m, plain, "%s gets a painted sky" % id)
	assert_eq(ManorRoomLook.wall_material(_find(&"svc_kitchen")[0]).get_class(), "StandardMaterial3D")


func test_hero_light_aims_down_at_the_hero() -> void:
	var r: ManorRoomDef = _find(&"dining_hall")[0]
	var node := Node3D.new()
	var origin := Vector3(r.rect.position.x, 0.0, r.rect.position.y)
	var light := ManorRoomLook.add_hero_light(node, r, origin, 4.5)
	assert_not_null(light)
	var hero := ManorRoomLook.hero_of(r)
	var target := origin + hero.position + Vector3(0, PropLib.size_of(hero.prop_id).y * 0.5, 0)
	var forward := -light.transform.basis.z
	assert_gt(forward.dot((target - light.position).normalized()), 0.999, "points at the hero")
	assert_gt(light.position.y, 3.5, "hangs from the ceiling")
	assert_false(light.shadow_enabled)
	assert_gt(light.light_energy, 1.6, "brighter than a chandelier")
	node.free()


func test_dressing_room_is_a_jewel_box() -> void:
	var r: ManorRoomDef = _find(&"dressing_room")[0]
	var mirrors := r.props.filter(func(p: ManorPropPlacement) -> bool: return String(p.prop_id).contains("mirror"))
	assert_gte(mirrors.size(), 8, "mirror wall plus cheval mirrors")
	assert_true(ManorRoomLook.has_sky(r))
	assert_eq(ManorRoomLook.hero_of(r).prop_id, &"vanity_table")


func test_lights_dim_and_cool_under_dread_then_recover() -> void:
	var house := Node3D.new()
	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.0
	lamp.light_color = Color(1.0, 0.8, 0.7)
	house.add_child(lamp)
	var mood := ManorMoodLights.new()
	house.add_child(mood)
	mood.collect()
	assert_eq(mood.light_count(), 1)
	mood._on_mood_requested(&"dread", 1.0, 1.0)
	mood._process(1.0)
	assert_almost_eq(lamp.light_energy, 2.0 * ManorMoodLights.DIM, 0.001)
	assert_lt(lamp.light_color.r, 0.95, "cools")
	mood._on_mood_requested(&"calm", 0.0, 0.5)
	mood._process(0.5)
	assert_almost_eq(lamp.light_energy, 2.0, 0.001)
	house.free()
