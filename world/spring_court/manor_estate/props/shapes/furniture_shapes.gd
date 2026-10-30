## Seating, tables, desks, cabinets and chests. Front faces -Z, backs at +Z.
class_name FurnitureShapes
extends RefCounted



static func build(k: PropMeshKit, id: StringName, s: Vector3, c: Color) -> bool:
	match id:
		&"sofa": _sofa(k, s, c, 3, true)
		&"chaise_longue": _chaise(k, s, c)
		&"armchair": _armchair(k, s, c, false)
		&"wingback_chair": _armchair(k, s, c, true)
		&"chair_dining": _chair(k, s, PropMats.pearl(c), PropMats.fabric(EstateKit.ROSE), true)
		&"chair_simple": _chair(k, s, PropMats.wood(c), PropMats.fabric(EstateKit.BLUSH), false)
		&"bench_settle": _settle(k, s, c)
		&"stool": _stool(k, s, c)
		&"table_dining_long": _table(k, s, c, 0, true)
		&"table_round": _round_table(k, s, c, true)
		&"table_side": _round_table(k, s, c, false)
		&"table_tea": _tea_table(k, s, c)
		&"table_work": _table(k, s, c, 2, false)
		&"desk_writing": _desk(k, s, c, false)
		&"desk_large": _desk(k, s, c, true)
		&"sideboard": _sideboard(k, s, c)
		&"chest_trunk": _trunk(k, s, c)
		&"coat_rack": _coat_rack(k, s, c)
		&"window_seat": _window_seat(k, s, c)
		&"pew": _pew(k, s, c)
		&"cabinet_curio": _curio(k, s, c)
		_: return false
	return true


static func rolled_x(k: PropMeshKit, m: Material, center: Vector3, r: float, length: float,
		sc: Vector3 = Vector3.ONE, seg: int = 10) -> void:
	k.cyl(m, Vector3(0, -length * 0.5, 0), r, r, length, seg, true, PropMeshKit.at(center, 0, 0, PI * 0.5, sc))


static func rolled_z(k: PropMeshKit, m: Material, center: Vector3, r: float, length: float,
		sc: Vector3 = Vector3.ONE, seg: int = 10) -> void:
	k.cyl(m, Vector3(0, -length * 0.5, 0), r, r, length, seg, true, PropMeshKit.at(center, 0, PI * 0.5, 0, sc))


static func _sofa(k: PropMeshKit, s: Vector3, c: Color, seats: int, buttons: bool) -> void:
	var fab := PropMats.fabric(c)
	var gold := PropMats.gold()
	var w := s.x
	var d := s.z
	var leg_h := 0.14
	PropParts.legs4(k, gold, w * 0.94, d * 0.86, leg_h, 0.035, 1)
	k.box(fab, Vector3(0, leg_h + 0.13, 0), Vector3(w * 0.9, 0.26, d * 0.9))
	k.box(gold, Vector3(0, leg_h + 0.02, -d * 0.45), Vector3(w * 0.9, 0.04, 0.03))
	var inner := w * 0.78
	for i in seats:
		var cx := -inner * 0.5 + inner * (i + 0.5) / seats
		PropParts.cushion(k, fab, Vector3(cx, leg_h + 0.33, -d * 0.06), Vector3(inner / seats * 0.98, 0.18, d * 0.7))
		PropParts.cushion(k, fab, Vector3(cx, leg_h + 0.58, d * 0.3), Vector3(inner / seats * 0.96, 0.46, 0.2))
	# camel back with a gilt crest
	k.box(fab, Vector3(0, s.y * 0.62, d * 0.42), Vector3(w * 0.88, s.y * 0.6, 0.12))
	PropParts.cushion(k, fab, Vector3(0, s.y * 0.9, d * 0.42), Vector3(w * 0.7, 0.2, 0.14))
	k.sphere(gold, Vector3(0, s.y * 0.97, d * 0.38), Vector3(0.08, 0.06, 0.03), 6, 3)
	if buttons:
		for i in seats * 2 + 1:
			var bx := -inner * 0.5 + inner * i / float(seats * 2)
			k.sphere(gold, Vector3(bx, s.y * 0.72, d * 0.355), Vector3.ONE * 0.018, 5, 3)
	for sx: float in [-1.0, 1.0]:
		k.box(fab, Vector3(sx * w * 0.44, leg_h + 0.32, 0), Vector3(w * 0.08, 0.36, d * 0.86))
		rolled_z(k, fab, Vector3(sx * w * 0.44, leg_h + 0.52, 0), 0.1, d * 0.9)
		k.sphere(gold, Vector3(sx * w * 0.44, leg_h + 0.52, -d * 0.46), Vector3(0.05, 0.05, 0.02), 6, 3)
	# throw pillows
	PropParts.cushion(k, PropMats.fabric(EstateKit.BUTTER), Vector3(-w * 0.32, leg_h + 0.55, d * 0.12), Vector3(0.32, 0.3, 0.12),
			PropMeshKit.at(Vector3.ZERO, 0.3))
	PropParts.cushion(k, PropMats.fabric(EstateKit.MINT), Vector3(w * 0.32, leg_h + 0.55, d * 0.12), Vector3(0.32, 0.3, 0.12),
			PropMeshKit.at(Vector3.ZERO, -0.3))


