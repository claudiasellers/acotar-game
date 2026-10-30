## The pond: a glossy periwinkle water surface at ManorTerrain.pond_level(), a
## timber jetty on the north shore, a boathouse with a rowing boat on the east
## shore, stepping stones out to a little island pavilion, an arched footbridge
## on to a willow islet, reeds, water lilies, shore willows and irises.
class_name ManorPond
extends RefCounted

const WATER_SCALE := 1.12
const JETTY_X := 175.0
const BOATHOUSE := Rect2(246.0, 104.0, 12.0, 12.0)
const ISLAND_R := 6.0
const ISLET_R := 4.0
const STONES_FROM := Vector2(210.0, 66.5)


static func footprints() -> Array[Rect2]:
	return [BOATHOUSE.grow(1.0), Rect2(JETTY_X - 2.0, 58.0, 4.0, 24.0)]


static func level() -> float:
	return ManorTerrain.pond_level()


static func stones() -> PackedVector2Array:
	var to := ManorSitePlan.POND_ISLAND + Vector2(0.4, -ISLAND_R + 0.3)
	var out := PackedVector2Array()
	var n := 16
	for i in n:
		var t := (i + 0.5) / n
		var p := STONES_FROM.lerp(to, t) + Vector2(sin(t * 9.0) * 0.6, 0)
		out.append(p)
	return out


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("pond_plant")
	var c := ManorSitePlan.POND_CENTER
	var rr := ManorSitePlan.POND_RADII
	# reeds in clumps round the shore, leaving the jetty, boathouse and stones clear
	var placed := 0
	while placed < 220:
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.0, 1.12)
		var p := c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * r
		if _near_access(p):
			continue
		for k in 4:
			var q := p + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
			sb.put(&"deco_reed", q.x, q.y, rng.randf() * TAU, rng.randf_range(0.8, 1.2))
		placed += 4
	# water lilies on the surface
	for i in 110:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.85
		var p := c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * r
		if p.distance_to(ManorSitePlan.POND_ISLAND) < ISLAND_R + 1.0 or p.distance_to(ManorSitePlan.POND_ISLET) < ISLET_R + 1.0:
			continue
		sb.put_at(&"deco_water_lily", Vector3(p.x, level() + 0.02, p.y), rng.randf() * TAU, rng.randf_range(0.7, 1.2))
	# shore willows with bark, silt on the shore
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var p := c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * 1.3
		if _near_access(p):
			continue
		sb.put(&"deco_willow", p.x, p.y, rng.randf() * TAU, rng.randf_range(0.9, 1.1))
		for k in 2:
			sb.put(&"ing_willow_bark", p.x + rng.randf_range(-1.5, 1.5), p.y + rng.randf_range(-1.5, 1.5), rng.randf() * TAU)
	var silt := 0
	while silt < 32:
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * rng.randf_range(1.13, 1.2)
		if _near_access(p):
			continue
		sb.put(&"ing_river_silt", p.x, p.y, rng.randf() * TAU)
		silt += 1
	# the islet's willow and the island's flowers (on the structure tops)
	var it := ManorSitePlan.POND_ISLET
	sb.put_at(&"deco_willow", Vector3(it.x, level() + 0.5, it.y), 0.4, 0.7)
	var il := ManorSitePlan.POND_ISLAND
	for i in 10:
		var a := TAU * i / 10.0
		sb.put_at(&"ing_iris" if i % 2 == 0 else &"deco_forget_me_not", Vector3(il.x + cos(a) * 4.8, level() + 0.5, il.y + sin(a) * 4.8), a, 0.8)
	sb.put_at(&"col_painted_pebble", Vector3(il.x + 1.5, level() + 0.5, il.y + 2.0), 0.0)


