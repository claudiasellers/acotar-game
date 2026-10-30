## Kitchen, pantry, laundry, bath and stillroom: copper, crockery, bread, cheese,
## herbs, potions, claw-foot tubs. Warm and cosy, still in the candy palette.
class_name ServiceShapes
extends RefCounted


enum Fill { CROCKERY, JARS, CHEESE, PANTRY, LINEN, VIALS, BANDAGES, BOTTLES }


static func build(k: PropMeshKit, id: StringName, s: Vector3, c: Color) -> bool:
	match id:
		&"table_kitchen": _kitchen_table(k, s, c)
		&"hearth_kitchen": _hearth(k, s, c)
		&"range_iron": _range(k, s, c)
		&"bread_oven": _bread_oven(k, s, c)
		&"copper_pots": _copper_pots(k, s, c)
		&"pot_rack_hanging": _pot_rack(k, s, c)
		&"dresser_crockery": _shelves(k, id, s, c, Fill.CROCKERY, 4, true)
		&"sink_stone": _sink(k, s, c)
		&"barrel": _barrel(k, Vector3(0, 0, 0), s.x * 0.5, s.y, PropMats.wood(c))
		&"barrel_rack": _barrel_rack(k, s, c)
		&"crate": _crate(k, s, c)
		&"sack_flour": _sack(k, s, c)
		&"basket_produce": _basket(k, s, c)
		&"herb_bundle_hanging": _herb_bundles(k, s, c)
		&"cheese_shelf": _shelves(k, id, s, c, Fill.CHEESE, 4, false)
		&"wine_rack": _wine_rack(k, s, c)
		&"cake_stand": _cake(k, s, c)
		&"pantry_shelf": _shelves(k, id, s, c, Fill.PANTRY, 5, false)
		&"laundry_tub": _laundry_tub(k, s, c)
		&"drying_line": _drying_line(k, s, c)
		&"ironing_table": _ironing(k, s, c)
		&"linen_press": _shelves(k, id, s, c, Fill.LINEN, 4, true)
		&"stillroom_bench": _still_bench(k, s, c)
		&"alembic": _alembic(k, s, c)
		&"drying_rack_herbs": _herb_rack(k, s, c)
		&"apothecary_cabinet": _apothecary(k, s, c)
		&"mortar_pestle": _mortar(k, s, c)
		&"vial_rack": _vial_rack(k, s, c)
		&"infirmary_cot": _cot(k, s, c)
		&"bandage_shelf": _shelves(k, id, s, c, Fill.BANDAGES, 4, false)
		&"bathtub_clawfoot": _tub(k, s, c)
		&"bath_sunken": _sunken(k, s, c)
		&"washstand": _washstand(k, s, c)
		&"towel_rack": _towel_rack(k, s, c)
		&"soap_shelf": _soap_shelf(k, s, c)
		_: return false
	return true


static func _kitchen_table(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y - 0.04, 0), Vector3(s.x, 0.08, s.z))
	PropParts.legs4(k, wood, s.x, s.z, s.y - 0.08, 0.06, 2, 0.12)
	k.box(wood, Vector3(0, 0.2, 0), Vector3(s.x * 0.86, 0.05, s.z * 0.8))
	# bread loaves, a pie, a bowl of berries, a rolling pin and a gingham cloth
	k.box(PropMats.fabric(EstateKit.BLUSH), Vector3(-s.x * 0.2, s.y + 0.003, 0), Vector3(s.x * 0.3, 0.006, s.z * 0.7))
	for i in 2:
		k.sphere(PropMats.satin(Color(0.96, 0.72, 0.45)), Vector3(-s.x * 0.25 + i * 0.25, s.y + 0.05, -0.1), Vector3(0.14, 0.07, 0.08), 10, 5,
				Transform3D.IDENTITY, true)
	k.cyl(PropMats.satin(Color(0.98, 0.78, 0.5)), Vector3(s.x * 0.15, s.y, 0.15), 0.15, 0.13, 0.05, 14)
	k.disc(PropMats.satin(PropMats.BERRY), Vector3(s.x * 0.15, s.y + 0.051, 0.15), 0.12, 12)
	k.lathe(PropMats.pearl(EstateKit.MINT), Vector3(s.x * 0.35, s.y, -0.1), PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0),
			Vector2(0.13, 0.08), Vector2(0.12, 0.09), Vector2(0, 0.06)]), 12)
	for i in 6:
		var a := TAU * i / 6.0
		k.sphere(PropMats.gloss(Color(0.95, 0.25, 0.35)), Vector3(s.x * 0.35 + cos(a) * 0.05, s.y + 0.08, -0.1 + sin(a) * 0.05), Vector3.ONE * 0.025, 5, 3)
	k.cyl(PropMats.wood(EstateKit.OAK.lightened(0.2)), Vector3(0, -0.2, 0), 0.03, 0.03, 0.4, 8, true,
			PropMeshKit.at(Vector3(s.x * 0.4, s.y + 0.03, 0.3), 0.3, 0, PI * 0.5))


