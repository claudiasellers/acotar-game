## Armory, stables and secrets: weapon racks, bows, armour, straw targets, hay,
## tack, troughs, the flower cart, the gilt carriage, levers and keepsake glints.
class_name OutbuildingShapes
extends RefCounted



static func build(k: PropMeshKit, id: StringName, s: Vector3, c: Color) -> bool:
	match id:
		&"weapon_rack": _weapon_rack(k, s, c)
		&"bow_rack": _bow_rack(k, s, c)
		&"armor_stand": _armor(k, s, c)
		&"target_straw": _target(k, s, c)
		&"quiver_barrel": _quiver(k, s, c)
		&"stall_divider": _stall(k, s, c)
		&"hay_bale": _bale(k, s, c)
		&"hay_pile": _hay_pile(k, s, c)
		&"saddle_rack": _saddle_rack(k, s, c)
		&"tack_wall": _tack_wall(k, s, c)
		&"water_trough": _trough(k, s, c)
		&"feed_bin": _feed_bin(k, s, c)
		&"cart_flower": _flower_cart(k, s, c)
		&"carriage_gilt": _carriage(k, s, c)
		&"horse_statue": _horse_statue(k, s, c)
		&"secret_lever": _lever(k, s, c)
		&"keepsake_glint": _glint(k, s, c)
		&"loose_panel": _loose_panel(k, s, c)
		_: return false
	return true


static func _sword(k: PropMeshKit, base: Vector3, length: float, hilt: Color) -> void:
	var steel := PropMats.metal(PropMats.STEEL)
	k.box(steel, base + Vector3(0, length * 0.62, 0), Vector3(0.05, length * 0.7, 0.012))
	k.cyl(steel, base + Vector3(0, length * 0.97, 0), 0.025, 0.0, length * 0.05, 4)
	k.box(PropMats.gold(), base + Vector3(0, length * 0.27, 0), Vector3(0.18, 0.025, 0.03))
	k.cyl(PropMats.satin(hilt), base + Vector3(0, length * 0.08, 0), 0.016, 0.016, length * 0.18, 6)
	k.sphere(PropMats.gold(), base + Vector3(0, length * 0.06, 0), Vector3.ONE * 0.03, 6, 3)


static func _weapon_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y * 0.5, s.z * 0.4), Vector3(s.x, s.y, s.z * 0.15))
	k.box(wood, Vector3(0, 0.1, 0), Vector3(s.x, 0.2, s.z))
	k.box(wood, Vector3(0, s.y * 0.6, -s.z * 0.1), Vector3(s.x * 0.95, 0.06, s.z * 0.5))
	for i in 7:
		var x := -s.x * 0.42 + i * s.x * 0.14
		if i % 2 == 0:
			_sword(k, Vector3(x, 0.2, s.z * 0.1), s.y * 0.8, [EstateKit.ROSE, PropMats.PLUM, EstateKit.PERIWINKLE, PropMats.BERRY][(i / 2) % 4])
		else:
			# spear with a ribbon
			k.cyl(PropMats.wood(EstateKit.OAK), Vector3(x, 0.2, s.z * 0.05), 0.016, 0.016, s.y * 0.75, 6)
			k.cyl(PropMats.metal(PropMats.STEEL), Vector3(x, 0.2 + s.y * 0.75, s.z * 0.05), 0.035, 0.0, 0.16, 4)
			k.box(PropMats.satin(EstateKit.ROSE), Vector3(x + 0.03, s.y * 0.85, s.z * 0.05), Vector3(0.04, 0.2, 0.004))
	# a shield with the Spring Court rose at the top centre
	k.cyl(PropMats.metal(EstateKit.PERIWINKLE), Vector3(0, -0.02, 0), s.x * 0.12, s.x * 0.12, 0.04, 14, true,
			PropMeshKit.at(Vector3(0, s.y * 0.85, s.z * 0.28), 0, PI * 0.5))
	PropParts.bloom(k, PropMats.gold(), Vector3(0, s.y * 0.85, s.z * 0.24), 0.06)


