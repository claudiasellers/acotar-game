extends GutTest

const MANOR := preload("res://data/creatures/spawn/manor_grounds.tres")


func _entry(start: float, end: float) -> SpawnEntry:
	var e := SpawnEntry.new()
	e.id = &"t"
	e.start_hour = start
	e.end_hour = end
	return e


func test_hours_wrap_midnight() -> void:
	var night := _entry(20.0, 5.0)
	assert_true(night.active_at(23.0))
	assert_true(night.active_at(2.0))
	assert_false(night.active_at(12.0))
	assert_true(_entry(0.0, 0.0).active_at(13.0), "equal hours means all day")


func test_flags_and_glamour_gate_entries() -> void:
	var e := _entry(0.0, 0.0)
	e.require_flags = PackedStringArray(["wall_crossed"])
	e.glamour = SpawnEntry.Glamour.GLAMOURED_ONLY
	var none := func(_f: String) -> bool: return false
	var all := func(_f: String) -> bool: return true
	assert_false(e.allowed(10.0, none, false))
	assert_true(e.allowed(10.0, all, false))
	assert_false(e.allowed(10.0, all, true), "glamoured-only things vanish once it lifts")


func test_positions_are_seeded_and_inside_bounds() -> void:
	var s := CreatureSpawner.new()
	s.bounds = Rect2(100, 200, 50, 40)
	s.height_func = func(_x: float, _z: float) -> float: return 3.0
	var e := _entry(0.0, 0.0)
	e.count = 4
	e.groups = 3
	var a := s.positions_for(e, 0)
	var b := s.positions_for(e, 0)
	assert_eq(a.size(), 12)
	assert_eq(a, b, "same seed, same layout")
	for p in a:
		assert_true(s.bounds.has_point(Vector2(p.x, p.z)))
		assert_almost_eq(p.y, 3.2, 0.001)
	s.free()


func test_spawner_follows_the_clock() -> void:
	WorldState.clear()
	var s := CreatureSpawner.new()
	s.table = MANOR
	s.bounds = Rect2(-20, -20, 40, 40)
	s.height_func = func(_x: float, _z: float) -> float: return 0.0
	Clock.time_of_day = 12.0 / 24.0
	add_child_autofree(s)
	assert_true(s.spawned.has(&"butterflies_roses"))
	assert_false(s.spawned.has(&"faelights_gardens"))
	Clock.time_of_day = 22.0 / 24.0
	s.refresh()
	assert_false(s.spawned.has(&"butterflies_roses"), "butterflies leave at dusk")
	assert_eq((s.spawned[&"faelights_gardens"] as Array).size(), 4)
	Clock.time_of_day = 0.3


func test_every_table_loads_with_scenes() -> void:
	for region in ["manor_grounds", "border_woods", "eastern_woods", "starlight_glen", "solstice_meadow", "blossom_vale", "rosewild"]:
		var t := load("res://data/creatures/spawn/%s.tres" % region) as CreatureSpawnTable
		assert_not_null(t, region)
		assert_gte(t.entries.size(), 6, region)
		for e in t.entries:
			assert_not_null(e.scene, "%s/%s" % [region, e.id])