static func _near_access(p: Vector2) -> bool:
	if absf(p.x - JETTY_X) < 4.0 and p.y < 85.0:
		return true
	if BOATHOUSE.grow(3.0).has_point(p):
		return true
	for s in stones():
		if p.distance_to(s) < 2.5:
			return true
	return p.distance_to(STONES_FROM) < 3.0


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "Pond")
	var c := ManorSitePlan.POND_CENTER
	var y := level()
	b.disc(Vector3(c.x, y, c.y), ManorSitePlan.POND_RADII * WATER_SCALE, ManorGrounds.water(), 64)
	_jetty(b, y)
	_boathouse(b, y)
	_island(b, y)
	# stepping stones
	for s in stones():
		b.cylinder(Vector3(s.x, y - 1.6, s.y), 0.6, 1.78, ManorGrounds.stone(), true, 10, 0.55)
	# shore benches and lamps
	for p: Vector2 in [Vector2(160, 66), Vector2(225, 155), Vector2(140, 140)]:
		b.prop_on_ground(&"garden_bench", p.x, p.y, (c - p).angle_to(Vector2(0, -1)))
	for p: Vector2 in [Vector2(171, 60), Vector2(179, 60), Vector2(242, 98), Vector2(214, 64)]:
		ManorGrounds.lamp(b, p.x, p.y)
	b.drape_path(PackedVector2Array([Vector2(26, 6), Vector2(120, 40), Vector2(JETTY_X, 58.0)]), 3.0, ManorGrounds.gravel())
	b.drape_path(PackedVector2Array([Vector2(JETTY_X, 58.0), Vector2(230, 70), Vector2(BOATHOUSE.end.x + 1.5, BOATHOUSE.get_center().y)]), 2.5, ManorGrounds.gravel())
	b.flush()


static func _jetty(b: GroundsBatch, y: float) -> void:
	var deck := y + 0.55
	var z0 := 60.0
	var z1 := 84.0
	b.box(Vector3(JETTY_X, deck - 0.1, (z0 + z1) * 0.5), Vector3(2.6, 0.2, z1 - z0), ManorGrounds.wood())
	for i in 9:
		var z := z0 + 1.0 + i * (z1 - z0 - 2.0) / 8.0
		for side: float in [-1.0, 1.0]:
			b.cylinder(Vector3(JETTY_X + side * 1.2, y - 2.0, z), 0.13, 3.3 if i % 2 == 0 else 2.6, ManorGrounds.wood_dark(), false, 8)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(JETTY_X + side * 1.25, deck + 0.85, (z0 + 8.0 + z1) * 0.5), Vector3(0.08, 0.08, z1 - z0 - 8.0), ManorGrounds.wood_dark(), false)
	b.add_box_shape(Transform3D(Basis(), Vector3(JETTY_X - 1.3, deck + 0.5, (z0 + 8.0 + z1) * 0.5)), Vector3(0.12, 1.0, z1 - z0 - 8.0))
	b.add_box_shape(Transform3D(Basis(), Vector3(JETTY_X + 1.3, deck + 0.5, (z0 + 8.0 + z1) * 0.5)), Vector3(0.12, 1.0, z1 - z0 - 8.0))
	b.prop(&"lantern_hanging", Vector3(JETTY_X, deck, z1 - 0.6))
	_boat(b, Vector3(JETTY_X + 2.4, y + 0.05, z1 - 4.0), 0.1)


static func _boathouse(b: GroundsBatch, y: float) -> void:
	var r := BOATHOUSE
	var deck := y + 0.55
	var wall := ManorGrounds.plaster()
	var top := deck + 4.0
	# north, south and east walls on piles; open to the water on the west
	for z: float in [r.position.y, r.end.y]:
		b.span(Vector3(r.position.x, y - 1.5, z), Vector3(r.end.x, y - 1.5, z), 0.35, top - y + 1.5, wall)
	var cz := r.get_center().y
	b.span(Vector3(r.end.x, y - 1.5, r.position.y), Vector3(r.end.x, y - 1.5, cz - 0.9), 0.35, top - y + 1.5, wall)
	b.span(Vector3(r.end.x, y - 1.5, cz + 0.9), Vector3(r.end.x, y - 1.5, r.end.y), 0.35, top - y + 1.5, wall)
	b.span(Vector3(r.end.x, deck + 2.3, cz - 0.9), Vector3(r.end.x, deck + 2.3, cz + 0.9), 0.35, top - deck - 2.3, wall)
	# side walkways and a back landing round the boat slip
	for z: float in [r.position.y + 1.3, r.end.y - 1.3]:
		b.box(Vector3(r.get_center().x, deck - 0.1, z), Vector3(r.size.x, 0.2, 2.4), ManorGrounds.wood())
	b.box(Vector3(r.end.x - 1.3, deck - 0.1, r.get_center().y), Vector3(2.4, 0.2, r.size.y), ManorGrounds.wood())
	b.gable(Vector3(r.get_center().x, top, r.get_center().y), Vector3(r.size.x + 1.2, 3.0, r.size.y + 1.2), ManorGrounds.rose_roof())
	b.box(Vector3(r.position.x, top - 0.4, r.get_center().y), Vector3(0.3, 0.8, r.size.y), ManorGrounds.wood_dark(), false)
	_boat(b, Vector3(r.get_center().x - 1.0, y + 0.05, r.get_center().y), PI * 0.5)
	b.prop(&"lantern_hanging", Vector3(r.get_center().x, top - 1.0, r.get_center().y))
	b.prop(&"chest_trunk", Vector3(r.end.x - 1.3, deck, r.position.y + 2.5))
	# a ramp from the shore up to the back landing (the east wall has a doorway gap)
	b.ramp(Vector3(r.end.x + 3.5, ManorGrounds.ground(r.end.x + 3.5, r.get_center().y), r.get_center().y), 1.6, 3.0, deck - ManorGrounds.ground(r.end.x + 3.5, r.get_center().y), PI * 0.5, ManorGrounds.wood())