static func _bow_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y * 0.5, s.z * 0.4), Vector3(s.x, s.y, s.z * 0.12))
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * s.x * 0.45, s.y * 0.5, 0), Vector3(0.08, s.y, s.z))
	for r in 3:
		var y := s.y * (0.25 + r * 0.28)
		for i in 5:
			k.cyl(wood, Vector3(0, 0, 0), 0.015, 0.015, s.z * 0.5, 4, true, PropMeshKit.at(Vector3(-s.x * 0.36 + i * s.x * 0.18, y, s.z * 0.35), 0, -PI * 0.5))
		# a recurve bow lying across the pegs
		var pts := PackedVector3Array()
		for j in 9:
			var t := float(j) / 8.0
			var x := -s.x * 0.38 + t * s.x * 0.76
			pts.append(Vector3(x, y + 0.05 + sin(t * PI) * 0.12 - (0.03 if t < 0.1 or t > 0.9 else 0.0), s.z * 0.05))
		k.tube(PropMats.wood([EstateKit.OAK, EstateKit.OAK_DARK, EstateKit.GOLD][r]), pts, 0.018, 5)
		k.tube(PropMats.pearl(EstateKit.CREAM), PackedVector3Array([pts[0], pts[8]]), 0.003, 3)
		k.torus(PropMats.satin(EstateKit.ROSE), pts[4], 0.025, 0.008, 6, 3, PropMeshKit.at(Vector3.ZERO, 0, 0, PI * 0.5))


static func _armor(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var steel := PropMats.metal(c.lightened(0.2))
	var gold := PropMats.gold()
	k.cyl(PropMats.wood(EstateKit.OAK_DARK), Vector3.ZERO, s.x * 0.4, s.x * 0.4, 0.06, 10)
	k.cyl(PropMats.wood(EstateKit.OAK_DARK), Vector3(0, 0.06, 0), 0.025, 0.025, s.y * 0.45, 6)
	# greaves, tassets, breastplate with gold trim, pauldrons, a plumed helm
	for sx: float in [-1.0, 1.0]:
		k.cyl(steel, Vector3(sx * 0.1, 0.08, 0), 0.06, 0.07, s.y * 0.38, 8)
	k.lathe(steel, Vector3(0, s.y * 0.42, 0), PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.28, 0), Vector2(s.x * 0.24, s.y * 0.12),
			Vector2(s.x * 0.2, s.y * 0.2), Vector2(s.x * 0.3, s.y * 0.33), Vector2(s.x * 0.22, s.y * 0.38), Vector2(0, s.y * 0.38)]), 12,
			PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, s.z / s.x * 0.8)))
	k.torus(gold, Vector3(0, s.y * 0.62, 0), s.x * 0.21, 0.012, 12, 3, PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, s.z / s.x * 0.8)))
	PropParts.bloom(k, gold, Vector3(0, s.y * 0.7, -s.z * 0.2), 0.04)
	for sx: float in [-1.0, 1.0]:
		k.sphere(steel, Vector3(sx * s.x * 0.33, s.y * 0.76, 0), Vector3(0.1, 0.07, 0.09), 8, 4, Transform3D.IDENTITY, true)
		k.cyl(steel, Vector3(sx * s.x * 0.36, s.y * 0.48, 0), 0.04, 0.05, s.y * 0.26, 6)
	k.sphere(steel, Vector3(0, s.y * 0.88, 0), Vector3(0.12, 0.13, 0.13), 10, 6)
	k.box(PropMats.satin(PropMats.PLUM), Vector3(0, s.y * 0.88, -0.125), Vector3(0.12, 0.02, 0.01))
	k.tube(PropMats.satin(EstateKit.ROSE), PackedVector3Array([Vector3(0, s.y * 0.96, 0), Vector3(0, s.y, 0.08), Vector3(0, s.y * 0.92, 0.2)]), 0.04, 6, Transform3D.IDENTITY, 0.01)


