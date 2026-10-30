## Shared materials for the Blender prop models. A model has at most two
## surfaces, "opaque" and "clear" (glass, water); the finish of each face
## (gold, pearl, fabric, glow...) rides in its UV.x and the vertex colour is the
## albedo, so one uber shader shades them all and a merged room of props costs
## two draw calls (R9). See tools/blender/prop_kit.py.
class_name PropFinishes
extends RefCounted

const OPAQUE_SHADER := preload("res://world/spring_court/manor_estate/props/prop_finish.gdshader")
const CLEAR_SHADER := preload("res://world/spring_court/manor_estate/props/prop_finish_clear.gdshader")

static var _cache: Dictionary = {}


## The material for a model surface name ("opaque" or "clear").
static func material(surface: StringName) -> Material:
	var key := &"clear" if surface == &"clear" else &"opaque"
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = CLEAR_SHADER if key == &"clear" else OPAQUE_SHADER
		m.resource_name = "prop_" + String(key)
		_cache[key] = m
	return _cache[key]
