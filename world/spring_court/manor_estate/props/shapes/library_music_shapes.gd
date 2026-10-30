## Library (bookcases full of candy-coloured spines, ladders, maps, scrolls),
## music (gilt harp, pianoforte, lute) and Feyre's painting things.
class_name LibraryMusicShapes
extends RefCounted



static func build(k: PropMeshKit, id: StringName, s: Vector3, c: Color) -> bool:
	match id:
		&"bookcase_tall": _bookcase(k, id, s, c, true)
		&"bookcase_low": _bookcase(k, id, s, c, false)
		&"library_ladder": _ladder(k, s, c)
		&"reading_lectern": _lectern(k, s, c)
		&"book_stack": _book_stack(k, s, c)
		&"map_table": _map_table(k, s, c)
		&"map_wall": _map_wall(k, s, c)
		&"scroll_rack": _scroll_rack(k, s, c)
		&"inkstand": _inkstand(k, s, c)
		&"harp_gilt": _harp(k, s, c)
		&"pianoforte": _piano(k, s, c)
		&"music_stand": _music_stand(k, s, c)
		&"lute_on_stand": _lute(k, s, c)
		&"easel": _easel(k, s, c)
		&"canvas_stack": _canvas_stack(k, s, c)
		&"paint_table": _paint_table(k, s, c)
		&"pigment_jars": _pigments(k, s, c)
		_: return false
	return true


static func _open_book(k: PropMeshKit, center: Vector3, w: float, d: float, tilt: float) -> void:
	for sx: float in [-1.0, 1.0]:
		var t := PropMeshKit.at(center, 0, 0, sx * -tilt)
		k.box(PropMats.satin(EstateKit.ROSE), Vector3(sx * w * 0.25, -0.006, 0), Vector3(w * 0.5, 0.008, d), t)
		k.box(PropMats.pearl(EstateKit.CREAM), Vector3(sx * w * 0.24, 0.006, 0), Vector3(w * 0.46, 0.016, d * 0.94), t)


static func _bookcase(k: PropMeshKit, id: StringName, s: Vector3, c: Color, tall: bool) -> void:
	var wood := PropMats.wood(c)
	var gold := PropMats.gold()
	var rnd := PropParts.rng(id)
	var side := 0.06
	k.box(wood, Vector3(0, s.y * 0.5, s.z * 0.47), Vector3(s.x, s.y, s.z * 0.06))
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * (s.x * 0.5 - side * 0.5), s.y * 0.5, 0), Vector3(side, s.y, s.z))
		if tall:
			k.box(gold, Vector3(sx * (s.x * 0.5 - side * 0.5), s.y * 0.5, -s.z * 0.5), Vector3(0.02, s.y * 0.9, 0.01))
	k.box(wood, Vector3(0, 0.05, 0), Vector3(s.x, 0.1, s.z))
	var top_h := 0.18 if tall else 0.05
	k.box(wood, Vector3(0, s.y - top_h * 0.5, 0), Vector3(s.x * 1.04, top_h, s.z * 1.06))
	if tall:
		k.box(gold, Vector3(0, s.y - top_h - 0.01, -s.z * 0.52), Vector3(s.x * 0.98, 0.02, 0.02))
		PropParts.bloom(k, gold, Vector3(0, s.y - top_h * 0.5, -s.z * 0.54), 0.07)
	var shelves := 6 if tall else 2
	var inner := s.x - side * 2.0
	var span := (s.y - top_h - 0.1) / shelves
	for i in shelves:
		var y := 0.1 + i * span
		if i > 0:
			k.box(wood, Vector3(0, y, 0), Vector3(inner, 0.03, s.z * 0.92))
		var by := y + 0.015
		var mh := span * 0.8
		# most shelves are full of books; a few hold a vase, a globe of glass or a stacked pile
		var bx0 := -inner * 0.5
		var bx1 := inner * 0.5
		var deco := rnd.randi() % 4
		if deco == 0 and tall:
			var dx := rnd.randf_range(-inner * 0.3, inner * 0.3)
			k.lathe(PropMats.pearl(EstateKit.PERIWINKLE), Vector3(dx, by, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0),
					Vector2(0.09, mh * 0.35), Vector2(0.04, mh * 0.7), Vector2(0, mh * 0.7)]), 8)
			PropParts.books(k, rnd, bx0, dx - 0.12, by, -s.z * 0.42, s.z * 0.8, mh)
			PropParts.books(k, rnd, dx + 0.12, bx1, by, -s.z * 0.42, s.z * 0.8, mh)
		elif deco == 1:
			for j in 4:
				var col: Color = PropMats.BOOKS[rnd.randi() % PropMats.BOOKS.size()]
				k.box(PropMats.satin(col), Vector3(bx1 - 0.2, by + 0.025 + j * 0.05, -s.z * 0.05), Vector3(0.3, 0.048, s.z * 0.6),
						PropMeshKit.at(Vector3.ZERO, j * 0.15))
			PropParts.books(k, rnd, bx0, bx1 - 0.4, by, -s.z * 0.42, s.z * 0.8, mh, 0.04)
		else:
			PropParts.books(k, rnd, bx0, bx1, by, -s.z * 0.42, s.z * 0.8, mh, 0.03)