static func _target(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(EstateKit.OAK)
	for sx: float in [-1.0, 1.0]:
		k.tube(wood, PackedVector3Array([Vector3(sx * s.x * 0.35, 0, -s.z * 0.3), Vector3(sx * s.x * 0.2, s.y * 0.9, s.z * 0.1)]), 0.03, 5)
	k.tube(wood, PackedVector3Array([Vector3(0, 0, s.z * 0.5), Vector3(0, s.y * 0.8, s.z * 0.15)]), 0.03, 5)
	var t := PropMeshKit.at(Vector3(0, s.y * 0.55, 0), 0, PI * 0.5 - 0.2)
	var r := s.x * 0.45
	k.cyl(PropMats.fabric(c), Vector3(0, -0.1, 0), r, r, 0.2, 18, true, t)
	var rings := [EstateKit.PEARL, EstateKit.ROSE, EstateKit.PEARL, EstateKit.PERIWINKLE, EstateKit.GOLD]
	for i in 5:
		k.disc(PropMats.satin(rings[i]), Vector3(0, 0.102 + i * 0.002, 0), r * (0.9 - i * 0.18), 18, t * Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO))
	for i in 3:
		var p := Vector3(-0.1 + i * 0.09, s.y * 0.55 + 0.05 * (i - 1), -0.12)
		k.tube(PropMats.wood(EstateKit.OAK_DARK), PackedVector3Array([p, p + Vector3(0.02, 0.05, -0.35)]), 0.006, 3)
		k.leaf(PropMats.satin(EstateKit.ROSE), p + Vector3(0.02, 0.05, -0.32), Vector3(0, 0.15, -1), 0.06, 0.03, 0.0)


static func _quiver(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	ServiceShapes._barrel(k, Vector3.ZERO, s.x * 0.45, s.y * 0.6, wood)
	var rnd := PropParts.rng(&"quiver_barrel")
	for i in 14:
		var a := rnd.randf() * TAU
		var rr := rnd.randf() * s.x * 0.3
		var base := Vector3(cos(a) * rr, s.y * 0.2, sin(a) * rr)
		var tip := base + Vector3(cos(a) * 0.05, s.y * 0.75, sin(a) * 0.05)
		k.tube(PropMats.wood(EstateKit.OAK.lightened(0.2)), PackedVector3Array([base, tip]), 0.006, 3)
		k.leaf(PropMats.satin([EstateKit.ROSE, EstateKit.PEARL, EstateKit.PERIWINKLE][i % 3]), tip - Vector3(0, 0.08, 0), Vector3(cos(a), 0.2, sin(a)), 0.07, 0.035, 0.0)


static func _stall(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y * 0.3, 0), Vector3(s.x * 0.7, s.y * 0.6, s.z))
	for i in 6:
		k.box(PropMats.wood(c.lightened(0.06 * float(i % 2))), Vector3(0, s.y * 0.05 + i * s.y * 0.1, 0), Vector3(s.x * 0.75, s.y * 0.09, s.z * 0.98))
	k.box(wood, Vector3(0, s.y * 0.6, 0), Vector3(s.x, 0.06, s.z))
	for i in 12:
		k.cyl(PropMats.metal(PropMats.IRON), Vector3(0, s.y * 0.6, -s.z * 0.45 + i * s.z * 0.082), 0.012, 0.012, s.y * 0.38, 4)
	k.box(wood, Vector3(0, s.y - 0.03, 0), Vector3(s.x, 0.06, s.z))
	k.cyl(wood, Vector3(0, 0, -s.z * 0.5), 0.09, 0.09, s.y, 8)
	k.sphere(PropMats.gold(), Vector3(0, s.y + 0.0, -s.z * 0.5), Vector3.ONE * 0.08, 6, 3)
	k.box(PropMats.satin(EstateKit.BLUSH), Vector3(0.0, s.y * 0.7, -s.z * 0.42), Vector3(s.x * 1.1, 0.12, 0.3))


