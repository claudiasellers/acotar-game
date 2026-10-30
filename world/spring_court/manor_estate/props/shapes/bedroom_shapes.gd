## Beds, wardrobes, dressers and the dressing room (mirrors, gowns, shoes, hats,
## jewellery, perfume, makeup). Front faces -Z; the headboard sits at +Z.
class_name BedroomShapes
extends RefCounted



static func build(k: PropMeshKit, id: StringName, s: Vector3, c: Color) -> bool:
	match id:
		&"bed_canopy": _canopy_bed(k, s, c)
		&"bed_single": _bed(k, s, c, PropMats.pearl(), true)
		&"bed_servant": _bed(k, s, c, PropMats.wood(c), false)
		&"cradle_chest": _cradle_chest(k, s, c)
		&"nightstand": _nightstand(k, s, c)
		&"wardrobe_tall": _wardrobe(k, s, c)
		&"dresser": _dresser(k, s, c)
		&"vanity_table": _vanity(k, s, c)
		&"vanity_mirror": _vanity_mirror(k, s, c)
		&"cheval_mirror": _cheval(k, s, c)
		&"gown_rack": _gown_rack(k, s, c)
		&"mannequin_gown": _mannequin(k, s, c)
		&"shoe_shelf": _shoe_shelf(k, s, c)
		&"hat_stand": _hat_stand(k, s, c)
		&"jewelry_box": _jewelry_box(k, s, c)
		&"perfume_tray": _perfume_tray(k, s, c)
		&"makeup_palette": _makeup(k, s, c)
		&"dressing_screen": _screen(k, s, c)
		&"pouf_stool": _pouf(k, s, c)
		_: return false
	return true


static func _bedding(k: PropMeshKit, w: float, d: float, y: float, cover: Color, pillows: int) -> void:
	k.box(PropMats.fabric(EstateKit.CREAM), Vector3(0, y + 0.1, 0), Vector3(w * 0.96, 0.2, d * 0.96))
	PropParts.cushion(k, PropMats.fabric(cover), Vector3(0, y + 0.22, -d * 0.1), Vector3(w * 1.0, 0.12, d * 0.8))
	k.box(PropMats.fabric(cover), Vector3(0, y + 0.02, -d * 0.1), Vector3(w * 1.01, 0.28, d * 0.8))
	k.box(PropMats.gold(), Vector3(0, y - 0.1, -d * 0.1), Vector3(w * 1.02, 0.02, d * 0.8))
	var cols := [EstateKit.PEARL, EstateKit.BLUSH, EstateKit.LILAC, EstateKit.BUTTER, EstateKit.PEARL]
	for i in pillows:
		var x := -w * 0.36 + w * 0.72 * (i + 0.5) / pillows
		PropParts.cushion(k, PropMats.fabric(cols[i % cols.size()]), Vector3(x, y + 0.32, d * 0.36),
				Vector3(w * 0.72 / pillows * 1.05, 0.18, 0.32), PropMeshKit.at(Vector3.ZERO, 0, -0.3))
	if pillows > 2:
		k.sphere(PropMats.fabric(EstateKit.ROSE), Vector3(0, y + 0.36, d * 0.2), Vector3(0.22, 0.2, 0.08), 10, 5)