static func _hearth(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var stone := PropMats.satin(c)
	var gold := PropMats.gold()
	var copper := PropMats.metal(PropMats.COPPER)
	var ow := s.x * 0.62
	var oh := s.y * 0.55
	k.box(PropMats.satin(PropMats.PLUM), Vector3(0, oh * 0.5, s.z * 0.2), Vector3(ow, oh, s.z * 0.6))
	for sx: float in [-1.0, 1.0]:
		k.box(stone, Vector3(sx * (ow * 0.5 + (s.x - ow) * 0.25), s.y * 0.35, 0), Vector3((s.x - ow) * 0.5, s.y * 0.7, s.z))
	k.box(stone, Vector3(0, oh + (s.y * 0.7 - oh) * 0.5, 0), Vector3(ow, s.y * 0.7 - oh, s.z))
	k.box(PropMats.wood(EstateKit.OAK_DARK), Vector3(0, s.y * 0.72, -s.z * 0.05), Vector3(s.x * 1.02, 0.1, s.z * 1.05))
	k.box(stone, Vector3(0, s.y * 0.87, s.z * 0.15), Vector3(s.x * 0.7, s.y * 0.26, s.z * 0.7))
	# fire, a hanging cauldron on a crane, spit
	for i in 5:
		var x := -ow * 0.3 + i * ow * 0.15
		k.cyl(PropMats.glow(Color(1.0, 0.62, 0.40), 3.0), Vector3(x, 0.08, s.z * 0.15), 0.1, 0.0, oh * (0.3 + 0.12 * float(i % 2)), 6)
	k.lathe(PropMats.metal(PropMats.IRON), Vector3(0, oh * 0.3, s.z * 0.1), PackedVector2Array([Vector2(0, 0), Vector2(0.15, 0.03),
			Vector2(0.22, 0.15), Vector2(0.2, 0.3), Vector2(0.18, 0.32), Vector2(0, 0.3)]), 12)
	k.tube(PropMats.metal(PropMats.IRON), PackedVector3Array([Vector3(0, oh * 0.3 + 0.32, s.z * 0.1), Vector3(0, oh * 0.95, s.z * 0.1)]), 0.01, 4)
	k.tube(PropMats.metal(PropMats.IRON), PackedVector3Array([Vector3(-ow * 0.48, oh * 0.6, -s.z * 0.1), Vector3(ow * 0.48, oh * 0.6, -s.z * 0.1)]), 0.012, 4)
	# mantel: copper pans, crocks, a rose jug
	for i in 4:
		var x := -s.x * 0.36 + i * s.x * 0.24
		k.cyl(copper if i % 2 == 0 else PropMats.pearl(EstateKit.BUTTER), Vector3(x, s.y * 0.77, -s.z * 0.15), 0.08, 0.07, 0.12, 10)
	for i in 3:
		var x := -ow * 0.35 + i * ow * 0.35
		k.disc(copper, Vector3.ZERO, 0.13, 12, PropMeshKit.at(Vector3(x, s.y * 0.58, -s.z * 0.51), 0, -PI * 0.5))
		k.tube(copper, PackedVector3Array([Vector3(x, s.y * 0.45, -s.z * 0.51), Vector3(x, s.y * 0.35, -s.z * 0.51)]), 0.015, 4)


static func _range(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var iron := PropMats.metal(c)
	var gold := PropMats.gold()
	k.box(iron, Vector3(0, s.y * 0.45, 0), Vector3(s.x, s.y * 0.8, s.z))
	k.box(iron, Vector3(0, s.y * 0.88, 0), Vector3(s.x * 1.02, 0.05, s.z * 1.02))
	k.box(PropMats.metal(c.lightened(0.15)), Vector3(0, s.y * 0.95, s.z * 0.45), Vector3(s.x, s.y * 0.12, 0.1))
	for i in 3:
		var x := -s.x * 0.33 + i * s.x * 0.33
		k.box(PropMats.metal(c.lightened(0.1)), Vector3(x, s.y * 0.4, -s.z * 0.505), Vector3(s.x * 0.28, s.y * 0.4, 0.02))
		k.tube(gold, PackedVector3Array([Vector3(x - 0.1, s.y * 0.62, -s.z * 0.53), Vector3(x + 0.1, s.y * 0.62, -s.z * 0.53)]), 0.012, 4)
		k.torus(gold, Vector3(x, s.y * 0.91, 0), 0.15, 0.015, 12, 3)
	k.box(gold, Vector3(0, s.y * 0.1, -s.z * 0.505), Vector3(s.x * 0.96, 0.03, 0.02))
	k.cyl(PropMats.metal(PropMats.IRON), Vector3(s.x * 0.35, s.y * 0.95, s.z * 0.3), 0.12, 0.12, s.y * 0.05, 8)
	k.lathe(PropMats.metal(PropMats.COPPER), Vector3(-s.x * 0.33, s.y * 0.92, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.14, 0),
			Vector2(0.15, 0.18), Vector2(0, 0.18)]), 10)
	k.lathe(PropMats.pearl(EstateKit.ROSE), Vector3(0, s.y * 0.92, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.08, 0),
			Vector2(0.1, 0.1), Vector2(0.05, 0.16), Vector2(0.02, 0.2), Vector2(0, 0.2)]), 10)


