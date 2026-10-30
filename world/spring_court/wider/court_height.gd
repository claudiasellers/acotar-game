## Height provider for the wider court's regions (docs/contracts/world.md §2).
## Starts from MacroHeight's land, adds this lane's sculpting (the Hill of the
## Rite and its terraces, lake basins, the escarpment, pads for the village and
## the dance ring), then carves the Thornwater exactly as MacroHeight does so
## the river runs on unbroken through every lane.
class_name CourtHeight
extends RefCounted

enum K { HILL, PAD, BASIN, TERRACES, CLIFF_WEST, NOTCH, RISE_NORTH, RISE_EAST }

## [kind, x, z, radius, a, b, (c, d)]
## HILL: a = amplitude (gaussian, radius = sigma).
## PAD: flatten to land height at the centre + a; full inside radius, eased to 1.7 x radius.
## BASIN: lake. Water at land height at the centre + a (negative), depth b.
## TERRACES: steps of b metres on the ring a..radius around the centre, on the face toward (c, d).
## CLIFF_WEST: west of x, drop a metres over radius metres.
## NOTCH: valley of depth a, half-width radius, from (x, z) to (b, c).
## RISE_NORTH / RISE_EAST: north of z = x (east of x = x), climb a metres over radius metres: the court's edge.
const STAMPS := [
	# Hill of the Rite: the great hill, flat crown for the stone ring, bonfire terraces on the south-west face.
	[K.HILL, 800.0, -1100.0, 210.0, 92.0, 0.0],
	[K.PAD, 800.0, -1100.0, 38.0, 0.0, 0.0],
	[K.TERRACES, 800.0, -1100.0, 230.0, 70.0, 6.5, -0.7, 0.7],
	[K.PAD, 560.0, -860.0, 55.0, 0.0, 0.0], # drumming field
	[K.PAD, 690.0, -1000.0, 24.0, 0.0, 0.0], # cave mouth apron
	# Solstice meadow: the crown hill and the dance ring.
	[K.HILL, 100.0, -1180.0, 190.0, 24.0, 0.0],
	[K.PAD, -150.0, -1080.0, 42.0, 0.0, 0.0],
	# Starlight Glen: the Looking Lake and its isle, the hidden pool under the Glimmerfall, Willow Mere.
	[K.BASIN, -1230.0, -170.0, 120.0, -1.2, 4.5],
	[K.HILL, -1235.0, -175.0, 16.0, 9.0, 0.0],
	[K.PAD, -1300.0, 260.0, 70.0, -5.0, 0.0],
	[K.HILL, -1300.0, 200.0, 30.0, 16.0, 0.0],
	[K.BASIN, -1300.0, 262.0, 20.0, -5.6, 2.4],
	[K.BASIN, -1120.0, 400.0, 60.0, -1.0, 3.0],
	# Fae village: a terrace for the green on the east bank, the mill race pad.
	[K.PAD, -980.0, -900.0, 85.0, 0.5, 0.0],
	[K.PAD, -1150.0, -950.0, 45.0, 0.5, 0.0],
	# Western Fells: watchtower knolls, the Old Shrines terrace, the Ash Grove hollow, the escarpment.
	[K.HILL, -1650.0, -650.0, 34.0, 11.0, 0.0],
	[K.HILL, -1650.0, 350.0, 34.0, 11.0, 0.0],
	[K.HILL, -1050.0, 1250.0, 30.0, 8.0, 0.0],
	[K.PAD, -1640.0, 120.0, 45.0, 0.0, 0.0],
	[K.HILL, -1250.0, 1100.0, 70.0, -9.0, 0.0],
	[K.CLIFF_WEST, -1785.0, 0.0, 45.0, 95.0, 0.0],
	# Autumn foothills: the Ember Crown ridge and the sealed pass cut toward the north-west.
	[K.HILL, -1200.0, -1450.0, 80.0, 22.0, 0.0],
	[K.NOTCH, -1560.0, -1560.0, 28.0, 14.0, -1760.0, -1690.0],
	# The court's northern and eastern rim: grey ridges toward the mountain, cut by the pass.
	[K.RISE_NORTH, -1715.0, 0.0, 90.0, 85.0, 0.0],
	[K.RISE_EAST, 1715.0, 0.0, 90.0, 70.0, 0.0],
	[K.NOTCH, 300.0, -1690.0, 16.0, 70.0, 300.0, -1960.0],
	# Blighted Reaches: the sunken heart.
	[K.HILL, 1500.0, -1600.0, 110.0, -9.0, 0.0],
]

static var _centre_cache := {}


static func height_at(x: float, z: float) -> float:
	var h := MacroHeight.land_height_at(x, z)
	for i in STAMPS.size():
		var s: Array = STAMPS[i]
		if s[0] != K.BASIN and s[0] != K.NOTCH:
			h = _apply(i, s, x, z, h)
	for i in STAMPS.size():
		var s: Array = STAMPS[i]
		if s[0] == K.NOTCH:
			h = _apply(i, s, x, z, h)
	h = _carve_river(x, z, h)
	for i in STAMPS.size():
		var s: Array = STAMPS[i]
		if s[0] == K.BASIN:
			h = _apply(i, s, x, z, h)
	return h