static func _boat(b: GroundsBatch, pos: Vector3, yaw: float) -> void:
	var hull := EstateKit.mat(EstateKit.ROSE, 0.4, 0.0, "boat_hull")
	var basis := Basis(Vector3.UP, yaw)
	b.box(pos + basis * Vector3(0, 0.25, 0), Vector3(1.4, 0.5, 4.0), hull, true, yaw)
	b.box(pos + basis * Vector3(0, 0.25, -2.3), Vector3(0.9, 0.5, 0.8), hull, false, yaw)
	b.box(pos + basis * Vector3(0, 0.5, 0), Vector3(1.2, 0.06, 0.4), ManorGrounds.wood(), false, yaw)
	b.box(pos + basis * Vector3(0, 0.52, 0), Vector3(1.5, 0.05, 3.8), ManorGrounds.gold(), false, yaw)


static func _island(b: GroundsBatch, y: float) -> void:
	for spec in [[ManorSitePlan.POND_ISLAND, ISLAND_R], [ManorSitePlan.POND_ISLET, ISLET_R]]:
		var p: Vector2 = spec[0]
		var r: float = spec[1]
		var base := Vector3(p.x, y - 3.0, p.y)
		b.cylinder(base, r + 0.3, 3.45, ManorGrounds.stone(), true, 24)
		b.cylinder(Vector3(p.x, y + 0.45, p.y), r, 0.1, ManorGrounds.grass(), false, 24)
	# island pavilion: six columns, a pearl dome, a bench
	var il := ManorSitePlan.POND_ISLAND
	var top := Vector3(il.x, y + 0.55, il.y)
	for i in 6:
		var a := TAU * i / 6.0
		b.cylinder(top + Vector3(cos(a), 0, sin(a)) * 2.6, 0.18, 3.2, ManorGrounds.marble(), true, 10)
	b.cylinder(top + Vector3.UP * 3.2, 3.0, 0.3, ManorGrounds.marble(), false, 18)
	b.sphere(top + Vector3.UP * 3.5, 2.9, ManorGrounds.pearl(), -1.0, true, 18)
	b.sphere(top + Vector3.UP * 6.5, 0.25, ManorGrounds.gold())
	b.prop(&"garden_bench", top + Vector3(0, 0, -1.2), PI)
	b.prop(&"faelight_orb", top + Vector3(0, 2.6, 0))
	# arched footbridge to the islet
	var a2 := il + Vector2(ISLAND_R - 0.2, 0.2)
	var b2 := ManorSitePlan.POND_ISLET + Vector2(-ISLET_R + 0.2, 0.0)
	var n := 8
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var p0 := a2.lerp(b2, t0)
		var p1 := a2.lerp(b2, t1)
		var h0 := y + 0.55 + 1.2 * sin(PI * t0)
		var h1 := y + 0.55 + 1.2 * sin(PI * t1)
		var d := p1 - p0
		var yaw := atan2(-d.y, d.x)
		var len := d.length()
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, atan2(h1 - h0, len))
		var mid := Vector3((p0.x + p1.x) * 0.5, (h0 + h1) * 0.5 - 0.1, (p0.y + p1.y) * 0.5)
		b.box(mid, Vector3(len + 0.05, 0.2, 1.8), ManorGrounds.wood(), true, 0.0, basis)
		for side: float in [-1.0, 1.0]:
			var off := Basis(Vector3.UP, yaw) * Vector3(0, 0, side * 0.9)
			b.box(mid + off + Vector3.UP * 0.9, Vector3(len + 0.05, 0.08, 0.08), ManorGrounds.pearl(), false, 0.0, basis)
			b.box(Vector3(p0.x, h0 + 0.45, p0.y) + off, Vector3(0.1, 0.9, 0.1), ManorGrounds.pearl(), false)
	b.prop(&"lamp_post", Vector3(ManorSitePlan.POND_ISLET.x + 1.5, y + 0.55, ManorSitePlan.POND_ISLET.y + 1.5))