static func _bread_oven(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var stone := PropMats.satin(c)
	k.box(stone, Vector3(0, s.y * 0.2, 0), Vector3(s.x, s.y * 0.4, s.z))
	k.sphere(stone, Vector3(0, s.y * 0.4, 0), Vector3(s.x * 0.5, s.y * 0.6, s.z * 0.5), 14, 6, Transform3D.IDENTITY, true)
	k.lathe(PropMats.satin(PropMats.PLUM), Vector3(0, s.y * 0.4, -s.z * 0.45), PackedVector2Array([Vector2(0, 0), Vector2(0.3, 0),
			Vector2(0.3, 0.15), Vector2(0.15, 0.27), Vector2(0, 0.3)]), 10, PropMeshKit.at(Vector3.ZERO, 0, -PI * 0.5, 0, Vector3(1, 1, 0.3)))
	k.tube(PropMats.satin(EstateKit.STONE_DARK), PropParts.arch_pts(0.7, s.y * 0.4, -s.z * 0.5, 10, 0.35), 0.05, 5)
	k.cyl(stone, Vector3(s.x * 0.2, s.y * 0.85, s.z * 0.2), 0.12, 0.1, s.y * 0.15, 8)
	k.cyl(PropMats.glow(Color(1.0, 0.6, 0.4), 2.5), Vector3(0, s.y * 0.4, -s.z * 0.38), 0.18, 0.0, 0.2, 6)
	for i in 3:
		k.sphere(PropMats.satin(Color(0.96, 0.72, 0.45)), Vector3(-0.15 + i * 0.15, s.y * 0.43, -s.z * 0.42), Vector3(0.07, 0.04, 0.05), 8, 4)
	# wooden peel resting against the side
	k.tube(PropMats.wood(EstateKit.OAK), PackedVector3Array([Vector3(s.x * 0.48, 0.05, -s.z * 0.3), Vector3(s.x * 0.5, s.y * 0.7, -s.z * 0.1)]), 0.02, 5)
	k.box(PropMats.wood(EstateKit.OAK), Vector3(s.x * 0.48, 0.15, -s.z * 0.32), Vector3(0.02, 0.3, 0.3))


static func _pot(k: PropMeshKit, m: Material, pos: Vector3, r: float, h: float, handle_dir: float) -> void:
	k.lathe(m, pos, PackedVector2Array([Vector2(0, 0), Vector2(r * 0.9, 0), Vector2(r, h * 0.2), Vector2(r, h), Vector2(r * 1.05, h),
			Vector2(r * 0.95, h * 0.95), Vector2(0, h * 0.1)]), 10)
	k.tube(PropMats.gold(), PackedVector3Array([pos + Vector3(r * handle_dir, h * 0.8, 0), pos + Vector3((r + r * 1.2) * handle_dir, h * 0.85, 0)]), 0.012, 4)


static func _copper_pots(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.metal(c)
	var n := 4
	for i in n:
		var r := s.z * (0.35 + 0.1 * (i % 2))
		_pot(k, m, Vector3(-s.x * 0.36 + i * s.x * 0.24, 0, 0), r, s.y * (0.5 + 0.15 * float(i % 3)), 1.0)
	k.sphere(PropMats.metal(c), Vector3(-s.x * 0.36, s.y * 0.72, 0), Vector3(0.03, 0.02, 0.03), 6, 3)


static func _pot_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var iron := PropMats.metal(PropMats.IRON)
	var copper := PropMats.metal(c)
	k.tube(iron, PropParts.ring_pts(Vector3(0, s.y - 0.02, 0), 0.5, 16), 0.015, 4, PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(s.x * 0.95, 1, s.z * 0.9)))
	for sx: float in [-1.0, 1.0]:
		k.tube(iron, PackedVector3Array([Vector3(sx * s.x * 0.4, s.y - 0.02, 0), Vector3(0, s.y, 0)]), 0.01, 4)
	for i in 5:
		var x := -s.x * 0.4 + i * s.x * 0.2
		var z := -s.z * 0.4 if i % 2 == 0 else s.z * 0.4
		k.tube(iron, PackedVector3Array([Vector3(x, s.y - 0.02, z), Vector3(x, s.y - 0.12, z)]), 0.006, 3)
		var r := 0.08 + 0.03 * float(i % 3)
		var t := PropMeshKit.at(Vector3(x, s.y - 0.14, z), 0, PI * 0.5)
		k.push(t)
		k.lathe(copper, Vector3(0, 0, 0), PackedVector2Array([Vector2(0, 0), Vector2(r, 0), Vector2(r * 1.05, 0.06), Vector2(0, 0.06)]), 10)
		k.pop()
		k.box(copper, Vector3(x, s.y - 0.14 - r - 0.1, z), Vector3(0.02, 0.18, 0.01))
	# a garland of garlic and dried chillies
	for i in 6:
		k.sphere(PropMats.pearl(EstateKit.CREAM), Vector3(-s.x * 0.25 + i * s.x * 0.1, s.y * 0.35, 0), Vector3.ONE * 0.03, 6, 3)


static func _shelves(k: PropMeshKit, id: StringName, s: Vector3, c: Color, fill: Fill, rows: int, doors: bool) -> void:
	var body := PropMats.body(c) if fill == Fill.CROCKERY or fill == Fill.LINEN else PropMats.wood(c)
	var rnd := PropParts.rng(id)
	var base_h := s.y * 0.38 if doors else 0.08
	k.box(body, Vector3(0, s.y * 0.5, s.z * 0.46), Vector3(s.x, s.y, s.z * 0.08))
	for sx: float in [-1.0, 1.0]:
		k.box(body, Vector3(sx * s.x * 0.48, s.y * 0.5, 0), Vector3(s.x * 0.04, s.y, s.z))
	k.box(body, Vector3(0, s.y - 0.03, 0), Vector3(s.x * 1.03, 0.06, s.z * 1.04))
	if doors:
		k.box(body, Vector3(0, base_h * 0.5, 0), Vector3(s.x * 0.96, base_h, s.z * 0.96))
		for sx: float in [-1.0, 1.0]:
			k.box(PropMats.pearl(EstateKit.CREAM) if fill == Fill.CROCKERY else PropMats.pearl(EstateKit.BLUSH),
					Vector3(sx * s.x * 0.24, base_h * 0.5, -s.z * 0.49), Vector3(s.x * 0.44, base_h * 0.8, 0.02))
			k.sphere(PropMats.gold(), Vector3(sx * 0.05, base_h * 0.55, -s.z * 0.51), Vector3.ONE * 0.025, 5, 3)
	else:
		k.box(body, Vector3(0, base_h * 0.5, 0), Vector3(s.x * 0.96, base_h, s.z * 0.96))
	var span := (s.y - 0.06 - base_h) / rows
	var inner := s.x * 0.9
	for r in rows:
		var y := base_h + r * span
		k.box(body, Vector3(0, y, 0), Vector3(inner, 0.025, s.z * 0.92))
		var mh := span * 0.75
		var x := -inner * 0.5 + 0.06
		while x < inner * 0.5 - 0.08:
			var col: Color = PropMats.BOOKS[rnd.randi() % 8]
			var step := 0.0
			match fill:
				Fill.CROCKERY:
					# plates standing on the rail and cups hanging
					var pr := minf(mh * 0.45, 0.14)
					k.disc(PropMats.pearl(col.lightened(0.4)), Vector3.ZERO, pr, 10, PropMeshKit.at(Vector3(x + pr, y + pr + 0.02, s.z * 0.3), 0, -PI * 0.5 + 0.15))
					k.disc(PropMats.pearl(col), Vector3.ZERO, pr * 0.6, 8, PropMeshKit.at(Vector3(x + pr, y + pr + 0.02, s.z * 0.29), 0, -PI * 0.5 + 0.15))
					k.cyl(PropMats.pearl(col), Vector3(x + pr, y + 0.02, -s.z * 0.2), 0.035, 0.045, 0.07, 6)
					step = pr * 2.1
				Fill.JARS, Fill.PANTRY:
					var jr := rnd.randf_range(0.05, 0.08)
					var jh := mh * rnd.randf_range(0.5, 0.9)
					if rnd.randf() < 0.3 and fill == Fill.PANTRY:
						k.sphere(PropMats.fabric(PropMats.STRAW), Vector3(x + jr, y + jh * 0.4, 0), Vector3(jr * 1.3, jh * 0.4, jr * 1.2), 8, 4)
					else:
						k.cyl(PropMats.glass(Color(col.r, col.g, col.b, 0.7)), Vector3(x + jr, y + 0.012, 0), jr, jr, jh, 6)
						k.cyl(PropMats.fabric(EstateKit.BLUSH if rnd.randf() < 0.5 else EstateKit.CREAM), Vector3(x + jr, y + jh, 0), jr * 1.15, jr * 1.1, 0.02, 6)
					step = jr * 2.3
				Fill.CHEESE:
					var cr := rnd.randf_range(0.1, 0.16)
					k.cyl(PropMats.satin(Color(1.0, 0.86, 0.45)), Vector3(x + cr, y + 0.012, 0), cr, cr, minf(mh * 0.5, 0.12), 12)
					if rnd.randf() < 0.4:
						k.cyl(PropMats.satin(Color(1.0, 0.6, 0.55)), Vector3(x + cr, y + 0.012, 0), cr * 1.02, cr * 1.02, 0.02, 12)
					step = cr * 2.1
				Fill.LINEN, Fill.BANDAGES:
					var lw := rnd.randf_range(0.25, 0.35)
					var lc := col.lightened(0.45) if fill == Fill.LINEN else EstateKit.CREAM
					var stack := rnd.randi_range(2, 5)
					for j in stack:
						k.box(PropMats.fabric(lc if j % 2 == 0 else (EstateKit.BLUSH if fill == Fill.LINEN else EstateKit.PEARL)),
								Vector3(x + lw * 0.5, y + 0.03 + j * 0.05, 0), Vector3(lw, 0.048, s.z * 0.7))
					if fill == Fill.BANDAGES and rnd.randf() < 0.5:
						k.cyl(PropMats.fabric(EstateKit.PEARL), Vector3(x + lw * 0.5, y + 0.02 + stack * 0.05, 0), 0.04, 0.04, 0.06, 8)
					step = lw + 0.04
				_:
					step = 0.2
			x += step
	if fill == Fill.CROCKERY:
		k.tube(PropMats.gold(), PackedVector3Array([Vector3(-s.x * 0.45, s.y - 0.1, -s.z * 0.5), Vector3(s.x * 0.45, s.y - 0.1, -s.z * 0.5)]), 0.01, 4)
		for i in 7:
			PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(-s.x * 0.42 + i * s.x * 0.14, s.y - 0.03, -s.z * 0.52), 0.035)


