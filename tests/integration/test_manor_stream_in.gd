## act1-fixlist F16 follow-up: the manor rebuilt its stand-in terrain (~11.5 s
## on the main thread) on every stream-in, although the World frees it when
## Terrain3D is up, and re-merged the house's meshes (~2 s) each time.
extends GutTest

## Done-when bar: the manor's own stream-in under 3 s on cloud CPU when she
## comes back to it (F16: home from the Bogge hunt).
const MAX_STREAM_IN_MSEC := 3000
const MANOR := "res://world/spring_court/manor_estate/manor_estate.tscn"


func test_under_the_world_terrain_the_manor_streams_in_without_a_fallback() -> void:
	if not TerrainSetup.available():
		pending("Terrain3D extension not loaded")
		return
	var world := (load("res://world/shared/world/world.tscn") as PackedScene).instantiate() as World
	add_child_autofree(world)
	assert_true(ManorTerrain.world_terrain_active(get_tree()), "Terrain3D up")
	var scene := load(MANOR) as PackedScene
	var first := _stream_in(scene, world)
	first[0].free()  # streamed out for the hunt
	var again := _stream_in(scene, world)
	var manor: Node = again[0]
	gut.p("manor streamed in under the World in %d ms, %d ms coming back" % [first[1], again[1]])
	assert_lt(again[1], MAX_STREAM_IN_MSEC)
	assert_null(manor.get_node_or_null(^"TerrainFallback"), "no stand-in built")
	assert_not_null(manor.get_node_or_null(^"House/Shell/Merged"), "the house shell is there")


func _stream_in(scene: PackedScene, world: World) -> Array:
	var t := Time.get_ticks_msec()
	var manor := scene.instantiate()
	world.regions.add_child(manor)
	return [manor, Time.get_ticks_msec() - t]


func test_without_terrain3d_the_fallback_is_built_once_and_reused() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	ManorTerrain.build_fallback(host)  # first stream-in (or already cached)
	var t := Time.get_ticks_msec()
	var again := ManorTerrain.build_fallback(host)
	var msec := Time.get_ticks_msec() - t
	gut.p("second fallback in %d ms" % msec)
	assert_lt(msec, 500)
	assert_gt(again.get_child_count(), 1, "chunks and collider")
	assert_not_null(again.get_node_or_null(^"Collider"))