static func _canopy_bed(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	var pearl := PropMats.pearl()
	var w := s.x
	var d := s.z
	var mat_y := 0.55
	k.box(pearl, Vector3(0, 0.3, 0), Vector3(w * 0.94, 0.3, d * 0.94))
	_bedding(k, w * 0.9, d * 0.9, mat_y, c, 5)
	# tufted headboard arch at +Z
	k.box(PropMats.fabric(c), Vector3(0, 1.1, d * 0.46), Vector3(w * 0.86, 1.2, 0.1))
	k.cyl(PropMats.fabric(c), Vector3(0, -0.05, 0), w * 0.43, w * 0.43, 0.1, 16, true,
			PropMeshKit.at(Vector3(0, 1.7, d * 0.46), 0, PI * 0.5, 0, Vector3(1, 0.45, 1)))
	for i in 7:
		for j in 3:
			k.sphere(gold, Vector3(-w * 0.36 + i * w * 0.12, 0.9 + j * 0.25, d * 0.405), Vector3.ONE * 0.02, 4, 2)
	# four turned posts with finials
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(sx * w * 0.47, 0, sz * d * 0.47)
			PropParts.turned_leg(k, pearl, p, s.y - 0.25, 0.06)
			k.sphere(gold, p + Vector3(0, s.y - 0.12, 0), Vector3(0.07, 0.1, 0.07), 8, 4)
	# canopy frame and swagged roof
	var top := s.y - 0.3
	k.box(PropMats.fabric(c), Vector3(0, top, 0), Vector3(w, 0.18, d))
	k.sphere(PropMats.fabric(c.lightened(0.1)), Vector3(0, top + 0.08, 0), Vector3(w * 0.5, 0.18, d * 0.5), 12, 5, Transform3D.IDENTITY, true)
	for sz: float in [-1.0, 1.0]:
		k.box(gold, Vector3(0, top - 0.1, sz * d * 0.5), Vector3(w * 1.01, 0.03, 0.03))
		for i in 4:
			var cx := -w * 0.375 + i * w * 0.25
			k.torus(PropMats.fabric(EstateKit.PEARL), Vector3(cx, top - 0.1, sz * d * 0.5), w * 0.125, 0.04, 8, 3,
					PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5), PI)
	for sx: float in [-1.0, 1.0]:
		k.box(gold, Vector3(sx * w * 0.5, top - 0.1, 0), Vector3(0.03, 0.03, d * 1.01))
	# sheer drapes gathered at the posts with gold ties
	var sheer := PropMats.glass(Color(1.0, 0.86, 0.92, 0.45))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(sx * w * 0.5, 0, sz * d * 0.5)
			k.lathe(sheer, p, PackedVector2Array([Vector2(0.0, 0.05), Vector2(0.22, 0.05), Vector2(0.2, 0.6), Vector2(0.09, 1.2),
					Vector2(0.14, 1.6), Vector2(0.24, top - 0.4), Vector2(0.12, top - 0.1), Vector2(0, top - 0.1)]), 8)
			k.torus(gold, p + Vector3(0, 1.2, 0), 0.1, 0.018, 10, 4)


static func _bed(k: PropMeshKit, s: Vector3, c: Color, frame: Material, fancy: bool) -> void:
	var w := s.x
	var d := s.z
	k.box(frame, Vector3(0, 0.22, 0), Vector3(w, 0.2, d))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.cyl(frame, Vector3(sx * w * 0.46, 0, sz * d * 0.47), 0.04, 0.04, 0.25 if sz < 0 else s.y, 8)
	_bedding(k, w * 0.94, d * 0.94, 0.32, c if fancy else EstateKit.MINT, 2 if fancy else 1)
	k.box(frame, Vector3(0, s.y * 0.7, d * 0.47), Vector3(w * 0.9, s.y * 0.5, 0.05))
	if fancy:
		k.cyl(frame, Vector3(0, -0.025, 0), w * 0.42, w * 0.42, 0.05, 14, true,
				PropMeshKit.at(Vector3(0, s.y * 0.92, d * 0.47), 0, PI * 0.5, 0, Vector3(1, 0.15, 1)))
		k.sphere(PropMats.gold(), Vector3(0, s.y * 0.75, d * 0.44), Vector3(0.08, 0.08, 0.02), 8, 4)
	else:
		# a patchwork quilt in candy squares
		for i in 4:
			for j in 3:
				var col: Color = PropMats.BOOKS[(i + j * 2) % 6]
				k.box(PropMats.fabric(col), Vector3(-w * 0.36 + j * w * 0.36, 0.62, -d * 0.4 + i * d * 0.2),
						Vector3(w * 0.34, 0.012, d * 0.19))


static func _cradle_chest(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y * 0.45, 0), Vector3(s.x, s.y * 0.8, s.z))
	k.box(PropMats.wood(c.lightened(0.1)), Vector3(0, s.y * 0.92, 0), Vector3(s.x * 1.04, s.y * 0.12, s.z * 1.06))
	for sx: float in [-1.0, 1.0]:
		k.sphere(wood, Vector3(sx * s.x * 0.44, 0.04, 0), Vector3(0.06, 0.05, s.z * 0.4), 8, 4)
	# painted flowers on the front
	for i in 3:
		var x := -s.x * 0.3 + i * s.x * 0.3
		PropParts.bloom(k, PropMats.satin([EstateKit.ROSE, EstateKit.BUTTER, EstateKit.PERIWINKLE][i]), Vector3(x, s.y * 0.48, -s.z * 0.5), 0.05)
		k.leaf(PropMats.satin(PropMats.LEAF), Vector3(x + 0.04, s.y * 0.45, -s.z * 0.505), Vector3(1, -0.4, 0), 0.1, 0.04, 0.0)
	k.box(PropMats.gold(), Vector3(0, s.y * 0.8, -s.z * 0.52), Vector3(0.08, 0.08, 0.02))