static func _ladder(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	var gold := PropMats.gold()
	# leaning ladder: feet forward (-Z), top hooks onto a rail at +Z
	for sx: float in [-1.0, 1.0]:
		k.tube(wood, PackedVector3Array([Vector3(sx * s.x * 0.42, 0.04, -s.z * 0.45), Vector3(sx * s.x * 0.42, s.y - 0.1, s.z * 0.35)]), 0.03, 5)
		k.sphere(gold, Vector3(sx * s.x * 0.42, 0.035, -s.z * 0.45), Vector3.ONE * 0.04, 6, 3)
		k.tube(gold, PackedVector3Array([Vector3(sx * s.x * 0.42, s.y - 0.12, s.z * 0.33), Vector3(sx * s.x * 0.42, s.y - 0.02, s.z * 0.42),
				Vector3(sx * s.x * 0.42, s.y - 0.1, s.z * 0.5)]), 0.012, 4)
	var n := int(s.y / 0.3)
	for i in n:
		var t := (i + 0.5) / n
		var p := Vector3(0, 0.04 + t * (s.y - 0.14), -s.z * 0.45 + t * s.z * 0.8)
		k.box(wood, p, Vector3(s.x * 0.84, 0.035, 0.08))
	k.box(PropMats.fabric(EstateKit.ROSE), Vector3(0, s.y * 0.5, -s.z * 0.05), Vector3(s.x * 0.6, 0.02, 0.07))


static func _lectern(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	var gold := PropMats.gold()
	for i in 3:
		var a := TAU * i / 3.0 + PI * 0.5
		k.tube(wood, PackedVector3Array([Vector3(0, 0.15, 0), Vector3(cos(a) * s.x * 0.45, 0.02, sin(a) * s.z * 0.45)]), 0.03, 5)
	k.lathe(wood, Vector3(0, 0.1, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.04, 0.1),
			Vector2(0.035, s.y * 0.6), Vector2(0.06, s.y * 0.68), Vector2(0, s.y * 0.7)]), 8)
	var t := PropMeshKit.at(Vector3(0, s.y * 0.88, 0), 0, -0.45)
	k.box(wood, Vector3(0, 0, 0), Vector3(s.x * 0.9, 0.04, s.z * 0.6), t)
	k.box(gold, Vector3(0, 0.03, -s.z * 0.3), Vector3(s.x * 0.9, 0.03, 0.02), t)
	k.push(t)
	_open_book(k, Vector3(0, 0.03, 0), s.x * 0.8, s.z * 0.5, 0.12)
	k.box(PropMats.satin(EstateKit.ROSE), Vector3(0.0, 0.03, s.z * 0.22), Vector3(0.012, 0.002, 0.2))
	k.pop()


