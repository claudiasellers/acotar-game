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
	# Roads and the square: trodden mud that thins into slush and then snow
	# through a ragged verge, not a hard edge (lane L32, audit A7). `snow` is
	# the snow overlay's weight over the mud (0 bare mud .. 255 all snow).
	var n := _vnoise(x * 0.35, z * 0.35) * 0.65 + _vnoise(x * 1.3, z * 1.3) * 0.35  # 0..1
	var snow := 255.0
	var dr := HumanRealmLayout.distance_to_road(p)
	var hw := HumanRealmLayout.ROAD_HALF_WIDTH
	if dr < hw + 3.5:
		# Wheel ruts 0.9 m either side of the crown stay bare and wet; the
		# crown between them and the verges carry more snow.
		var rut := 1.0 - clampf(absf(dr - 0.9) / 0.6, 0.0, 1.0)
		var verge := smoothstep(hw * 0.55, hw + 2.5, dr + (n - 0.5) * 2.2)
		snow = minf(snow, lerpf(75.0, 255.0, verge) * (1.0 - 0.7 * rut) + (35.0 if dr < 0.45 else 0.0))
	var ds := p.distance_to(HumanRealmLayout.VILLAGE_SQUARE)
	if ds < 60.0:
		# Footpaths of slush across a trampled square; the edge frays out.
		var edge := 42.0 + (n - 0.5) * 12.0
		var trodden := lerpf(55.0, 150.0, smoothstep(0.35, 0.7, _vnoise(x * 0.6 + 17.0, z * 0.6 - 9.0)))
		snow = minf(snow, lerpf(trodden, 255.0, smoothstep(edge - 7.0, edge + 7.0, ds)))
	if snow < 250.0:
		return Vector3i(T.PATH, T.SNOW, int(clampf(snow, 0.0, 255.0)))
	if p.distance_to(HumanRealmLayout.BURNT_ESTATE) < 40.0:
		return Vector3i(T.FROZEN_EARTH, T.SNOW, 110)
	var dpath := HumanRealmLayout.distance_to_path(p)
	if dpath < HumanRealmLayout.PATH_HALF_WIDTH + 0.5:
		return Vector3i(T.SNOW, T.FROZEN_EARTH, 120)
	if HumanRealmLayout.REGION_RECTS[&"hunting_forest"].has_point(p):
		return Vector3i(T.SNOW, T.FOREST_FLOOR, 40)
	# Dead grass shows through the thin snow in drifts, most near the village
	# and along the roads where feet and wheels have scuffed it.
	var near := maxf(1.0 - clampf((p.distance_to(HumanRealmLayout.VILLAGE_SQUARE) - 60.0) / 120.0, 0.0, 1.0),
			1.0 - clampf((dr - hw - 3.0) / 12.0, 0.0, 1.0))
	var tufts := smoothstep(0.55, 0.85, _vnoise(x * 0.5 - 31.0, z * 0.5 + 5.0))
	return Vector3i(T.SNOW, T.WINTER_GRASS, int(30.0 + tufts * lerpf(25.0, 95.0, near)))


## Smooth value noise in 0..1, pure (safe from the baker's threads).
static func _vnoise(x: float, z: float) -> float:
	var ix := floorf(x)
	var iz := floorf(z)
	var fx := x - ix
	var fz := z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := _hash2(ix, iz)
	var b := _hash2(ix + 1.0, iz)
	var c := _hash2(ix, iz + 1.0)
	var d := _hash2(ix + 1.0, iz + 1.0)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


static func _hash2(x: float, z: float) -> float:
	var h := sin(x * 127.1 + z * 311.7) * 43758.5453
	return h - floorf(h)


static func _pond_level() -> float:
	return MacroHeight.land_height_at(HumanRealmLayout.MILL_POND.x, HumanRealmLayout.MILL_POND.y) - 1.6


static func _flatten(p: Vector2, h: float, centre: Vector2, radius: float, falloff: float) -> float:
	var d := p.distance_to(centre)
	if d > radius + falloff:
		return h
	var target := MacroHeight.land_height_at(centre.x, centre.y)
	var t := clampf((d - radius) / falloff, 0.0, 1.0)
	return lerpf(target, h, t * t * (3.0 - 2.0 * t))