static func _chaise(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var fab := PropMats.fabric(c)
	var gold := PropMats.gold()
	var w := s.x
	var d := s.z
	PropParts.legs4(k, gold, w * 0.94, d * 0.84, 0.16, 0.035, 1)
	k.box(fab, Vector3(0, 0.3, 0), Vector3(w * 0.94, 0.28, d * 0.9))
	PropParts.cushion(k, fab, Vector3(w * 0.05, 0.48, 0), Vector3(w * 0.86, 0.14, d * 0.86))
	# scrolled head end rising at -X
	var pts := PackedVector3Array()
	for i in 9:
		var t := float(i) / 8.0
		pts.append(Vector3(-w * 0.44 + sin(t * PI * 0.5) * -0.04, 0.42 + t * (s.y - 0.55), 0))
	for zi: float in [-1.0, 1.0]:
		var side := PackedVector3Array()
		for p in pts:
			side.append(p + Vector3(0, 0, zi * d * 0.36))
		k.tube(gold, side, 0.025, 5)
	k.box(fab, Vector3(-w * 0.43, (s.y + 0.42) * 0.5, 0), Vector3(0.14, s.y - 0.42 - 0.12, d * 0.86))
	rolled_z(k, fab, Vector3(-w * 0.42, s.y - 0.12, 0), 0.12, d * 0.9)
	# half back along +Z
	k.box(fab, Vector3(-w * 0.15, 0.62, d * 0.42), Vector3(w * 0.55, 0.36, 0.1))
	PropParts.cushion(k, PropMats.fabric(EstateKit.LILAC), Vector3(-w * 0.28, 0.62, 0), Vector3(0.18, 0.18, d * 0.6),
			PropMeshKit.at(Vector3.ZERO, 0.0, 0.0, 0.0))
	k.torus(gold, Vector3(-w * 0.42, s.y - 0.12, -d * 0.45), 0.08, 0.015, 10, 4, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))


