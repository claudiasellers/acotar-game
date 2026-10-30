## Height provider for the human realm (registered in
## world/shared/terrain/height_providers.tres). Starts from the shared macro
## land and adds the realm's features from HumanRealmLayout.
extends RefCounted


static var _detail: FastNoiseLite


static func height_at(x: float, z: float) -> float:
	if _detail == null:
		_detail = FastNoiseLite.new()
		_detail.seed = 4242
		_detail.frequency = 1.0 / 60.0
		_detail.fractal_octaves = 3
	var p := Vector2(x, z)
	var h := MacroHeight.land_height_at(x, z) + _detail.get_noise_2d(x, z) * 1.6
	# The estate hill: the family's old life, looking down on the village.
	var dh := p.distance_to(HumanRealmLayout.BURNT_ESTATE)
	if dh < HumanRealmLayout.ESTATE_HILL_RADIUS:
		var t := 1.0 - dh / HumanRealmLayout.ESTATE_HILL_RADIUS
		h += HumanRealmLayout.ESTATE_HILL_HEIGHT * t * t * (3.0 - 2.0 * t)
	# Flat pads: the village plateau, the cottage, the estate's terrace.
	h = _flatten(p, h, HumanRealmLayout.VILLAGE_SQUARE, HumanRealmLayout.VILLAGE_PLATEAU, 60.0)
	h = _flatten(p, h, HumanRealmLayout.COTTAGE, HumanRealmLayout.COTTAGE_PAD, 18.0)
	h = _flatten(p, h, HumanRealmLayout.BURNT_ESTATE, 45.0, 30.0)
	h = _flatten(p, h, HumanRealmLayout.HUNTING_LODGE, 25.0, 20.0)
	# Roads sit slightly into the snow and smooth the bumps.
	var dr := HumanRealmLayout.distance_to_road(p)
	if dr < HumanRealmLayout.ROAD_HALF_WIDTH + 4.0:
		var t := clampf((dr - HumanRealmLayout.ROAD_HALF_WIDTH) / 4.0, 0.0, 1.0)
		h -= 0.25 * (1.0 - t)
	# The frozen creek and the mill pond.
	var dc := HumanRealmLayout.distance_to_creek(p)
	if dc < HumanRealmLayout.CREEK_HALF_WIDTH + HumanRealmLayout.CREEK_BANK:
		var t := clampf((dc - HumanRealmLayout.CREEK_HALF_WIDTH) / HumanRealmLayout.CREEK_BANK, 0.0, 1.0)
		h -= HumanRealmLayout.CREEK_DEPTH * (1.0 - t * t * (3.0 - 2.0 * t))
	var dp := p.distance_to(HumanRealmLayout.MILL_POND)
	if dp < HumanRealmLayout.MILL_POND_RADIUS + 10.0:
		var t := clampf((dp - HumanRealmLayout.MILL_POND_RADIUS) / 10.0, 0.0, 1.0)
		h = minf(h, lerpf(_pond_level(), h, t * t))
	return h


static func texture_at(x: float, z: float) -> Vector3i:
	var p := Vector2(x, z)
	var T := WorldHeight.Tex
	if HumanRealmLayout.distance_to_creek(p) < HumanRealmLayout.CREEK_HALF_WIDTH or p.distance_to(HumanRealmLayout.MILL_POND) < HumanRealmLayout.MILL_POND_RADIUS:
		return Vector3i(T.ICE, T.ICE, 0)
	var dr := HumanRealmLayout.distance_to_road(p)
	if dr < HumanRealmLayout.ROAD_HALF_WIDTH:
		return Vector3i(T.PATH, T.SNOW, int(clampf(dr / HumanRealmLayout.ROAD_HALF_WIDTH, 0.0, 1.0) * 160.0))
	if p.distance_to(HumanRealmLayout.VILLAGE_SQUARE) < 45.0:
		return Vector3i(T.PATH, T.SNOW, 90)
	if p.distance_to(HumanRealmLayout.BURNT_ESTATE) < 40.0:
		return Vector3i(T.FROZEN_EARTH, T.SNOW, 110)
	var dpath := HumanRealmLayout.distance_to_path(p)
	if dpath < HumanRealmLayout.PATH_HALF_WIDTH + 0.5:
		return Vector3i(T.SNOW, T.FROZEN_EARTH, 120)
	if HumanRealmLayout.REGION_RECTS[&"hunting_forest"].has_point(p):
		return Vector3i(T.SNOW, T.FOREST_FLOOR, 40)
	return Vector3i(T.SNOW, T.WINTER_GRASS, 30)


static func _pond_level() -> float:
	return MacroHeight.land_height_at(HumanRealmLayout.MILL_POND.x, HumanRealmLayout.MILL_POND.y) - 1.6


static func _flatten(p: Vector2, h: float, centre: Vector2, radius: float, falloff: float) -> float:
	var d := p.distance_to(centre)
	if d > radius + falloff:
		return h
	var target := MacroHeight.land_height_at(centre.x, centre.y)
	var t := clampf((d - radius) / falloff, 0.0, 1.0)
	return lerpf(target, h, t * t * (3.0 - 2.0 * t))
