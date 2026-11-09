# gate: needs:terrain
## act1-fixlist F16 follow-up: the manor rebuilt its stand-in terrain (~11.5 s
## on the main thread) on every stream-in, although the World frees it when
## Terrain3D is up, and re-merged the house's meshes (~2 s) each time.
extends GutTest

## Done-when bar: the manor's own stream-in when she comes back to it (F16:
## home from the Bogge hunt). T089: counted in main-thread CPU time, not wall
## time, so waiting for a core can't fail it. Under load (avg 15-40 on the
## Mac's 10 cores) the same stream-in took 3.4-19 s wall and 2.3-2.85 s of
## main-thread CPU; CPU per unit of work still rises with load, so the bar is
## the worst loaded run times 1.5. The known regressions are also checked by
## what was built, which no load can move: the stand-in terrain (+11.5 s) and
## re-merging the house (+1.2 s CPU).
const MAX_STREAM_IN_CPU_MSEC := 4300
const CpuClock := preload("res://tests/fixtures/cpu_clock.gd")
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
	var shell_mesh: Mesh = (first[0].get_node(^"House/Shell/Merged") as MeshInstance3D).mesh
	first[0].free()  # streamed out for the hunt
	var again := _stream_in(scene, world)
	var manor: Node = again[0]
	gut.p("manor streamed in under the World in %d ms CPU (%d ms wall), %d ms CPU (%d ms wall) coming back"
			% [first[1], first[2], again[1], again[2]])
	assert_lt(again[1], MAX_STREAM_IN_CPU_MSEC, "main-thread CPU ms coming back")
	assert_null(manor.get_node_or_null(^"TerrainFallback"), "no stand-in built")
	var shell := manor.get_node_or_null(^"House/Shell/Merged") as MeshInstance3D
	assert_not_null(shell, "the house shell is there")
	if shell:
		assert_same(shell.mesh, shell_mesh, "the house shell is reused, not merged again")


## [manor, main-thread CPU ms, wall ms]. CPU falls back to wall where it can't be read.
func _stream_in(scene: PackedScene, world: World) -> Array:
	var cpu := CpuClock.main_thread_msec()
	var t := Time.get_ticks_msec()
	var manor := scene.instantiate()
	world.regions.add_child(manor)
	var wall := Time.get_ticks_msec() - t
	var used := int(CpuClock.main_thread_msec() - cpu) if cpu >= 0.0 else wall
	return [manor, used, wall]


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