static func _bale(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var straw := PropMats.fabric(c)
	k.box(straw, Vector3(0, s.y * 0.5, 0), Vector3(s.x * 0.98, s.y * 0.96, s.z * 0.98))
	for sx: float in [-1.0, 1.0]:
		k.sphere(straw, Vector3(sx * s.x * 0.48, s.y * 0.5, 0), Vector3(0.03, s.y * 0.48, s.z * 0.48), 6, 4)
	for x: float in [-0.25, 0.25]:
		k.box(PropMats.fabric(EstateKit.ROSE), Vector3(x * s.x, s.y * 0.5, 0), Vector3(0.03, s.y * 1.01, s.z * 1.01))
	for i in 5:
		k.leaf(straw, Vector3(-s.x * 0.3 + i * 0.15, s.y, 0), Vector3(0.3 - i * 0.15, 0.5, 0.4), 0.15, 0.02, 0.4)


static func _hay_pile(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var straw := PropMats.fabric(c)
	k.sphere(straw, Vector3.ZERO, Vector3(s.x * 0.5, s.y, s.z * 0.5), 14, 6, Transform3D.IDENTITY, true)
	var rnd := PropParts.rng(&"hay_pile")
	for i in 30:
		var a := rnd.randf() * TAU
		var e := rnd.randf_range(0.1, 1.4)
		var p := Vector3(cos(a) * sin(e) * s.x * 0.5, cos(e) * s.y, sin(a) * sin(e) * s.z * 0.5)
		k.leaf(PropMats.fabric(c.lightened(0.1)), p * 0.98, Vector3(cos(a + 1.0), 0.3, sin(a + 1.0)), 0.25, 0.03, 0.2)
	k.sphere(PropMats.satin(PropMats.LEAF), Vector3(s.x * 0.2, s.y * 0.75, -s.z * 0.2), Vector3(0.06, 0.04, 0.06), 6, 3)
	for i in 4:
		PropParts.bloom(k, PropMats.satin(EstateKit.BUTTER if i % 2 else EstateKit.PEARL), Vector3(-s.x * 0.2 + i * 0.12, s.y * 0.85, s.z * 0.12), 0.03)


static func _saddle(k: PropMeshKit, pos: Vector3, col: Color) -> void:
	var leather := PropMats.satin(col)
	k.sphere(leather, pos, Vector3(0.2, 0.08, 0.28), 10, 5, Transform3D.IDENTITY, true)
	k.sphere(leather, pos + Vector3(0, 0.06, -0.2), Vector3(0.08, 0.06, 0.05), 6, 3)
	k.box(PropMats.fabric(EstateKit.BLUSH), pos + Vector3(0, -0.02, 0), Vector3(0.5, 0.02, 0.6))
	for sx: float in [-1.0, 1.0]:
		k.tube(PropMats.satin(col.darkened(0.1)), PackedVector3Array([pos + Vector3(sx * 0.18, 0.0, 0), pos + Vector3(sx * 0.22, -0.3, 0)]), 0.012, 3)
		k.torus(PropMats.gold(), pos + Vector3(sx * 0.22, -0.33, 0), 0.04, 0.008, 8, 3, PropMeshKit.at(Vector3.ZERO, 0, 0, PI * 0.5))


static func _saddle_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * s.x * 0.45, s.y * 0.4, 0), Vector3(0.08, s.y * 0.8, s.z * 0.8))
		k.box(wood, Vector3(sx * s.x * 0.45, 0.03, 0), Vector3(0.12, 0.06, s.z))
	k.box(wood, Vector3(0, s.y * 0.8, 0), Vector3(s.x * 0.95, 0.08, 0.1), PropMeshKit.at(Vector3.ZERO, 0, 0, 0))
	for sx: float in [-1.0, 1.0]:
		_saddle(k, Vector3(sx * s.x * 0.24, s.y * 0.86, 0), EstateKit.OAK if sx < 0 else EstateKit.ROSE.darkened(0.15))