static func _armchair(k: PropMeshKit, s: Vector3, c: Color, wing: bool) -> void:
	var fab := PropMats.fabric(c)
	var gold := PropMats.gold()
	var w := s.x
	var d := s.z
	PropParts.legs4(k, gold, w * 0.9, d * 0.86, 0.16, 0.035, 1)
	k.box(fab, Vector3(0, 0.3, 0), Vector3(w * 0.86, 0.28, d * 0.86))
	PropParts.cushion(k, fab, Vector3(0, 0.48, -d * 0.05), Vector3(w * 0.66, 0.16, d * 0.7))
	var back_h := s.y - 0.4
	k.box(fab, Vector3(0, 0.4 + back_h * 0.5, d * 0.38), Vector3(w * 0.8, back_h, 0.14))
	PropParts.cushion(k, fab, Vector3(0, 0.4 + back_h - 0.06, d * 0.38), Vector3(w * 0.8, 0.2, 0.18))
	PropParts.cushion(k, fab, Vector3(0, 0.75, d * 0.26), Vector3(w * 0.6, back_h * 0.6, 0.14))
	for sx: float in [-1.0, 1.0]:
		k.box(fab, Vector3(sx * w * 0.4, 0.5, 0), Vector3(0.12, 0.28, d * 0.84))
		rolled_z(k, fab, Vector3(sx * w * 0.4, 0.66, -0.02), 0.08, d * 0.86)
		k.sphere(gold, Vector3(sx * w * 0.4, 0.66, -d * 0.45), Vector3(0.04, 0.04, 0.015), 6, 3)
		if wing:
			PropParts.cushion(k, fab, Vector3(sx * w * 0.4, s.y * 0.78, d * 0.22), Vector3(0.12, s.y * 0.38, d * 0.44))
	k.sphere(gold, Vector3(0, s.y - 0.02, d * 0.33), Vector3(0.06, 0.04, 0.02), 6, 3)


static func _chair(k: PropMeshKit, s: Vector3, frame: Material, pad: Material, oval: bool) -> void:
	var w := s.x
	var d := s.z
	var seat_h := 0.46
	PropParts.legs4(k, frame, w, d, seat_h - 0.04, 0.025, 0)
	k.box(frame, Vector3(0, seat_h - 0.03, 0), Vector3(w, 0.06, d))
	PropParts.cushion(k, pad, Vector3(0, seat_h + 0.03, -0.01), Vector3(w * 0.9, 0.08, d * 0.88))
	for sx: float in [-1.0, 1.0]:
		k.cyl(frame, Vector3(sx * (w * 0.5 - 0.03), seat_h, d * 0.45), 0.022, 0.018, s.y - seat_h - 0.02, 6)
	if oval:
		var cy := seat_h + (s.y - seat_h) * 0.55
		var t := PropMeshKit.at(Vector3(0, cy, d * 0.45), 0, PI * 0.5, 0, Vector3(1.0, 1.0, 1.35))
		k.torus(PropMats.gold(), Vector3.ZERO, w * 0.36, 0.022, 16, 5, t)
		PropParts.cushion(k, pad, Vector3(0, cy, d * 0.45), Vector3(w * 0.66, (s.y - seat_h) * 0.66, 0.05))
		k.sphere(PropMats.gold(), Vector3(0, s.y - 0.03, d * 0.45), Vector3(0.04, 0.03, 0.02), 6, 3)
	else:
		for i in 3:
			k.box(frame, Vector3(0, seat_h + 0.18 + i * 0.12, d * 0.45), Vector3(w * 0.9, 0.05, 0.03))
		k.box(frame, Vector3(0, s.y - 0.02, d * 0.45), Vector3(w, 0.05, 0.05))


static func _settle(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, 0.22, 0), Vector3(s.x, 0.44, s.z * 0.9))
	PropParts.drawers(k, PropMats.wood(c.lightened(0.08)), PropMats.gold(), -s.x * 0.45, s.x * 0.45, 0.05, 0.38, -s.z * 0.45, 1, 3)
	k.box(wood, Vector3(0, 0.7, s.z * 0.44), Vector3(s.x, 0.6, 0.06))
	for i in 5:
		k.box(PropMats.wood(c.lightened(0.1)), Vector3(-s.x * 0.4 + i * s.x * 0.2, 0.7, s.z * 0.4), Vector3(0.12, 0.45, 0.02))
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * s.x * 0.48, 0.65, 0), Vector3(0.05, 0.42, s.z * 0.9))
	PropParts.cushion(k, PropMats.fabric(EstateKit.BLUSH), Vector3(0, 0.48, -0.02), Vector3(s.x * 0.88, 0.08, s.z * 0.7))


