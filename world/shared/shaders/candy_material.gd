@tool
class_name CandyMaterial
extends ShaderMaterial
## The candy_lit surface with BaseMaterial3D's property names (render program
## T2), so code that used to build a stock material keeps working line for line
## and imported glb materials keep their colours. Build one with
## MaterialLibrary.surface() or MaterialLibrary.get_material(kind).
##
## Colour/number properties live in the shader parameters (saved by
## ShaderMaterial itself). The render flags pick a shader variant: a committed
## file under candy/ when one exists, else a shader built once per session.

const SURFACE_INC := "res://world/shared/shaders/candy_surface.gdshaderinc"
const DEFAULT_SHADER := "res://world/shared/shaders/candy_lit.gdshader"
const VARIANT_DIR := "res://world/shared/shaders/candy/"
## Glare rule (L18-4): the most a lit candy surface reflects per channel (hex D9).
## candy_surface applies it to the final albedo (colour x texture x vertex colour).
const MAX_ALBEDO := 0.85

static var _variants: Dictionary = {}

@export_storage var transparency: BaseMaterial3D.Transparency = BaseMaterial3D.TRANSPARENCY_DISABLED:
	set(v):
		transparency = v
		_rebuild()
@export_storage var shading_mode: BaseMaterial3D.ShadingMode = BaseMaterial3D.SHADING_MODE_PER_PIXEL:
	set(v):
		shading_mode = v
		_rebuild()
@export_storage var cull_mode: BaseMaterial3D.CullMode = BaseMaterial3D.CULL_BACK:
	set(v):
		cull_mode = v
		_rebuild()
@export_storage var blend_mode: BaseMaterial3D.BlendMode = BaseMaterial3D.BLEND_MODE_MIX:
	set(v):
		blend_mode = v
		_rebuild()
@export_storage var depth_draw_mode: BaseMaterial3D.DepthDrawMode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY:
	set(v):
		depth_draw_mode = v
		_rebuild()
@export_storage var billboard_mode: BaseMaterial3D.BillboardMode = BaseMaterial3D.BILLBOARD_DISABLED:
	set(v):
		billboard_mode = v
		_rebuild()
@export_storage var billboard_keep_scale := false:
	set(v):
		billboard_keep_scale = v
		_rebuild()
@export_storage var specular_mode: BaseMaterial3D.SpecularMode = BaseMaterial3D.SPECULAR_SCHLICK_GGX:
	set(v):
		specular_mode = v
		_rebuild()
@export_storage var no_depth_test := false:
	set(v):
		no_depth_test = v
		_rebuild()
@export_storage var disable_fog := false:
	set(v):
		disable_fog = v
		_rebuild()
@export_storage var disable_receive_shadows := false:
	set(v):
		disable_receive_shadows = v
		_rebuild()
@export_storage var disable_ambient_light := false:
	set(v):
		disable_ambient_light = v
		_rebuild()
@export_storage var proximity_fade_enabled := false:
	set(v):
		proximity_fade_enabled = v
		_rebuild()
@export_storage var normal_enabled := false:
	set(v):
		normal_enabled = v
		_rebuild()
## Kept for BaseMaterial3D parity; the candy surface always samples with mipmaps.
@export_storage var texture_filter: BaseMaterial3D.TextureFilter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
@export_storage var rim_enabled := false:
	set(v):
		rim_enabled = v
		set_shader_parameter(&"rim", rim if v else 0.0)
@export_storage var rim := 1.0:
	set(v):
		rim = v
		set_shader_parameter(&"rim", v if rim_enabled else 0.0)
@export_storage var clearcoat_enabled := false:
	set(v):
		clearcoat_enabled = v
		set_shader_parameter(&"clearcoat", clearcoat if v else 0.0)
		_rebuild()
@export_storage var clearcoat := 1.0:
	set(v):
		clearcoat = v
		set_shader_parameter(&"clearcoat", v if clearcoat_enabled else 0.0)

var albedo_color: Color:
	get: return _get_param(&"albedo_color", Color.WHITE)
	set(v): set_shader_parameter(&"albedo_color", v)
var albedo_texture: Texture2D:
	get: return get_shader_parameter(&"albedo_texture")
	set(v): set_shader_parameter(&"albedo_texture", v)
