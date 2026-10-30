## The look of each prop: one cached procedural ArrayMesh per id (a few surfaces,
## one per material), built by the category builders under props/shapes/.
## Blender models can replace any id later without touching a layout.
class_name PropShapes
extends RefCounted

## Props that carry ONE warm light: id -> [height fraction, range, energy].
const LIGHTS := {
	&"chandelier_crystal": [0.35, 9.0, 1.6],
	&"chandelier_small": [0.4, 7.0, 1.2],
	&"candelabra": [0.95, 4.0, 0.6],
	&"floor_candlestand": [0.98, 4.5, 0.6],
	&"lantern_hanging": [0.45, 5.0, 0.8],
	&"candle_bank": [0.9, 4.5, 0.7],
	&"faelight_orb": [0.5, 3.5, 0.6],
	&"star_lamp": [0.6, 4.0, 0.7],
}
const LIGHT_COLOR := Color(1.0, 0.80, 0.72)

static var _cache: Dictionary = {}
static var _tris: Dictionary = {}
## Ids that fell back to the stand-in box (a test keeps this empty).
static var fallback_ids: Dictionary = {}


## Returns a visual-only Node3D for the prop, base at y = 0, facing -Z, fitting `size`.
static func build(id: StringName, size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh(id, size, color)
	mi.visibility_range_end = 90.0 if maxf(size.x, maxf(size.y, size.z)) < 3.5 else 220.0
	root.add_child(mi)
	if LIGHTS.has(id):
		var l: Array = LIGHTS[id]
		var omni := OmniLight3D.new()
		omni.name = "Glow"
		omni.position.y = size.y * float(l[0])
		omni.omni_range = minf(float(l[1]), 9.0)
		omni.light_energy = float(l[2])
		omni.light_color = LIGHT_COLOR
		omni.shadow_enabled = false
		omni.distance_fade_enabled = true
		omni.distance_fade_begin = 30.0
		omni.distance_fade_length = 10.0
		root.add_child(omni)
	return root


## The shared mesh for an id at a size and colour (cached).
static func mesh(id: StringName, size: Vector3, color: Color) -> ArrayMesh:
	var key := "%s|%s|%s" % [id, size, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var k := PropMeshKit.new()
	var ok := _dispatch(k, id, size, color)
	if not ok or k.tri_count() == 0:
		fallback_ids[id] = true
		k = PropMeshKit.new()
		k.box(PropMats.body(color), Vector3(0, size.y * 0.5, 0), size)
	_tris[id] = k.tri_count()
	var m := k.to_mesh(size)
	_cache[key] = m
	return m


static func tri_count(id: StringName) -> int:
	return int(_tris.get(id, 0))


static func _dispatch(k: PropMeshKit, id: StringName, s: Vector3, c: Color) -> bool:
	if FurnitureShapes.build(k, id, s, c):
		return true
	if BedroomShapes.build(k, id, s, c):
		return true
	if LightingShapes.build(k, id, s, c):
		return true
	if DecorShapes.build(k, id, s, c):
		return true
	if LibraryMusicShapes.build(k, id, s, c):
		return true
	if ServiceShapes.build(k, id, s, c):
		return true
	if OutbuildingShapes.build(k, id, s, c):
		return true
	if GardenShapes.build(k, id, s, c):
		return true
	if CharmShapes.build(k, id, s, c):
		return true
	return false