static func _stool(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	for i in 3:
		var a := TAU * i / 3.0
		var foot := Vector3(cos(a) * s.x * 0.45, 0, sin(a) * s.z * 0.45)
		k.tube(wood, PackedVector3Array([foot, Vector3(foot.x * 0.6, s.y - 0.05, foot.z * 0.6)]), 0.022, 6)
	k.torus(wood, Vector3(0, s.y * 0.35, 0), s.x * 0.36, 0.015, 12, 4)
	k.cyl(wood, Vector3(0, s.y - 0.06, 0), s.x * 0.45, s.x * 0.45, 0.04, 12)
	PropParts.cushion(k, PropMats.fabric(EstateKit.ROSE), Vector3(0, s.y - 0.015, 0), Vector3(s.x * 0.85, 0.05, s.z * 0.85))


static func _table(k: PropMeshKit, s: Vector3, c: Color, style: int, runner: bool) -> void:
	var top := PropMats.pearl(c) if c.s < 0.1 else PropMats.wood(c)
	var gold := PropMats.gold()
	PropParts.slab(k, top, Vector3(0, s.y - 0.03, 0), Vector3(s.x, 0.06, s.z), gold if style == 0 else null)
	k.box(top, Vector3(0, s.y - 0.1, 0), Vector3(s.x * 0.94, 0.1, s.z * 0.9))
	if style == 0 and s.x > 4.0:
		# pedestal pairs down a long table
		var n := int(s.x / 2.6)
		for i in n:
			var x := -s.x * 0.5 + s.x * (i + 0.5) / n
			k.lathe(top, Vector3(x, 0, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.32, 0), Vector2(0.3, 0.06),
					Vector2(0.12, 0.16), Vector2(0.1, 0.4), Vector2(0.16, 0.55), Vector2(0.09, s.y - 0.15), Vector2(0, s.y - 0.15)]), 10)
			k.torus(gold, Vector3(x, 0.4, 0), 0.11, 0.02, 10, 4)
	else:
		PropParts.legs4(k, top, s.x, s.z, s.y - 0.06, 0.05 if style == 2 else 0.04, style)
		if style == 2:
			k.box(top, Vector3(0, 0.15, 0), Vector3(s.x * 0.86, 0.05, 0.06))
			k.box(top, Vector3(0, s.y - 0.18, -s.z * 0.45), Vector3(s.x * 0.8, 0.12, 0.03))
	if runner:
		k.box(PropMats.fabric(EstateKit.ROSE), Vector3(0, s.y + 0.005, 0), Vector3(s.x * 0.86, 0.01, s.z * 0.32))
		var n2 := int(s.x / 1.6)
		for i in n2:
			var x := -s.x * 0.4 + s.x * 0.8 * (i + 0.5) / n2
			if i % 2 == 0:
				PropParts.candle(k, Vector3(x, s.y, 0), 0.22, 0.025)
				k.cyl(gold, Vector3(x, s.y, 0), 0.06, 0.03, 0.03, 8)
			else:
				k.lathe(PropMats.pearl(EstateKit.PERIWINKLE), Vector3(x, s.y, 0), PackedVector2Array([Vector2(0, 0),
						Vector2(0.06, 0), Vector2(0.09, 0.08), Vector2(0.05, 0.16), Vector2(0.07, 0.2), Vector2(0, 0.2)]), 8)
				for b in 5:
					var a := TAU * b / 5.0
					PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if b % 2 == 0 else EstateKit.BLUSH),
							Vector3(x + cos(a) * 0.06, s.y + 0.25, sin(a) * 0.06), 0.045)
		for i in int(s.x / 0.9):
			for sz: float in [-1.0, 1.0]:
				var x := -s.x * 0.44 + i * 0.9 + 0.2
				k.disc(PropMats.pearl(), Vector3(x, s.y + 0.008, sz * s.z * 0.33), 0.12, 10)
				k.torus(gold, Vector3(x, s.y + 0.012, sz * s.z * 0.33), 0.11, 0.006, 8, 3)