static func _book_stack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var rnd := PropParts.rng(&"book_stack")
	var y := 0.0
	var i := 0
	while y < s.y - 0.06:
		var h := rnd.randf_range(0.035, 0.06)
		var col: Color = c if i == 0 else PropMats.BOOKS[rnd.randi() % PropMats.BOOKS.size()]
		var t := PropMeshKit.at(Vector3.ZERO, rnd.randf_range(-0.25, 0.25))
		k.box(PropMats.satin(col), Vector3(0, y + h * 0.5, 0), Vector3(s.x * rnd.randf_range(0.75, 0.95), h, s.z * rnd.randf_range(0.75, 0.95)), t)
		k.box(PropMats.pearl(EstateKit.CREAM), Vector3(0.004, y + h * 0.5, 0), Vector3(s.x * 0.7, h * 0.8, s.z * 0.72), t)
		y += h
		i += 1
	k.sphere(PropMats.satin(EstateKit.BUTTER), Vector3(0.05, y + 0.02, 0), Vector3(0.05, 0.02, 0.04), 6, 3)


static func _map_table(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	var gold := PropMats.gold()
	k.box(wood, Vector3(0, s.y - 0.04, 0), Vector3(s.x, 0.06, s.z))
	k.box(gold, Vector3(0, s.y - 0.08, 0), Vector3(s.x * 0.96, 0.02, s.z * 0.96))
	PropParts.legs4(k, wood, s.x, s.z, s.y - 0.07, 0.06, 0)
	k.box(wood, Vector3(0, 0.18, 0), Vector3(s.x * 0.85, 0.05, s.z * 0.85))
	# a big map of Prythian unrolled with weights, compass and model ships
	var mw := s.x * 0.8
	var md := s.z * 0.7
	k.box(PropMats.pearl(EstateKit.CREAM), Vector3(0, s.y + 0.003, 0), Vector3(mw, 0.006, md))
	var lands := [EstateKit.MINT, EstateKit.BLUSH, EstateKit.BUTTER, EstateKit.LILAC, EstateKit.PERIWINKLE]
	for i in 5:
		k.disc(PropMats.satin(lands[i]), Vector3(-mw * 0.32 + i * mw * 0.16, s.y + 0.008, (i % 2) * md * 0.2 - md * 0.1),
				mw * 0.09, 8, Transform3D.IDENTITY, md * 0.18)
	for sx: float in [-1.0, 1.0]:
		k.cyl(PropMats.pearl(EstateKit.CREAM), Vector3(0, -md * 0.5, 0), 0.03, 0.03, md, 8, true,
				PropMeshKit.at(Vector3(sx * mw * 0.5, s.y + 0.03, 0), 0, PI * 0.5))
	k.cyl(gold, Vector3(mw * 0.3, s.y, md * 0.3), 0.07, 0.07, 0.02, 12)
	k.box(PropMats.satin(PropMats.BERRY), Vector3(mw * 0.3, s.y + 0.025, md * 0.3), Vector3(0.11, 0.006, 0.012), PropMeshKit.at(Vector3.ZERO, 0.6))
	for i in 3:
		var p := Vector3(-mw * 0.2 + i * 0.2, s.y + 0.01, md * 0.15 - i * 0.1)
		k.sphere(PropMats.wood(EstateKit.OAK), p + Vector3(0, 0.01, 0), Vector3(0.05, 0.02, 0.02), 6, 3)
		k.leaf(PropMats.pearl(), p + Vector3(0, 0.02, 0), Vector3(0, 1, 0.01), 0.06, 0.05, 0.0)
	k.lathe(gold, Vector3(-mw * 0.35, s.y, md * 0.35), PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.03, 0.04),
			Vector2(0.01, 0.06), Vector2(0, 0.07)]), 8)
	PropParts.candle(k, Vector3(s.x * 0.44, s.y, s.z * 0.4), 0.18, 0.025)


