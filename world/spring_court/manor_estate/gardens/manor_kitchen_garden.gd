## The kitchen garden beside the service wing: a blush brick wall with two
## gateways, twelve raised beds of vegetables and herbs, espaliered fruit on the
## north wall, a potting shed, a well with a little roof, beehives, a water
## butt, a flower cart and produce baskets.
class_name ManorKitchenGarden
extends RefCounted

const WALL_H := 1.6
const SHED := Rect2(148.0, -77.0, 10.0, 7.0)
const WELL := Vector2(126.0, -27.0)
const HIVES := [Vector2(152.0, -26.0), Vector2(155.5, -26.0), Vector2(159.0, -26.0)]
const BED_SIZE := Vector2(8.0, 3.0)


static func footprints() -> Array[Rect2]:
	return [SHED.grow(0.8), ManorGrounds.circle_rect(WELL, 2.0)]


static func beds() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for col in 4:
		for row in 3:
			var c := Vector2(100.0 + col * 13.0, -64.0 + row * 9.0)
			out.append(Rect2(c - BED_SIZE * 0.5, BED_SIZE))
	return out


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("kitchen_garden_plant")
	var i := 0
	for bed in beds():
		var y := ManorGrounds.ground(bed.get_center().x, bed.get_center().y) + 0.55
		var kind := i % 4
		for k in 7:
			var x := bed.position.x + 0.6 + k * 1.15
			for row: float in [-0.7, 0.7]:
				var pos := Vector3(x, y, bed.get_center().y + row)
				match kind:
					0: sb.put_at(&"deco_vegetable_row", pos, 0.0, 0.9)
					1: sb.put_at(&"deco_herb_patch", pos, rng.randf() * TAU, 0.9)
					2: sb.put_at(&"ing_wild_strawberry" if k % 2 == 0 else &"deco_vegetable_row", pos, rng.randf() * TAU)
					3: sb.put_at(&"ing_lavender" if row < 0.0 else &"ing_madder", pos, rng.randf() * TAU, 0.8)
		i += 1
	# espaliered fruit on the north wall, windfalls below
	var g := ManorSitePlan.KITCHEN_GARDEN
	var x2 := g.position.x + 4.0
	while x2 < SHED.position.x - 2.0:
		sb.put(&"ing_manor_fruit", x2, g.position.y + 1.6, rng.randf() * TAU, 0.8)
		x2 += 6.0
	# honey at the hives
	for h in HIVES:
		sb.put(&"ing_honey", h.x, h.y + 1.0, rng.randf() * TAU)
	# snail shells along the bed edges
	for bed in beds():
		if rng.randf() < 0.5:
			sb.put(&"ing_snail_shell", bed.end.x + 0.6, bed.position.y + rng.randf() * bed.size.y, rng.randf() * TAU)


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "KitchenGarden")
	var g := ManorSitePlan.KITCHEN_GARDEN
	var brick := ManorGrounds.brick()
	var cap := ManorGrounds.marble()
	var y := ManorGrounds.ground(g.get_center().x, g.get_center().y)
	# wall with a west gate (to the service yard) and a south gate
	var west_gate := Vector2(g.position.x, -50.0)
	var south_gate := Vector2(126.0, g.end.y)
	_wall(b, Vector2(g.position.x, g.position.y), Vector2(g.end.x, g.position.y), brick, cap, Vector2.INF)
	_wall(b, Vector2(g.position.x, g.position.y), Vector2(g.position.x, g.end.y), brick, cap, west_gate)
	_wall(b, Vector2(g.end.x, g.position.y), Vector2(g.end.x, g.end.y), brick, cap, Vector2.INF)
	_wall(b, Vector2(g.position.x, g.end.y), Vector2(g.end.x, g.end.y), brick, cap, south_gate)
	for gate: Vector2 in [west_gate, south_gate]:
		b.prop(&"arch_trellis", Vector3(gate.x, ManorGrounds.ground(gate.x, gate.y), gate.y), PI * 0.5 if gate == west_gate else 0.0)
	# raised beds
	var plank := ManorGrounds.wood()
	for bed in beds():
		var c := bed.get_center()
		var by := ManorGrounds.ground(c.x, c.y)
		b.box(Vector3(c.x, by + 0.25, c.y), Vector3(bed.size.x, 0.5, bed.size.y), plank)
		b.box(Vector3(c.x, by + 0.52, c.y), Vector3(bed.size.x - 0.3, 0.06, bed.size.y - 0.3), ManorGrounds.soil(), false)
	# gravel walks
	b.drape_path(PackedVector2Array([Vector2(g.position.x, -50.0), Vector2(g.end.x - 2.0, -50.0)]), 2.4, ManorGrounds.gravel())
	b.drape_path(PackedVector2Array([Vector2(126.0, g.end.y), Vector2(126.0, g.position.y + 3.0)]), 2.4, ManorGrounds.gravel())
	# espalier trellis on the north wall: posts, wires, flattened fan trees with fruit
	var leaf := EstateKit.mat(Color(0.42, 0.76, 0.40), 0.8, 0.0, "espalier_leaf")
	var fruit := EstateKit.mat(Color(1.0, 0.52, 0.48), 0.4, 0.0, "espalier_fruit")
	var wz := g.position.y + 0.5
	var x := g.position.x + 4.0
	while x < SHED.position.x - 2.0:
		var ty := ManorGrounds.ground(x, wz)
		b.box(Vector3(x, ty + 0.6, wz), Vector3(0.18, 1.2, 0.18), ManorGrounds.wood_dark(), false)
		for arm in 3:
			var h := 0.5 + arm * 0.45
			b.box(Vector3(x, ty + h, wz + 0.1), Vector3(4.6 - arm * 0.9, 0.08, 0.08), ManorGrounds.wood_dark(), false)
			b.box(Vector3(x, ty + h + 0.12, wz + 0.15), Vector3(4.4 - arm * 0.9, 0.26, 0.1), leaf, false)
			for f in 3:
				b.sphere(Vector3(x - 1.2 + f * 1.2, ty + h - 0.08, wz + 0.25), 0.11, fruit, -1.0, false, 8)
		x += 6.0
	ManorGrounds.cottage(b, SHED, 2.8, ManorGrounds.plaster(), ManorGrounds.rose_roof(), "s", 1.4)
	var sy := ManorGrounds.ground(SHED.get_center().x, SHED.get_center().y)
	b.prop(&"table_work", Vector3(SHED.get_center().x, sy + 0.1, SHED.position.y + 1.2))
	b.prop(&"fern_pot", Vector3(SHED.position.x + 1.2, sy + 0.1, SHED.end.y - 1.2))
	b.prop(&"crate", Vector3(SHED.end.x - 1.2, sy + 0.1, SHED.end.y - 1.4))
	_well(b)
	# hives, water butt, cart, baskets
	for h in HIVES:
		var hy := ManorGrounds.ground(h.x, h.y)
		b.box(Vector3(h.x, hy + 0.25, h.y), Vector3(0.7, 0.5, 0.7), ManorGrounds.wood(), true)
		for k in 3:
			b.box(Vector3(h.x, hy + 0.7 + k * 0.32, h.y), Vector3(0.62, 0.3, 0.62), EstateKit.mat(EstateKit.BUTTER if k % 2 == 0 else EstateKit.PEARL, 0.6), false)
		b.gable(Vector3(h.x, hy + 1.6, h.y), Vector3(0.8, 0.3, 0.8), ManorGrounds.rose_roof())
	b.prop_on_ground(&"barrel", SHED.position.x - 1.2, SHED.end.y - 0.6)
	b.prop_on_ground(&"cart_flower", 140.0, -24.0, 0.3)
	for p: Vector2 in [Vector2(108, -46), Vector2(134, -55), Vector2(118, -37)]:
		b.prop_on_ground(&"basket_produce", p.x, p.y)
	b.prop_on_ground(&"garden_bench", 96.0, -24.0, PI)
	b.prop_on_ground(&"sundial", 126.0, -50.0)
	b.flush()