static func _round_table(k: PropMeshKit, s: Vector3, c: Color, cloth: bool) -> void:
	var top := PropMats.body(c)
	var gold := PropMats.gold()
	var r := s.x * 0.5
	k.cyl(top, Vector3(0, s.y - 0.04, 0), r, r, 0.04, 20)
	k.torus(gold, Vector3(0, s.y - 0.04, 0), r, 0.012, 20, 4)
	k.lathe(top, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(r * 0.5, 0), Vector2(r * 0.45, 0.05),
			Vector2(r * 0.12, s.y * 0.2), Vector2(r * 0.08, s.y * 0.5), Vector2(r * 0.14, s.y * 0.65),
			Vector2(r * 0.07, s.y - 0.04), Vector2(0, s.y - 0.04)]), 12)
	k.torus(gold, Vector3(0, s.y * 0.5, 0), r * 0.09, 0.012, 10, 4)
	if cloth:
		k.lathe(PropMats.fabric(EstateKit.BLUSH), Vector3.ZERO, PackedVector2Array([Vector2(0, s.y - 0.3), Vector2(r * 1.02, s.y - 0.32),
				Vector2(r * 1.01, s.y - 0.1), Vector2(r * 1.0, s.y), Vector2(0, s.y + 0.005)]), 20)
		k.lathe(PropMats.pearl(), Vector3(0, s.y, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.12, 0), Vector2(0.1, 0.1),
				Vector2(0.06, 0.18), Vector2(0, 0.18)]), 8)
		for b in 4:
			PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(cos(b * 1.57) * 0.05, s.y + 0.22, sin(b * 1.57) * 0.05), 0.045)
	else:
		k.lathe(PropMats.pearl(EstateKit.MINT), Vector3(0, s.y, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0),
				Vector2(0.07, 0.07), Vector2(0.03, 0.14), Vector2(0, 0.14)]), 8)


static func _tea_table(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var top := PropMats.body(c)
	var gold := PropMats.gold()
	k.box(top, Vector3(0, s.y - 0.03, 0), Vector3(s.x, 0.04, s.z))
	k.box(gold, Vector3(0, s.y - 0.06, 0), Vector3(s.x * 0.96, 0.03, s.z * 0.96))
	PropParts.legs4(k, top, s.x * 0.95, s.z * 0.9, s.y - 0.05, 0.025, 1)
	k.box(top, Vector3(0, 0.12, 0), Vector3(s.x * 0.8, 0.02, s.z * 0.7))
	# tea set: pot and two cups
	k.lathe(PropMats.pearl(EstateKit.BLUSH), Vector3(0, s.y - 0.01, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.07, 0),
			Vector2(0.09, 0.06), Vector2(0.07, 0.12), Vector2(0.03, 0.14), Vector2(0.02, 0.17), Vector2(0, 0.17)]), 10)
	k.tube(gold, PackedVector3Array([Vector3(0.08, s.y + 0.06, 0), Vector3(0.14, s.y + 0.1, 0), Vector3(0.16, s.y + 0.13, 0)]), 0.012, 5)
	for sx: float in [-1.0, 1.0]:
		k.cyl(PropMats.pearl(), Vector3(sx * 0.25, s.y - 0.01, -0.05), 0.07, 0.07, 0.01, 10)
		k.cyl(PropMats.pearl(EstateKit.ROSE), Vector3(sx * 0.25, s.y, -0.05), 0.03, 0.04, 0.05, 10)