static func _tack_wall(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y * 0.5, s.z * 0.3), Vector3(s.x, s.y, s.z * 0.4))
	for i in 6:
		var x := -s.x * 0.4 + i * s.x * 0.16
		k.cyl(PropMats.gold(), Vector3(0, 0, 0), 0.015, 0.015, 0.12, 5, true, PropMeshKit.at(Vector3(x, s.y * 0.8, s.z * 0.1), 0, -PI * 0.5))
		# bridle loops with gold bits and coloured browbands
		k.torus(PropMats.satin(EstateKit.OAK_DARK), Vector3.ZERO, 0.12, 0.012, 10, 3, PropMeshKit.at(Vector3(x, s.y * 0.65, -s.z * 0.1), 0, PI * 0.5, 0, Vector3(0.7, 1.3, 1)))
		k.box(PropMats.satin([EstateKit.ROSE, EstateKit.LILAC, EstateKit.MINT][i % 3]), Vector3(x, s.y * 0.78, -s.z * 0.12), Vector3(0.18, 0.025, 0.01))
		k.torus(PropMats.gold(), Vector3(x, s.y * 0.48, -s.z * 0.12), 0.03, 0.006, 8, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
	k.tube(PropMats.satin(EstateKit.OAK), PropParts.ring_pts(Vector3(0, 0, 0), 0.15, 10), 0.015, 3, PropMeshKit.at(Vector3(s.x * 0.3, s.y * 0.25, -s.z * 0.1), 0, PI * 0.5))
	k.box(PropMats.fabric(EstateKit.PERIWINKLE), Vector3(-s.x * 0.3, s.y * 0.2, -s.z * 0.05), Vector3(0.5, 0.35, 0.02))


static func _trough(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var stone := PropMats.satin(c)
	k.box(stone, Vector3(0, s.y * 0.05, 0), Vector3(s.x, s.y * 0.1, s.z))
	for sx: float in [-1.0, 1.0]:
		k.box(stone, Vector3(sx * s.x * 0.47, s.y * 0.5, 0), Vector3(s.x * 0.06, s.y, s.z))
	for sz: float in [-1.0, 1.0]:
		k.box(stone, Vector3(0, s.y * 0.5, sz * s.z * 0.44), Vector3(s.x, s.y, s.z * 0.12))
	k.box(PropMats.water(), Vector3(0, s.y * 0.8, 0), Vector3(s.x * 0.9, 0.01, s.z * 0.8))
	for i in 3:
		PropParts.bloom(k, PropMats.satin(EstateKit.PEARL), Vector3(-s.x * 0.2 + i * s.x * 0.2, s.y * 0.81, 0.02 * i), 0.04)
	k.box(PropMats.satin(EstateKit.ROSE), Vector3(0, s.y * 0.6, -s.z * 0.51), Vector3(s.x * 0.3, s.y * 0.2, 0.01))


static func _feed_bin(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y * 0.42, 0), Vector3(s.x, s.y * 0.84, s.z))
	k.box(PropMats.wood(c.lightened(0.12)), Vector3(0, s.y * 0.9, -0.03), Vector3(s.x * 1.02, 0.05, s.z * 1.04), PropMeshKit.at(Vector3.ZERO, 0, 0.12))
	for x: float in [-0.3, 0.3]:
		k.box(PropMats.metal(PropMats.IRON), Vector3(x * s.x, s.y * 0.42, -s.z * 0.505), Vector3(0.05, s.y * 0.84, 0.01))
	k.box(PropMats.satin(EstateKit.BUTTER), Vector3(0, s.y * 0.6, -s.z * 0.51), Vector3(s.x * 0.3, 0.12, 0.005))
	k.sphere(PropMats.satin(Color(1.0, 0.6, 0.3)), Vector3(s.x * 0.3, s.y * 0.9, s.z * 0.2), Vector3(0.05, 0.08, 0.05), 6, 3)


static func _wheel(k: PropMeshKit, m: Material, center: Vector3, r: float, spokes: int, axis_x: bool = true) -> void:
	var t := PropMeshKit.at(center, 0, 0, PI * 0.5) if axis_x else PropMeshKit.at(center, 0, PI * 0.5)
	k.torus(m, Vector3.ZERO, r, r * 0.07, 14, 4, t)
	k.cyl(m, Vector3(0, -0.05, 0), r * 0.15, r * 0.15, 0.1, 8, true, t)
	for i in spokes:
		var a := TAU * i / spokes
		k.tube(m, PackedVector3Array([Vector3.ZERO, Vector3(cos(a) * r, 0, sin(a) * r)]), r * 0.035, 4, t)


static func _flower_cart(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	var bed_y := s.y * 0.35
	k.box(wood, Vector3(0, bed_y, 0), Vector3(s.x * 0.75, 0.06, s.z * 0.8))
	for sz: float in [-1.0, 1.0]:
		k.box(wood, Vector3(0, bed_y + 0.15, sz * s.z * 0.39), Vector3(s.x * 0.75, 0.3, 0.04))
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * s.x * 0.37, bed_y + 0.15, 0), Vector3(0.04, 0.3, s.z * 0.8))
	for sz: float in [-1.0, 1.0]:
		_wheel(k, PropMats.pearl(EstateKit.MINT), Vector3(s.x * 0.05, bed_y * 0.9, sz * s.z * 0.46), bed_y * 0.88, 8, false)
	for sz: float in [-1.0, 1.0]:
		k.tube(wood, PackedVector3Array([Vector3(-s.x * 0.35, bed_y, sz * s.z * 0.25), Vector3(-s.x * 0.5, bed_y * 0.7, sz * s.z * 0.25)]), 0.025, 4)
	# heaped buckets of flowers in every colour
	var cols := [EstateKit.ROSE, EstateKit.BUTTER, EstateKit.LILAC, EstateKit.PEARL, EstateKit.PERIWINKLE, Color(1.0, 0.6, 0.3)]
	for i in 6:
		var p := Vector3(-s.x * 0.25 + (i % 3) * s.x * 0.25, bed_y + 0.03, -s.z * 0.18 + (i / 3) * s.z * 0.36)
		k.cyl(PropMats.metal(PropMats.COPPER) if i % 2 else PropMats.pearl(EstateKit.BLUSH), p, 0.13, 0.15, 0.25, 8)
		k.sphere(PropMats.satin(PropMats.LEAF), p + Vector3(0, 0.25, 0), Vector3(0.16, 0.1, 0.16), 6, 3, Transform3D.IDENTITY, true)
		for j in 4:
			var a := TAU * j / 4.0
			PropParts.bloom(k, PropMats.satin(cols[(i + j) % 6]), p + Vector3(cos(a) * 0.09, 0.32 + (0.06 if j == 0 else 0.0), sin(a) * 0.09), 0.045)
	# a striped canopy on poles
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.cyl(wood, Vector3(sx * s.x * 0.35, bed_y, sz * s.z * 0.37), 0.02, 0.02, s.y - bed_y - 0.15, 5)
	for i in 6:
		k.box(PropMats.fabric(EstateKit.ROSE if i % 2 == 0 else EstateKit.PEARL), Vector3(-s.x * 0.35 + (i + 0.5) * s.x * 0.7 / 6.0, s.y - 0.12, 0),
				Vector3(s.x * 0.7 / 6.0, 0.04, s.z * 0.85), PropMeshKit.at(Vector3.ZERO, 0, 0, 0))
	for i in 7:
		k.sphere(PropMats.fabric(EstateKit.ROSE), Vector3(-s.x * 0.36 + i * s.x * 0.12, s.y - 0.17, -s.z * 0.43), Vector3(0.06, 0.05, 0.02), 5, 3)


