## The one height function for the whole map: MacroHeight blended with every
## registered lane provider. The terrain bake, scatter placement and anything
## that needs ground height outside a physics query use this.
class_name WorldHeight
extends RefCounted

const PROVIDER_SET_PATH := "res://world/shared/terrain/height_providers.tres"

## Terrain3D texture slots (see docs/contracts/world.md).
enum Tex { SNOW, FROZEN_EARTH, ROCK, WINTER_GRASS, SPRING_GRASS, MOSS, FOREST_FLOOR, PATH, RIVERBED, BLIGHT, ICE }

static var _providers: Array[HeightProvider] = []
static var _loaded := false


static func height_at(x: float, z: float) -> float:
	_ensure_loaded()
	var h := MacroHeight.height_at(x, z)
	for p in _providers:
		var w := p.weight_at(x, z)
		if w > 0.0:
			h = lerpf(h, p.height_at(x, z), w)
	return h


static func normal_at(x: float, z: float, step: float = 1.0) -> Vector3:
	var dx := height_at(x + step, z) - height_at(x - step, z)
	var dz := height_at(x, z + step) - height_at(x, z - step)
	return Vector3(-dx, 2.0 * step, -dz).normalized()


## Slope in degrees at a point.
static func slope_at(x: float, z: float) -> float:
	return rad_to_deg(acos(clampf(normal_at(x, z).y, -1.0, 1.0)))


## Ground texture as (base slot, overlay slot, blend 0-255). The strongest
## provider with a texture rule decides; otherwise a default by realm and slope.
static func texture_at(x: float, z: float) -> Vector3i:
	_ensure_loaded()
	var best: HeightProvider = null
	var best_w := 0.0
	for p in _providers:
		if p.has_texture_rule():
			var w := p.weight_at(x, z)
			if w > 0.5 and w >= best_w:
				best = p
				best_w = w
	if best != null:
		return best.texture_at(x, z)
	var winter := z >= WorldMap.WALL_Z
	if MacroHeight.distance_to_river(x, z) < MacroHeight.RIVER_HALF_WIDTH:
		return Vector3i(Tex.RIVERBED, Tex.RIVERBED, 0)
	var slope := slope_at(x, z)
	var ground := Tex.SNOW if winter else Tex.SPRING_GRASS
	if slope > 38.0:
		return Vector3i(Tex.ROCK, ground, 0)
	if slope > 26.0:
		return Vector3i(ground, Tex.ROCK, int(remap(slope, 26.0, 38.0, 0.0, 255.0)))
	return Vector3i(ground, Tex.FROZEN_EARTH if winter else Tex.MOSS, 0)


## Initialise every lazily-built noise before sampling from threads.
static func warm_up() -> void:
	_ensure_loaded()
	MacroHeight.height_at(0.0, 0.0)
	for p in _providers:
		var c := p.bounds.get_center()
		p.height_at(c.x, c.y)
		if p.has_texture_rule():
			p.texture_at(c.x, c.y)


static func providers() -> Array[HeightProvider]:
	_ensure_loaded()
	return _providers


## Tests and tools can swap the registry. Pass null to reload from disk.
static func set_providers(list: Variant) -> void:
	_providers.clear()
	_loaded = list != null
	if list != null:
		for p in list:
			_providers.append(p)
		_providers.sort_custom(func(a: HeightProvider, b: HeightProvider) -> bool: return a.priority < b.priority)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var set := load(PROVIDER_SET_PATH) as HeightProviderSet
	set_providers(set.providers if set != null else [])