## Ground textures (WorldHeight.Tex slots): blight in the Reaches, leaf litter in
## the Autumn foothills, moss in the glen, grass elsewhere, rock on steep slopes.
static func texture_at(x: float, z: float) -> Vector3i:
	var region := CourtMap.region_at(x, z)
	if MacroHeight.distance_to_river(x, z) < MacroHeight.RIVER_HALF_WIDTH:
		return Vector3i(WorldHeight.Tex.RIVERBED, WorldHeight.Tex.RIVERBED, 0)
	var base: int = WorldHeight.Tex.SPRING_GRASS
	var overlay: int = WorldHeight.Tex.MOSS
	match region:
		&"blighted_reaches":
			base = WorldHeight.Tex.BLIGHT
			overlay = WorldHeight.Tex.FROZEN_EARTH
		&"autumn_foothills":
			base = WorldHeight.Tex.FOREST_FLOOR
		&"starlight_glen":
			overlay = WorldHeight.Tex.MOSS
	var dx := height_at(x + 1.0, z) - height_at(x - 1.0, z)
	var dz := height_at(x, z + 1.0) - height_at(x, z - 1.0)
	var slope := rad_to_deg(atan(sqrt(dx * dx + dz * dz) * 0.5))
	if slope > 36.0:
		return Vector3i(WorldHeight.Tex.ROCK, base, 0)
	if slope > 24.0:
		return Vector3i(base, WorldHeight.Tex.ROCK, int(remap(slope, 24.0, 36.0, 0.0, 255.0)))
	var blend := int(clampf(0.5 + 0.5 * sin(x * 0.031) * cos(z * 0.027), 0.0, 1.0) * 140.0)
	return Vector3i(base, overlay, blend)


## Lakes as {center: Vector2, radius: float, level: float}, for water surfaces.
static func lakes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in STAMPS.size():
		var s: Array = STAMPS[i]
		if s[0] == K.BASIN:
			out.append({"center": Vector2(s[1], s[2]), "radius": s[3], "level": _centre(i, s) + s[4]})
	return out


## Fills the static caches up front so worker threads only read them.
static func prewarm() -> void:
	for i in STAMPS.size():
		_centre(i, STAMPS[i])


## Water surface height of the Thornwater near a point (bank level less a metre).
static func river_level_at(x: float, z: float) -> float:
	return MacroHeight.land_height_at(x, z) - 1.0


static func _centre(i: int, s: Array) -> float:
	if not _centre_cache.has(i):
		_centre_cache[i] = MacroHeight.land_height_at(s[1], s[2])
	return _centre_cache[i]


static func _apply(i: int, s: Array, x: float, z: float, h: float) -> float:
	var dx: float = x - s[1]
	var dz: float = z - s[2]
	var r: float = s[3]
	match s[0]:
		K.HILL:
			var d2 := dx * dx + dz * dz
			if d2 > 9.0 * r * r:
				return h
			return h + s[4] * exp(-d2 / (2.0 * r * r))
		K.PAD:
			var d := sqrt(dx * dx + dz * dz)
			if d > r * 1.7:
				return h
			var target: float = _centre(i, s) + s[4] + _hill_sum(s[1], s[2])
			var t := 1.0 - smoothstep(r, r * 1.7, d)
			return lerpf(h, target, t)
		K.BASIN:
			var d := sqrt(dx * dx + dz * dz)
			if d > r * 1.6:
				return h
			var level: float = _centre(i, s) + s[4]
			if d < r:
				var bottom: float = level - s[5] * (1.0 - (d / r) * (d / r)) - 0.4
				return minf(h, bottom)
			var t := smoothstep(r, r * 1.6, d)
			return maxf(lerpf(level - 0.3, h, t), level + 0.25 * t)
		K.TERRACES:
			var d := sqrt(dx * dx + dz * dz)
			if d > r or d < s[4]:
				return h
			var face := Vector2(s[6], s[7]).normalized()
			var dir := Vector2(dx, dz) / maxf(d, 0.001)
			var w := smoothstep(0.15, 0.55, dir.dot(face))
			w *= smoothstep(s[4], s[4] + 20.0, d) * (1.0 - smoothstep(r - 30.0, r, d))
			if w <= 0.0:
				return h
			var step: float = s[5]
			var q := floorf(h / step)
			var f := h / step - q
			var stepped := (q + smoothstep(0.82, 1.0, f)) * step
			return lerpf(h, stepped, w)
		K.CLIFF_WEST:
			if x > s[1]:
				return h
			return h - smoothstep(s[1], s[1] - r, x) * s[4]
		K.RISE_NORTH:
			if z > s[1]:
				return h
			return h + smoothstep(s[1], s[1] - r, z) * s[4]
		K.RISE_EAST:
			if x < s[1]:
				return h
			return h + smoothstep(s[1], s[1] + r, x) * s[4]
		K.NOTCH:
			var p := Vector2(x, z)
			var q := Geometry2D.get_closest_point_to_segment(p, Vector2(s[1], s[2]), Vector2(s[5], s[6]))
			var d := p.distance_to(q)
			if d > r:
				return h
			var k := 1.0 - d / r
			return h - s[4] * k * k
	return h


## Height the hills add at a point, so a pad on a hill sits on the hill.
static func _hill_sum(x: float, z: float) -> float:
	var add := 0.0
	for s: Array in STAMPS:
		if s[0] == K.HILL:
			var dx: float = x - s[1]
			var dz: float = z - s[2]
			var r: float = s[3]
			add += s[4] * exp(-(dx * dx + dz * dz) / (2.0 * r * r))
	return add


static func _carve_river(x: float, z: float, h: float) -> float:
	var d := MacroHeight.distance_to_river(x, z)
	if d >= MacroHeight.RIVER_HALF_WIDTH + MacroHeight.RIVER_BANK:
		return h
	var bed := h - MacroHeight.RIVER_DEPTH
	var t := clampf((d - MacroHeight.RIVER_HALF_WIDTH) / MacroHeight.RIVER_BANK, 0.0, 1.0)
	return lerpf(bed, h, t * t * (3.0 - 2.0 * t))