static func _map_wall(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.box(PropMats.pearl(c), Vector3(0, s.y * 0.5, s.z * 0.2), Vector3(s.x * 0.96, s.y * 0.92, 0.01))
	for sy: float in [-1.0, 1.0]:
		k.cyl(PropMats.wood(EstateKit.OAK_DARK), Vector3(0, -s.x * 0.5, 0), 0.025, 0.025, s.x, 8, true,
				PropMeshKit.at(Vector3(0, s.y * 0.5 + sy * (s.y * 0.5 - 0.025), 0), 0, 0, PI * 0.5))
	var lands := [EstateKit.MINT, EstateKit.BLUSH, EstateKit.BUTTER, EstateKit.LILAC, PropMats.SKY, EstateKit.ROSE]
	var names := [Vector2(-0.3, 0.3), Vector2(0.1, 0.35), Vector2(0.32, 0.1), Vector2(-0.1, -0.05), Vector2(0.25, -0.3), Vector2(-0.32, -0.28)]
	for i in 6:
		var p: Vector2 = names[i]
		k.disc(PropMats.satin(lands[i]), Vector3.ZERO, s.x * 0.12, 9, PropMeshKit.at(Vector3(p.x * s.x, s.y * 0.5 + p.y * s.y, 0.0), 0, -PI * 0.5), s.y * 0.13)
	# the Wall across the south, a compass rose
	k.box(PropMats.satin(PropMats.PLUM), Vector3(0, s.y * 0.2, -0.004), Vector3(s.x * 0.85, 0.02, 0.004))
	k.disc(gold, Vector3.ZERO, s.y * 0.08, 8, PropMeshKit.at(Vector3(s.x * 0.4, s.y * 0.78, -0.006), 0, -PI * 0.5))
	k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(0, s.y - 0.01, -0.02), Vector3(0.08, 0.04, 0.02), 8, 3)


static func _scroll_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y * 0.5, s.z * 0.45), Vector3(s.x, s.y, s.z * 0.1))
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * s.x * 0.48, s.y * 0.5, 0), Vector3(s.x * 0.04, s.y, s.z))
	k.box(wood, Vector3(0, s.y - 0.02, 0), Vector3(s.x * 1.02, 0.04, s.z * 1.02))
	var rows := 5
	var cols := 5
	var cw := s.x * 0.92 / cols
	var rh := s.y * 0.95 / rows
	var rnd := PropParts.rng(&"scroll_rack")
	for r in rows:
		k.box(wood, Vector3(0, r * rh + 0.01, 0), Vector3(s.x * 0.92, 0.02, s.z * 0.9))
		for ci in cols:
			if ci > 0:
				k.box(wood, Vector3(-s.x * 0.46 + ci * cw, r * rh + rh * 0.5, 0), Vector3(0.015, rh, s.z * 0.9))
			var n := rnd.randi_range(1, 2)
			for j in n:
				var p := Vector3(-s.x * 0.46 + ci * cw + cw * (0.3 + j * 0.2), r * rh + 0.06 + (j % 2) * 0.05, 0)
				k.cyl(PropMats.pearl(EstateKit.CREAM), Vector3(0, -s.z * 0.45, 0), 0.035, 0.035, s.z * 0.9, 5, true,
						PropMeshKit.at(p, 0, PI * 0.5))
				k.torus(PropMats.satin(PropMats.BOOKS[rnd.randi() % 6]), Vector3.ZERO, 0.036, 0.006, 5, 2, PropMeshKit.at(p + Vector3(0, 0, -s.z * 0.3), 0, PI * 0.5))