static func _wall(b: GroundsBatch, a: Vector2, c: Vector2, m: Material, cap: Material, gate: Vector2) -> void:
	var length := a.distance_to(c)
	var dir := (c - a) / length
	var n := ceili(length / 6.0)
	for k in n:
		var p0 := a + dir * length * k / n
		var p1 := a + dir * length * (k + 1) / n
		if gate != Vector2.INF:
			var t := (gate - a).dot(dir)
			var t0 := length * k / n
			var t1 := length * (k + 1) / n
			if t1 > t - 1.6 and t0 < t + 1.6:
				# cut the gate gap out of this segment
				if t0 < t - 1.6:
					_wall_piece(b, p0, a + dir * (t - 1.6), m, cap)
				if t1 > t + 1.6:
					_wall_piece(b, a + dir * (t + 1.6), p1, m, cap)
				continue
		_wall_piece(b, p0, p1, m, cap)


static func _wall_piece(b: GroundsBatch, p0: Vector2, p1: Vector2, m: Material, cap: Material) -> void:
	var mid := (p0 + p1) * 0.5
	var y := ManorGrounds.ground(mid.x, mid.y)
	b.span(Vector3(p0.x, y - 0.4, p0.y), Vector3(p1.x, y - 0.4, p1.y), 0.5, WALL_H + 0.4, m)
	b.span(Vector3(p0.x, y + WALL_H, p0.y), Vector3(p1.x, y + WALL_H, p1.y), 0.65, 0.12, cap, false)


static func _well(b: GroundsBatch) -> void:
	var y := ManorGrounds.ground(WELL.x, WELL.y)
	var base := Vector3(WELL.x, y, WELL.y)
	b.cylinder(base, 1.3, 0.95, ManorGrounds.stone(), true, 16)
	b.disc(base + Vector3.UP * 0.6, Vector2.ONE * 1.0, ManorGrounds.water(), 16)
	for side: float in [-1.0, 1.0]:
		b.box(base + Vector3(side * 1.15, 1.5, 0), Vector3(0.18, 2.1, 0.18), ManorGrounds.wood(), false)
	b.box(base + Vector3(0, 2.2, 0), Vector3(2.4, 0.14, 0.14), ManorGrounds.wood(), false)
	b.gable(base + Vector3(0, 2.5, 0), Vector3(2.9, 0.9, 1.9), ManorGrounds.rose_roof())
	b.cylinder(base + Vector3(0, 1.4, 0), 0.22, 0.32, ManorGrounds.wood_dark(), false, 10)