var vertex_color_use_as_albedo: bool:
	get: return _get_param(&"vertex_color_use_as_albedo", false)
	set(v): set_shader_parameter(&"vertex_color_use_as_albedo", v)
var vertex_color_is_srgb: bool:
	get: return _get_param(&"vertex_color_is_srgb", false)
	set(v): set_shader_parameter(&"vertex_color_is_srgb", v)
var roughness: float:
	get: return _get_param(&"roughness", 1.0)
	set(v): set_shader_parameter(&"roughness", v)
var metallic: float:
	get: return _get_param(&"metallic", 0.0)
	set(v): set_shader_parameter(&"metallic", v)
var metallic_specular: float:
	get: return _get_param(&"specular", 0.5)
	set(v): set_shader_parameter(&"specular", v)
## glTF-style ORM texture (G roughness, B metallic).
var roughness_texture: Texture2D:
	get: return get_shader_parameter(&"orm_texture")
	set(v): set_shader_parameter(&"orm_texture", v)
var normal_texture: Texture2D:
	get: return get_shader_parameter(&"normal_texture")
	set(v): set_shader_parameter(&"normal_texture", v)
var normal_scale: float:
	get: return _get_param(&"normal_scale", 1.0)
	set(v): set_shader_parameter(&"normal_scale", v)
var emission_enabled: bool:
	get: return _get_param(&"emission_enabled", false)
	set(v): set_shader_parameter(&"emission_enabled", v)
var emission: Color:
	get: return _get_param(&"emission", Color.BLACK)
	set(v): set_shader_parameter(&"emission", v)
var emission_energy_multiplier: float:
	get: return _get_param(&"emission_energy_multiplier", 1.0)
	set(v): set_shader_parameter(&"emission_energy_multiplier", v)
var emission_texture: Texture2D:
	get: return get_shader_parameter(&"emission_texture")
	set(v): set_shader_parameter(&"emission_texture", v)
var rim_tint: float:
	get: return _get_param(&"rim_tint", 0.5)
	set(v): set_shader_parameter(&"rim_tint", v)
var clearcoat_roughness: float:
	get: return _get_param(&"clearcoat_roughness", 0.5)
	set(v): set_shader_parameter(&"clearcoat_roughness", v)
var uv1_scale: Vector3:
	get: return _get_param(&"uv1_scale", Vector3.ONE)
	set(v): set_shader_parameter(&"uv1_scale", v)
var uv1_offset: Vector3:
	get: return _get_param(&"uv1_offset", Vector3.ZERO)
	set(v): set_shader_parameter(&"uv1_offset", v)
var proximity_fade_distance: float:
	get: return _get_param(&"proximity_fade_distance", 1.0)
	set(v): set_shader_parameter(&"proximity_fade_distance", v)
var alpha_scissor_threshold: float:
	get: return _get_param(&"alpha_scissor_threshold", 0.5)
	set(v): set_shader_parameter(&"alpha_scissor_threshold", v)
## Candy extras (docs/tuning.md): the warm emissive rim, sheen and glitter.
var rim_strength: float:
	get: return _get_param(&"rim_strength", 0.0)
	set(v): set_shader_parameter(&"rim_strength", v)
var rim_color: Color:
	get: return _get_param(&"rim_color", Color(1.0, 0.86, 0.74))
	set(v): set_shader_parameter(&"rim_color", v)
var pearl: float:
	get: return _get_param(&"pearl", 0.0)
	set(v): set_shader_parameter(&"pearl", v)
var glitter: float:
	get: return _get_param(&"glitter", 0.0)
	set(v): set_shader_parameter(&"glitter", v)


func _init() -> void:
	_rebuild()


## The albedo a lit candy surface actually shows for a colour (the shader's cap).
func shown_albedo(c: Color = albedo_color) -> Color:
	if shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return c
	var cap: float = _get_param(&"albedo_cap", MAX_ALBEDO)
	return Color(minf(c.r, cap), minf(c.g, cap), minf(c.b, cap), c.a)


func _get_param(param: StringName, fallback: Variant) -> Variant:
	var v: Variant = get_shader_parameter(param)
	return fallback if v == null else v