static func _inkstand(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.box(gold, Vector3(0, 0.01, 0), Vector3(s.x, 0.02, s.z))
	for sx: float in [-1.0, 1.0]:
		k.lathe(PropMats.glass(Color(0.5, 0.3, 0.7, 0.8)), Vector3(sx * s.x * 0.25, 0.02, 0.02), PackedVector2Array([Vector2(0, 0),
				Vector2(0.03, 0), Vector2(0.035, 0.04), Vector2(0.015, 0.06), Vector2(0, 0.06)]), 8)
		k.sphere(gold, Vector3(sx * s.x * 0.25, 0.085, 0.02), Vector3.ONE * 0.012, 5, 3)
	k.tube(PropMats.pearl(EstateKit.BLUSH), PackedVector3Array([Vector3(-s.x * 0.25, 0.07, 0.02), Vector3(-s.x * 0.1, s.y, s.z * 0.3)]),
			0.008, 4, Transform3D.IDENTITY, 0.002)
	k.leaf(PropMats.pearl(EstateKit.BLUSH), Vector3(-s.x * 0.2, 0.09, 0.07), Vector3(0.3, 1, 0.6), 0.06, 0.025, 0.0)
	k.box(gold, Vector3(0, 0.03, -s.z * 0.3), Vector3(s.x * 0.6, 0.02, 0.02))


static func _harp(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	var w := s.x
	# base, the tall column at -X, the curved neck over the top, sound box at +X
	k.box(gold, Vector3(0, 0.06, 0), Vector3(w * 0.7, 0.12, s.z * 0.8))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.sphere(gold, Vector3(sx * w * 0.3, 0.03, sz * s.z * 0.35), Vector3.ONE * 0.035, 6, 3)
	var col_x := -w * 0.32
	k.lathe(gold, Vector3(col_x, 0.12, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.035, 0.1),
			Vector2(0.03, s.y * 0.75), Vector2(0.05, s.y * 0.8), Vector2(0.06, s.y * 0.84), Vector2(0, s.y * 0.86)]), 8)
	var neck := PackedVector3Array()
	for i in 11:
		var t := float(i) / 10.0
		neck.append(Vector3(col_x + t * w * 0.66, s.y * 0.94 - sin(t * PI) * 0.12 - t * s.y * 0.25 + sin(t * TAU) * 0.05, 0))
	k.tube(gold, neck, 0.035, 6)
	var box_bot := Vector3(-w * 0.18, 0.12, 0)
	var box_top := neck[10]
	k.tube(PropMats.pearl(EstateKit.BLUSH), PackedVector3Array([box_bot, (box_bot + box_top) * 0.5 + Vector3(0.05, 0, 0), box_top]), 0.07, 8,
			Transform3D.IDENTITY, 0.035)
	k.tube(gold, PackedVector3Array([box_bot + Vector3(0, 0, -0.07), box_top + Vector3(0, 0, -0.035)]), 0.012, 4)
	# strings (thin pearl-gold lines from neck to sound box)
	for i in 12:
		var t := (i + 1) / 13.0
		var top := neck[int(t * 10.0)]
		var bot := box_bot.lerp(box_top, t)
		if top.y - bot.y > 0.05:
			k.tube(PropMats.pearl(EstateKit.CREAM), PackedVector3Array([bot, Vector3(bot.x, top.y, 0)]), 0.003, 3)
	# a carved swan-and-rose crown on the column
	k.sphere(gold, Vector3(col_x, s.y * 0.93, 0), Vector3(0.07, 0.05, 0.05), 8, 4)
	PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(col_x, s.y * 0.97, 0), 0.04)


static func _piano(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.body(c)
	var gold := PropMats.gold()
	var w := s.x
	var d := s.z
	var top := s.y * 0.72
	# curved grand case: a box at the keyboard end, a rounded tail at +Z
	k.box(body, Vector3(0, top - 0.15, -d * 0.2), Vector3(w, 0.3, d * 0.6))
	k.cyl(body, Vector3(w * 0.05, top - 0.3, d * 0.1), w * 0.45, w * 0.45, 0.3, 16, true,
			PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, (d * 0.4) / (w * 0.45))))
	k.box(gold, Vector3(0, top - 0.31, -d * 0.2), Vector3(w * 1.01, 0.02, d * 0.6))
	for p: Vector3 in [Vector3(-w * 0.42, 0, -d * 0.42), Vector3(w * 0.42, 0, -d * 0.42), Vector3(0, 0, d * 0.4)]:
		PropParts.cabriole_leg(k, body, p, top - 0.3, 0.05, Vector3(p.x, 0, p.z))
	# keyboard: pearl keys with plum sharps, a music desk and the lifted lid
	k.box(body, Vector3(0, top - 0.2, -d * 0.53), Vector3(w * 0.9, 0.08, 0.14))
	k.box(PropMats.pearl(), Vector3(0, top - 0.155, -d * 0.53), Vector3(w * 0.84, 0.02, 0.12))
	for i in 14:
		k.box(PropMats.satin(PropMats.PLUM), Vector3(-w * 0.4 + i * w * 0.06, top - 0.135, -d * 0.51), Vector3(0.02, 0.015, 0.07))
	k.box(gold, Vector3(0, top - 0.06, -d * 0.45), Vector3(w * 0.5, 0.18, 0.015), PropMeshKit.at(Vector3.ZERO, 0, 0.2))
	var lid := PropMeshKit.at(Vector3(-w * 0.45, top, 0), 0, 0, 0.6)
	k.box(body, Vector3(w * 0.45, 0, -d * 0.05), Vector3(w * 0.9, 0.025, d * 0.8), lid)
	k.tube(gold, PackedVector3Array([Vector3(w * 0.3, top - 0.02, 0.0), Vector3(w * 0.3, top + w * 0.45, 0.0)]), 0.01, 4)
	# gold rose inlay on the case
	for i in 3:
		PropParts.bloom(k, gold, Vector3(-w * 0.3 + i * w * 0.3, top - 0.15, -d * 0.505 + 0.0), 0.035)
	# a matching bench
	k.box(body, Vector3(0, 0.45, -d * 0.82 + 0.15), Vector3(w * 0.5, 0.06, 0.3))
	PropParts.cushion(k, PropMats.fabric(EstateKit.ROSE), Vector3(0, 0.5, -d * 0.82 + 0.15), Vector3(w * 0.48, 0.06, 0.28))
	PropParts.legs4(k, body, w * 0.5, 0.3, 0.43, 0.02, 1)