static func _desk(k: PropMeshKit, s: Vector3, c: Color, large: bool) -> void:
	var wood := PropMats.wood(c)
	var light := PropMats.wood(c.lightened(0.12))
	var gold := PropMats.gold()
	k.box(wood, Vector3(0, s.y - 0.03, 0), Vector3(s.x, 0.05, s.z))
	k.box(PropMats.satin(EstateKit.MINT.darkened(0.25)), Vector3(0, s.y + 0.001, 0.02), Vector3(s.x * 0.7, 0.004, s.z * 0.6))
	var ped_w := s.x * 0.28
	for sx: float in [-1.0, 1.0]:
		if not large and sx > 0:
			PropParts.legs4(k, wood, ped_w * 2.0, s.z, s.y - 0.05, 0.03, 1, 0.05)
			continue
		var px := sx * (s.x * 0.5 - ped_w * 0.5 - 0.02)
		k.box(wood, Vector3(px, (s.y - 0.05) * 0.5, 0), Vector3(ped_w, s.y - 0.05, s.z * 0.9))
		PropParts.drawers(k, light, gold, px - ped_w * 0.45, px + ped_w * 0.45, 0.06, s.y - 0.1, -s.z * 0.45, 3)
	k.box(light, Vector3(0, s.y - 0.12, -s.z * 0.45), Vector3(s.x * 0.36, 0.1, 0.02))
	# desk set: inkwell, quill, books, candle
	k.cyl(gold, Vector3(s.x * 0.3, s.y, -s.z * 0.15), 0.04, 0.035, 0.05, 8)
	k.tube(PropMats.pearl(EstateKit.BLUSH), PackedVector3Array([Vector3(s.x * 0.3, s.y + 0.04, -s.z * 0.15),
			Vector3(s.x * 0.33, s.y + 0.2, -s.z * 0.12)]), 0.01, 4, Transform3D.IDENTITY, 0.002)
	PropParts.books(k, PropParts.rng(&"desk_books"), -s.x * 0.42, -s.x * 0.2, s.y, s.z * 0.15, 0.2, 0.25)
	PropParts.candle(k, Vector3(s.x * 0.4, s.y, s.z * 0.3), 0.18, 0.025)
	if large:
		var g := PropMats.metal(EstateKit.PERIWINKLE)
		k.sphere(g, Vector3(-s.x * 0.05, s.y + 0.18, s.z * 0.25), Vector3.ONE * 0.12, 10, 6)
		k.torus(gold, Vector3(-s.x * 0.05, s.y + 0.18, s.z * 0.25), 0.13, 0.008, 14, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
		k.cyl(gold, Vector3(-s.x * 0.05, s.y, s.z * 0.25), 0.06, 0.02, 0.06, 8)


static func _sideboard(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.body(c)
	var gold := PropMats.gold()
	var leg := 0.16
	PropParts.legs4(k, gold, s.x * 0.96, s.z * 0.9, leg, 0.03, 1)
	k.box(body, Vector3(0, leg + (s.y - leg - 0.35) * 0.5, 0), Vector3(s.x, s.y - leg - 0.35, s.z * 0.95))
	k.box(body, Vector3(0, s.y - 0.37, 0), Vector3(s.x * 1.02, 0.04, s.z))
	PropParts.drawers(k, PropMats.pearl(EstateKit.BLUSH), gold, -s.x * 0.48, s.x * 0.48, leg + 0.35, s.y - 0.4, -s.z * 0.47, 1, 3)
	for i in 2:
		var x := -s.x * 0.25 + i * s.x * 0.5
		k.box(PropMats.pearl(EstateKit.BLUSH), Vector3(x, leg + 0.17, -s.z * 0.48), Vector3(s.x * 0.46, 0.3, 0.02))
		k.torus(gold, Vector3(x, leg + 0.17, -s.z * 0.49), 0.07, 0.008, 12, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
	# silver service and fruit
	var top := s.y - 0.35
	k.lathe(PropMats.metal(EstateKit.LILAC.lightened(0.3)), Vector3(-s.x * 0.3, top, 0), PackedVector2Array([Vector2(0, 0),
			Vector2(0.06, 0), Vector2(0.1, 0.12), Vector2(0.06, 0.22), Vector2(0.02, 0.26), Vector2(0, 0.26)]), 10)
	k.lathe(gold, Vector3(s.x * 0.15, top, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.03, 0.06),
			Vector2(0.18, 0.1), Vector2(0.17, 0.12), Vector2(0, 0.11)]), 12)
	var fruit := [EstateKit.ROSE, EstateKit.BUTTER, PropMats.BERRY, EstateKit.MINT, Color(1.0, 0.6, 0.3)]
	for i in 5:
		var a := TAU * i / 5.0
		k.sphere(PropMats.gloss(fruit[i]), Vector3(s.x * 0.15 + cos(a) * 0.08, top + 0.15, sin(a) * 0.08), Vector3.ONE * 0.045, 7, 4)
	PropParts.candle(k, Vector3(s.x * 0.4, top, 0.05), 0.24, 0.025)
	PropParts.candle(k, Vector3(-s.x * 0.45, top, 0.05), 0.2, 0.025)


static func _trunk(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	var gold := PropMats.gold()
	k.box(wood, Vector3(0, s.y * 0.35, 0), Vector3(s.x, s.y * 0.7, s.z))
	rolled_x(k, wood, Vector3(0, s.y * 0.7, 0), s.z * 0.5, s.x, Vector3(1, s.y * 0.3 / (s.z * 0.5), 1), 14)
	for x: float in [-0.35, 0.0, 0.35]:
		k.box(gold, Vector3(x * s.x, s.y * 0.35, 0), Vector3(0.04, s.y * 0.72, s.z * 1.02))
	k.box(gold, Vector3(0, s.y * 0.55, -s.z * 0.51), Vector3(0.1, 0.12, 0.02))
	k.sphere(PropMats.gloss(EstateKit.ROSE), Vector3(0, s.y * 0.55, -s.z * 0.53), Vector3(0.025, 0.025, 0.01), 6, 3)


static func _coat_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.lathe(wood, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.05, 0.1), Vector2(0.025, 0.2),
			Vector2(0.025, s.y - 0.12), Vector2(0.04, s.y - 0.06), Vector2(0, s.y)]), 8)
	for i in 3:
		var a := TAU * i / 3.0
		k.tube(wood, PackedVector3Array([Vector3(0, 0.15, 0), Vector3(cos(a) * s.x * 0.48, 0.0, sin(a) * s.z * 0.48)]), 0.02, 5)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var tip := Vector3(cos(a) * 0.2, s.y - 0.1, sin(a) * 0.2)
		k.tube(PropMats.gold(), PackedVector3Array([Vector3(0, s.y - 0.25, 0), tip * Vector3(0.7, 1, 0.7), tip + Vector3(0, 0.05, 0)]), 0.012, 4)
		k.sphere(PropMats.gold(), tip + Vector3(0, 0.06, 0), Vector3.ONE * 0.02, 5, 3)
	# a lilac cloak and a straw bonnet
	k.lathe(PropMats.fabric(EstateKit.LILAC), Vector3(0.12, s.y * 0.35, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.18, 0),
			Vector2(0.12, s.y * 0.3), Vector2(0.05, s.y * 0.48), Vector2(0, s.y * 0.5)]), 8)
	k.cyl(PropMats.fabric(PropMats.STRAW), Vector3(-0.13, s.y - 0.12, 0.05), 0.15, 0.15, 0.02, 10)
	k.sphere(PropMats.fabric(PropMats.STRAW), Vector3(-0.13, s.y - 0.1, 0.05), Vector3(0.08, 0.07, 0.08), 8, 4)


