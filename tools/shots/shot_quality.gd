## Render settings for probe screenshots (contract: docs/contracts/shot_request.md).
## "layout" answers "is the stair where it should be?": small, no shadows, glow,
## fog, screen-space effects, GI, AA or particles, so a software renderer
## draws it in seconds. "full" leaves the scene's own look alone for final
## look checks. Applied again before every shot, since streamed regions bring
## their own lights and particles.
class_name ShotQuality
extends RefCounted

const LAYOUT := &"layout"
const FULL := &"full"
const LAYOUT_SIZE := Vector2i(640, 360)
const FULL_SIZE := Vector2i(1920, 1080)
## Forced draws before the capture. Layout has nothing temporal to settle;
## full keeps the old 30 frames for volumetric fog and GI to converge.
const LAYOUT_SETTLE := 1
const FULL_SETTLE := 30
const FULL_WARMUP_S := 3.0


static func default_size(quality: StringName) -> Vector2i:
	return LAYOUT_SIZE if quality == LAYOUT else FULL_SIZE


static func default_settle(quality: StringName) -> int:
	return LAYOUT_SETTLE if quality == LAYOUT else FULL_SETTLE


## Seconds a look shot keeps running before capture (on a GPU 30 frames
## alone would be half a second, too short for GI and TAA).
static func default_warmup(quality: StringName) -> float:
	return 0.0 if quality == LAYOUT else FULL_WARMUP_S


## Sizes the viewport and, for layout, strips everything expensive under `root`.
static func apply(quality: StringName, viewport: Viewport, root: Node, size: Vector2i) -> void:
	if viewport is Window:
		(viewport as Window).size = size
	elif viewport is SubViewport:
		(viewport as SubViewport).size = size
	if quality != LAYOUT:
		return
	apply_layout_viewport(viewport)
	for env in environments(viewport, root):
		apply_layout_environment(env)
	for node in root.find_children("*", "", true, false):
		apply_layout_node(node)


static func apply_layout_viewport(viewport: Viewport) -> void:
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	viewport.use_debanding = false
	viewport.scaling_3d_scale = 1.0
	viewport.positional_shadow_atlas_size = 0
	viewport.mesh_lod_threshold = 4.0


static func apply_layout_environment(env: Environment) -> void:
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	if env.sky != null:
		env.sky.radiance_size = Sky.RADIANCE_SIZE_32
		env.sky.process_mode = Sky.PROCESS_MODE_QUALITY


static func apply_layout_node(node: Node) -> void:
	if node is Light3D:
		(node as Light3D).shadow_enabled = false
		if node is DirectionalLight3D:
			(node as DirectionalLight3D).light_volumetric_fog_energy = 0.0
	elif node is GPUParticles3D or node is CPUParticles3D:
		(node as Node3D).visible = false
	elif node is VoxelGI or node is ReflectionProbe or node is LightmapGI:
		(node as Node3D).visible = false


## Every Environment that can reach the frame: WorldEnvironment nodes, camera
## overrides and the world's fallback.
static func environments(viewport: Viewport, root: Node) -> Array[Environment]:
	var out: Array[Environment] = []
	for node in root.find_children("*", "WorldEnvironment", true, false):
		var env := (node as WorldEnvironment).environment
		if env != null and not out.has(env):
			out.append(env)
	var cam := viewport.get_camera_3d()
	if cam != null and cam.environment != null and not out.has(cam.environment):
		out.append(cam.environment)
	var world := viewport.find_world_3d()
	if world != null:
		for env in [world.environment, world.fallback_environment]:
			if env != null and not out.has(env):
				out.append(env)
	return out


## Mesa lavapipe (cloud CPU Vulkan) segfaults on two things in the World:
## MSAA, and the Terrain3D clipmap past ~200 m (3+ LODs at mesh_size 48).
## Turn both down so Forward+ shots run in the cloud; Compatibility and real
## GPUs are left alone.
const LAVAPIPE_TERRAIN_LODS := 2


static func on_lavapipe() -> bool:
	return RenderingServer.get_video_adapter_name().contains("llvmpipe") \
		and RenderingServer.get_current_rendering_method() != "gl_compatibility"


static func guard_software_renderer(viewport: Viewport, root: Node) -> void:
	if not on_lavapipe():
		return
	if viewport.msaa_3d != Viewport.MSAA_DISABLED:
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		push_warning("ShotQuality: lavapipe, MSAA off")
	for t in root.find_children("*", "Terrain3D", true, false):
		if int(t.get(&"mesh_lods")) > LAVAPIPE_TERRAIN_LODS:
			t.set(&"mesh_lods", LAVAPIPE_TERRAIN_LODS)
			push_warning("ShotQuality: lavapipe, Terrain3D clamped to %d LODs (terrain ends ~200 m out)" % LAVAPIPE_TERRAIN_LODS)
