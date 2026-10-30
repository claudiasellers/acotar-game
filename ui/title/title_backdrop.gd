## The title screen's living backdrop: the Wall at dusk (Storykeeper's brief).
## The Wall is the plane x = 0. The human side (x > 0, screen left) is a blue-grey snowy
## wood under falling snow, with two golden eyes in the brush; the spring side
## (x < 0, screen right) is meadow, blossom trees and gold haze under a pastel sunset. A
## thorned rose reaches across the line, and Feyre stands at the edge of the
## snow, facing spring. The camera drifts slowly; cross_over() pushes it
## through the Wall for New Game / Continue.
##
## Built in code from existing world assets (fixed seed), MultiMesh per mesh.
class_name TitleBackdrop
extends Node3D

const SEED := 20261030
## Render layers: each side is lit by its own light (cold moon, warm sun);
## the hero layer (Feyre, the rose) takes both, so she gets a warm rim.
const LAYER_SNOW := 1
const LAYER_SPRING := 2
const LAYER_HERO := 4

const FLORA := "res://world/human_realm/shared/assets/flora/"
const COURT := "res://world/spring_court/manor_estate/flora/models/"
const COURT_SHARED := "res://world/spring_court/shared/models/"
const FEYRE_MODEL := "res://characters/feyre/model/feyre_model.tscn"
const HUNTER_PIECES: Array[String] = [
	"res://data/wardrobe/pieces/hunter_tunic.tres",
	"res://data/wardrobe/pieces/hunter_trousers.tres",
	"res://data/wardrobe/pieces/hunter_boots.tres",
	"res://data/wardrobe/pieces/hunter_cloak.tres",
]
const SKY_SHADER := preload("res://ui/title/title_sky.gdshader")
const SHIMMER_SHADER := preload("res://world/human_realm/wall_seam/wall_shimmer.gdshader")
const FLORA_MAT := preload("res://world/shared/materials/stylized_flora.tres")
## Shader globals the backdrop sets; restored to project defaults on exit.
const GLOBALS := {&"snow_cover": 1.0, &"wind_strength": 0.35, &"magic_amount": 0.6}

const CAMERA_FROM := Vector3(2.7, 1.5, -3.6)
const LOOK_AT := Vector3(-1.5, 1.75, 30.0)
const CROSS_TO := Vector3(-1.6, 1.55, 9.5)
const CROSS_LOOK := Vector3(-9.0, 1.9, 26.0)
const FEYRE_AT := Vector3(0.85, 0.0, 7.2)
const EYES_AT := Vector3(6.4, 0.72, 14.0)

var camera: Camera3D
var environment: Environment
## 0 = the title view, 1 = through the Wall into spring.
var cross := 0.0
var _sky: ShaderMaterial
var _time := 0.0
var _eyes: Node3D
var _blink_in := 4.0
var _rng := RandomNumberGenerator.new()
var _winter_mat: ShaderMaterial
var _spring_mat: ShaderMaterial


func _ready() -> void:
	_rng.seed = SEED
	for key: StringName in GLOBALS:
		RenderingServer.global_shader_parameter_set(key, GLOBALS[key])
	_winter_mat = FLORA_MAT.duplicate() as ShaderMaterial
	_winter_mat.set_shader_parameter(&"snow_catch", 0.9)
	# The human side is a cold foil: bark and needles pulled toward blue-grey.
	_winter_mat.set_shader_parameter(&"albedo", Color(0.66, 0.70, 0.86))
	_winter_mat.set_shader_parameter(&"rim_color", Color(0.70, 0.78, 1.0))
	_winter_mat.set_shader_parameter(&"shade_tint", Color(0.42, 0.46, 0.66))
	_spring_mat = FLORA_MAT.duplicate() as ShaderMaterial
	_spring_mat.set_shader_parameter(&"snow_catch", 0.0)
	_spring_mat.set_shader_parameter(&"sparkle", 0.0)
	_build_environment()
	_build_ground()
	_build_trees()
	_build_flora()
	_build_wall()
	_build_rose_reach()
	_build_feyre()
	_build_eyes()
	_build_weather()
	_build_camera()