static func _carriage(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	var pearl := PropMats.pearl()
	var pink := PropMats.pearl(EstateKit.BLUSH)
	# wheels front (smaller, -X) and back, along X
	for sz: float in [-1.0, 1.0]:
		_wheel(k, gold, Vector3(-s.x * 0.32, s.y * 0.17, sz * s.z * 0.44), s.y * 0.16, 10, false)
		_wheel(k, gold, Vector3(s.x * 0.3, s.y * 0.22, sz * s.z * 0.44), s.y * 0.21, 12, false)
	for sz: float in [-1.0, 1.0]:
		k.tube(gold, PackedVector3Array([Vector3(-s.x * 0.32, s.y * 0.17, sz * s.z * 0.35), Vector3(-s.x * 0.1, s.y * 0.32, sz * s.z * 0.3),
				Vector3(s.x * 0.3, s.y * 0.22, sz * s.z * 0.35)]), 0.035, 5)
	# pumpkin-round coach body with a gold crown and rose garlands
	var body_c := Vector3(0, s.y * 0.58, 0)
	k.sphere(pink, body_c, Vector3(s.x * 0.24, s.y * 0.3, s.z * 0.36), 16, 8)
	for i in 8:
		var a := TAU * i / 8.0
		var t := PropMeshKit.at(body_c, a)
		k.torus(gold, Vector3.ZERO, 1.0, 0.012, 12, 3, t * PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5, 0, Vector3(s.x * 0.24, s.y * 0.3, 1.0)), PI)
	for sz: float in [-1.0, 1.0]:
		k.disc(PropMats.glass(Color(1.0, 0.9, 0.95, 0.45)), Vector3.ZERO, s.x * 0.08, 12,
				PropMeshKit.at(body_c + Vector3(0, s.y * 0.05, sz * s.z * 0.355), 0, sz * PI * 0.5), s.y * 0.1)
		k.torus(gold, Vector3.ZERO, 1.0, 0.04, 16, 3, PropMeshKit.at(body_c + Vector3(0, s.y * 0.05, sz * s.z * 0.36), 0, PI * 0.5 * sz, 0, Vector3(s.x * 0.08, s.y * 0.1, 1)) * PropMeshKit.at(Vector3.ZERO, 0, 0, 0))
	k.lathe(gold, body_c + Vector3(0, s.y * 0.28, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.25, 0), Vector2(0.2, 0.12),
			Vector2(0.06, 0.18), Vector2(0.04, 0.26), Vector2(0, 0.3)]), 10)
	k.sphere(PropMats.crystal(), body_c + Vector3(0, s.y * 0.28 + 0.34, 0), Vector3.ONE * 0.06, 8, 4)
	# coachman's bench, lanterns, a footboard
	k.box(pearl, Vector3(-s.x * 0.34, s.y * 0.45, 0), Vector3(0.4, 0.08, s.z * 0.6))
	PropParts.cushion(k, PropMats.fabric(EstateKit.ROSE), Vector3(-s.x * 0.34, s.y * 0.5, 0), Vector3(0.36, 0.08, s.z * 0.55))
	for sz: float in [-1.0, 1.0]:
		k.sphere(PropMats.glow(EstateKit.BUTTER, 1.5), Vector3(-s.x * 0.2, s.y * 0.68, sz * s.z * 0.3), Vector3(0.05, 0.08, 0.05), 6, 4)
		k.cyl(gold, Vector3(-s.x * 0.2, s.y * 0.75, sz * s.z * 0.3), 0.06, 0.0, 0.08, 6)
	for i in 8:
		var a := PI * 0.15 + PI * 0.7 * i / 7.0
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if i % 2 else EstateKit.PEARL), body_c + Vector3(-cos(a) * s.x * 0.24, -s.y * 0.05 + sin(a) * 0.0, -s.z * 0.36) + Vector3(0, -sin(a) * s.y * 0.2 + s.y * 0.15, 0), 0.05)
	k.tube(gold, PackedVector3Array([Vector3(-s.x * 0.4, s.y * 0.2, 0), Vector3(-s.x * 0.5, s.y * 0.15, 0)]), 0.03, 4)