static func _nightstand(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.body(c)
	PropParts.legs4(k, PropMats.gold(), s.x * 0.92, s.z * 0.88, 0.14, 0.022, 1)
	k.box(body, Vector3(0, 0.14 + (s.y - 0.2) * 0.5, 0), Vector3(s.x * 0.95, s.y - 0.2, s.z * 0.95))
	k.box(body, Vector3(0, s.y - 0.04, 0), Vector3(s.x, 0.03, s.z))
	PropParts.drawers(k, PropMats.pearl(EstateKit.BLUSH), PropMats.gold(), -s.x * 0.42, s.x * 0.42, 0.18, s.y - 0.08, -s.z * 0.475, 2)
	PropParts.candle(k, Vector3(s.x * 0.25, s.y - 0.02, 0.05), 0.12, 0.02)
	k.cyl(PropMats.gold(), Vector3(s.x * 0.25, s.y - 0.025, 0.05), 0.05, 0.05, 0.01, 8)
	k.lathe(PropMats.pearl(EstateKit.LILAC), Vector3(-s.x * 0.2, s.y - 0.025, 0.05), PackedVector2Array([Vector2(0, 0),
			Vector2(0.03, 0), Vector2(0.045, 0.06), Vector2(0.02, 0.1), Vector2(0, 0.1)]), 8)
	PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(-s.x * 0.2, s.y + 0.1, 0.05), 0.035)