static func _sink(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var stone := PropMats.satin(c)
	k.box(PropMats.wood(EstateKit.OAK), Vector3(0, s.y * 0.35, 0), Vector3(s.x * 0.95, s.y * 0.7, s.z * 0.95))
	k.box(PropMats.fabric(EstateKit.MINT), Vector3(0, s.y * 0.35, -s.z * 0.48), Vector3(s.x * 0.9, s.y * 0.6, 0.01))
	k.box(stone, Vector3(0, s.y * 0.72, 0), Vector3(s.x, 0.04, s.z))
	for sx: float in [-1.0, 1.0]:
		k.box(stone, Vector3(sx * s.x * 0.47, s.y * 0.86, 0), Vector3(s.x * 0.06, s.y * 0.28, s.z))
	for sz: float in [-1.0, 1.0]:
		k.box(stone, Vector3(0, s.y * 0.86, sz * s.z * 0.47), Vector3(s.x, s.y * 0.28, s.z * 0.06))
	k.box(PropMats.water(), Vector3(0, s.y * 0.88, 0), Vector3(s.x * 0.88, 0.01, s.z * 0.88))
	# a brass pump spout at the back
	var copper := PropMats.metal(PropMats.COPPER)
	k.cyl(copper, Vector3(s.x * 0.3, s.y, s.z * 0.4), 0.04, 0.04, 0.0 + s.y * 0.0 + 0.3, 8)
	k.tube(copper, PackedVector3Array([Vector3(s.x * 0.3, s.y + 0.25, s.z * 0.4), Vector3(s.x * 0.3, s.y + 0.28, s.z * 0.25), Vector3(s.x * 0.3, s.y + 0.2, s.z * 0.18)]), 0.025, 5)


static func _barrel(k: PropMeshKit, base: Vector3, r: float, h: float, m: Material, t: Transform3D = Transform3D.IDENTITY) -> void:
	k.lathe(m, base, PackedVector2Array([Vector2(0, 0), Vector2(r * 0.85, 0), Vector2(r * 0.97, h * 0.25), Vector2(r, h * 0.5),
			Vector2(r * 0.97, h * 0.75), Vector2(r * 0.85, h), Vector2(0, h)]), 12, t)
	var hoop := PropMats.metal(PropMats.IRON)
	for y: float in [0.1, 0.32, 0.68, 0.9]:
		var rr := r * (0.88 + 0.1 * sin(y * PI))
		k.torus(hoop, base + Vector3(0, h * y, 0), rr + 0.005, 0.012, 12, 3, t)


static func _barrel_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	var dark := PropMats.wood(EstateKit.OAK_DARK)
	for sz: float in [-1.0, 1.0]:
		k.box(dark, Vector3(0, 0.1, sz * s.z * 0.35), Vector3(s.x, 0.2, 0.1))
	var r := s.y * 0.27
	for i in 3:
		var x := -s.x * 0.33 + i * s.x * 0.33
		_barrel(k, Vector3(0, -s.z * 0.45, 0), r, s.z * 0.9, wood, PropMeshKit.at(Vector3(x, 0.2 + r, 0), 0, PI * 0.5))
		k.disc(PropMats.wood(c.lightened(0.15)), Vector3.ZERO, r * 0.85, 12, PropMeshKit.at(Vector3(x, 0.2 + r, -s.z * 0.451), 0, -PI * 0.5))
		k.cyl(PropMats.metal(PropMats.COPPER), Vector3(0, 0, 0), 0.02, 0.02, 0.08, 6, true, PropMeshKit.at(Vector3(x, 0.2 + r * 0.5, -s.z * 0.45), 0, -PI * 0.5))
	for i in 2:
		var x := -s.x * 0.165 + i * s.x * 0.33
		_barrel(k, Vector3(0, -s.z * 0.45, 0), r, s.z * 0.9, wood, PropMeshKit.at(Vector3(x, 0.2 + r * 2.7, 0), 0, PI * 0.5))
		k.disc(PropMats.wood(c.lightened(0.15)), Vector3.ZERO, r * 0.85, 12, PropMeshKit.at(Vector3(x, 0.2 + r * 2.7, -s.z * 0.451), 0, -PI * 0.5))


static func _crate(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	var light := PropMats.wood(c.lightened(0.15))
	k.box(wood, Vector3(0, s.y * 0.45, 0), Vector3(s.x * 0.96, s.y * 0.9, s.z * 0.96))
	for sz: float in [-1.0, 1.0]:
		k.box(light, Vector3(0, s.y * 0.45, sz * s.z * 0.49), Vector3(s.x, 0.06, 0.03), PropMeshKit.at(Vector3.ZERO, 0, 0, atan2(s.y, s.x) * 0.9))
		for y: float in [0.05, 0.85]:
			k.box(light, Vector3(0, s.y * y, sz * s.z * 0.49), Vector3(s.x, 0.08, 0.03))
	# apples and pears heaped over the top
	for i in 9:
		var a := TAU * i / 9.0
		var rr := 0.0 if i == 8 else s.x * 0.28
		k.sphere(PropMats.gloss(Color(0.95, 0.3, 0.38) if i % 3 else Color(0.8, 0.9, 0.4)), Vector3(cos(a) * rr, s.y * 0.92, sin(a) * rr * s.z / s.x),
				Vector3.ONE * 0.06, 7, 4)


static func _sack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var cloth := PropMats.fabric(c)
	k.lathe(cloth, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.42, 0.02), Vector2(s.x * 0.5, s.y * 0.3),
			Vector2(s.x * 0.45, s.y * 0.65), Vector2(s.x * 0.2, s.y * 0.82), Vector2(s.x * 0.1, s.y * 0.85), Vector2(s.x * 0.2, s.y),
			Vector2(0, s.y * 0.95)]), 10, PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, s.z / s.x)))
	k.torus(PropMats.fabric(EstateKit.ROSE), Vector3(0, s.y * 0.84, 0), s.x * 0.11, 0.015, 8, 3)
	k.disc(PropMats.fabric(EstateKit.PERIWINKLE), Vector3.ZERO, s.x * 0.15, 10, PropMeshKit.at(Vector3(0, s.y * 0.4, -s.z * 0.5), 0, -PI * 0.5 - 0.1))


static func _basket(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wicker := PropMats.fabric(c)
	k.lathe(wicker, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.38, 0), Vector2(s.x * 0.5, s.y * 0.5),
			Vector2(s.x * 0.48, s.y * 0.52), Vector2(0, s.y * 0.45)]), 12, PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, s.z / s.x)))
	for y: float in [0.15, 0.3, 0.45]:
		k.torus(PropMats.fabric(c.darkened(0.1)), Vector3(0, s.y * y, 0), s.x * (0.4 + y * 0.2), 0.01, 12, 3,
				PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, s.z / s.x)))
	k.tube(wicker, PropParts.arch_pts(s.x * 0.9, s.y * 0.5, 0, 10, s.y * 0.48), 0.015, 4)
	var produce := [Color(0.95, 0.3, 0.38), Color(1.0, 0.6, 0.25), Color(0.8, 0.9, 0.4), EstateKit.LILAC, Color(0.95, 0.3, 0.38)]
	for i in 7:
		var a := TAU * i / 7.0
		k.sphere(PropMats.gloss(produce[i % 5]), Vector3(cos(a) * s.x * 0.22, s.y * 0.5, sin(a) * s.z * 0.2), Vector3.ONE * 0.05, 6, 3)
	k.leaf(PropMats.satin(PropMats.LEAF), Vector3(0, s.y * 0.52, 0), Vector3(0.4, 0.7, 0.2), 0.15, 0.06, 0.4)