func _exit_tree() -> void:
	for key: StringName in GLOBALS:
		var entry: Variant = ProjectSettings.get_setting("shader_globals/%s" % key)
		if entry is Dictionary:
			RenderingServer.global_shader_parameter_set(key, (entry as Dictionary).get("value", 0.0))


func _process(delta: float) -> void:
	_time += delta
	_place_camera()
	_blink_in -= delta
	if _blink_in <= 0.0 and _eyes != null:
		_blink_in = _rng.randf_range(5.0, 11.0)
		var tw := create_tween()
		tw.tween_property(_eyes, ^"scale:y", 0.05, 0.07)
		tw.tween_property(_eyes, ^"scale:y", 1.0, 0.09)


## Pushes the camera through the Wall into the spring grade. Returns the tween.
func cross_over(seconds: float = 2.4) -> Tween:
	var tw := create_tween().set_parallel()
	tw.tween_property(self, ^"cross", 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float) -> void: _sky.set_shader_parameter(&"spring_all", v), 0.0, 1.0, seconds * 0.6) \
			.set_delay(seconds * 0.35)
	tw.tween_property(environment, ^"tonemap_exposure", 1.35, seconds).set_ease(Tween.EASE_IN)
	return tw


## Ground height (m) at x, z: soft snow drifts on the human side, a meadow on
## the spring side, and hills rising behind both.
static func height_at(x: float, z: float) -> float:
	var h := 0.18 * sin(x * 0.45 + z * 0.13) + 0.12 * sin(z * 0.37 - x * 0.21)
	h += smoothstep(40.0, 110.0, z) * (6.0 + 3.0 * sin(x * 0.06))
	if x < 0.0:
		h += smoothstep(12.0, 45.0, -x) * 2.5
	else:
		h += smoothstep(14.0, 45.0, x) * 3.5
	return h


# --- build -----------------------------------------------------------------------

func _build_environment() -> void:
	_sky = ShaderMaterial.new()
	_sky.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.35
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.95
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 0.85
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.80, 0.72, 0.88)
	environment.fog_density = 0.004
	environment.fog_sky_affect = 0.1
	environment.fog_aerial_perspective = 0.2
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.18
	environment.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)

	# The human side: a cold low moon-lilac light, no warmth.
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.68, 0.92)
	moon.light_energy = 0.55
	moon.rotation_degrees = Vector3(-38, -150, 0)
	moon.light_cull_mask = LAYER_SNOW | LAYER_HERO
	moon.shadow_enabled = true
	add_child(moon)
	# The spring side: a low gold sun from beyond the Wall (rim on Feyre).
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.86, 0.76)
	sun.light_energy = 1.45
	sun.rotation_degrees = Vector3(-22, -60, 0)
	sun.light_cull_mask = LAYER_SPRING | LAYER_HERO
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _build_ground() -> void:
	add_child(_ground_side(0.0, 60.0, LAYER_SNOW))
	add_child(_ground_side(-60.0, 0.0, LAYER_SPRING))


