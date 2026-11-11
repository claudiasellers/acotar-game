# gate: needs:terrain
## act1-fixlist F16 follow-up: the manor rebuilt its stand-in terrain (~11.5 s
## on the main thread) on every stream-in, although the World frees it when
## Terrain3D is up, and re-merged the house's meshes (~2 s) each time.
extends GutTest

## T098: asserts what was built, which no load can move: no stand-in terrain
## (+11.5 s) and the house shell reused, not re-merged (+1.2 s CPU). The old
## 4300 ms main-thread CPU bar (T089) still flaked, because CPU per unit of work
## rises with load (2.3-2.85 s measured at load 15-40), so it is now logged and
## only a runaway bound is asserted, far above anything load alone produces.
const RUNAWAY_STREAM_IN_CPU_MSEC := 12000
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
	assert_lt(again[1], RUNAWAY_STREAM_IN_CPU_MSEC, "main-thread CPU ms coming back (runaway bound only)")
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
	var first := ManorTerrain.build_fallback(host)  # first stream-in (or already cached)
	var again := ManorTerrain.build_fallback(host)
	# Reuse is what makes the second one cheap: the very same chunk meshes and
	# collider shape, not new ones (no timing, so load can't move it).
	var reused := 0
	for chunk in first.get_children():
		var twin := again.get_node_or_null(NodePath(chunk.name))
		if chunk is MeshInstance3D:
			assert_not_null(twin, "%s is in the second build" % chunk.name)
			if twin:
				assert_same((twin as MeshInstance3D).mesh, (chunk as MeshInstance3D).mesh, "%s mesh is reused" % chunk.name)
				reused += 1
	assert_gt(reused, 1, "chunks")
	var shape_a := (first.get_node(^"Collider") as StaticBody3D).get_child(0) as CollisionShape3D
	var shape_b := (again.get_node(^"Collider") as StaticBody3D).get_child(0) as CollisionShape3D
	assert_same(shape_b.shape, shape_a.shape, "the collider shape is reused")