static func _herb_bundles(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(EstateKit.OAK)
	k.tube(wood, PackedVector3Array([Vector3(-s.x * 0.5, s.y - 0.03, 0), Vector3(s.x * 0.5, s.y - 0.03, 0)]), 0.025, 6)
	var cols := [c, EstateKit.LILAC, PropMats.LEAF, EstateKit.BUTTER, c, EstateKit.ROSE, EstateKit.MINT]
	for i in 7:
		var x := -s.x * 0.42 + i * s.x * 0.14
		k.tube(PropMats.fabric(PropMats.STRAW), PackedVector3Array([Vector3(x, s.y - 0.03, 0), Vector3(x, s.y - 0.12, 0)]), 0.005, 3)
		k.cyl(PropMats.satin(cols[i]), Vector3(x, s.y * 0.15, 0), 0.07, 0.015, s.y * 0.7, 7)
		k.torus(PropMats.satin(EstateKit.ROSE), Vector3(x, s.y * 0.8, 0), 0.02, 0.006, 6, 3)


static func _wine_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y * 0.5, s.z * 0.46), Vector3(s.x, s.y, s.z * 0.08))
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * s.x * 0.48, s.y * 0.5, 0), Vector3(s.x * 0.04, s.y, s.z))
	k.box(wood, Vector3(0, s.y - 0.03, 0), Vector3(s.x, 0.06, s.z))
	var rows := 7
	var cols := 8
	var glass_cols := [Color(0.6, 0.2, 0.4, 0.9), Color(0.85, 0.75, 0.4, 0.9), Color(0.5, 0.75, 0.5, 0.9), Color(0.9, 0.5, 0.6, 0.9)]
	for r in rows:
		var y := 0.1 + r * (s.y - 0.2) / rows
		k.box(wood, Vector3(0, y - 0.07, 0), Vector3(s.x * 0.92, 0.02, s.z * 0.9))
		for ci in cols:
			if (r * 3 + ci * 5) % 7 == 0:
				continue
			var x := -s.x * 0.41 + ci * s.x * 0.82 / (cols - 1)
			k.cyl(PropMats.glass(glass_cols[(r + ci) % 4]), Vector3(0, 0, 0), 0.04, 0.04, s.z * 0.6, 6, true,
					PropMeshKit.at(Vector3(x, y, -s.z * 0.4), 0, PI * 0.5))
			k.disc(PropMats.gold(), Vector3.ZERO, 0.016, 6, PropMeshKit.at(Vector3(x, y, -s.z * 0.42), 0, -PI * 0.5))


static func _cake(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.lathe(PropMats.pearl(), Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.25, 0), Vector2(0.03, 0.04),
			Vector2(0.025, s.y * 0.2), Vector2(s.x * 0.5, s.y * 0.22), Vector2(s.x * 0.5, s.y * 0.24), Vector2(0, s.y * 0.24)]), 14)
	# a three-tier pink cake with pearl piping and a rose on top
	var tiers := [[0.42, 0.18], [0.32, 0.16], [0.22, 0.14]]
	var y := s.y * 0.24
	for t in 3:
		var r: float = tiers[t][0] * s.x
		var h: float = tiers[t][1] * s.y
		k.cyl(PropMats.satin(c if t % 2 == 0 else EstateKit.PEARL), Vector3(0, y, 0), r, r, h, 14)
		k.torus(PropMats.pearl(), Vector3(0, y + h, 0), r * 0.97, 0.01, 14, 3)
		k.torus(gold if t == 1 else PropMats.satin(EstateKit.ROSE), Vector3(0, y + 0.008, 0), r, 0.008, 14, 3)
		y += h
	PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(0, y + 0.03, 0), 0.04)
	for i in 3:
		var a := TAU * i / 3.0
		k.sphere(PropMats.gloss(Color(0.95, 0.25, 0.35)), Vector3(cos(a) * 0.04, y + 0.02, sin(a) * 0.04), Vector3.ONE * 0.015, 5, 3)
	k.cyl(PropMats.glass(), Vector3(0, s.y * 0.24, 0), s.x * 0.48, s.x * 0.0, s.y * 0.76, 12, false)


static func _laundry_tub(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.lathe(wood, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.4, 0), Vector2(s.x * 0.5, s.y * 0.9),
			Vector2(s.x * 0.46, s.y * 0.9), Vector2(s.x * 0.37, s.y * 0.1), Vector2(0, s.y * 0.1)]), 14,
			PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, s.z / s.x)))
	for y: float in [0.2, 0.75]:
		k.torus(PropMats.metal(PropMats.IRON), Vector3(0, s.y * y, 0), s.x * (0.41 + y * 0.09), 0.012, 14, 3,
				PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, s.z / s.x)))
	k.disc(PropMats.water(), Vector3(0, s.y * 0.7, 0), s.x * 0.44, 14, PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, s.z / s.x)))
	for i in 6:
		var a := TAU * i / 6.0
		k.sphere(PropMats.glass(Color(1.0, 0.9, 1.0, 0.5)), Vector3(cos(a) * s.x * 0.25, s.y * 0.75, sin(a) * s.z * 0.2), Vector3.ONE * 0.05, 6, 3)
	k.box(PropMats.wood(EstateKit.OAK.lightened(0.2)), Vector3(s.x * 0.3, s.y * 0.6, 0), Vector3(0.3, 0.45, 0.03), PropMeshKit.at(Vector3.ZERO, 0, 0, -0.4))
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * s.x * 0.52, s.y * 0.85, 0), Vector3(0.06, 0.06, 0.15))


static func _drying_line(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(EstateKit.OAK)
	for sx: float in [-1.0, 1.0]:
		k.cyl(wood, Vector3(sx * s.x * 0.48, 0, 0), 0.04, 0.035, s.y, 6)
		k.box(wood, Vector3(sx * s.x * 0.48, s.y - 0.05, 0), Vector3(0.05, 0.05, 0.08))
	var line := PackedVector3Array()
	for i in 9:
		var t := float(i) / 8.0
		line.append(Vector3(-s.x * 0.48 + t * s.x * 0.96, s.y - 0.08 - sin(t * PI) * 0.12, 0))
	k.tube(PropMats.fabric(EstateKit.CREAM), line, 0.005, 3)
	var cols := [c, EstateKit.BLUSH, EstateKit.LILAC, EstateKit.MINT, EstateKit.PEARL, EstateKit.BUTTER]
	for i in 6:
		var t := (i + 0.7) / 7.0
		var p := Vector3(-s.x * 0.48 + t * s.x * 0.96, s.y - 0.08 - sin(t * PI) * 0.12, 0)
		var w := 0.35 + 0.15 * float(i % 2)
		var h := 0.5 + 0.3 * float(i % 3)
		k.box(PropMats.fabric(cols[i]), Vector3(p.x, p.y - h * 0.5, 0), Vector3(w, h, 0.012), PropMeshKit.at(Vector3.ZERO, 0, 0, (i % 2) * 0.04))
		for sx: float in [-1.0, 1.0]:
			k.box(wood, Vector3(p.x + sx * w * 0.4, p.y, 0), Vector3(0.012, 0.06, 0.02))


static func _ironing(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y - 0.03, 0), Vector3(s.x, 0.04, s.z))
	k.box(PropMats.fabric(EstateKit.BLUSH), Vector3(0, s.y + 0.005, 0), Vector3(s.x * 0.98, 0.02, s.z * 0.98))
	for sx: float in [-1.0, 1.0]:
		k.tube(wood, PackedVector3Array([Vector3(sx * s.x * 0.4, 0, -s.z * 0.4), Vector3(-sx * s.x * 0.3, s.y - 0.05, s.z * 0.3)]), 0.022, 4)
		k.tube(wood, PackedVector3Array([Vector3(sx * s.x * 0.4, 0, s.z * 0.4), Vector3(-sx * s.x * 0.3, s.y - 0.05, -s.z * 0.3)]), 0.022, 4)
	# a flat iron and a folded petticoat
	k.box(PropMats.metal(PropMats.IRON), Vector3(s.x * 0.25, s.y + 0.04, 0), Vector3(0.2, 0.05, 0.1))
	k.tube(PropMats.wood(EstateKit.OAK_DARK), PropParts.arch_pts(0.14, s.y + 0.065, 0.0, 6, 0.06), 0.012, 4, PropMeshKit.at(Vector3(s.x * 0.25, 0, 0)))
	k.box(PropMats.fabric(EstateKit.LILAC), Vector3(-s.x * 0.2, s.y + 0.03, 0), Vector3(0.4, 0.04, s.z * 0.7))