static func _window_seat(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.pearl()
	var fab := PropMats.fabric(c)
	k.box(body, Vector3(0, 0.22, 0), Vector3(s.x, 0.44, s.z))
	for i in 3:
		var x := -s.x / 3.0 + i * s.x / 3.0
		k.box(PropMats.pearl(EstateKit.BLUSH), Vector3(x, 0.22, -s.z * 0.5), Vector3(s.x / 3.0 - 0.08, 0.32, 0.02))
		k.sphere(PropMats.gold(), Vector3(x, 0.3, -s.z * 0.52), Vector3.ONE * 0.02, 5, 3)
	PropParts.cushion(k, fab, Vector3(0, 0.49, 0), Vector3(s.x * 0.98, 0.1, s.z * 0.95))
	var cols := [EstateKit.LILAC, EstateKit.MINT, EstateKit.BUTTER, EstateKit.PERIWINKLE]
	for i in 4:
		PropParts.cushion(k, PropMats.fabric(cols[i]), Vector3(-s.x * 0.38 + i * s.x * 0.25, 0.5 + 0.06, s.z * 0.3),
				Vector3(0.36, 0.06 + 0.22, 0.14), PropMeshKit.at(Vector3.ZERO, (i - 1.5) * 0.12))


static func _pew(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, 0.44, -s.z * 0.1), Vector3(s.x, 0.05, s.z * 0.65))
	k.box(wood, Vector3(0, 0.72, s.z * 0.4), Vector3(s.x, 0.56, 0.05))
	k.box(wood, Vector3(0, s.y - 0.02, s.z * 0.4), Vector3(s.x * 1.01, 0.04, 0.12))
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * s.x * 0.49, s.y * 0.45, 0), Vector3(0.06, s.y * 0.9, s.z))
		k.sphere(PropMats.gold(), Vector3(sx * s.x * 0.49, s.y * 0.92, -s.z * 0.2), Vector3(0.05, 0.05, 0.05), 6, 3)
		k.torus(PropMats.gold(), Vector3(sx * s.x * 0.5, s.y * 0.6, 0), 0.12, 0.012, 12, 3, PropMeshKit.at(Vector3.ZERO, 0, 0, PI * 0.5))
	PropParts.cushion(k, PropMats.fabric(EstateKit.ROSE), Vector3(0, 0.49, -s.z * 0.1), Vector3(s.x * 0.95, 0.06, s.z * 0.6))
	k.box(wood, Vector3(0, 0.12, -s.z * 0.42), Vector3(s.x * 0.95, 0.08, 0.14))