static func _wardrobe(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.body(c)
	var gold := PropMats.gold()
	var panel := PropMats.pearl(EstateKit.BLUSH)
	PropParts.legs4(k, gold, s.x * 0.94, s.z * 0.9, 0.14, 0.035, 1)
	k.box(body, Vector3(0, 0.14 + (s.y - 0.4) * 0.5, 0), Vector3(s.x, s.y - 0.4, s.z))
	k.box(body, Vector3(0, s.y - 0.24, 0), Vector3(s.x * 1.05, 0.08, s.z * 1.06))
	# crown pediment with a gold rose medallion
	k.cyl(body, Vector3(0, -s.z * 0.5, 0), s.x * 0.45, s.x * 0.45, s.z, 16, true,
			PropMeshKit.at(Vector3(0, s.y - 0.2, 0), 0, PI * 0.5, 0, Vector3(1, 0.42, 1)))
	PropParts.bloom(k, gold, Vector3(0, s.y - 0.09, -s.z * 0.5), 0.06)
	for sx: float in [-1.0, 1.0]:
		var x := sx * s.x * 0.245
		k.box(panel, Vector3(x, s.y * 0.48, -s.z * 0.505), Vector3(s.x * 0.46, s.y * 0.62, 0.02))
		var t := PropMeshKit.at(Vector3(x, s.y * 0.52, -s.z * 0.52), 0, PI * 0.5, 0, Vector3(1, 1, 1.9))
		k.torus(gold, Vector3.ZERO, s.x * 0.17, 0.012, 18, 3, t)
		k.box(PropMats.mirror(), Vector3(x, s.y * 0.52, -s.z * 0.516), Vector3(s.x * 0.28, s.y * 0.5, 0.01))
		k.cyl(gold, Vector3(sx * 0.04, s.y * 0.4, -s.z * 0.53), 0.012, 0.012, 0.18, 6)
	PropParts.drawers(k, panel, gold, -s.x * 0.47, s.x * 0.47, 0.18, s.y * 0.15, -s.z * 0.5, 1, 2)


static func _dresser(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.body(c)
	var gold := PropMats.gold()
	PropParts.legs4(k, gold, s.x * 0.95, s.z * 0.9, 0.14, 0.03, 1)
	k.box(body, Vector3(0, 0.14 + (s.y - 0.18) * 0.5, 0), Vector3(s.x, s.y - 0.18, s.z))
	k.box(body, Vector3(0, s.y - 0.02, 0), Vector3(s.x * 1.03, 0.04, s.z * 1.04))
	PropParts.drawers(k, PropMats.pearl(EstateKit.LILAC), gold, -s.x * 0.47, s.x * 0.47, 0.17, s.y - 0.06, -s.z * 0.5, 3, 2)
	PropParts.bottle(k, PropMats.glass(Color(1.0, 0.7, 0.85, 0.6)), gold, Vector3(s.x * 0.3, s.y, 0), 0.16, 0.04)
	k.cyl(PropMats.fabric(EstateKit.BLUSH), Vector3(-s.x * 0.25, s.y, 0.05), 0.1, 0.1, 0.03, 12)
	k.sphere(PropMats.pearl(), Vector3(-s.x * 0.25, s.y + 0.06, 0.05), Vector3(0.05, 0.04, 0.05), 8, 4)


static func _vanity(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.body(c)
	var gold := PropMats.gold()
	k.box(body, Vector3(0, s.y - 0.04, 0), Vector3(s.x, 0.05, s.z))
	k.box(gold, Vector3(0, s.y - 0.075, 0), Vector3(s.x * 0.97, 0.02, s.z * 0.97))
	PropParts.legs4(k, body, s.x * 0.96, s.z * 0.9, s.y - 0.06, 0.025, 1)
	for sx: float in [-1.0, 1.0]:
		k.box(body, Vector3(sx * s.x * 0.33, s.y - 0.15, 0), Vector3(s.x * 0.3, 0.16, s.z * 0.9))
		PropParts.drawers(k, PropMats.pearl(EstateKit.BLUSH), gold, sx * s.x * 0.33 - s.x * 0.14, sx * s.x * 0.33 + s.x * 0.14,
				s.y - 0.22, s.y - 0.08, -s.z * 0.45, 1)
	# skirt of ruffled tulle
	k.box(PropMats.fabric(EstateKit.BLUSH), Vector3(0, s.y - 0.22, -s.z * 0.47), Vector3(s.x * 0.36, 0.25, 0.02))
	for i in 9:
		k.sphere(PropMats.fabric(EstateKit.ROSE), Vector3(-s.x * 0.48 + i * s.x * 0.12, s.y - 0.1, -s.z * 0.5),
				Vector3(0.06, 0.04, 0.02), 6, 3)
	# perfumes, powder, brush
	var cols := [Color(1.0, 0.7, 0.85, 0.6), Color(0.8, 0.7, 1.0, 0.6), Color(0.7, 0.95, 0.85, 0.6)]
	for i in 3:
		PropParts.bottle(k, PropMats.glass(cols[i]), gold, Vector3(s.x * 0.2 + i * 0.08, s.y, s.z * 0.15), 0.12 + i * 0.02, 0.03)
	k.cyl(PropMats.pearl(EstateKit.ROSE), Vector3(-s.x * 0.25, s.y, s.z * 0.1), 0.06, 0.06, 0.04, 10)
	k.sphere(PropMats.fabric(EstateKit.PEARL), Vector3(-s.x * 0.25, s.y + 0.05, s.z * 0.1), Vector3(0.05, 0.025, 0.05), 8, 3)
	k.tube(gold, PackedVector3Array([Vector3(-s.x * 0.05, s.y + 0.01, -s.z * 0.1), Vector3(s.x * 0.05, s.y + 0.01, -s.z * 0.15)]), 0.01, 5)


static func _vanity_mirror(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	# oval glass in a gilt frame with a rose crest, flanked by two little sconces
	var cy := s.y * 0.48
	var ry := s.y * 0.42
	var rx := s.x * 0.3
	k.disc(PropMats.mirror(), Vector3.ZERO, rx, 20, PropMeshKit.at(Vector3(0, cy, -0.01), 0, -PI * 0.5), ry)
	k.torus(gold, Vector3.ZERO, 1.0, 0.06, 24, 5, PropMeshKit.at(Vector3(0, cy, 0), 0, PI * 0.5, 0, Vector3(rx, ry, 1.0)))
	k.box(PropMats.pearl(), Vector3(0, cy, 0.04), Vector3(rx * 2.0, ry * 2.0, 0.03))
	PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(0, s.y - 0.08, -0.02), 0.07)
	for sx: float in [-1.0, 1.0]:
		k.leaf(gold, Vector3(sx * 0.06, s.y - 0.1, -0.02), Vector3(sx, -0.3, 0), 0.22, 0.08, 0.2)
		var base := Vector3(sx * s.x * 0.44, cy - 0.1, 0)
		k.tube(gold, PackedVector3Array([base + Vector3(-sx * 0.1, 0, 0.0), base + Vector3(0, 0.02, -0.05), base + Vector3(0, 0.1, -0.05)]), 0.012, 5)
		PropParts.candle(k, base + Vector3(0, 0.1, -0.05), 0.12, 0.018)
	k.sphere(gold, Vector3(0, 0.03, -0.01), Vector3(0.08, 0.04, 0.04), 8, 3)


static func _cheval(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	var w := s.x
	for sx: float in [-1.0, 1.0]:
		k.tube(gold, PackedVector3Array([Vector3(sx * w * 0.42, 0.02, -s.z * 0.45), Vector3(sx * w * 0.42, 0.06, 0),
				Vector3(sx * w * 0.42, 0.02, s.z * 0.45)]), 0.025, 5)
		k.cyl(gold, Vector3(sx * w * 0.42, 0.04, 0), 0.025, 0.02, s.y * 0.6, 8)
		k.sphere(gold, Vector3(sx * w * 0.42, s.y * 0.62, 0), Vector3.ONE * 0.04, 6, 3)
	var cy := s.y * 0.55
	var ry := s.y * 0.42
	var rx := w * 0.34
	var tilt := PropMeshKit.at(Vector3(0, cy, 0), 0, -0.08)
	k.push(tilt)
	k.disc(PropMats.mirror(), Vector3.ZERO, rx, 20, PropMeshKit.at(Vector3(0, 0, -0.012), 0, -PI * 0.5), ry)
	k.disc(PropMats.pearl(EstateKit.BLUSH), Vector3.ZERO, rx, 20, PropMeshKit.at(Vector3(0, 0, 0.012), 0, PI * 0.5), ry)
	k.torus(gold, Vector3.ZERO, 1.0, 0.035, 24, 5, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5, 0, Vector3(rx, ry, 1.0)))
	PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(0, ry + 0.04, 0), 0.06)
	k.pop()


static func _gown_rack(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	for sx: float in [-1.0, 1.0]:
		k.tube(gold, PackedVector3Array([Vector3(sx * s.x * 0.47, 0.03, -s.z * 0.45), Vector3(sx * s.x * 0.47, 0.05, s.z * 0.45)]), 0.025, 5)
		k.cyl(gold, Vector3(sx * s.x * 0.47, 0.04, 0), 0.022, 0.022, s.y - 0.1, 6)
		k.sphere(gold, Vector3(sx * s.x * 0.47, s.y - 0.05, 0), Vector3.ONE * 0.05, 6, 3)
	k.tube(gold, PackedVector3Array([Vector3(-s.x * 0.47, s.y - 0.1, 0), Vector3(s.x * 0.47, s.y - 0.1, 0)]), 0.018, 6)
	var cols := [c, EstateKit.LILAC, EstateKit.PERIWINKLE, EstateKit.BUTTER, EstateKit.MINT, EstateKit.BLUSH]
	var n := 6
	for i in n:
		var x := -s.x * 0.4 + s.x * 0.8 * i / (n - 1.0)
		var m := PropMats.satin(cols[i % cols.size()])
		k.torus(gold, Vector3(x, s.y - 0.14, 0), 0.03, 0.005, 6, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
		k.lathe(m, Vector3(x, 0.22, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.26, 0), Vector2(0.24, 0.25),
				Vector2(0.15, 0.7), Vector2(0.1, 0.95), Vector2(0.12, 1.2), Vector2(0.06, 1.3), Vector2(0, 1.32)]), 10,
				PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(0.6, 1.0, 0.5)))
		k.torus(gold, Vector3(x, 0.22 + 0.93, 0), 0.06, 0.008, 8, 3)


static func _mannequin(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.cyl(gold, Vector3.ZERO, 0.22, 0.2, 0.04, 12)
	k.cyl(gold, Vector3(0, 0.04, 0), 0.02, 0.02, 0.3, 6)
	PropParts.gown(k, PropMats.satin(c), gold, Vector3(0, 0.1, 0), s.y - 0.22, s.x * 0.5)
	k.sphere(PropMats.pearl(EstateKit.BLUSH), Vector3(0, s.y - 0.22 + 0.08, 0), Vector3(0.11, 0.1, 0.09), 8, 4)
	k.cyl(PropMats.pearl(EstateKit.BLUSH), Vector3(0, s.y - 0.12, 0), 0.03, 0.03, 0.04, 6)
	k.sphere(PropMats.pearl(EstateKit.BLUSH), Vector3(0, s.y - 0.05, 0), Vector3(0.05, 0.06, 0.05), 6, 4)
	# pearl necklace and a ribbon sash bow
	k.torus(PropMats.pearl(), Vector3(0, s.y - 0.2, 0), 0.08, 0.012, 12, 4, PropMeshKit.at(Vector3.ZERO, 0, 0.3))
	k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(0, (s.y - 0.22) * 0.58 + 0.1, -0.12), Vector3(0.1, 0.05, 0.03), 8, 4)


static func _shoe_shelf(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.pearl()
	k.box(body, Vector3(0, s.y * 0.5, s.z * 0.45), Vector3(s.x, s.y, s.z * 0.1))
	for sx: float in [-1.0, 1.0]:
		k.box(body, Vector3(sx * s.x * 0.48, s.y * 0.5, 0), Vector3(s.x * 0.04, s.y, s.z))
	var cols := [EstateKit.ROSE, EstateKit.GOLD, EstateKit.LILAC, EstateKit.PERIWINKLE, EstateKit.MINT, c, EstateKit.BUTTER]
	for r in 4:
		var y := 0.04 + r * (s.y - 0.08) / 3.5
		k.box(PropMats.pearl(c), Vector3(0, y, 0), Vector3(s.x * 0.94, 0.03, s.z))
		if r == 3:
			continue
		for i in 4:
			var x := -s.x * 0.36 + i * s.x * 0.24
			var m := PropMats.gloss(cols[(i + r * 2) % cols.size()])
			for sx: float in [-0.04, 0.04]:
				# heeled slipper: sole wedge, toe cap, little heel
				k.box(m, Vector3(x + sx, y + 0.04, -0.02), Vector3(0.06, 0.02, 0.22), PropMeshKit.at(Vector3.ZERO, 0, -0.25))
				k.sphere(m, Vector3(x + sx, y + 0.035, -0.11), Vector3(0.035, 0.03, 0.06), 6, 3)
				k.cyl(m, Vector3(x + sx, y + 0.015, 0.07), 0.012, 0.01, 0.07, 5)
				k.sphere(PropMats.pearl(), Vector3(x + sx, y + 0.06, -0.12), Vector3.ONE * 0.012, 4, 2)


static func _hat_stand(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	k.lathe(gold, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.45, 0), Vector2(s.x * 0.4, 0.04),
			Vector2(0.03, 0.1), Vector2(0.02, s.y - 0.4), Vector2(0, s.y - 0.4)]), 10)
	var hats := [[EstateKit.ROSE, 0.0], [EstateKit.LILAC, 2.1], [PropMats.STRAW, 4.2]]
	for i in 3:
		var a: float = hats[i][1]
		var arm := Vector3(cos(a) * 0.12, s.y - 0.55 + i * 0.2, sin(a) * 0.12)
		k.tube(gold, PackedVector3Array([Vector3(0, arm.y - 0.1, 0), arm]), 0.01, 4)
		var m := PropMats.fabric(hats[i][0])
		var hat_c := arm + Vector3(0, 0.03, 0)
		k.cyl(m, hat_c, 0.2 - i * 0.03, 0.2 - i * 0.03, 0.015, 12, true, PropMeshKit.at(Vector3.ZERO, 0, 0.15))
		k.sphere(m, hat_c + Vector3(0, 0.02, 0), Vector3(0.09, 0.08, 0.09), 8, 4, Transform3D.IDENTITY, true)
		k.torus(PropMats.satin(EstateKit.PEARL if i != 2 else EstateKit.ROSE), hat_c + Vector3(0, 0.035, 0), 0.09, 0.012, 10, 3)
	# tiara on top
	k.sphere(PropMats.pearl(EstateKit.BLUSH), Vector3(0, s.y - 0.14, 0), Vector3(0.09, 0.11, 0.09), 8, 4)
	k.torus(gold, Vector3(0, s.y - 0.08, 0), 0.075, 0.01, 12, 3)
	for i in 5:
		var a := -0.9 + i * 0.45
		k.sphere(PropMats.crystal(), Vector3(sin(a) * 0.075, s.y - 0.04 + (0.04 if i == 2 else 0.0), -cos(a) * 0.075),
				Vector3(0.015, 0.03, 0.01), 4, 2)


