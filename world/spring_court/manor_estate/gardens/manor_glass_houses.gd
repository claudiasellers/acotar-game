## Two walkable glass houses: the domed palm house (estate landmark) and the
## orchid house. Iron-gold frames on a blush brick plinth, glass panes with
## collision, glass gable roofs, doorways at both ends, tiled floors, planters
## of exotic flowers, orange trees, palms and a little fountain.
class_name ManorGlassHouses
extends RefCounted

const WALL_H := 6.0
const ROOF_H := 4.0
const BAY := 3.0
const DOOR_W := 2.6
const DOME_R := 8.0
const DRUM_H := 5.0


static func houses() -> Array[Rect2]:
	return [ManorSitePlan.PALM_HOUSE, ManorSitePlan.ORCHID_HOUSE]


static func footprints() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in houses():
		out.append(r.grow(0.6))
	return out


static func dome_top() -> Vector3:
	var c := ManorSitePlan.PALM_HOUSE.get_center()
	return Vector3(c.x, ManorGrounds.ground(c.x, c.y) + WALL_H + DRUM_H + DOME_R + 2.6, c.y)


## Interior planter rows: [Rect2 planter footprint] per house.
static func planters(house: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var c := house.get_center()
	var inner := house.grow(-2.5)
	for side: float in [-1.0, 1.0]:
		var x := inner.position.x
		while x + 4.0 < inner.end.x:
			if absf(x + 2.0 - c.x) > 5.0:
				out.append(Rect2(x, c.y + side * (house.size.y * 0.5 - 3.6) - 0.7, 4.0, 1.4))
			x += 5.5
	return out


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("glass_houses_plant")
	var exotic := [&"deco_peony", &"deco_tulip_bed", &"ing_iris", &"ing_rose_white", &"ing_rose_gold", &"ing_lilac"]
	for h in houses().size():
		var house := houses()[h]
		for p in planters(house):
			var y := ManorGrounds.ground(p.get_center().x, p.get_center().y) + 0.7
			for k in 4:
				var x := p.position.x + 0.5 + k * 1.0
				var id: StringName = exotic[(k + h * 2 + int(p.position.x)) % exotic.size()]
				sb.put_at(id, Vector3(x, y, p.get_center().y), rng.randf() * TAU, 0.7 if id == &"ing_lilac" else 0.85)
		# dew on the glass-house roses, windfall oranges, wisteria at the doors
		for k in 6:
			sb.put(&"ing_rose_maze_dew", house.position.x + rng.randf_range(3, house.size.x - 3), house.get_center().y + rng.randf_range(-2.5, 2.5), rng.randf() * TAU)
		for k in 6:
			sb.put(&"ing_manor_fruit", house.position.x + rng.randf_range(3, house.size.x - 3), house.get_center().y + rng.randf_range(-1.5, 1.5), rng.randf() * TAU, 0.8)
		for side: float in [-1.0, 1.0]:
			var dz: float = house.get_center().y + side * (house.size.y * 0.5 + 1.2)
			sb.put(&"ing_wisteria", house.get_center().x - 2.2, dz, 0.0, 0.8)
			sb.put(&"ing_wisteria", house.get_center().x + 2.2, dz, 0.0, 0.8)
		var cols := [&"col_pressed_violet", &"col_pearl_button", &"col_garden_key", &"col_shell_comb"]
		for k in 2:
			sb.put(cols[(h * 2 + k) % cols.size()], house.position.x + 4.0 + k * (house.size.x - 8.0), house.get_center().y + 1.0, 0.0)


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "GlassHouses")
	for i in houses().size():
		_house(b, houses()[i], i == 0)
	b.flush()
	var dome := Node3D.new()
	dome.name = "PalmHouseDome"
	dome.position = dome_top()
	b.root.add_child(dome)
	ManorGrounds.landmark(dome, "palm_house_dome")
	b.root.set_meta(&"house_count", houses().size())