## The variant key: one token per render flag that differs from the default.
func variant_key() -> String:
	var t: PackedStringArray = []
	if shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		t.append("unshaded")
	match transparency:
		BaseMaterial3D.TRANSPARENCY_ALPHA:
			t.append("alpha")
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
			t.append("scissor")
		BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
			t.append("prepass")
	match blend_mode:
		BaseMaterial3D.BLEND_MODE_ADD:
			t.append("add")
		BaseMaterial3D.BLEND_MODE_SUB:
			t.append("sub")
		BaseMaterial3D.BLEND_MODE_MUL:
			t.append("mul")
		BaseMaterial3D.BLEND_MODE_PREMULT_ALPHA:
			t.append("premul")
	match cull_mode:
		BaseMaterial3D.CULL_DISABLED:
			t.append("double")
		BaseMaterial3D.CULL_FRONT:
			t.append("front")
	match depth_draw_mode:
		BaseMaterial3D.DEPTH_DRAW_ALWAYS:
			t.append("depth_always")
		BaseMaterial3D.DEPTH_DRAW_DISABLED:
			t.append("depth_never")
	match billboard_mode:
		BaseMaterial3D.BILLBOARD_ENABLED:
			t.append("bb_view")
		BaseMaterial3D.BILLBOARD_FIXED_Y:
			t.append("bb_y")
		BaseMaterial3D.BILLBOARD_PARTICLES:
			t.append("bb_particles")
	if billboard_keep_scale and billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		t.append("keep_scale")
	if specular_mode == BaseMaterial3D.SPECULAR_DISABLED:
		t.append("nospec")
	if no_depth_test:
		t.append("nodepth")
	if disable_fog:
		t.append("nofog")
	if disable_receive_shadows:
		t.append("noshadow")
	if disable_ambient_light:
		t.append("noambient")
	if normal_enabled:
		t.append("normal")
	if proximity_fade_enabled:
		t.append("proxfade")
	if clearcoat_enabled and shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		t.append("coat")
	return "-".join(t)


## Shader source for a variant key (also used by tools/render/candy_variants.gd).
static func variant_code(key: String) -> String:
	var tokens := key.split("-", false)
	var modes: PackedStringArray = []
	var defines: PackedStringArray = []
	var blend := "blend_mix"
	var cull := "cull_back"
	var depth := "depth_draw_opaque"
	for tok in tokens:
		match tok:
			"unshaded":
				modes.append("unshaded")
				defines.append("CANDY_UNSHADED")
			"alpha":
				defines.append("CANDY_ALPHA")
			"scissor":
				defines.append("CANDY_SCISSOR")
			"prepass":
				modes.append("depth_prepass_alpha")
				defines.append("CANDY_ALPHA")
			"add":
				blend = "blend_add"
			"sub":
				blend = "blend_sub"
			"mul":
				blend = "blend_mul"
			"premul":
				blend = "blend_premul_alpha"
			"double":
				cull = "cull_disabled"
			"front":
				cull = "cull_front"
			"depth_always":
				depth = "depth_draw_always"
			"depth_never":
				depth = "depth_draw_never"
			"bb_view":
				defines.append_array(["CANDY_BILLBOARD", "CANDY_BILLBOARD_VIEW"])
			"bb_y":
				defines.append_array(["CANDY_BILLBOARD", "CANDY_BILLBOARD_Y"])
			"bb_particles":
				defines.append_array(["CANDY_BILLBOARD", "CANDY_BILLBOARD_PARTICLES"])
			"keep_scale":
				defines.append("CANDY_KEEP_SCALE")
			"nospec":
				modes.append("specular_disabled")
				defines.append("CANDY_NO_SPEC_LOBE")
			"nodepth":
				modes.append("depth_test_disabled")
			"nofog":
				modes.append("fog_disabled")
			"noshadow":
				modes.append("shadows_disabled")
			"noambient":
				modes.append("ambient_light_disabled")
			"normal":
				defines.append("CANDY_NORMAL_MAP")
			"proxfade":
				defines.append("CANDY_PROXIMITY_FADE")
			"coat":
				defines.append("CANDY_COAT")
	modes.append_array([blend, cull, depth])
	var code := "// Generated candy_lit variant \"%s\" (CandyMaterial.variant_code).\n" % key
	code += "shader_type spatial;\nrender_mode %s;\n" % ", ".join(modes)
	for d in defines:
		code += "#define %s\n" % d
	code += "#include \"%s\"\n" % SURFACE_INC
	return code