static func _music_stand(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	for i in 3:
		var a := TAU * i / 3.0
		k.tube(gold, PackedVector3Array([Vector3(0, 0.2, 0), Vector3(cos(a) * s.x * 0.45, 0.0, sin(a) * s.z * 0.45)]), 0.012, 4)
	k.cyl(gold, Vector3(0, 0.0, 0), 0.015, 0.012, s.y * 0.75, 6)
	var t := PropMeshKit.at(Vector3(0, s.y * 0.85, 0), 0, -0.35)
	k.push(t)
	# lyre-shaped desk with music sheets
	var lyre := PackedVector3Array()
	for i in 11:
		var a := PI * i / 10.0
		lyre.append(Vector3(-cos(a) * s.x * 0.45, sin(a) * s.y * 0.12 - 0.06, 0))
	k.tube(gold, lyre, 0.01, 4)
	k.box(gold, Vector3(0, -0.12, -0.02), Vector3(s.x * 0.9, 0.02, 0.05))
	for i in 5:
		k.cyl(gold, Vector3(-s.x * 0.3 + i * s.x * 0.15, -0.12, 0), 0.006, 0.006, 0.14, 4)
	k.box(PropMats.pearl(EstateKit.CREAM), Vector3(0, 0.0, -0.01), Vector3(s.x * 0.8, s.y * 0.2, 0.005))
	for i in 4:
		k.box(PropMats.satin(PropMats.PLUM), Vector3(0, -0.06 + i * 0.04, -0.015), Vector3(s.x * 0.7, 0.003, 0.002))
	k.pop()


static func _lute(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	var wood := PropMats.wood(c)
	# A-frame stand
	for sx: float in [-1.0, 1.0]:
		k.tube(gold, PackedVector3Array([Vector3(sx * s.x * 0.4, 0, -s.z * 0.3), Vector3(sx * 0.05, s.y * 0.55, s.z * 0.2)]), 0.01, 4)
	k.tube(gold, PackedVector3Array([Vector3(0, 0, s.z * 0.45), Vector3(0, s.y * 0.55, s.z * 0.2)]), 0.01, 4)
	var lean := PropMeshKit.at(Vector3(0, 0.08, 0), 0, 0.25)
	k.push(lean)
	k.sphere(wood, Vector3(0, 0.2, 0.02), Vector3(s.x * 0.36, 0.22, 0.09), 12, 6)
	k.disc(PropMats.wood(EstateKit.OAK.lightened(0.3)), Vector3.ZERO, s.x * 0.34, 14, PropMeshKit.at(Vector3(0, 0.2, -0.04), 0, -PI * 0.5), 0.21)
	k.disc(PropMats.wood(EstateKit.OAK_DARK), Vector3.ZERO, 0.04, 10, PropMeshKit.at(Vector3(0, 0.24, -0.045), 0, -PI * 0.5))
	k.box(PropMats.wood(EstateKit.OAK_DARK), Vector3(0, 0.6, -0.02), Vector3(0.06, 0.4, 0.03))
	k.box(wood, Vector3(0, 0.84, 0.02), Vector3(0.07, 0.14, 0.03), PropMeshKit.at(Vector3.ZERO, 0, 0.9))
	for i in 4:
		k.cyl(PropMats.pearl(EstateKit.CREAM), Vector3(-0.015 + i * 0.01, 0.1, -0.05), 0.0015, 0.0015, 0.68, 3, false)
	k.torus(PropMats.satin(EstateKit.ROSE), Vector3(0, 0.78, -0.02), 0.04, 0.01, 8, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
	k.pop()


static func _easel(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	for sx: float in [-1.0, 1.0]:
		k.tube(wood, PackedVector3Array([Vector3(sx * s.x * 0.42, 0, -s.z * 0.3), Vector3(sx * 0.06, s.y, -s.z * 0.05)]), 0.022, 5)
	k.tube(wood, PackedVector3Array([Vector3(0, 0, s.z * 0.48), Vector3(0, s.y * 0.92, -s.z * 0.04)]), 0.02, 5)
	var ledge_y := s.y * 0.4
	k.box(wood, Vector3(0, ledge_y, -s.z * 0.22), Vector3(s.x * 0.8, 0.03, 0.08))
	# a canvas mid-painting: a spring meadow with a rose sky
	var cv := PropMeshKit.at(Vector3(0, ledge_y + 0.02, -s.z * 0.24), 0, -0.12)
	k.push(cv)
	var cw := s.x * 0.75
	var ch := s.y * 0.38
	k.box(PropMats.pearl(EstateKit.CREAM), Vector3(0, ch * 0.5, 0.02), Vector3(cw, ch, 0.025))
	k.box(PropMats.satin(EstateKit.BLUSH), Vector3(0, ch * 0.72, 0.006), Vector3(cw * 0.9, ch * 0.5, 0.002))
	k.box(PropMats.satin(EstateKit.MINT), Vector3(0, ch * 0.25, 0.006), Vector3(cw * 0.9, ch * 0.42, 0.002))
	k.disc(PropMats.satin(EstateKit.BUTTER), Vector3.ZERO, ch * 0.1, 10, PropMeshKit.at(Vector3(cw * 0.25, ch * 0.75, 0.004), 0, -PI * 0.5))
	for i in 5:
		k.disc(PropMats.satin([EstateKit.ROSE, EstateKit.LILAC, EstateKit.PEARL][i % 3]), Vector3.ZERO, ch * 0.04, 6,
				PropMeshKit.at(Vector3(-cw * 0.35 + i * cw * 0.15, ch * 0.2 + (i % 2) * 0.05, 0.004), 0, -PI * 0.5))
	k.pop()
	k.box(wood, Vector3(0, ledge_y + ch + 0.06, -s.z * 0.2), Vector3(0.12, 0.05, 0.05))
	# palette hanging on the leg, with blobs of pigment
	k.disc(PropMats.wood(EstateKit.OAK.lightened(0.2)), Vector3.ZERO, 0.14, 12, PropMeshKit.at(Vector3(s.x * 0.38, ledge_y - 0.15, -s.z * 0.25), 0, -PI * 0.5 + 0.2, 0.3), 0.1)
	var pig := [EstateKit.ROSE, EstateKit.BUTTER, EstateKit.PERIWINKLE, EstateKit.MINT, PropMats.BERRY]
	for i in 5:
		k.sphere(PropMats.gloss(pig[i]), Vector3(s.x * 0.33 + (i % 3) * 0.05, ledge_y - 0.1 - (i / 3) * 0.06, -s.z * 0.28), Vector3(0.018, 0.018, 0.01), 5, 3)


static func _canvas_stack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var rnd := PropParts.rng(&"canvas_stack")
	for i in 5:
		var w := s.x * rnd.randf_range(0.6, 0.95)
		var h := s.y * rnd.randf_range(0.5, 0.95)
		var z := -s.z * 0.35 + i * s.z * 0.17
		var t := PropMeshKit.at(Vector3(rnd.randf_range(-0.05, 0.05), 0, z), 0, 0.18)
		k.push(t)
		k.box(PropMats.wood(EstateKit.OAK), Vector3(0, h * 0.5, 0.02), Vector3(w, h, 0.03))
		k.box(PropMats.pearl(c), Vector3(0, h * 0.5, 0.0), Vector3(w * 0.94, h * 0.94, 0.012))
		if i % 2 == 0:
			k.disc(PropMats.satin(PropMats.BOOKS[i]), Vector3.ZERO, w * 0.25, 10, PropMeshKit.at(Vector3(0, h * 0.55, -0.008), 0, -PI * 0.5), h * 0.2)
		k.pop()
	k.box(PropMats.fabric(EstateKit.LILAC), Vector3(0, 0.02, 0), Vector3(s.x, 0.04, s.z), PropMeshKit.at(Vector3.ZERO, 0.1))


static func _paint_table(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y - 0.03, 0), Vector3(s.x, 0.05, s.z))
	PropParts.legs4(k, wood, s.x, s.z, s.y - 0.05, 0.03, 2)
	k.box(wood, Vector3(0, 0.25, 0), Vector3(s.x * 0.9, 0.03, s.z * 0.85))
	# splashes of colour on the top, brushes in a jar, rags, jars below
	var cols := [EstateKit.ROSE, EstateKit.BUTTER, EstateKit.PERIWINKLE, EstateKit.MINT, EstateKit.LILAC]
	for i in 5:
		k.disc(PropMats.satin(cols[i]), Vector3(-s.x * 0.35 + i * s.x * 0.17, s.y + 0.002, (i % 2) * 0.12 - 0.1), 0.05, 7)
	k.cyl(PropMats.glass(Color(0.8, 0.9, 1.0, 0.4)), Vector3(s.x * 0.3, s.y, s.z * 0.2), 0.05, 0.05, 0.12, 8)
	for i in 5:
		var a := TAU * i / 5.0
		k.tube(PropMats.wood(EstateKit.OAK_DARK), PackedVector3Array([Vector3(s.x * 0.3, s.y + 0.02, s.z * 0.2),
				Vector3(s.x * 0.3 + cos(a) * 0.05, s.y + 0.25, s.z * 0.2 + sin(a) * 0.05)]), 0.006, 3)
		k.sphere(PropMats.satin(cols[i]), Vector3(s.x * 0.3 + cos(a) * 0.05, s.y + 0.26, s.z * 0.2 + sin(a) * 0.05), Vector3(0.01, 0.02, 0.01), 4, 2)
	k.sphere(PropMats.fabric(EstateKit.BLUSH), Vector3(-s.x * 0.3, s.y + 0.02, s.z * 0.25), Vector3(0.12, 0.03, 0.08), 8, 3)
	for i in 4:
		k.cyl(PropMats.glass(Color(cols[i], 0.75)), Vector3(-s.x * 0.3 + i * s.x * 0.2, 0.265, 0), 0.05, 0.05, 0.12, 8)
		k.cyl(PropMats.gold(), Vector3(-s.x * 0.3 + i * s.x * 0.2, 0.385, 0), 0.052, 0.052, 0.02, 8)


static func _pigments(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var cols := [c, EstateKit.BUTTER, EstateKit.PERIWINKLE, EstateKit.MINT, EstateKit.LILAC, PropMats.BERRY, Color(1.0, 0.6, 0.35), PropMats.SKY]
	k.box(PropMats.wood(EstateKit.OAK), Vector3(0, 0.01, 0), Vector3(s.x, 0.02, s.z))
	for i in 8:
		var x := -s.x * 0.375 + (i % 4) * s.x * 0.25
		var z := -s.z * 0.25 + (i / 4) * s.z * 0.5
		var h := s.y * (0.6 + 0.15 * float(i % 3))
		k.cyl(PropMats.glass(Color(1, 1, 1, 0.35)), Vector3(x, 0.02, z), 0.05, 0.05, h, 8)
		k.cyl(PropMats.satin(cols[i]), Vector3(x, 0.025, z), 0.045, 0.045, h * 0.7, 8)
		k.cyl(PropMats.wood(EstateKit.OAK_DARK), Vector3(x, h + 0.02, z), 0.035, 0.03, s.y - h - 0.02, 6)