static func _curio(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.body(c)
	var gold := PropMats.gold()
	PropParts.legs4(k, gold, s.x * 0.95, s.z * 0.9, 0.15, 0.03, 1)
	k.box(body, Vector3(0, 0.25, 0), Vector3(s.x, 0.2, s.z))
	for sx: float in [-1.0, 1.0]:
		k.box(body, Vector3(sx * s.x * 0.47, s.y * 0.6, 0), Vector3(s.x * 0.06, s.y * 0.7, s.z))
	k.box(body, Vector3(0, s.y * 0.6, s.z * 0.47), Vector3(s.x, s.y * 0.7, s.z * 0.06))
	# bonnet pediment
	rolled_z(k, body, Vector3(0, s.y - s.x * 0.18 - 0.02, 0), s.x * 0.5, s.z, Vector3(1, 0.36, 1), 14)
	k.box(body, Vector3(0, s.y * 0.95 - 0.1, 0), Vector3(s.x * 1.04, 0.06, s.z * 1.04))
	k.sphere(gold, Vector3(0, s.y - 0.06, -s.z * 0.3), Vector3(0.06, 0.06, 0.04), 6, 3)
	var glass := PropMats.glass()
	k.box(glass, Vector3(0, s.y * 0.6, -s.z * 0.48), Vector3(s.x * 0.88, s.y * 0.7, 0.01))
	PropParts.frame(k, gold, Vector3(0, s.y * 0.6, -s.z * 0.49), s.x * 0.9, s.y * 0.7, 0.03, 0.02)
	# shelves of curios: teacups, shells, figurines, little vases
	var trinket := [EstateKit.ROSE, EstateKit.LILAC, EstateKit.MINT, EstateKit.PERIWINKLE, EstateKit.BUTTER]
	for sh in 3:
		var y := 0.35 + sh * s.y * 0.22
		k.box(PropMats.pearl(EstateKit.BLUSH), Vector3(0, y, 0), Vector3(s.x * 0.86, 0.025, s.z * 0.85))
		for i in 4:
			var x := -s.x * 0.33 + i * s.x * 0.22
			var m := PropMats.pearl(trinket[(i + sh) % trinket.size()])
			match (i + sh) % 3:
				0: k.lathe(m, Vector3(x, y, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.06, 0.08),
						Vector2(0.03, 0.15), Vector2(0.04, 0.18), Vector2(0, 0.18)]), 8)
				1: k.sphere(m, Vector3(x, y + 0.06, 0), Vector3(0.06, 0.06, 0.05), 8, 4)
				_:
					k.cyl(m, Vector3(x, y, 0), 0.05, 0.05, 0.01, 8)
					k.cyl(m, Vector3(x, y + 0.01, 0), 0.025, 0.035, 0.04, 8)