static func _horse_statue(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var marble := PropMats.pearl(c)
	var gold := PropMats.gold()
	var ph := s.y * 0.15
	k.box(marble, Vector3(0, ph * 0.5, 0), Vector3(s.x, ph, s.z))
	k.box(gold, Vector3(0, ph - 0.02, -s.z * 0.5), Vector3(s.x * 0.8, 0.02, 0.01))
	# a rearing horse facing -Z: body tilted up, hind legs planted, forelegs raised
	var body := Vector3(0, ph + s.y * 0.45, s.z * 0.05)
	k.sphere(marble, body, Vector3(s.x * 0.22, s.y * 0.16, s.z * 0.3), 12, 6, PropMeshKit.at(Vector3.ZERO, 0, -0.6))
	for sx: float in [-1.0, 1.0]:
		k.tube(marble, PackedVector3Array([body + Vector3(sx * 0.12, -0.15, s.z * 0.15), body + Vector3(sx * 0.13, -s.y * 0.25, s.z * 0.28),
				Vector3(sx * 0.13, ph + 0.02, s.z * 0.3)]), 0.06, 6, Transform3D.IDENTITY, 0.04)
		k.tube(marble, PackedVector3Array([body + Vector3(sx * 0.12, 0.08, -s.z * 0.2), body + Vector3(sx * 0.13, 0.0, -s.z * 0.38),
				body + Vector3(sx * 0.13, -0.18, -s.z * 0.42)]), 0.05, 6, Transform3D.IDENTITY, 0.035)
	var neck := PackedVector3Array([body + Vector3(0, 0.12, -s.z * 0.2), body + Vector3(0, s.y * 0.25, -s.z * 0.3), body + Vector3(0, s.y * 0.33, -s.z * 0.33)])
	k.tube(marble, neck, 0.1, 8, Transform3D.IDENTITY, 0.07)
	k.sphere(marble, neck[2] + Vector3(0, 0.0, -0.1), Vector3(0.08, 0.09, 0.17), 8, 5, PropMeshKit.at(Vector3.ZERO, 0, 0.5))
	for sx: float in [-1.0, 1.0]:
		k.leaf(marble, neck[2] + Vector3(sx * 0.05, 0.08, 0.0), Vector3(sx * 0.2, 1, 0.1), 0.1, 0.04, 0.0)
	# a gilded flowing mane and tail
	var mane := PackedVector3Array()
	for i in 6:
		mane.append(neck[0].lerp(neck[2], i / 5.0) + Vector3(0, 0.08, 0.06))
	k.tube(gold, mane, 0.04, 5, Transform3D.IDENTITY, 0.02)
	k.tube(gold, PackedVector3Array([body + Vector3(0, -0.05, s.z * 0.3), body + Vector3(0, -s.y * 0.15, s.z * 0.42), Vector3(0, ph + 0.05, s.z * 0.45)]), 0.05, 5, Transform3D.IDENTITY, 0.02)
	k.torus(PropMats.satin(EstateKit.ROSE), neck[1], 0.11, 0.02, 10, 3, PropMeshKit.at(Vector3.ZERO, 0, 0.4))


static func _lever(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.box(gold, Vector3(0, s.y * 0.3, s.z * 0.35), Vector3(s.x * 0.8, s.y * 0.6, s.z * 0.3))
	k.tube(gold, PackedVector3Array([Vector3(0, s.y * 0.25, s.z * 0.2), Vector3(0, s.y * 0.6, -s.z * 0.2), Vector3(0, s.y * 0.85, -s.z * 0.3)]), 0.012, 5)
	PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(0, s.y * 0.88, -s.z * 0.3), s.x * 0.3)
	k.sphere(PropMats.glow(EstateKit.BUTTER, 0.8), Vector3(0, s.y * 0.3, s.z * 0.18), Vector3.ONE * 0.012, 4, 2)


static func _glint(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var glow := PropMats.glow(c, 3.0)
	k.sphere(glow, Vector3(0, s.y * 0.5, 0), Vector3.ONE * s.x * 0.12, 6, 4)
	# a four-point sparkle star of thin spikes
	for i in 4:
		var a := PI * 0.5 * i
		k.cyl(glow, Vector3(0, 0, 0), s.x * 0.04, 0.0, s.y * 0.45, 4, false, PropMeshKit.at(Vector3(0, s.y * 0.5, 0), 0, 0, a))
	for i in 2:
		k.cyl(PropMats.glow(EstateKit.PEARL, 2.0), Vector3(0, 0, 0), s.x * 0.03, 0.0, s.y * 0.3, 4, false,
				PropMeshKit.at(Vector3(0, s.y * 0.5, 0), 0, PI * 0.5 + PI * i))


static func _loose_panel(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y * 0.5, 0), Vector3(s.x, s.y, s.z * 0.6), PropMeshKit.at(Vector3.ZERO, 0, 0, 0.03))
	PropParts.frame(k, PropMats.wood(c.lightened(0.1)), Vector3(0, s.y * 0.5, -s.z * 0.25), s.x * 0.95, s.y * 0.95, 0.05, s.z * 0.4)
	PropParts.bloom(k, PropMats.gold(), Vector3(0, s.y * 0.5, -s.z * 0.45), 0.04)
	k.box(PropMats.satin(PropMats.PLUM), Vector3(s.x * 0.48, s.y * 0.5, -s.z * 0.1), Vector3(0.012, s.y * 0.9, s.z * 0.4))
