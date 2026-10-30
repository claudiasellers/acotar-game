extends GutTest

const FIXTURES := "res://tests/fixtures/regions/region_%s.tscn"

var parent: Node3D


func _region(id: String, center: Vector3, radius: float, neighbors: Array = []) -> RegionDef:
	var region := RegionDef.new()
	region.id = StringName(id)
	region.scene_path = FIXTURES % id
	region.center = center
	region.radius = radius
	region.neighbors = PackedStringArray(neighbors)
	return region


func before_each() -> void:
	parent = Node3D.new()
	add_child_autofree(parent)
	WorldStreamer.synchronous = true
	WorldStreamer.load_margin = 50.0
	WorldStreamer.unload_margin = 100.0
	# a at the origin, b next door and declared a neighbor, c far away.
	WorldStreamer.configure([
		_region("a", Vector3.ZERO, 100.0, ["b"]),
		_region("b", Vector3(400, 0, 0), 100.0),
		_region("c", Vector3(0, 0, 1200), 100.0),
	], parent)


func after_each() -> void:
	WorldStreamer.configure([], null)
	WorldStreamer.synchronous = false


func test_loads_current_region_and_its_neighbors() -> void:
	watch_signals(WorldStreamer)
	WorldStreamer.update_for(Vector3(10, 0, 10))
	assert_true(WorldStreamer.is_loaded(&"a"))
	assert_true(WorldStreamer.is_loaded(&"b"), "neighbor of a")
	assert_false(WorldStreamer.is_loaded(&"c"))
	assert_signal_emitted(WorldStreamer, "region_loaded")
	assert_eq(WorldStreamer.loaded_root(&"a").get_parent(), parent)


func test_region_at_picks_the_containing_region() -> void:
	assert_eq(WorldStreamer.region_at(Vector3(390, 0, 0)).id, &"b")
	assert_null(WorldStreamer.region_at(Vector3(0, 0, 600)))


func test_unload_waits_for_the_hysteresis_margin() -> void:
	WorldStreamer.update_for(Vector3(0, 0, 1150))
	assert_true(WorldStreamer.is_loaded(&"c"))
	# 60 m past c's edge: outside load_margin but inside unload_margin.
	WorldStreamer.update_for(Vector3(0, 0, 1040))
	assert_true(WorldStreamer.is_loaded(&"c"), "kept inside the hysteresis band")
	WorldStreamer.update_for(Vector3(0, 0, 800))
	assert_false(WorldStreamer.is_loaded(&"c"))