static func variant_path(key: String) -> String:
	return DEFAULT_SHADER if key.is_empty() else VARIANT_DIR + "candy_%s.gdshader" % key


static func shader_for(key: String) -> Shader:
	if _variants.has(key):
		return _variants[key]
	var path := variant_path(key)
	var sh: Shader
	if ResourceLoader.exists(path):
		sh = load(path) as Shader
	else:
		sh = Shader.new()
		sh.code = variant_code(key)
	_variants[key] = sh
	return sh


func _rebuild() -> void:
	var sh := shader_for(variant_key())
	if shader != sh:
		shader = sh


## A candy copy of any BaseMaterial3D (imported glb surfaces, old .tres files).
static func from_base(src: BaseMaterial3D) -> CandyMaterial:
	var m := CandyMaterial.new()
	m.resource_name = src.resource_name
	m.transparency = src.transparency
	m.shading_mode = src.shading_mode
	m.cull_mode = src.cull_mode
	m.blend_mode = src.blend_mode
	m.depth_draw_mode = src.depth_draw_mode
	m.billboard_mode = src.billboard_mode
	m.billboard_keep_scale = src.billboard_keep_scale
	m.specular_mode = src.specular_mode
	m.no_depth_test = src.no_depth_test
	m.disable_fog = src.disable_fog
	m.disable_receive_shadows = src.disable_receive_shadows
	m.disable_ambient_light = src.disable_ambient_light
	m.render_priority = src.render_priority
	m.albedo_color = src.albedo_color
	m.albedo_texture = src.albedo_texture
	m.vertex_color_use_as_albedo = src.vertex_color_use_as_albedo
	m.vertex_color_is_srgb = src.vertex_color_is_srgb
	m.roughness = src.roughness
	m.metallic = src.metallic
	m.metallic_specular = src.metallic_specular
	m.roughness_texture = src.roughness_texture if src.roughness_texture != null else src.metallic_texture
	m.alpha_scissor_threshold = src.alpha_scissor_threshold
	m.uv1_scale = src.uv1_scale
	m.uv1_offset = src.uv1_offset
	if src.normal_enabled and src.normal_texture != null:
		m.normal_enabled = true
		m.normal_texture = src.normal_texture
		m.normal_scale = src.normal_scale
	if src.emission_enabled:
		m.emission_enabled = true
		m.emission = src.emission
		m.emission_energy_multiplier = src.emission_energy_multiplier
		m.emission_texture = src.emission_texture
	if src.rim_enabled:
		m.rim_enabled = true
		m.rim = src.rim
		m.rim_tint = src.rim_tint
	if src.clearcoat_enabled:
		m.clearcoat_enabled = true
		m.clearcoat = src.clearcoat
		m.clearcoat_roughness = src.clearcoat_roughness
	if src.proximity_fade_enabled:
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = src.proximity_fade_distance
	m.next_pass = src.next_pass
	return m


## Swaps every BaseMaterial3D under root (mesh surfaces, surface overrides,
## material overrides) for a CandyMaterial copy; shared materials stay shared.
## Used by the project-wide glb import script (tools/import/candy_import.gd).
static func remap_scene(root: Node) -> int:
	var done := {}
	var count := 0
	for n in root.find_children("*", "GeometryInstance3D", true, false) + [root]:
		var gi := n as GeometryInstance3D
		if gi == null:
			continue
		if gi.material_override is BaseMaterial3D:
			gi.material_override = _remapped(gi.material_override, done)
			count += 1
		var mi := gi as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m is BaseMaterial3D:
				mi.mesh.surface_set_material(s, _remapped(m, done))
				count += 1
			var o := mi.get_surface_override_material(s)
			if o is BaseMaterial3D:
				mi.set_surface_override_material(s, _remapped(o, done))
				count += 1
	return count


static func _remapped(m: Material, done: Dictionary) -> Material:
	if not done.has(m):
		done[m] = from_base(m as BaseMaterial3D)
	return done[m]
