class_name MaterialLibrary
extends RefCounted
## Every runtime surface is built here (render program T2): no stock BaseMaterial3D
## outside tools/ and tests/. surface() is the general CandyMaterial with
## the stock BaseMaterial3D property names; get_material(kind) returns a named
## starting point. Each call returns a fresh material the caller may change.

const FOLIAGE_SHADER := "res://world/shared/shaders/candy_lit_foliage.gdshader"
const UNLIT_SHADER := "res://world/shared/shaders/candy_lit_unlit.gdshader"

## Named kinds. Values are neutral: the finishes the props and rooms already use.
const KINDS: Array[StringName] = [&"matte", &"satin", &"gloss", &"gold", &"pearl", &"glass", &"glow", &"unlit", &"sprite", &"foliage", &"fx"]


## The general surface (lit, opaque, back-face culled), optionally coloured.
static func surface(color: Color = Color.WHITE, rough: float = 1.0, metal: float = 0.0) -> CandyMaterial:
	var m := CandyMaterial.new()
	if color != Color.WHITE:
		m.albedo_color = color
	if rough != 1.0:
		m.roughness = rough
	if metal != 0.0:
		m.metallic = metal
	return m


## A named material kind; unknown kinds fall back to a plain surface.
static func get_material(kind: StringName, color: Color = Color.WHITE) -> ShaderMaterial:
	match kind:
		&"foliage", &"fx":
			var sm := ShaderMaterial.new()
			sm.shader = load(FOLIAGE_SHADER if kind == &"foliage" else UNLIT_SHADER) as Shader
			sm.set_shader_parameter(&"albedo_color", color)
			if kind == &"foliage":
				sm.set_shader_parameter(&"vertex_color_use_as_albedo", true)
			return sm
	var m := surface(color)
	match kind:
		&"matte":
			m.roughness = 0.85
		&"satin":
			m.roughness = 0.42
			m.clearcoat_enabled = true
			m.clearcoat = 0.3
			m.clearcoat_roughness = 0.35
		&"gloss":
			m.roughness = 0.25
		&"gold":
			m.roughness = 0.3
			m.metallic = 1.0
			m.rim_enabled = true
			m.rim = 0.3
			m.rim_tint = 1.0
		&"pearl":
			m.roughness = 0.18
			m.metallic = 0.12
			m.clearcoat_enabled = true
			m.clearcoat = 0.7
			m.clearcoat_roughness = 0.15
			m.rim_enabled = true
			m.rim = 0.6
			m.rim_tint = 0.7
		&"glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic = 0.1
			m.metallic_specular = 0.9
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"glow":
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 2.0
		&"unlit":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		&"sprite":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.vertex_color_use_as_albedo = true
	return m


## True for any member of the candy_lit family (CandyMaterial or a kind's ShaderMaterial).
static func is_candy(mat: Material) -> bool:
	if mat is CandyMaterial:
		return true
	var sm := mat as ShaderMaterial
	return sm != null and sm.shader != null and sm.shader.resource_path.begins_with("res://world/shared/shaders/candy")
