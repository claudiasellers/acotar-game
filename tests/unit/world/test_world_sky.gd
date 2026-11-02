# gate: needs:terrain
extends GutTest
## The World scene's sky is the painted sky (clouds), not the plain procedural one.


func test_the_world_sky_is_the_painted_sky() -> void:
	var scene := load("res://world/shared/world/world.tscn") as PackedScene
	var world := scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	var env := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var mat := env.sky.sky_material as ShaderMaterial
	assert_not_null(mat, "a ShaderMaterial sky")
	assert_eq(mat.shader.resource_path, "res://world/shared/grades/painted_sky.gdshader")
	assert_eq(env.sky.process_mode, Sky.PROCESS_MODE_INCREMENTAL, "drifting clouds update the sky cheaply")
	world.free()