static func _still_bench(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y - 0.04, 0), Vector3(s.x, 0.07, s.z))
	PropParts.legs4(k, wood, s.x, s.z, s.y - 0.07, 0.05, 2)
	k.box(wood, Vector3(0, 0.2, 0), Vector3(s.x * 0.9, 0.03, s.z * 0.85))
	# glassware, a candle warmer, herbs in bowls, open recipe book
	var cols := [EstateKit.ROSE, EstateKit.MINT, EstateKit.LILAC, EstateKit.BUTTER, PropMats.SKY]
	for i in 5:
		PropParts.bottle(k, PropMats.glass(Color(cols[i].r, cols[i].g, cols[i].b, 0.65)), PropMats.gold(),
				Vector3(-s.x * 0.42 + i * 0.12, s.y, s.z * 0.3), 0.18 + 0.05 * float(i % 2), 0.04)
	k.sphere(PropMats.glass(Color(0.8, 0.95, 0.85, 0.6)), Vector3(0, s.y + 0.12, 0), Vector3.ONE * 0.1, 10, 6)
	k.cyl(PropMats.metal(PropMats.IRON), Vector3(0, s.y, 0), 0.08, 0.08, 0.04, 8)
	PropParts.candle(k, Vector3(0, s.y + 0.0, -0.12), 0.06, 0.02)
	for i in 3:
		var p := Vector3(s.x * 0.2 + i * 0.18, s.y, -s.z * 0.2)
		k.lathe(PropMats.satin(EstateKit.WARM_STONE), p, PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.08, 0.05), Vector2(0, 0.04)]), 10)
		k.sphere(PropMats.satin(cols[i + 1]), p + Vector3(0, 0.04, 0), Vector3(0.06, 0.02, 0.06), 6, 3)
	var t := PropMeshKit.at(Vector3(-s.x * 0.15, s.y + 0.01, -s.z * 0.15), 0.2)
	k.box(PropMats.satin(PropMats.BERRY), Vector3.ZERO, Vector3(0.36, 0.015, 0.26), t)
	k.box(PropMats.pearl(EstateKit.CREAM), Vector3(0, 0.01, 0), Vector3(0.34, 0.012, 0.24), t)
	# hanging bunches over the bench edge
	for i in 4:
		k.cyl(PropMats.satin(PropMats.LEAF if i % 2 else EstateKit.LILAC), Vector3(s.x * 0.45 - i * 0.1, s.y * 0.6, -s.z * 0.45), 0.04, 0.012, s.y * 0.3, 6)


static func _alembic(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var copper := PropMats.metal(c)
	var glass := PropMats.glass(Color(0.85, 1.0, 0.92, 0.5))
	for i in 3:
		var a := TAU * i / 3.0
		k.tube(PropMats.metal(PropMats.IRON), PackedVector3Array([Vector3(cos(a) * s.x * 0.3, 0, sin(a) * s.z * 0.3), Vector3(cos(a) * 0.12, s.y * 0.25, sin(a) * 0.12)]), 0.01, 4)
	k.torus(PropMats.metal(PropMats.IRON), Vector3(0, s.y * 0.25, 0), 0.13, 0.01, 10, 3)
	PropParts.candle(k, Vector3(0, 0, 0), s.y * 0.12, 0.03)
	k.sphere(copper, Vector3(0, s.y * 0.4, 0), Vector3(0.16, 0.16, 0.16), 10, 6)
	k.lathe(copper, Vector3(0, s.y * 0.5, 0), PackedVector2Array([Vector2(0.06, 0), Vector2(0.1, 0.06), Vector2(0.1, 0.18),
			Vector2(0.03, 0.26), Vector2(0, 0.27)]), 10)
	k.tube(copper, PackedVector3Array([Vector3(0, s.y * 0.5 + 0.22, 0), Vector3(s.x * 0.25, s.y * 0.75, 0), Vector3(s.x * 0.42, s.y * 0.4, 0)]), 0.012, 4)
	k.sphere(glass, Vector3(s.x * 0.42, 0.1, 0), Vector3(0.08, 0.1, 0.08), 8, 5)
	k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(s.x * 0.42, 0.07, 0), Vector3(0.06, 0.05, 0.06), 8, 4)


static func _herb_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(EstateKit.OAK)
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * s.x * 0.47, s.y * 0.5, 0), Vector3(0.06, s.y, s.z * 0.5))
		k.box(wood, Vector3(sx * s.x * 0.47, 0.03, 0), Vector3(0.1, 0.06, s.z))
	var cols := [c, EstateKit.LILAC, PropMats.LEAF, EstateKit.BUTTER, EstateKit.ROSE, EstateKit.MINT, EstateKit.PERIWINKLE]
	for r in 3:
		var y := s.y * (0.4 + r * 0.25)
		k.tube(wood, PackedVector3Array([Vector3(-s.x * 0.47, y, 0), Vector3(s.x * 0.47, y, 0)]), 0.018, 5)
		for i in 7:
			var x := -s.x * 0.4 + i * s.x * 0.133
			k.cyl(PropMats.satin(cols[(i + r) % 7]), Vector3(x, y - s.y * 0.17, 0), 0.06, 0.012, s.y * 0.16, 6)
			k.torus(PropMats.satin(EstateKit.ROSE), Vector3(x, y - 0.03, 0), 0.015, 0.005, 6, 3)
	k.box(PropMats.fabric(PropMats.STRAW), Vector3(0, s.y * 0.15, 0), Vector3(s.x * 0.85, 0.04, s.z * 0.8))