static func _house(b: GroundsBatch, r: Rect2, domed: bool) -> void:
	var c := r.get_center()
	var y := ManorGrounds.ground(c.x, c.y)
	var frame := ManorGrounds.iron_gold()
	var glass := ManorGrounds.glass()
	var brick := ManorGrounds.brick()
	# floor: mint and cream tiles
	b.box(Vector3(c.x, y + 0.05, c.y), Vector3(r.size.x, 0.1, r.size.y), EstateKit.mat(EstateKit.CREAM, 0.35, 0.0, "glass_floor"), true)
	for i in int(r.size.x / 2.0):
		b.box(Vector3(r.position.x + 1.0 + i * 2.0, y + 0.105, c.y), Vector3(1.0, 0.01, r.size.y - 1.0), EstateKit.mat(EstateKit.MINT, 0.35, 0.0, "glass_floor_mint"), false)
	# four walls: plinth, posts, panes; doors in the middle of the short (x) ends? the long sides face N/S
	var walls := [
		[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), true],   # north, door
		[Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), true],             # south, door
		[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), false],
		[Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), false],
	]
	for w in walls:
		var a: Vector2 = w[0]
		var e: Vector2 = w[1]
		var length := a.distance_to(e)
		var n := maxi(1, roundi(length / BAY))
		var dir := (e - a) / length
		var yaw := atan2(-dir.y, dir.x)
		var mid := (a + e) * 0.5
		for k in n + 1:
			var p := a + dir * (length * k / n)
			b.box(Vector3(p.x, y + WALL_H * 0.5, p.y), Vector3(0.22, WALL_H, 0.22), frame, false)
		for k in n:
			var p0 := a + dir * (length * k / n)
			var p1 := a + dir * (length * (k + 1) / n)
			var pm := (p0 + p1) * 0.5
			var seg := length / n
			var is_door: bool = w[2] and pm.distance_to(mid) < seg * 0.6
			if is_door:
				# doorway: gilt frame and a fanlight above the opening
				b.box(Vector3(pm.x, y + 2.9, pm.y), Vector3(seg, 0.2, 0.25), frame, false, yaw)
				b.box(Vector3(pm.x, y + 2.9 + (WALL_H - 2.9) * 0.5, pm.y), Vector3(seg, WALL_H - 2.9, 0.05), glass, true, yaw)
				continue
			b.box(Vector3(pm.x, y + 0.35, pm.y), Vector3(seg, 0.7, 0.4), brick, false, yaw)
			b.box(Vector3(pm.x, y + 0.7 + (WALL_H - 0.7) * 0.5, pm.y), Vector3(seg, WALL_H - 0.7, 0.05), glass, false, yaw)
			b.box(Vector3(pm.x, y + 3.2, pm.y), Vector3(seg, 0.08, 0.1), frame, false, yaw)
			b.add_box_shape(Transform3D(Basis(Vector3.UP, yaw), Vector3(pm.x, y + WALL_H * 0.5, pm.y)), Vector3(seg, WALL_H, 0.3))
	b.box(Vector3(c.x, y + WALL_H, c.y), Vector3(r.size.x + 0.3, 0.25, r.size.y + 0.3), frame, false)
	# glass gable roof, ridge along x
	var half := r.size.y * 0.5
	var slope := atan2(ROOF_H, half)
	var pane_len := sqrt(half * half + ROOF_H * ROOF_H)
	for side: float in [-1.0, 1.0]:
		var basis := Basis(Vector3.RIGHT, side * slope)
		var center := Vector3(c.x, y + WALL_H + ROOF_H * 0.5, c.y + side * half * 0.5)
		b.box(center, Vector3(r.size.x, 0.05, pane_len), glass, false, 0.0, basis)
		var x := r.position.x
		while x <= r.end.x + 0.01:
			b.box(Vector3(x, center.y, center.z), Vector3(0.14, 0.14, pane_len), frame, false, 0.0, basis)
			x += BAY
	b.box(Vector3(c.x, y + WALL_H + ROOF_H, c.y), Vector3(r.size.x + 0.4, 0.3, 0.3), frame, false)
	for i in int(r.size.x / 6.0) + 1:
		b.cone(Vector3(r.position.x + i * 6.0, y + WALL_H + ROOF_H + 0.15, c.y), 0.12, 0.8, ManorGrounds.gold(), 6)
	if domed:
		var base := Vector3(c.x, y + WALL_H, c.y)
		# drum of glass with gold bands, then the dome, lantern and finial
		b.cylinder(base, DOME_R, DRUM_H, glass, false, 24)
		for t: float in [0.0, DRUM_H * 0.5, DRUM_H]:
			b.torus(base + Vector3.UP * t, DOME_R - 0.12, DOME_R + 0.12, frame)
		for i in 16:
			var a := TAU * i / 16.0
			b.box(base + Vector3(cos(a) * DOME_R, DRUM_H * 0.5, sin(a) * DOME_R), Vector3(0.18, DRUM_H, 0.18), frame, false)
		b.sphere(base + Vector3.UP * DRUM_H, DOME_R, glass, -1.0, true, 24)
		for k: float in [0.35, 0.65, 0.88]:
			var rr: float = DOME_R * sqrt(1.0 - k * k)
			b.torus(base + Vector3.UP * (DRUM_H + DOME_R * k), rr - 0.1, rr + 0.1, frame)
		for i in 8:
			var a := TAU * i / 8.0
			b.torus(base + Vector3.UP * DRUM_H, DOME_R - 0.1, DOME_R + 0.1, frame, Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5))
		var top := base + Vector3.UP * (DRUM_H + DOME_R)
		b.cylinder(top - Vector3.UP * 0.3, 1.2, 1.6, glass, false, 12)
		b.cone(top + Vector3.UP * 1.3, 1.4, 1.0, ManorGrounds.gold(), 12)
		b.sphere(top + Vector3.UP * 2.5, 0.35, ManorGrounds.gold())
		# palm-house centre: fountain under the dome, palms round it
		b.prop(&"fountain_small", Vector3(c.x, y + 0.1, c.y))
		for i in 6:
			var a := TAU * i / 6.0
			b.prop(&"potted_palm", Vector3(c.x + cos(a) * 5.5, y + 0.1, c.y + sin(a) * 4.0), a)
	else:
		b.prop(&"birdcage_gilt", Vector3(c.x, y + 0.1, c.y))
	# planters, orange trees, ferns, benches
	for p in planters(r):
		b.prop(&"planter_box", Vector3(p.get_center().x, y + 0.1, p.get_center().y), 0.0, 1.0)
		b.box(Vector3(p.get_center().x, y + 0.75, p.get_center().y), Vector3(p.size.x, 0.06, p.size.y - 0.2), ManorGrounds.soil(), false)
	var x2 := r.position.x + 3.0
	while x2 < r.end.x - 2.0:
		if absf(x2 - c.x) > 6.0:
			b.prop(&"orange_tree_tub", Vector3(x2, y + 0.1, c.y + 1.6))
			b.prop(&"fern_pot", Vector3(x2 + 1.5, y + 0.1, c.y - 1.6))
		x2 += 7.0
	b.prop(&"garden_bench", Vector3(c.x - 7.5, y + 0.1, c.y), PI * 0.5)
	b.prop(&"garden_bench", Vector3(c.x + 7.5, y + 0.1, c.y), -PI * 0.5)
	# gravel apron and walk to the doors
	for side: float in [-1.0, 1.0]:
		var dz: float = c.y + side * (r.size.y * 0.5 + 3.0)
		b.drape_path(PackedVector2Array([Vector2(c.x, dz - side * 2.5), Vector2(c.x, dz + side * 3.0)]), 3.0, ManorGrounds.gravel())
