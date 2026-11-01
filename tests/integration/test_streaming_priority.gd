## act1-fixlist F16: back from the Bogge hunt the manor took 97 s to stream in,
## queued behind 7 other regions. The region she arrives in loads first.
extends GutTest

## Done-when bar: her region is in within a few seconds of what it takes to
## build on its own, whatever else is queued. (The manor's own build is ~15 s
## on cloud CPU, mostly its fallback terrain; that is the manor's to cut.)
const MAX_QUEUE_MSEC := 3000

var parent: Node3D


func before_each() -> void:
	parent = Node3D.new()
	add_child_autofree(parent)
	WorldStreamer.synchronous = false


func after_each() -> void:
	WorldStreamer.track(null)
	WorldStreamer.configure([], null)
	await wait_frames(2)


func _build_alone_msec(path: String) -> int:
	var scene := load(path) as PackedScene
	var t := Time.get_ticks_msec()
	var root := scene.instantiate()
	parent.add_child(root)
	var msec := Time.get_ticks_msec() - t
	root.free()
	return msec


func test_back_from_the_bogge_hunt_the_manor_lands_first() -> void:
	var alone := _build_alone_msec("res://world/spring_court/manor_estate/manor_estate.tscn")
	WorldStreamer.configure_from_tree("res://data/regions", parent)
	var manor := WorldStreamer.get_region(&"manor_estate")
	var hunt := Vector3(BorderWoodsTerrain.BOGGE_HUNT.x, 0.0, BorderWoodsTerrain.BOGGE_HUNT.y)
	# Everything the hunt wants is queued when she jumps home.
	WorldStreamer.update_for(hunt)
	var wanted := WorldStreamer.wanted_at(hunt)
	var order: Array[StringName] = []
	var log_order := func(id: StringName, _root: Node3D) -> void: order.append(id)
	WorldStreamer.region_loaded.connect(log_order)
	var t := Time.get_ticks_msec()
	WorldStreamer.update_for(manor.center)
	await wait_until(func() -> bool: return WorldStreamer.is_loaded(&"manor_estate"), 120.0)
	var msec := Time.get_ticks_msec() - t
	WorldStreamer.region_loaded.disconnect(log_order)
	gut.p("manor in after %d ms, %d ms on its own (%d regions wanted at the hunt); landed: %s" % [msec, alone, wanted.size(), order])
	assert_true(WorldStreamer.is_loaded(&"manor_estate"))
	assert_lt(msec, alone + MAX_QUEUE_MSEC, "no more than a few seconds over its own build")
	assert_lte(order.size(), 2, "at most the one load already in flight landed before it")