static func _apothecary(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.satin(c)
	var gold := PropMats.gold()
	k.box(body, Vector3(0, s.y * 0.2, 0), Vector3(s.x, s.y * 0.4, s.z))
	PropParts.drawers(k, PropMats.pearl(EstateKit.CREAM), gold, -s.x * 0.47, s.x * 0.47, 0.06, s.y * 0.38, -s.z * 0.5, 4, 6)
	k.box(body, Vector3(0, s.y * 0.41, -s.z * 0.02), Vector3(s.x * 1.02, 0.04, s.z * 1.04))
	k.box(body, Vector3(0, s.y * 0.7, s.z * 0.4), Vector3(s.x, s.y * 0.6, s.z * 0.2))
	for sx: float in [-1.0, 1.0]:
		k.box(body, Vector3(sx * s.x * 0.48, s.y * 0.7, s.z * 0.2), Vector3(s.x * 0.04, s.y * 0.6, s.z * 0.6))
	k.box(body, Vector3(0, s.y - 0.03, s.z * 0.2), Vector3(s.x * 1.03, 0.06, s.z * 0.64))
	var cols := [EstateKit.ROSE, EstateKit.MINT, EstateKit.LILAC, EstateKit.BUTTER, PropMats.SKY, PropMats.BERRY, EstateKit.PERIWINKLE]
	for r in 3:
		var y := s.y * (0.43 + r * 0.18)
		k.box(body, Vector3(0, y, s.z * 0.2), Vector3(s.x * 0.94, 0.02, s.z * 0.55))
		for i in 8:
			var x := -s.x * 0.41 + i * s.x * 0.117
			PropParts.bottle(k, PropMats.glass(Color(cols[(i + r * 2) % 7], 0.7)), gold, Vector3(x, y + 0.01, s.z * 0.15), s.y * 0.13, 0.035)
	k.box(PropMats.pearl(EstateKit.CREAM), Vector3(0, s.y * 0.95, -s.z * 0.12), Vector3(s.x * 0.5, 0.08, 0.01))


static func _mortar(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var stone := PropMats.satin(c)
	k.lathe(stone, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.35, 0), Vector2(s.x * 0.5, s.y * 0.45),
			Vector2(s.x * 0.48, s.y * 0.55), Vector2(s.x * 0.38, s.y * 0.5), Vector2(0, s.y * 0.2)]), 12)
	k.disc(PropMats.satin(EstateKit.LILAC), Vector3(0, s.y * 0.35, 0), s.x * 0.36, 10)
	k.tube(PropMats.satin(EstateKit.WARM_STONE.lightened(0.05)), PackedVector3Array([Vector3(0, s.y * 0.3, 0), Vector3(s.x * 0.2, s.y, 0.0)]), 0.025, 6, Transform3D.IDENTITY, 0.018)
	for i in 4:
		k.leaf(PropMats.satin(PropMats.LEAF), Vector3(-s.x * 0.3, 0.01, s.z * 0.3 - i * 0.04), Vector3(-1, 0, i * 0.3), 0.06, 0.03, 0.0)


static func _vial_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(EstateKit.OAK)
	k.box(wood, Vector3(0, 0.015, 0), Vector3(s.x, 0.03, s.z))
	k.box(wood, Vector3(0, s.y * 0.5, 0), Vector3(s.x, 0.02, s.z * 0.9))
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * s.x * 0.48, s.y * 0.3, 0), Vector3(0.02, s.y * 0.6, s.z))
	var cols := [c, EstateKit.ROSE, EstateKit.MINT, EstateKit.LILAC, EstateKit.BUTTER, PropMats.BERRY]
	for row in 2:
		for i in 6:
			var p := Vector3(-s.x * 0.38 + i * s.x * 0.152, 0.03, -s.z * 0.2 + row * s.z * 0.4)
			k.cyl(PropMats.glass(Color(0.95, 0.95, 1.0, 0.35)), p, 0.018, 0.018, s.y * 0.85, 6)
			k.cyl(PropMats.glow(cols[(i + row) % 6], 0.6), p, 0.016, 0.016, s.y * (0.35 + 0.1 * float((i + row) % 3)), 6)
			k.cyl(PropMats.wood(EstateKit.OAK_DARK), p + Vector3(0, s.y * 0.85, 0), 0.016, 0.014, s.y * 0.12, 5)


static func _cot(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var frame := PropMats.pearl()
	k.box(frame, Vector3(0, s.y * 0.45, 0), Vector3(s.x, 0.06, s.z))
	PropParts.legs4(k, frame, s.x, s.z, s.y * 0.45, 0.025, 0)
	k.box(PropMats.fabric(c), Vector3(0, s.y * 0.55, 0), Vector3(s.x * 0.94, 0.14, s.z * 0.96))
	k.box(PropMats.fabric(EstateKit.MINT), Vector3(0, s.y * 0.63, -s.z * 0.1), Vector3(s.x * 0.96, 0.03, s.z * 0.72))
	PropParts.cushion(k, PropMats.fabric(EstateKit.PEARL), Vector3(0, s.y * 0.68, s.z * 0.38), Vector3(s.x * 0.7, 0.12, 0.3))
	k.box(frame, Vector3(0, s.y * 0.85, s.z * 0.49), Vector3(s.x, s.y * 0.5, 0.04))
	k.box(PropMats.satin(EstateKit.ROSE), Vector3(0, s.y * 0.95, s.z * 0.47), Vector3(0.14, 0.04, 0.005))
	k.box(PropMats.satin(EstateKit.ROSE), Vector3(0, s.y * 0.95, s.z * 0.47), Vector3(0.04, 0.14, 0.005))


static func _tub(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var porcelain := PropMats.pearl(c)
	var gold := PropMats.gold()
	var r := s.z * 0.5
	var h := s.y * 0.75
	var t := PropMeshKit.at(Vector3(0, s.y - h, 0), 0, 0, 0, Vector3(s.x / s.z, 1, 1))
	k.lathe(porcelain, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(r * 0.7, 0), Vector2(r * 0.95, h * 0.6),
			Vector2(r, h), Vector2(r * 0.92, h), Vector2(r * 0.88, h * 0.4), Vector2(0, h * 0.3)]), 16, t)
	k.torus(gold, Vector3.ZERO, r * 0.97, 0.018, 18, 3, PropMeshKit.at(Vector3(0, s.y, 0), 0, 0, 0, Vector3(s.x / s.z, 1, 1)))
	k.disc(PropMats.water(), Vector3.ZERO, r * 0.9, 16, PropMeshKit.at(Vector3(0, s.y - 0.12, 0), 0, 0, 0, Vector3(s.x / s.z, 1, 1)))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(sx * s.x * 0.32, 0, sz * s.z * 0.28)
			k.tube(gold, PackedVector3Array([p + Vector3(0, s.y - h + 0.05, 0), p + Vector3(sx * 0.03, (s.y - h) * 0.5, sz * 0.02), p + Vector3(sx * 0.05, 0.04, sz * 0.03)]), 0.025, 5)
			k.sphere(gold, p + Vector3(sx * 0.05, 0.03, sz * 0.03), Vector3(0.045, 0.03, 0.045), 6, 3)
	# gold taps and floating rose petals and bubbles
	k.tube(gold, PackedVector3Array([Vector3(s.x * 0.44, s.y - 0.05, 0), Vector3(s.x * 0.48, s.y + 0.0, 0), Vector3(s.x * 0.43, s.y + 0.03, 0)]), 0.015, 5)
	var rnd := PropParts.rng(&"bathtub")
	for i in 10:
		var p := Vector3(rnd.randf_range(-s.x * 0.35, s.x * 0.35), s.y - 0.115, rnd.randf_range(-s.z * 0.3, s.z * 0.3))
		if i % 2 == 0:
			k.disc(PropMats.satin(EstateKit.ROSE), p, 0.03, 5)
		else:
			k.sphere(PropMats.glass(Color(1.0, 0.92, 1.0, 0.55)), p, Vector3.ONE * 0.05, 6, 3, Transform3D.IDENTITY, true)