static func _jewelry_box(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	var pink := PropMats.pearl(EstateKit.BLUSH)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.sphere(gold, Vector3(sx * s.x * 0.42, 0.015, sz * s.z * 0.4), Vector3.ONE * 0.018, 5, 3)
	k.box(pink, Vector3(0, s.y * 0.3, 0), Vector3(s.x, s.y * 0.45, s.z))
	k.box(gold, Vector3(0, s.y * 0.53, 0), Vector3(s.x * 1.02, 0.015, s.z * 1.02))
	# open lid tipped back, mirror inside, velvet tray with rings and pearls
	var lid := PropMeshKit.at(Vector3(0, s.y * 0.54, s.z * 0.5), 0, -1.2)
	k.box(pink, Vector3(0, 0, -s.z * 0.5), Vector3(s.x, 0.02, s.z), lid)
	k.box(PropMats.mirror(), Vector3(0, -0.012, -s.z * 0.5), Vector3(s.x * 0.8, 0.004, s.z * 0.8), lid)
	k.box(PropMats.fabric(EstateKit.ROSE.darkened(0.15)), Vector3(0, s.y * 0.53, 0), Vector3(s.x * 0.92, 0.01, s.z * 0.9))
	var gems := [EstateKit.ROSE, EstateKit.PERIWINKLE, EstateKit.MINT, EstateKit.LILAC]
	for i in 4:
		var x := -s.x * 0.3 + i * s.x * 0.2
		k.torus(gold, Vector3(x, s.y * 0.555, -s.z * 0.15), 0.018, 0.004, 8, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
		k.sphere(PropMats.glow(gems[i], 0.4), Vector3(x, s.y * 0.58, -s.z * 0.15), Vector3.ONE * 0.01, 5, 3)
	k.tube(PropMats.pearl(), PropParts.ring_pts(Vector3(0, s.y * 0.545, s.z * 0.15), 0.07, 12), 0.008, 4)
	k.lathe(gold, Vector3(0, 0, 0), PackedVector2Array([Vector2(0, s.y * 0.53), Vector2(0.02, s.y * 0.53), Vector2(0.02, s.y * 0.62),
			Vector2(0, s.y * 0.66)]), 6)
	# ballerina charm on top of the hinge
	k.sphere(PropMats.pearl(EstateKit.ROSE), Vector3(s.x * 0.35, s.y * 0.75, s.z * 0.3), Vector3(0.025, 0.04, 0.025), 6, 3)


static func _perfume_tray(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.box(PropMats.mirror(), Vector3(0, 0.01, 0), Vector3(s.x, 0.012, s.z))
	k.tube(gold, PropParts.ring_pts(Vector3(0, 0.02, 0), 0.5, 16), 0.008, 4, PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(s.x, 1, s.z)))
	var cols := [Color(c, 0.6), Color(1.0, 0.7, 0.85, 0.6), Color(0.8, 0.7, 1.0, 0.6), Color(1.0, 0.9, 0.6, 0.6), Color(0.7, 0.95, 0.85, 0.6)]
	for i in 5:
		var x := -s.x * 0.38 + i * s.x * 0.19
		var h := s.y * (0.7 + 0.3 * float(i % 2))
		PropParts.bottle(k, PropMats.glass(cols[i]), gold, Vector3(x, 0.015, (i % 2) * 0.06 - 0.03), h - 0.02, 0.035)
	k.sphere(PropMats.fabric(EstateKit.ROSE), Vector3(s.x * 0.45, 0.06, s.z * 0.3), Vector3(0.03, 0.03, 0.03), 6, 3)


static func _makeup(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.box(PropMats.pearl(EstateKit.BLUSH), Vector3(0, 0.01, 0), Vector3(s.x, 0.02, s.z))
	k.box(gold, Vector3(0, 0.021, 0), Vector3(s.x * 1.01, 0.004, s.z * 1.01))
	var shades := [EstateKit.ROSE, Color(0.95, 0.4, 0.55), EstateKit.LILAC, EstateKit.PERIWINKLE, EstateKit.BUTTER,
			Color(0.95, 0.7, 0.6), EstateKit.MINT, Color(0.7, 0.4, 0.75)]
	for i in 8:
		var x := -s.x * 0.36 + (i % 4) * s.x * 0.24
		var z := -s.z * 0.2 + (i / 4) * s.z * 0.35
		k.cyl(PropMats.gloss(shades[i]), Vector3(x, 0.02, z), 0.035, 0.035, 0.01, 10)
	k.tube(PropMats.pearl(EstateKit.PERIWINKLE), PackedVector3Array([Vector3(-s.x * 0.4, 0.035, s.z * 0.38),
			Vector3(s.x * 0.2, 0.035, s.z * 0.38)]), 0.008, 5)
	k.sphere(PropMats.fabric(EstateKit.PEARL), Vector3(s.x * 0.28, 0.04, s.z * 0.38), Vector3(0.035, 0.02, 0.035), 6, 3)
	k.cyl(gold, Vector3(s.x * 0.42, 0.02, s.z * 0.35), 0.012, 0.012, 0.04, 6)
	k.cyl(PropMats.gloss(Color(0.9, 0.2, 0.4)), Vector3(s.x * 0.42, 0.06, s.z * 0.35), 0.01, 0.005, 0.015, 6)


static func _screen(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	var silk := PropMats.fabric(c)
	var panels := 3
	var pw := s.x / panels
	for i in panels:
		var x := -s.x * 0.5 + pw * (i + 0.5)
		var yaw := 0.25 if i != 1 else 0.0
		var z := 0.0 if i == 1 else -0.0
		var t := PropMeshKit.at(Vector3(x, 0, z), yaw * (1.0 if i == 0 else -1.0))
		k.push(t)
		k.box(silk, Vector3(0, s.y * 0.5, 0), Vector3(pw * 0.92, s.y * 0.82, 0.02))
		k.cyl(gold, Vector3(-pw * 0.47, 0, 0), 0.02, 0.02, s.y * 0.92, 6)
		k.cyl(gold, Vector3(pw * 0.47, 0, 0), 0.02, 0.02, s.y * 0.92, 6)
		k.tube(gold, PropParts.arch_pts(pw * 0.94, s.y * 0.91, 0.0, 8, 0.08), 0.018, 5)
		k.box(gold, Vector3(0, 0.09, 0), Vector3(pw * 0.94, 0.02, 0.03))
		# painted climbing rose on each panel
		var stem := PackedVector3Array()
		for j in 6:
			stem.append(Vector3(sin(j * 1.3 + i) * pw * 0.2, 0.2 + j * s.y * 0.13, -0.015))
		k.tube(PropMats.satin(PropMats.LEAF), stem, 0.008, 4)
		for j in 4:
			PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if j % 2 == 0 else EstateKit.PEARL), stem[j + 1] + Vector3(0.04, 0.02, -0.01), 0.04)
		k.pop()


static func _pouf(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var fab := PropMats.fabric(c)
	for i in 4:
		var a := TAU * i / 4.0 + 0.78
		k.sphere(PropMats.gold(), Vector3(cos(a) * s.x * 0.35, 0.03, sin(a) * s.z * 0.35), Vector3.ONE * 0.03, 5, 3)
	k.lathe(fab, Vector3(0, 0.04, 0), PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.4, 0), Vector2(s.x * 0.5, s.y * 0.3),
			Vector2(s.x * 0.48, s.y * 0.7), Vector2(s.x * 0.35, s.y * 0.88), Vector2(0, s.y * 0.92 - 0.04)]), 16)
	k.torus(PropMats.gold(), Vector3(0, 0.08, 0), s.x * 0.44, 0.012, 16, 3)
	for i in 8:
		var a := TAU * i / 8.0
		k.sphere(PropMats.gold(), Vector3(cos(a) * s.x * 0.3, s.y * 0.86, sin(a) * s.z * 0.3), Vector3.ONE * 0.012, 4, 2)
	k.sphere(PropMats.fabric(EstateKit.PEARL), Vector3(0, s.y * 0.9, 0), Vector3(0.06, 0.04, 0.06), 6, 3)
