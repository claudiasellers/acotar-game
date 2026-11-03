extends SceneTree
## Render program T2: renders one lit sphere per surface shader into
## <out_dir>/<name>.png so two checkouts can be compared (compile errors print too).
##   xvfb-run godot --path . -s tools/render/shader_swatches.gd -- <out_dir>

const SHADERS := [
	"res://world/spring_court/manor_estate/props/prop_finish.gdshader",
	"res://world/spring_court/manor_estate/props/prop_finish_clear.gdshader",
	"res://world/spring_court/manor_estate/scatter/manor_item.gdshader",
	"res://world/spring_court/wider/fx/shaders/court_prop.gdshader",
	"res://world/spring_court/wider/fx/shaders/court_foliage.gdshader",
	"res://world/spring_court/shared/woods_foliage.gdshader",
	"res://world/spring_court/shared/woods_foliage_hero.gdshader",
	"res://world/shared/shaders/stylized_foliage.gdshader",
	"res://world/spring_court/manor_estate/house/boiserie.gdshader",
	"res://world/spring_court/manor_estate/house/manor_floor.gdshader",
	"res://world/spring_court/manor_estate/house/marble_floor.gdshader",
	"res://world/spring_court/manor_estate/house/plaster_ceiling.gdshader",
	"res://world/spring_court/manor_estate/house/sky_ceiling.gdshader",
	"res://world/spring_court/manor_estate/house/facade/facade_slate.gdshader",
	"res://world/spring_court/manor_estate/house/facade/facade_stone.gdshader",
	"res://world/spring_court/manor_estate/house/facade/facade_window.gdshader",
	"res://characters/feyre/feyre_skin.gdshader",
	"res://creatures/materials/fur.gdshader",
	"res://characters/alis/true_form/bark_skin.gdshader",
	"res://world/spring_court/shared/woods_water.gdshader",
	"res://world/spring_court/wider/fx/shaders/court_water.gdshader",
	"res://creatures/ambient/unseen_shimmer.gdshader",
	"res://story/film/cutscenes/glamour_veil.gdshader",
	"res://world/shared/shaders/candy_lit.gdshader",
	"res://world/shared/shaders/candy_lit_foliage.gdshader",
	"res://world/shared/shaders/candy_lit_unlit.gdshader",
]


func _init() -> void:
	var out_dir := OS.get_cmdline_user_args()[0]
	RenderingServer.global_shader_parameter_set(&"magic_amount", 1.0)
	var vp := SubViewport.new()
	vp.size = Vector2i(200, 200)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.45, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.5, 0.6)
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 2.4)
	vp.add_child(cam)
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	vp.add_child(mi)
	for path in SHADERS:
		if not ResourceLoader.exists(path):
			continue
		var m := ShaderMaterial.new()
		m.shader = load(path)
		mi.material_override = m
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out_dir.path_join(path.get_file().get_basename() + ".png"))
		print("SWATCH ", path)
	quit()