static func _sunken(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var stone := PropMats.pearl(EstateKit.MARBLE)
	var gold := PropMats.gold()
	# the basin rim at floor level (the pool is cut by the room) with mosaic tiles,
	# shimmering water, floating petals and candles on the corners
	var w := s.x
	var d := s.z
	k.box(PropMats.glass(Color(c.r, c.g, c.b, 0.7)), Vector3(0, s.y * 0.4, 0), Vector3(w * 0.84, 0.01, d * 0.8))
	for sz: float in [-1.0, 1.0]:
		k.box(stone, Vector3(0, s.y * 0.5, sz * d * 0.45), Vector3(w, s.y, d * 0.1))
	for sx: float in [-1.0, 1.0]:
		k.box(stone, Vector3(sx * w * 0.46, s.y * 0.5, 0), Vector3(w * 0.08, s.y, d * 0.8))
	for i in 12:
		k.box(PropMats.gloss([EstateKit.MINT, PropMats.TEAL, EstateKit.PERIWINKLE][i % 3]), Vector3(-w * 0.38 + i * w * 0.07, s.y + 0.002, -d * 0.45),
				Vector3(w * 0.06, 0.005, d * 0.06))
	k.tube(gold, PropParts.ring_pts(Vector3(0, s.y, 0), 0.5, 4), 0.012, 4, PropMeshKit.at(Vector3.ZERO, PI * 0.25, 0, 0, Vector3(w * 1.2, 1, d * 1.2)))
	var rnd := PropParts.rng(&"bath_sunken")
	for i in 14:
		k.disc(PropMats.satin(EstateKit.ROSE if i % 3 else EstateKit.PEARL), Vector3(rnd.randf_range(-w * 0.38, w * 0.38), s.y * 0.42,
				rnd.randf_range(-d * 0.36, d * 0.36)), 0.04, 5)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			PropParts.candle(k, Vector3(sx * w * 0.46, s.y * 0.1, sz * d * 0.45), 0.0 + 0.08, 0.025)


static func _washstand(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.body(c)
	var gold := PropMats.gold()
	PropParts.legs4(k, gold, s.x * 0.95, s.z * 0.9, s.y * 0.85, 0.022, 1)
	k.box(body, Vector3(0, s.y * 0.85, 0), Vector3(s.x, 0.05, s.z))
	k.box(body, Vector3(0, s.y * 0.25, 0), Vector3(s.x * 0.9, 0.025, s.z * 0.85))
	k.box(body, Vector3(0, s.y * 0.95, s.z * 0.47), Vector3(s.x, s.y * 0.15, 0.03))
	# rose-painted basin and ewer, folded towels below
	k.lathe(PropMats.pearl(EstateKit.BLUSH), Vector3(0, s.y * 0.87, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0),
			Vector2(0.2, 0.08), Vector2(0.21, 0.1), Vector2(0, 0.06)]), 14)
	k.lathe(PropMats.pearl(EstateKit.BLUSH), Vector3(s.x * 0.33, s.y * 0.87, 0.05), PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0),
			Vector2(0.08, 0.1), Vector2(0.04, 0.18), Vector2(0.05, 0.24), Vector2(0, 0.24)]), 10)
	k.tube(gold, PackedVector3Array([Vector3(s.x * 0.33 + 0.06, s.y * 0.87 + 0.2, 0.05), Vector3(s.x * 0.33 + 0.1, s.y * 0.87 + 0.14, 0.05),
			Vector3(s.x * 0.33 + 0.06, s.y * 0.87 + 0.06, 0.05)]), 0.01, 4)
	for i in 3:
		k.box(PropMats.fabric([EstateKit.MINT, EstateKit.PEARL, EstateKit.ROSE][i]), Vector3(0, s.y * 0.25 + 0.03 + i * 0.05, 0), Vector3(s.x * 0.5, 0.045, s.z * 0.6))


static func _towel_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	for sx: float in [-1.0, 1.0]:
		k.tube(gold, PackedVector3Array([Vector3(sx * s.x * 0.45, 0.02, -s.z * 0.45), Vector3(sx * s.x * 0.45, 0.04, 0), Vector3(sx * s.x * 0.45, 0.02, s.z * 0.45)]), 0.02, 4)
		k.cyl(gold, Vector3(sx * s.x * 0.45, 0.03, 0), 0.018, 0.018, s.y - 0.06, 6)
		k.sphere(gold, Vector3(sx * s.x * 0.45, s.y - 0.03, 0), Vector3.ONE * 0.03, 6, 3)
	for y: float in [0.4, 0.75, 0.95]:
		k.tube(gold, PackedVector3Array([Vector3(-s.x * 0.45, s.y * y, 0), Vector3(s.x * 0.45, s.y * y, 0)]), 0.012, 4)
	var cols := [EstateKit.BLUSH, EstateKit.MINT, EstateKit.LILAC]
	for i in 3:
		var y: float = s.y * [0.95, 0.75, 0.4][i]
		var w := s.x * (0.7 - i * 0.1)
		k.box(PropMats.fabric(cols[i]), Vector3((i - 1) * 0.08, y - s.y * 0.15, -0.02 + i * 0.02), Vector3(w, s.y * 0.3, 0.02))
		k.box(PropMats.fabric(EstateKit.PEARL), Vector3((i - 1) * 0.08, y - s.y * 0.28, -0.032 + i * 0.02), Vector3(w, 0.03, 0.005))


static func _soap_shelf(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.pearl(c)
	k.box(body, Vector3(0, s.y * 0.5, s.z * 0.4), Vector3(s.x, s.y, s.z * 0.2))
	for y: float in [0.05, 0.5]:
		k.box(body, Vector3(0, s.y * y, 0), Vector3(s.x, 0.025, s.z))
		k.tube(PropMats.gold(), PackedVector3Array([Vector3(-s.x * 0.5, s.y * y + 0.04, -s.z * 0.48), Vector3(s.x * 0.5, s.y * y + 0.04, -s.z * 0.48)]), 0.006, 3)
	var cols := [EstateKit.ROSE, EstateKit.LILAC, EstateKit.MINT, EstateKit.BUTTER, EstateKit.PERIWINKLE]
	for i in 5:
		var x := -s.x * 0.38 + i * s.x * 0.19
		k.sphere(PropMats.gloss(cols[i]), Vector3(x, s.y * 0.05 + 0.04, 0), Vector3(0.06, 0.03, 0.04), 8, 4)
		PropParts.bottle(k, PropMats.glass(Color(cols[(i + 2) % 5], 0.65)), PropMats.gold(), Vector3(x, s.y * 0.5 + 0.01, 0), s.y * 0.35, 0.03)
	k.sphere(PropMats.fabric(EstateKit.PEARL), Vector3(s.x * 0.4, s.y * 0.5 + 0.06, -0.02), Vector3(0.05, 0.04, 0.05), 6, 3)