func _ground_side(x0: float, x1: float, layer: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 1.0
	var nx := int((x1 - x0) / step)
	var nz := int(140.0 / step)
	var spring := x1 <= 0.0
	for iz in nz:
		for ix in nx:
			var quad := [Vector2(ix, iz), Vector2(ix + 1, iz), Vector2(ix + 1, iz + 1), Vector2(ix, iz + 1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var g: Vector2 = quad[k]
				var x := x0 + g.x * step
				var z := -20.0 + g.y * step
				st.set_color(_ground_colour(x, z, spring))
				st.set_uv(Vector2(x, z) * 0.1)
				st.add_vertex(Vector3(x, height_at(x, z), z))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "SpringGround" if spring else "SnowGround"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.9 if spring else 0.55
	if not spring:
		mat.rim_enabled = true
		mat.rim = 0.25
	mi.material_override = mat
	mi.layers = layer
	return mi


func _ground_colour(x: float, z: float, spring: bool) -> Color:
	var n := 0.5 + 0.5 * sin(x * 1.7 + z * 0.9) * sin(z * 1.3 - x * 0.4)
	if spring:
		var moss := Color("#86c896").lerp(Color("#5fae86"), n)
		# Pale gold where the light pools by the line.
		return moss.lerp(Color("#d9ecb4"), clampf(1.0 + x / 6.0, 0.0, 1.0) * 0.3)
	var snow := Color("#c9d0e6").lerp(Color("#a9b2cf"), n * 0.6)
	# Colour bleeds a few inches into the grey at the line.
	return snow.lerp(Color("#d8b8cc"), clampf(1.0 - x / 0.7, 0.0, 1.0) * 0.6)


func _build_trees() -> void:
	var winter: Array[Transform3D] = []
	var winter_far: Array[Transform3D] = []
	var birches: Array[Transform3D] = []
	var snags: Array[Transform3D] = []
	# A framing row of near trunks on the left, then the wood behind.
	for p: Vector2 in [Vector2(4.6, 1.5), Vector2(7.5, 6.0), Vector2(3.4, 11.5), Vector2(9.5, 0.5)]:
		winter.append(_on_ground(p.x, p.y, _rng.randf_range(1.0, 1.25)))
	for i in 140:
		var x := _rng.randf_range(2.4, 48.0)
		var z := _rng.randf_range(4.0, 95.0)
		if absf(x - EYES_AT.x) < 3.0 and absf(z - EYES_AT.z) < 3.0:
			continue
		var t := _on_ground(x, z, _rng.randf_range(0.8, 1.3))
		var r := _rng.randf()
		if z > 50.0:
			winter_far.append(t)
		elif r < 0.55:
			winter.append(t)
		elif r < 0.8:
			birches.append(t)
		else:
			snags.append(t)
	_multimesh(FLORA + "tree_pine.glb", winter, LAYER_SNOW)
	_multimesh(FLORA + "tree_pine_far.glb", winter_far, LAYER_SNOW)
	_multimesh(FLORA + "tree_birch.glb", birches, LAYER_SNOW)
	_multimesh(FLORA + "tree_dead_snag.glb", snags, LAYER_SNOW)

	var blossom: Array[Transform3D] = []
	var apple: Array[Transform3D] = []
	var lilac: Array[Transform3D] = []
	var silver: Array[Transform3D] = []
	for i in 110:
		var x := _rng.randf_range(-50.0, -3.0)
		var z := _rng.randf_range(10.0, 100.0)
		# Keep a clear vista down the line toward the hills.
		if x > -9.0 and z < 40.0 and _rng.randf() < 0.7:
			continue
		var t := _on_ground(x, z, _rng.randf_range(0.9, 1.5))
		var r := _rng.randf()
		if r < 0.4:
			blossom.append(t)
		elif r < 0.65:
			apple.append(t)
		elif r < 0.85:
			lilac.append(t)
		else:
			silver.append(t)
	_multimesh(COURT + "cherry_blossom.glb", blossom, LAYER_SPRING)
	_multimesh(COURT + "apple_blossom.glb", apple, LAYER_SPRING)
	_multimesh(COURT_SHARED + "lilac_tree.glb", lilac, LAYER_SPRING)
	_multimesh(COURT_SHARED + "silver_birch.glb", silver, LAYER_SPRING)


func _build_flora() -> void:
	# Spring: drifts of crocus and snowdrops thickest at the line, moss, roses.
	var crocus: Array[Transform3D] = []
	var snowdrop: Array[Transform3D] = []
	var moss: Array[Transform3D] = []
	var roses: Array[Transform3D] = []
	var white_roses: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	for drift in 70:
		var cx := -0.2 - pow(_rng.randf(), 2.0) * 22.0
		var cz := _rng.randf_range(0.0, 55.0)
		var n := _rng.randi_range(8, 30)
		for i in n:
			var x := minf(-0.08, cx + _rng.randfn(0.0, 0.9))
			var z := cz + _rng.randfn(0.0, 1.2)
			var t := _on_ground(x, z, _rng.randf_range(1.6, 2.6))
			(crocus if _rng.randf() < 0.7 else snowdrop).append(t)
	for i in 160:
		moss.append(_on_ground(_rng.randf_range(-18.0, -0.1), _rng.randf_range(-2.0, 50.0), _rng.randf_range(0.8, 1.6)))
	for i in 26:
		var t := _on_ground(_rng.randf_range(-14.0, -1.2), _rng.randf_range(8.0, 45.0), _rng.randf_range(0.8, 1.2))
		(roses if _rng.randf() < 0.7 else white_roses).append(t)
	for i in 30:
		ferns.append(_on_ground(_rng.randf_range(-20.0, -4.0), _rng.randf_range(10.0, 50.0), _rng.randf_range(0.8, 1.2)))
	_multimesh(COURT + "crocus.glb", crocus, LAYER_SPRING)
	_multimesh(FLORA + "snowdrop_cluster.glb", snowdrop, LAYER_SPRING)
	_multimesh(COURT + "starmoss.glb", moss, LAYER_SPRING)
	_multimesh(COURT + "rose_pink.glb", roses, LAYER_SPRING)
	_multimesh(COURT + "rose_white.glb", white_roses, LAYER_SPRING)
	_multimesh(COURT + "fern.glb", ferns, LAYER_SPRING)

	# Winter: drifts and bare thorn brush (where the eyes hide).
	var mounds: Array[Transform3D] = []
	var thorn: Array[Transform3D] = []
	for i in 60:
		var mz := _rng.randf_range(2.0, 50.0)
		mounds.append(_on_ground(_rng.randf_range(0.6, 30.0), mz, _rng.randf_range(0.5, 0.9 + mz * 0.03)))
	for i in 18:
		thorn.append(_on_ground(_rng.randf_range(3.0, 24.0), _rng.randf_range(8.0, 45.0), _rng.randf_range(0.9, 1.4)))
	for o: Vector2 in [Vector2(-0.6, 0.35), Vector2(0.7, 0.2), Vector2(0.0, 0.6)]:
		thorn.append(_on_ground(EYES_AT.x + o.x, EYES_AT.z + o.y, 1.3))
	_multimesh(FLORA + "snow_mound.glb", mounds, LAYER_SNOW)
	_multimesh(FLORA + "blackthorn_sloe.glb", thorn, LAYER_SNOW)
	# A dark young spruce makes the hollow the eyes look out of.
	var hollow: Array[Transform3D] = [_on_ground(EYES_AT.x + 0.3, EYES_AT.z + 0.9, 0.32), _on_ground(EYES_AT.x - 0.8, EYES_AT.z + 0.6, 0.26)]
	_multimesh(FLORA + "tree_spruce.glb", hollow, LAYER_SNOW)


## The Wall: a barely-there haze standing on the line, running away from camera.
func _build_wall() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHIMMER_SHADER
	mat.set_shader_parameter(&"base_alpha", 0.06)
	mat.set_shader_parameter(&"near", 0.7)
	mat.set_shader_parameter(&"distortion", 0.004)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 4.0
	var z := -6.0
	while z < 120.0:
		var za := z
		var zb := z + seg
		var ya := height_at(0.0, za) - 1.0
		var yb := height_at(0.0, zb) - 1.0
		for v: Vector3 in [Vector3(za, ya, 1), Vector3(zb, yb, 1), Vector3(zb, yb + 40.0, 0), Vector3(za, ya, 1), Vector3(zb, yb + 40.0, 0), Vector3(za, ya + 40.0, 0)]:
			st.set_uv(Vector2(v.x / 120.0, v.z))
			st.add_vertex(Vector3(0.0, v.y, v.x))
		z = zb
	var mi := MeshInstance3D.new()
	mi.name = "WallHaze"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Thorns and roses: a wild briar straddles the line, blooms on the spring
## side and one reaching over into the snow.
func _build_rose_reach() -> void:
	var briar := _instance(FLORA + "wild_rose_briar.glb")
	if briar != null:
		briar.name = "RoseReach"
		briar.position = Vector3(-0.35, height_at(-0.35, 9.0), 9.0)
		briar.rotation.y = deg_to_rad(25.0)
		briar.scale = Vector3.ONE * 1.15
		_set_layers(briar, LAYER_HERO)
		_set_material(briar, _spring_mat)
		add_child(briar)
	for spot: Vector4 in [Vector4(-1.0, 9.6, 1.0, 0.0), Vector4(-1.6, 8.2, 0.8, 1.0), Vector4(0.35, 8.7, 0.55, 2.0)]:
		var bush := _instance(COURT + "rose_pink.glb")
		if bush == null:
			continue
		bush.position = Vector3(spot.x, height_at(spot.x, spot.y), spot.y)
		bush.rotation.y = spot.w
		bush.scale = Vector3.ONE * spot.z
		_set_layers(bush, LAYER_HERO)
		_set_material(bush, _spring_mat)
		add_child(bush)


## Feyre from behind at the edge of the snow, in her hunter's cloak, facing spring.
func _build_feyre() -> void:
	if not ResourceLoader.exists(FEYRE_MODEL):
		return
	var feyre := (load(FEYRE_MODEL) as PackedScene).instantiate() as Node3D
	feyre.name = "Feyre"
	feyre.position = Vector3(FEYRE_AT.x, height_at(FEYRE_AT.x, FEYRE_AT.z), FEYRE_AT.z)
	var facing := Vector3(-1.0, 0.0, 0.5)
	feyre.rotation.y = atan2(-facing.x, -facing.z)
	add_child(feyre)
	_dress(feyre)
	_set_layers(feyre, LAYER_HERO)


func _dress(model: Node3D) -> void:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	var skeleton := found[0] as Skeleton3D
	var hidden: Array[StringName] = []
	for path in HUNTER_PIECES:
		var piece := load(path) as WardrobePiece
		if piece == null or not ResourceLoader.exists(piece.mesh_path):
			continue
		hidden.append_array(piece.hides_body_regions)
		var inst := (load(piece.mesh_path) as PackedScene).instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var copy := MeshInstance3D.new()
			copy.mesh = (mi as MeshInstance3D).mesh
			copy.skin = (mi as MeshInstance3D).skin
			copy.set_meta(&"wardrobe", true)
			model.add_child(copy)
			copy.global_transform = skeleton.global_transform
			copy.skeleton = copy.get_path_to(skeleton)
			var base := copy.mesh.surface_get_material(0)
			var m: BaseMaterial3D = base.duplicate() if base is BaseMaterial3D else StandardMaterial3D.new()
			m.albedo_color = piece.color
			copy.set_surface_override_material(0, m)
		inst.free()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		if mesh_instance.has_meta(&"wardrobe") or not (mesh_instance.mesh is ArrayMesh):
			continue
		var mesh := mesh_instance.mesh as ArrayMesh
		for s in mesh.get_surface_count():
			if hidden.has(StringName(mesh.surface_get_name(s))):
				var clear := StandardMaterial3D.new()
				clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				clear.albedo_color = Color(0, 0, 0, 0)
				mesh_instance.set_surface_override_material(s, clear)


## Two golden eyes deep in the snowy brush. They blink, and are never explained.
func _build_eyes() -> void:
	_eyes = Node3D.new()
	_eyes.name = "Eyes"
	_eyes.position = EYES_AT
	_eyes.look_at_from_position(EYES_AT, CAMERA_FROM, Vector3.UP)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.32)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.3)
	mat.emission_energy_multiplier = 14.0
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.06
	for dx: float in [-0.08, 0.08]:
		var eye := MeshInstance3D.new()
		eye.mesh = sphere
		eye.material_override = mat
		eye.position = Vector3(dx, 0.0, 0.0)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_eyes.add_child(eye)
	add_child(_eyes)


func _build_weather() -> void:
	# Snow on the human side only; it stops at the line.
	add_child(_particles("Snow", 2400, 9.0, Vector3(16.0, 9.0, 24.0), Vector3(15.6, 3.0, 30.0),
			Vector3(0.05, -1.0, 0.0), 0.8, Vector3(0.08, -0.35, 0.0), Color(0.94, 0.96, 1.0, 0.95), 0.075, LAYER_SNOW, false))
	# Petals drift down on the spring side; a few cross into the snow.
	add_child(_particles("Petals", 260, 12.0, Vector3(-8.0, 7.0, 20.0), Vector3(8.5, 3.0, 22.0),
			Vector3(0.35, -0.4, 0.05), 0.5, Vector3(0.05, -0.12, 0.0), Color(1.0, 0.78, 0.86, 0.95), 0.09, LAYER_SPRING, false))
	# Gold motes hang in the spring haze.
	add_child(_particles("Motes", 140, 8.0, Vector3(-6.0, 2.2, 16.0), Vector3(6.0, 1.6, 14.0),
			Vector3(0.0, 0.15, 0.0), 0.15, Vector3.ZERO, Color(1.0, 0.9, 0.6, 1.0), 0.04, LAYER_SPRING, true))


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 52.0
	camera.near = 0.05
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	_place_camera()


func _place_camera() -> void:
	if camera == null:
		return
	var drift := Vector3(sin(_time * 0.07) * 0.5, sin(_time * 0.05) * 0.1, sin(_time * 0.045) * 0.7)
	var e := cross * cross * (3.0 - 2.0 * cross)
	var pos := (CAMERA_FROM + drift).lerp(CROSS_TO, e)
	var look := (LOOK_AT + Vector3(sin(_time * 0.06) * 0.8, 0.0, 0.0)).lerp(CROSS_LOOK, e)
	camera.look_at_from_position(pos, look, Vector3.UP)


# --- helpers -----------------------------------------------------------------------

func _on_ground(x: float, z: float, s: float) -> Transform3D:
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
	return Transform3D(basis, Vector3(x, height_at(x, z) - 0.05, z))


func _instance(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


## One MultiMeshInstance3D from the first (near) mesh in a glb.
func _multimesh(path: String, transforms: Array[Transform3D], layer: int) -> void:
	if transforms.is_empty() or not ResourceLoader.exists(path):
		return
	var scene := (load(path) as PackedScene).instantiate()
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		scene.free()
		return
	var src := meshes[0] as MeshInstance3D
	var local := src.transform
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = src.mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i] * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = path.get_file().get_basename()
	mmi.multimesh = mm
	mmi.layers = layer
	mmi.material_override = _spring_mat if layer == LAYER_SPRING else _winter_mat
	add_child(mmi)
	scene.free()


func _set_material(root: Node, mat: Material) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = mat


func _set_layers(root: Node, layer: int) -> void:
	for n in root.find_children("*", "VisualInstance3D", true, false):
		(n as VisualInstance3D).layers = layer
	if root is VisualInstance3D:
		(root as VisualInstance3D).layers = layer


func _particles(id: String, amount: int, lifetime: float, centre: Vector3, extents: Vector3,
		direction: Vector3, speed: float, gravity: Vector3, color: Color, size: float,
		layer: int, glow: bool) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = direction.normalized()
	pm.spread = 25.0
	pm.initial_velocity_min = speed * 0.6
	pm.initial_velocity_max = speed * 1.2
	pm.gravity = gravity
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.12, Color(1, 1, 1, 1))
	fade.add_point(0.85, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.albedo_texture = PauseStyle.soft_dot(32)
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size * (0.6 if id == "Petals" else 1.0))
	quad.material = mat
	var p := GPUParticles3D.new()
	p.name = id
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.process_material = pm
	p.draw_pass_1 = quad
	p.position = centre
	p.visibility_aabb = AABB(-extents - Vector3.ONE * 10.0, (extents + Vector3.ONE * 10.0) * 2.0)
	p.layers = layer
	return p
