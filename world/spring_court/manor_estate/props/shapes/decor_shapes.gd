## Rugs, fireplaces, paintings, statues, vases, mirrors, clocks, columns and
## other decor. Wall pieces hang with their face toward -Z and back at +Z.
class_name DecorShapes
extends RefCounted



static func build(k: PropMeshKit, id: StringName, s: Vector3, c: Color) -> bool:
	match id:
		&"rug_large": _rug(k, s, c, false)
		&"rug_runner": _rug(k, s, c, false)
		&"rug_round": _rug(k, s, c, true)
		&"cushion_pile": _cushion_pile(k, s, c)
		&"fireplace_grand": _fireplace(k, s, c, true)
		&"fireplace_small": _fireplace(k, s, c, false)
		&"painting_large": _painting(k, s, 0)
		&"painting_medium": _painting(k, s, 1)
		&"painting_small": _painting(k, s, 2)
		&"portrait_masked": _portrait(k, s)
		&"tapestry_roses": _tapestry(k, s, c)
		&"statue_maiden": _maiden(k, s, c)
		&"statue_stag": _stag(k, s, c)
		&"bust_pedestal": _bust(k, s, c)
		&"vase_roses": _vase(k, s, c, 7)
		&"vase_tall": _vase(k, s, c, 0)
		&"urn_flowers": _urn(k, s, c)
		&"potted_palm": _palm(k, s, c)
		&"potted_roses": _potted_roses(k, s, c)
		&"flower_garland": _garland(k, s, c)
		&"mirror_gilt": _mirror(k, s, c)
		&"clock_grandfather": _clock(k, s, c)
		&"globe_stand": _globe(k, s, c)
		&"birdcage_gilt": _birdcage(k, s, c)
		&"mask_display": _masks(k, s, c)
		&"column_marble": _column(k, s, c)
		&"pilaster": _pilaster(k, s, c)
		&"arch_trellis": _trellis(k, s, c)
		&"balustrade": _balustrade(k, s, c)
		&"altar_marble": _altar(k, s, c)
		_: return false
	return true


static func _rug(k: PropMeshKit, s: Vector3, c: Color, round_: bool) -> void:
	var base := PropMats.fabric(c)
	var border := PropMats.fabric(EstateKit.CREAM)
	var accent := PropMats.fabric(EstateKit.GOLD)
	if round_:
		var r := s.x * 0.5
		k.cyl(base, Vector3.ZERO, r, r, s.y * 0.6, 32)
		k.torus(border, Vector3(0, s.y * 0.6, 0), r * 0.88, r * 0.04, 32, 3, PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 0.1, 1)))
		k.torus(accent, Vector3(0, s.y * 0.6, 0), r * 0.55, r * 0.025, 24, 3, PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 0.1, 1)))
		for i in 8:
			var a := TAU * i / 8.0
			k.cyl(PropMats.fabric(EstateKit.BLUSH), Vector3(cos(a) * r * 0.72, 0, sin(a) * r * 0.72), r * 0.08, r * 0.08, s.y, 8)
		k.cyl(PropMats.fabric(EstateKit.PERIWINKLE), Vector3.ZERO, r * 0.25, r * 0.25, s.y, 16)
		return
	k.box(base, Vector3(0, s.y * 0.3, 0), Vector3(s.x, s.y * 0.6, s.z))
	# cream border frame, gold inner line, a medallion and corner roses
	var bw := minf(s.x, s.z) * 0.08
	k.push(PropMeshKit.at(Vector3(0, s.y * 0.8, 0), 0, PI * 0.5))
	PropParts.frame(k, border, Vector3.ZERO, s.x * 0.94, s.z * 0.94, bw, s.y * 0.4)
	k.pop()
	k.box(accent, Vector3(0, s.y * 0.85, -s.z * 0.47 + bw * 1.6), Vector3(s.x * 0.8, s.y * 0.3, bw * 0.3))
	k.box(accent, Vector3(0, s.y * 0.85, s.z * 0.47 - bw * 1.6), Vector3(s.x * 0.8, s.y * 0.3, bw * 0.3))
	var mr := minf(s.x, s.z) * 0.22
	k.cyl(PropMats.fabric(EstateKit.LILAC), Vector3(0, 0, 0), mr, mr, s.y, 20, true,
			PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, s.z / s.x if s.z > s.x else 1.0)))
	k.cyl(PropMats.fabric(EstateKit.BLUSH), Vector3(0, 0, 0), mr * 0.5, mr * 0.5, s.y * 1.05, 16)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.cyl(PropMats.fabric(EstateKit.MINT), Vector3(sx * s.x * 0.36, 0, sz * s.z * 0.36), bw * 0.9, bw * 0.9, s.y, 10)
	# tassel fringe at the short ends
	var long_z := s.z > s.x
	var n := int((s.x if long_z else s.z) / 0.15)
	for i in n:
		for e: float in [-1.0, 1.0]:
			if long_z:
				k.box(accent, Vector3(-s.x * 0.48 + i * s.x / n, s.y * 0.2, e * s.z * 0.5), Vector3(0.03, s.y * 0.4, 0.06))
			else:
				k.box(accent, Vector3(e * s.x * 0.5, s.y * 0.2, -s.z * 0.48 + i * s.z / n), Vector3(0.06, s.y * 0.4, 0.03))


static func _cushion_pile(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var cols := [c, EstateKit.LILAC, EstateKit.MINT, EstateKit.BUTTER, EstateKit.PERIWINKLE, EstateKit.PEARL, EstateKit.ROSE]
	var rnd := PropParts.rng(&"cushion_pile")
	PropParts.cushion(k, PropMats.fabric(EstateKit.ROSE), Vector3(0, 0.07, 0), Vector3(s.x * 0.98, 0.14, s.z * 0.98))
	for i in 7:
		var a := TAU * i / 7.0
		var rr := 0.0 if i == 6 else s.x * 0.25
		var p := Vector3(cos(a) * rr, 0.16 + (0.1 if i == 6 else 0.0), sin(a) * rr)
		PropParts.cushion(k, PropMats.fabric(cols[i]), p, Vector3(0.38, 0.14, 0.38), PropMeshKit.at(Vector3.ZERO, rnd.randf() * 3.0, rnd.randf_range(-0.3, 0.3)))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		k.sphere(PropMats.gold(), Vector3(cos(a) * s.x * 0.47, 0.06, sin(a) * s.z * 0.47), Vector3.ONE * 0.025, 5, 3)
	k.sphere(PropMats.fabric(EstateKit.ROSE), Vector3(0.05, s.y - 0.08, 0), Vector3(0.14, 0.08, 0.1), 8, 4)


static func _fireplace(k: PropMeshKit, s: Vector3, c: Color, grand: bool) -> void:
	var marble := PropMats.pearl(c)
	var gold := PropMats.gold()
	var w := s.x
	var d := s.z
	var open_w := w * 0.52
	var open_h := s.y * 0.48
	k.box(PropMats.satin(PropMats.PLUM), Vector3(0, open_h * 0.5, d * 0.15), Vector3(open_w, open_h, d * 0.7))
	k.box(marble, Vector3(0, 0.04, -d * 0.1), Vector3(w * 0.9, 0.08, d * 0.9))
	for sx: float in [-1.0, 1.0]:
		var x := sx * (open_w * 0.5 + (w - open_w) * 0.2)
		k.box(marble, Vector3(x, s.y * 0.33, d * 0.1), Vector3((w - open_w) * 0.38, s.y * 0.62, d * 0.75))
		# fluted column with gilt capital
		k.cyl(marble, Vector3(x, 0.08, -d * 0.32), 0.07 * w / 2.0, 0.06 * w / 2.0, s.y * 0.55, 10)
		k.lathe(gold, Vector3(x, s.y * 0.55 + 0.08, -d * 0.32), PackedVector2Array([Vector2(0, 0), Vector2(0.08, 0),
				Vector2(0.11, 0.06), Vector2(0, 0.08)]), 8)
	k.box(marble, Vector3(0, open_h + (s.y * 0.66 - open_h) * 0.5, d * 0.1), Vector3(open_w, s.y * 0.66 - open_h, d * 0.75))
	k.box(marble, Vector3(0, s.y * 0.68, -d * 0.02), Vector3(w * 1.02, 0.08, d))
	k.box(gold, Vector3(0, s.y * 0.635, -d * 0.5), Vector3(w * 0.98, 0.02, 0.02))
	# carved rose cartouche over the opening
	PropParts.bloom(k, gold, Vector3(0, open_h + 0.12, -d * 0.28), 0.09)
	for sx: float in [-1.0, 1.0]:
		k.leaf(gold, Vector3(sx * 0.08, open_h + 0.12, -d * 0.3), Vector3(sx, -0.1, 0), 0.3, 0.1, 0.1)
	# overmantel mirror on grand fireplaces
	if grand:
		var my := s.y * 0.72
		k.box(PropMats.mirror(), Vector3(0, my + (s.y - my) * 0.5, d * 0.35), Vector3(w * 0.5, s.y - my - 0.05, 0.03))
		PropParts.frame(k, gold, Vector3(0, my + (s.y - my) * 0.5, d * 0.33), w * 0.55, s.y - my, 0.06, 0.04)
	# fire: logs and flames, a gold fender
	for i in 3:
		var t := PropMeshKit.at(Vector3(-open_w * 0.2 + i * open_w * 0.2, 0.12, d * 0.1), 0.3 * (i - 1), 0, PI * 0.5)
		k.cyl(PropMats.wood(EstateKit.OAK_DARK), Vector3(0, -open_w * 0.2, 0), 0.05, 0.05, open_w * 0.4, 6, true, t)
	for i in 5:
		var x := -open_w * 0.3 + i * open_w * 0.15
		var fh := open_h * (0.35 + 0.2 * float(i % 2))
		k.cyl(PropMats.glow(Color(1.0, 0.62, 0.40), 3.0), Vector3(x, 0.14, d * 0.1), 0.08, 0.0, fh, 6)
		k.cyl(PropMats.glow(EstateKit.BUTTER, 3.5), Vector3(x, 0.14, d * 0.05), 0.04, 0.0, fh * 0.7, 5)
	k.tube(gold, PackedVector3Array([Vector3(-open_w * 0.5, 0.15, -d * 0.45), Vector3(-open_w * 0.4, 0.2, -d * 0.55),
			Vector3(open_w * 0.4, 0.2, -d * 0.55), Vector3(open_w * 0.5, 0.15, -d * 0.45)]), 0.02, 5)
	# mantel garnish: candlesticks and a clock
	var mt := s.y * 0.72
	for sx: float in [-1.0, 1.0]:
		k.cyl(gold, Vector3(sx * w * 0.4, mt, 0), 0.04, 0.02, 0.12, 8)
		PropParts.candle(k, Vector3(sx * w * 0.4, mt + 0.12, 0), 0.16, 0.02)
	k.box(gold, Vector3(0, mt + 0.1, 0), Vector3(0.22, 0.2, 0.1))
	k.disc(PropMats.pearl(), Vector3.ZERO, 0.07, 12, PropMeshKit.at(Vector3(0, mt + 0.12, -0.052), 0, -PI * 0.5))


static func _scene(k: PropMeshKit, w: float, h: float, cy: float, z: float, variant: int) -> void:
	# a painted landscape: sky bands, sun, hills, a blossom tree
	var sky: Color = [EstateKit.PERIWINKLE, EstateKit.BLUSH, EstateKit.LILAC][variant % 3]
	var sky2: Color = [EstateKit.BLUSH, EstateKit.BUTTER, EstateKit.PERIWINKLE][variant % 3]
	k.box(PropMats.satin(sky), Vector3(0, cy + h * 0.25, z), Vector3(w, h * 0.5, 0.01))
	k.box(PropMats.satin(sky2), Vector3(0, cy - h * 0.1, z), Vector3(w, h * 0.2, 0.01))
	k.box(PropMats.satin(EstateKit.MINT), Vector3(0, cy - h * 0.35, z), Vector3(w, h * 0.3, 0.01))
	k.disc(PropMats.glow(EstateKit.BUTTER, 0.4), Vector3.ZERO, h * 0.08, 10, PropMeshKit.at(Vector3(w * (0.25 - 0.2 * variant), cy + h * 0.28, z - 0.008), 0, -PI * 0.5))
	k.disc(PropMats.satin(PropMats.LEAF), Vector3.ZERO, w * 0.35, 12, PropMeshKit.at(Vector3(-w * 0.2, cy - h * 0.2, z - 0.007), 0, -PI * 0.5), h * 0.15)
	k.disc(PropMats.satin(EstateKit.MOSS), Vector3.ZERO, w * 0.3, 12, PropMeshKit.at(Vector3(w * 0.25, cy - h * 0.22, z - 0.009), 0, -PI * 0.5), h * 0.12)
	k.box(PropMats.wood(EstateKit.OAK_DARK), Vector3(w * 0.1, cy - h * 0.12, z - 0.012), Vector3(w * 0.02, h * 0.2, 0.004))
	k.disc(PropMats.satin(EstateKit.ROSE), Vector3.ZERO, h * 0.12, 10, PropMeshKit.at(Vector3(w * 0.1, cy + h * 0.02, z - 0.014), 0, -PI * 0.5))
	k.disc(PropMats.satin(EstateKit.PEARL), Vector3.ZERO, h * 0.06, 8, PropMeshKit.at(Vector3(-w * 0.3, cy + h * 0.3, z - 0.009), 0, -PI * 0.5), h * 0.03)


static func _painting(k: PropMeshKit, s: Vector3, variant: int) -> void:
	var gold := PropMats.gold()
	var bar := minf(s.x, s.y) * 0.08
	var cy := s.y * 0.5
	k.box(PropMats.pearl(), Vector3(0, cy, s.z * 0.3), Vector3(s.x * 0.98, s.y * 0.98, s.z * 0.3))
	_scene(k, s.x - bar * 2.0, s.y - bar * 2.0, cy, 0.0, variant)
	PropParts.frame(k, gold, Vector3(0, cy, -s.z * 0.1), s.x, s.y, bar, s.z * 0.6)
	PropParts.bloom(k, gold, Vector3(0, s.y - bar * 0.5, -s.z * 0.45), bar * 0.6)


static func _portrait(k: PropMeshKit, s: Vector3) -> void:
	var gold := PropMats.gold()
	var bar := s.x * 0.09
	k.box(PropMats.satin(PropMats.PLUM), Vector3(0, s.y * 0.5, s.z * 0.2), Vector3(s.x - bar, s.y - bar, 0.01))
	# a masked High Fae: shoulders, head, a gold leaf mask, auburn-gold hair
	k.sphere(PropMats.satin(EstateKit.MINT.darkened(0.2)), Vector3(0, s.y * 0.2, 0.1), Vector3(s.x * 0.32, s.y * 0.2, 0.02), 10, 5)
	k.sphere(PropMats.satin(Color(1.0, 0.85, 0.75)), Vector3(0, s.y * 0.52, 0.1), Vector3(s.x * 0.13, s.y * 0.13, 0.02), 10, 5)
	k.sphere(PropMats.satin(Color(0.95, 0.75, 0.4)), Vector3(0, s.y * 0.56, 0.11), Vector3(s.x * 0.17, s.y * 0.15, 0.01), 10, 5)
	k.sphere(gold, Vector3(0, s.y * 0.54, 0.08), Vector3(s.x * 0.15, s.y * 0.05, 0.01), 10, 4)
	for sx: float in [-1.0, 1.0]:
		k.leaf(gold, Vector3(sx * s.x * 0.1, s.y * 0.56, 0.075), Vector3(sx, 0.6, 0), s.x * 0.14, s.x * 0.06, 0.0)
	PropParts.frame(k, gold, Vector3(0, s.y * 0.5, 0.0), s.x, s.y, bar, s.z * 0.8)
	k.sphere(gold, Vector3(0, s.y - bar * 0.4, -s.z * 0.4), Vector3(bar * 1.2, bar * 0.6, 0.02), 8, 4)


static func _tapestry(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.tube(gold, PackedVector3Array([Vector3(-s.x * 0.5, s.y - 0.04, 0), Vector3(s.x * 0.5, s.y - 0.04, 0)]), 0.03, 6)
	for sx: float in [-1.0, 1.0]:
		k.sphere(gold, Vector3(sx * s.x * 0.5, s.y - 0.04, 0), Vector3.ONE * 0.05, 6, 3)
	k.box(PropMats.fabric(c), Vector3(0, s.y * 0.5, s.z * 0.2), Vector3(s.x * 0.94, s.y * 0.9, 0.02))
	k.box(PropMats.fabric(EstateKit.BLUSH), Vector3(0, s.y * 0.5, 0.0), Vector3(s.x * 0.8, s.y * 0.76, 0.01))
	# a rose vine border and a central heart of roses
	var pts := PackedVector3Array()
	for i in 13:
		var t := float(i) / 12.0
		pts.append(Vector3(-s.x * 0.38 + t * s.x * 0.76, s.y * 0.17 + sin(t * TAU * 2.0) * 0.05, -0.01))
	k.tube(PropMats.satin(PropMats.LEAF), pts, 0.012, 4)
	for i in 6:
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if i % 2 == 0 else Color(0.9, 0.25, 0.4)), pts[i * 2] + Vector3(0, 0.02, -0.01), 0.05)
	for i in 12:
		var a := TAU * i / 12.0
		var hx := 16.0 * pow(sin(a), 3.0) / 17.0
		var hy := (13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a)) / 17.0
		PropParts.bloom(k, PropMats.satin(Color(0.9, 0.25, 0.4)), Vector3(hx * s.x * 0.2, s.y * 0.55 + hy * s.y * 0.2, -0.02), 0.06)
	# fringe
	for i in 20:
		k.box(gold, Vector3(-s.x * 0.45 + i * s.x * 0.0474, s.y * 0.03, s.z * 0.2), Vector3(0.03, 0.08, 0.01))


static func _plinth(k: PropMeshKit, m: Material, w: float, d: float, h: float) -> void:
	k.box(m, Vector3(0, h * 0.08, 0), Vector3(w, h * 0.16, d))
	k.box(m, Vector3(0, h * 0.5, 0), Vector3(w * 0.85, h * 0.7, d * 0.85))
	k.box(m, Vector3(0, h * 0.93, 0), Vector3(w, h * 0.14, d))
	k.box(PropMats.gold(), Vector3(0, h * 0.86, -d * 0.43), Vector3(w * 0.6, 0.02, 0.01))


static func _maiden(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var marble := PropMats.pearl(c)
	var gold := PropMats.gold()
	var ph := s.y * 0.25
	_plinth(k, marble, s.x, s.z, ph)
	var fig_h := s.y - ph
	var b := Vector3(0, ph, 0)
	# flowing robe, bodice, head with hair bun, arms holding a gilt rose garland
	k.lathe(marble, b, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.36, 0), Vector2(s.x * 0.3, fig_h * 0.3),
			Vector2(s.x * 0.18, fig_h * 0.55), Vector2(s.x * 0.15, fig_h * 0.65), Vector2(s.x * 0.18, fig_h * 0.75),
			Vector2(s.x * 0.08, fig_h * 0.84), Vector2(0, fig_h * 0.85)]), 12)
	k.sphere(marble, b + Vector3(0, fig_h * 0.91, 0), Vector3(0.1, 0.12, 0.1), 10, 6)
	k.sphere(marble, b + Vector3(0, fig_h * 0.95, 0.08), Vector3(0.07, 0.07, 0.07), 8, 4)
	k.torus(gold, b + Vector3(0, fig_h * 0.96, 0), 0.1, 0.015, 12, 4)
	for sx: float in [-1.0, 1.0]:
		k.tube(marble, PackedVector3Array([b + Vector3(sx * 0.16, fig_h * 0.78, 0), b + Vector3(sx * 0.2, fig_h * 0.62, -0.08),
				b + Vector3(sx * 0.08, fig_h * 0.66, -0.2)]), 0.04, 6)
	var gpts := PackedVector3Array()
	for i in 9:
		var t := float(i) / 8.0
		gpts.append(b + Vector3(-0.12 + t * 0.24, fig_h * 0.62 - sin(t * PI) * 0.12, -0.22))
	k.tube(PropMats.satin(PropMats.LEAF), gpts, 0.02, 4)
	for i in 5:
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), gpts[i * 2], 0.035)


static func _stag(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var marble := PropMats.pearl(c)
	var gold := PropMats.gold()
	var ph := s.y * 0.2
	_plinth(k, marble, s.x, s.z, ph)
	# body along X (the plinth is wide), legs, arched neck, head, gilt antlers
	var bl := s.x * 0.36
	var by := ph + s.y * 0.38
	k.sphere(marble, Vector3(0, by, 0), Vector3(bl, s.y * 0.12, s.z * 0.2), 12, 6)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var top := Vector3(sx * bl * 0.65, by - 0.05, sz * s.z * 0.12)
			k.tube(marble, PackedVector3Array([top, top + Vector3(sx * 0.03, -(by - ph) * 0.5, 0),
					Vector3(top.x, ph + 0.02, top.z)]), 0.05, 6, Transform3D.IDENTITY, 0.03)
	var neck := PackedVector3Array([Vector3(-bl * 0.8, by + 0.05, 0), Vector3(-bl * 1.0, by + s.y * 0.18, 0), Vector3(-bl * 1.05, by + s.y * 0.26, 0)])
	k.tube(marble, neck, 0.09, 8, Transform3D.IDENTITY, 0.07)
	var head := Vector3(-bl * 1.12, by + s.y * 0.28, 0)
	k.sphere(marble, head, Vector3(0.14, 0.08, 0.08), 8, 5, PropMeshKit.at(Vector3.ZERO, 0, 0, -0.3))
	for sz: float in [-1.0, 1.0]:
		var base := head + Vector3(0.04, 0.06, sz * 0.05)
		var a := PackedVector3Array([base, base + Vector3(0.05, 0.15, sz * 0.08), base + Vector3(0.02, 0.32, sz * 0.14),
				base + Vector3(0.08, 0.45, sz * 0.16)])
		k.tube(gold, a, 0.018, 5, Transform3D.IDENTITY, 0.008)
		for t in 3:
			k.tube(gold, PackedVector3Array([a[t + 1], a[t + 1] + Vector3(-0.08, 0.1, sz * 0.03)]), 0.012, 4, Transform3D.IDENTITY, 0.004)
		k.leaf(marble, head + Vector3(0.06, 0.05, sz * 0.06), Vector3(0.2, 0.3, sz), 0.08, 0.04, 0.0)
	k.torus(PropMats.satin(PropMats.LEAF), neck[1], 0.1, 0.02, 10, 3, PropMeshKit.at(Vector3.ZERO, 0, 0, 0.4))
	k.sphere(marble, Vector3(bl * 1.0, by + 0.06, 0), Vector3(0.05, 0.05, 0.04), 6, 3)


static func _bust(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var marble := PropMats.pearl(c)
	var gold := PropMats.gold()
	k.lathe(marble, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.5, 0), Vector2(s.x * 0.5, 0.08),
			Vector2(s.x * 0.3, 0.14), Vector2(s.x * 0.22, 0.3), Vector2(s.x * 0.2, s.y * 0.55), Vector2(s.x * 0.32, s.y * 0.62),
			Vector2(s.x * 0.45, s.y * 0.66), Vector2(s.x * 0.45, s.y * 0.69), Vector2(0, s.y * 0.69)]), 12)
	k.torus(gold, Vector3(0, s.y * 0.6, 0), s.x * 0.24, 0.012, 12, 3)
	var y := s.y * 0.69
	k.sphere(marble, Vector3(0, y + 0.1, 0), Vector3(s.x * 0.4, 0.1, s.z * 0.25), 10, 5)
	k.cyl(marble, Vector3(0, y + 0.15, 0), 0.05, 0.045, 0.1, 8)
	k.sphere(marble, Vector3(0, y + 0.33, 0), Vector3(0.1, 0.13, 0.11), 10, 6)
	k.torus(gold, Vector3(0, y + 0.38, 0), 0.1, 0.014, 12, 4, PropMeshKit.at(Vector3.ZERO, 0, 0.15))
	for i in 5:
		var a := -1.0 + i * 0.5
		k.leaf(gold, Vector3(sin(a) * 0.1, y + 0.39, -cos(a) * 0.1), Vector3(sin(a), 0.6, -cos(a)), 0.06, 0.03, 0.0)


static func _vase(k: PropMeshKit, s: Vector3, c: Color, blooms: int) -> void:
	var porcelain := PropMats.pearl(c)
	var gold := PropMats.gold()
	var vh := s.y * (0.45 if blooms > 0 else 1.0)
	var r := s.x * (0.42 if blooms > 0 else 0.48)
	k.lathe(porcelain, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(r * 0.6, 0), Vector2(r * 0.6, vh * 0.05),
			Vector2(r, vh * 0.35), Vector2(r * 0.9, vh * 0.6), Vector2(r * 0.45, vh * 0.85), Vector2(r * 0.55, vh * 0.97),
			Vector2(r * 0.5, vh), Vector2(0, vh * 0.95)]), 14)
	k.torus(gold, Vector3(0, vh * 0.85, 0), r * 0.46, 0.008, 14, 3)
	k.torus(gold, Vector3(0, vh * 0.05, 0), r * 0.6, 0.01, 14, 3)
	if blooms == 0:
		# painted band of blossoms
		for i in 8:
			var a := TAU * i / 8.0
			PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if i % 2 == 0 else EstateKit.PEARL),
					Vector3(cos(a) * r * 0.93, vh * 0.4, sin(a) * r * 0.93), r * 0.12)
		for sx: float in [-1.0, 1.0]:
			k.torus(gold, Vector3(sx * r * 0.65, vh * 0.75, 0), r * 0.15, 0.012, 10, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
		return
	var rnd := PropParts.rng(&"vase_roses")
	for i in blooms:
		var a := TAU * i / blooms
		var tip := Vector3(cos(a) * s.x * 0.32, s.y - 0.08 - rnd.randf() * 0.1, sin(a) * s.x * 0.32)
		if i == 0:
			tip = Vector3(0, s.y - 0.06, 0)
		k.tube(PropMats.satin(PropMats.LEAF), PackedVector3Array([Vector3(0, vh * 0.8, 0), tip * Vector3(0.5, 1.0, 0.5) + Vector3(0, -0.08, 0), tip]), 0.006, 4)
		PropParts.bloom(k, PropMats.satin([c, EstateKit.BLUSH, EstateKit.PEARL][i % 3]), tip, 0.05)
		k.leaf(PropMats.satin(PropMats.LEAF), tip * 0.7 + Vector3(0, -0.05, 0), Vector3(cos(a), 0.2, sin(a)), 0.09, 0.04)


static func _urn(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var stone := PropMats.pearl(c)
	var r := s.x * 0.5
	var uh := s.y * 0.62
	k.lathe(stone, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(r * 0.55, 0), Vector2(r * 0.55, 0.08),
			Vector2(r * 0.25, 0.14), Vector2(r * 0.22, uh * 0.35), Vector2(r * 0.6, uh * 0.45), Vector2(r * 0.85, uh * 0.75),
			Vector2(r * 0.95, uh * 0.95), Vector2(r * 0.9, uh), Vector2(0, uh * 0.96)]), 14)
	k.torus(PropMats.gold(), Vector3(0, uh * 0.95, 0), r * 0.93, 0.02, 16, 3)
	for sx: float in [-1.0, 1.0]:
		k.torus(stone, Vector3(sx * r * 0.85, uh * 0.7, 0), r * 0.18, 0.03, 10, 4, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
	_flower_dome(k, Vector3(0, uh, 0), r * 0.85, s.y - uh, c, &"urn_flowers")


## A domed mound of foliage studded with blooms (urns, planters, tubs).
static func _flower_dome(k: PropMeshKit, base: Vector3, r: float, h: float, c: Color, seed_id: StringName) -> void:
	k.sphere(PropMats.satin(PropMats.LEAF), base, Vector3(r, h * 0.7, r), 12, 5, Transform3D.IDENTITY, true)
	var rnd := PropParts.rng(seed_id)
	var cols := [EstateKit.ROSE, EstateKit.BLUSH, EstateKit.BUTTER, EstateKit.LILAC, EstateKit.PEARL, EstateKit.PERIWINKLE]
	for i in 14:
		var a := rnd.randf() * TAU
		var e := rnd.randf_range(0.15, 1.3)
		var p := Vector3(cos(a) * sin(e) * r, cos(e) * h * 0.7, sin(a) * sin(e) * r)
		PropParts.bloom(k, PropMats.satin(cols[i % cols.size()]), base + p, r * 0.16)
	for i in 6:
		var a := TAU * i / 6.0
		k.leaf(PropMats.satin(PropMats.LEAF), base + Vector3(cos(a) * r * 0.8, h * 0.1, sin(a) * r * 0.8),
				Vector3(cos(a), -0.3, sin(a)), r * 0.6, r * 0.25, 0.6)


static func _palm(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var pot := PropMats.pearl(EstateKit.PERIWINKLE)
	var ph := s.y * 0.25
	k.lathe(pot, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.25, 0), Vector2(s.x * 0.33, ph * 0.8),
			Vector2(s.x * 0.36, ph), Vector2(0, ph * 0.95)]), 12)
	k.torus(PropMats.gold(), Vector3(0, ph * 0.92, 0), s.x * 0.34, 0.015, 12, 3)
	var trunk := PackedVector3Array()
	for i in 6:
		trunk.append(Vector3(sin(i * 0.5) * 0.04, ph + i * (s.y * 0.55) / 5.0, 0))
	k.tube(PropMats.wood(EstateKit.OAK), trunk, 0.05, 6, Transform3D.IDENTITY, 0.035)
	var top := trunk[5]
	var leaf := PropMats.satin(c)
	for i in 9:
		var a := TAU * i / 9.0
		k.leaf(leaf, top, Vector3(cos(a), 0.5 - (i % 2) * 0.4, sin(a)), s.x * 0.55, 0.16, 0.9)


static func _potted_roses(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var ph := s.y * 0.4
	k.lathe(PropMats.pearl(), Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.3, 0), Vector2(s.x * 0.28, 0.05),
			Vector2(s.x * 0.4, ph * 0.85), Vector2(s.x * 0.45, ph), Vector2(0, ph * 0.95)]), 12)
	k.torus(PropMats.gold(), Vector3(0, ph * 0.95, 0), s.x * 0.44, 0.012, 12, 3)
	k.tube(PropMats.satin(EstateKit.ROSE), PropParts.ring_pts(Vector3(0, ph * 0.6, 0), s.x * 0.37, 12), 0.015, 4)
	k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(0, ph * 0.6, -s.x * 0.38), Vector3(0.05, 0.035, 0.02), 6, 3)
	_rose_crown(k, Vector3(0, ph, 0), s.x * 0.45, s.y - ph, c, &"potted_roses")


static func _rose_crown(k: PropMeshKit, base: Vector3, r: float, h: float, c: Color, seed_id: StringName) -> void:
	k.sphere(PropMats.satin(EstateKit.HEDGE), base + Vector3(0, h * 0.4, 0), Vector3(r, h * 0.45, r), 12, 6)
	var rnd := PropParts.rng(seed_id)
	for i in 12:
		var a := rnd.randf() * TAU
		var e := rnd.randf_range(0.2, 1.4)
		var p := Vector3(cos(a) * sin(e) * r, h * 0.4 + cos(e) * h * 0.45, sin(a) * sin(e) * r)
		PropParts.bloom(k, PropMats.satin(c if i % 3 else EstateKit.BLUSH), base + p, r * 0.22)


static func _garland(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var pts := PackedVector3Array()
	for i in 13:
		var t := float(i) / 12.0
		pts.append(Vector3(-s.x * 0.5 + t * s.x, s.y - 0.06 - sin(t * PI) * (s.y - 0.15), 0))
	k.tube(PropMats.satin(PropMats.LEAF), pts, 0.04, 5)
	for i in 13:
		PropParts.bloom(k, PropMats.satin([c, EstateKit.BLUSH, EstateKit.PEARL, EstateKit.BUTTER][i % 4]), pts[i] + Vector3(0, 0.01, -0.03), 0.06)
		if i % 2 == 0:
			k.leaf(PropMats.satin(PropMats.LEAF), pts[i], Vector3(0.5, -0.6, -0.4), 0.1, 0.05)
	for sx: float in [-1.0, 1.0]:
		k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(sx * s.x * 0.48, s.y - 0.06, 0), Vector3(0.1, 0.05, 0.03), 8, 4)
		k.tube(PropMats.satin(EstateKit.ROSE), PackedVector3Array([Vector3(sx * s.x * 0.48, s.y - 0.08, 0),
				Vector3(sx * s.x * 0.46, s.y - 0.3, -0.02)]), 0.012, 4)


static func _mirror(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	var bar := s.x * 0.08
	k.box(PropMats.mirror(), Vector3(0, s.y * 0.45, 0.0), Vector3(s.x - bar * 1.5, s.y * 0.82, 0.01))
	PropParts.frame(k, gold, Vector3(0, s.y * 0.45, -0.01), s.x, s.y * 0.9, bar, s.z * 0.7)
	# scrolling crest with a rose and two acanthus leaves
	PropParts.bloom(k, gold, Vector3(0, s.y * 0.93, -0.02), bar * 0.9)
	for sx: float in [-1.0, 1.0]:
		k.leaf(gold, Vector3(sx * bar * 0.5, s.y * 0.92, -0.02), Vector3(sx, -0.2, 0), s.x * 0.35, bar * 1.2, 0.3)
	k.sphere(gold, Vector3(0, bar * 0.2, -0.02), Vector3(bar, bar * 0.4, 0.02), 8, 3)


static func _clock(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	var gold := PropMats.gold()
	k.box(wood, Vector3(0, s.y * 0.1, 0), Vector3(s.x, s.y * 0.2, s.z))
	k.box(wood, Vector3(0, s.y * 0.45, 0), Vector3(s.x * 0.75, s.y * 0.5, s.z * 0.8))
	k.box(PropMats.glass(), Vector3(0, s.y * 0.45, -s.z * 0.41), Vector3(s.x * 0.45, s.y * 0.38, 0.01))
	k.tube(gold, PackedVector3Array([Vector3(0, s.y * 0.66, -s.z * 0.3), Vector3(0, s.y * 0.38, -s.z * 0.3)]), 0.01, 4)
	k.cyl(gold, Vector3(0, -0.01, 0), 0.07, 0.07, 0.02, 12, true, PropMeshKit.at(Vector3(0, s.y * 0.36, -s.z * 0.3), 0, PI * 0.5))
	k.box(wood, Vector3(0, s.y * 0.82, 0), Vector3(s.x, s.y * 0.24, s.z))
	k.disc(PropMats.pearl(), Vector3.ZERO, s.x * 0.34, 16, PropMeshKit.at(Vector3(0, s.y * 0.82, -s.z * 0.505), 0, -PI * 0.5))
	k.torus(gold, Vector3.ZERO, s.x * 0.35, 0.015, 16, 3, PropMeshKit.at(Vector3(0, s.y * 0.82, -s.z * 0.505), 0, PI * 0.5))
	k.box(PropMats.satin(PropMats.PLUM), Vector3(0.04, s.y * 0.84, -s.z * 0.51), Vector3(0.1, 0.012, 0.005), PropMeshKit.at(Vector3.ZERO, 0, 0, 0.4))
	k.box(PropMats.satin(PropMats.PLUM), Vector3(0, s.y * 0.86, -s.z * 0.51), Vector3(0.01, 0.12, 0.005))
	# bonnet top with three gilt finials
	k.cyl(wood, Vector3(0, -s.z * 0.5, 0), s.x * 0.5, s.x * 0.5, s.z, 14, true,
			PropMeshKit.at(Vector3(0, s.y * 0.94, 0), 0, PI * 0.5, 0, Vector3(1, 0.24, 1)))
	for x: float in [-1.0, 0.0, 1.0]:
		k.sphere(gold, Vector3(x * s.x * 0.42, s.y * 0.97 + (0.02 if x == 0.0 else 0.0), -s.z * 0.2), Vector3.ONE * 0.035, 6, 3)


static func _globe(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	var gold := PropMats.gold()
	for i in 3:
		var a := TAU * i / 3.0
		k.tube(wood, PackedVector3Array([Vector3(cos(a) * s.x * 0.45, 0, sin(a) * s.z * 0.45),
				Vector3(cos(a) * s.x * 0.2, s.y * 0.3, sin(a) * s.z * 0.2), Vector3(0, s.y * 0.4, 0)]), 0.025, 5)
	k.cyl(wood, Vector3(0, s.y * 0.35, 0), 0.04, 0.05, s.y * 0.12, 8)
	var gc := Vector3(0, s.y * 0.72, 0)
	var gr := s.y * 0.26
	k.sphere(PropMats.satin(EstateKit.PERIWINKLE), gc, Vector3.ONE * gr, 14, 8, PropMeshKit.at(Vector3.ZERO, 0, 0, 0.4))
	# continents in mint, a meridian ring and horizon ring in gold
	var rnd := PropParts.rng(&"globe")
	for i in 6:
		var a := rnd.randf() * TAU
		var e := rnd.randf_range(0.6, 2.4)
		var p := Vector3(cos(a) * sin(e), cos(e), sin(a) * sin(e))
		k.sphere(PropMats.satin(EstateKit.MINT), gc + p * gr * 0.93, Vector3(gr * 0.3, gr * 0.22, gr * 0.3), 6, 3,
				Transform3D(Basis(Quaternion(Vector3.UP, p)), Vector3.ZERO))
	k.torus(gold, gc, gr * 1.08, 0.012, 20, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5, 0.4))
	k.torus(gold, gc, gr * 1.12, 0.015, 20, 3)


static func _birdcage(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	k.lathe(gold, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.4, 0), Vector2(s.x * 0.35, 0.04),
			Vector2(0.03, 0.12), Vector2(0.025, s.y * 0.45), Vector2(0, s.y * 0.45)]), 10)
	var cb := s.y * 0.45
	var ch := s.y * 0.4
	var r := s.x * 0.45
	k.cyl(gold, Vector3(0, cb, 0), r, r, 0.03, 14)
	for i in 12:
		var a := TAU * i / 12.0
		var pts := PackedVector3Array()
		for j in 6:
			var t := float(j) / 5.0
			var rr := r * (1.0 if t < 0.6 else cos((t - 0.6) / 0.4 * PI * 0.5))
			pts.append(Vector3(cos(a) * rr, cb + t * ch, sin(a) * rr))
		k.tube(gold, pts, 0.006, 3)
	k.torus(gold, Vector3(0, cb + ch * 0.3, 0), r, 0.008, 14, 3)
	k.torus(gold, Vector3(0, cb + ch * 0.62, 0), r * 0.98, 0.008, 14, 3)
	k.torus(gold, Vector3(0, s.y - 0.05, 0), 0.04, 0.01, 8, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
	k.cyl(gold, Vector3(0, cb + ch, 0), 0.02, 0.02, s.y - cb - ch - 0.08, 5)
	# a perch with a pastel songbird and trailing roses
	k.tube(gold, PackedVector3Array([Vector3(-r * 0.8, cb + ch * 0.35, 0), Vector3(r * 0.8, cb + ch * 0.35, 0)]), 0.006, 4)
	k.sphere(PropMats.satin(EstateKit.BUTTER), Vector3(0, cb + ch * 0.42, 0), Vector3(0.05, 0.04, 0.035), 8, 4)
	k.sphere(PropMats.satin(EstateKit.BUTTER), Vector3(-0.04, cb + ch * 0.5, 0), Vector3.ONE * 0.025, 6, 3)
	k.cyl(PropMats.satin(Color(1.0, 0.6, 0.3)), Vector3(-0.065, cb + ch * 0.5, 0), 0.006, 0.0, 0.02, 4, true, PropMeshKit.at(Vector3.ZERO, 0, 0, PI * 0.5))
	k.leaf(PropMats.satin(EstateKit.PERIWINKLE), Vector3(0.04, cb + ch * 0.42, 0), Vector3(1, -0.3, 0), 0.06, 0.03, 0.0)
	for i in 4:
		var a := TAU * i / 4.0
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(cos(a) * r, cb + ch * 0.62, sin(a) * r), 0.03)


static func _masks(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.box(PropMats.satin(PropMats.PLUM), Vector3(0, s.y * 0.5, s.z * 0.3), Vector3(s.x, s.y, s.z * 0.3))
	PropParts.frame(k, gold, Vector3(0, s.y * 0.5, 0.0), s.x, s.y, 0.05, s.z * 0.5)
	# three Spring Court masks: leaf, feather and flower
	var cols := [EstateKit.GOLD, EstateKit.MINT, EstateKit.ROSE]
	for i in 3:
		var x := -s.x * 0.3 + i * s.x * 0.3
		var m := PropMats.metal(cols[i]) if i == 0 else PropMats.gloss(cols[i])
		k.sphere(m, Vector3(x, s.y * 0.5, -0.0), Vector3(0.14, 0.07, 0.03), 10, 4)
		for sx: float in [-1.0, 1.0]:
			k.leaf(m, Vector3(x + sx * 0.1, s.y * 0.52, -0.02), Vector3(sx, 0.7, 0), 0.12, 0.05, 0.0)
			k.disc(PropMats.satin(PropMats.PLUM), Vector3.ZERO, 0.03, 8, PropMeshKit.at(Vector3(x + sx * 0.05, s.y * 0.51, -0.032), 0, -PI * 0.5), 0.018)


static func _column(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var marble := PropMats.pearl(c)
	var gold := PropMats.gold()
	var r := s.x * 0.36
	k.box(marble, Vector3(0, 0.1, 0), Vector3(s.x, 0.2, s.z))
	k.lathe(marble, Vector3(0, 0.2, 0), PackedVector2Array([Vector2(0, 0), Vector2(r * 1.25, 0), Vector2(r * 1.25, 0.08),
			Vector2(r * 1.1, 0.14), Vector2(r, 0.2), Vector2(r * 0.9, s.y - 0.75), Vector2(r * 1.05, s.y - 0.65),
			Vector2(r * 1.3, s.y - 0.5), Vector2(0, s.y - 0.5)]), 16)
	# spiral rose vine winding up the shaft
	var vine := PackedVector3Array()
	for i in 25:
		var t := float(i) / 24.0
		var a := t * TAU * 2.5
		var rr := lerpf(r, r * 0.9, t) + 0.015
		vine.append(Vector3(cos(a) * rr, 0.5 + t * (s.y - 1.4), sin(a) * rr))
	k.tube(PropMats.satin(PropMats.LEAF), vine, 0.015, 4)
	for i in 8:
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if i % 2 == 0 else EstateKit.BLUSH), vine[i * 3 + 1], 0.045)
	k.torus(gold, Vector3(0, s.y - 0.55, 0), r * 1.1, 0.03, 16, 4)
	k.box(marble, Vector3(0, s.y - 0.25, 0), Vector3(s.x, 0.5, s.z))
	for sx: float in [-1.0, 1.0]:
		k.torus(gold, Vector3(sx * s.x * 0.42, s.y - 0.3, 0), 0.1, 0.03, 10, 4, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))


static func _pilaster(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	var gold := PropMats.gold()
	k.box(m, Vector3(0, 0.15, 0), Vector3(s.x, 0.3, s.z))
	k.box(m, Vector3(0, s.y * 0.5, s.z * 0.15), Vector3(s.x * 0.8, s.y - 0.6, s.z * 0.7))
	for i in 4:
		k.cyl(PropMats.pearl(EstateKit.BLUSH), Vector3(-s.x * 0.27 + i * s.x * 0.18, 0.35, -s.z * 0.2), 0.03, 0.03, s.y - 0.75, 6)
	k.box(m, Vector3(0, s.y - 0.15, 0), Vector3(s.x, 0.3, s.z))
	k.box(gold, Vector3(0, s.y - 0.32, -s.z * 0.1), Vector3(s.x * 0.9, 0.05, s.z * 0.9))
	for sx: float in [-1.0, 1.0]:
		k.torus(gold, Vector3(sx * s.x * 0.36, s.y - 0.2, -s.z * 0.45), 0.06, 0.02, 10, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))


static func _trellis(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	var spring := s.y - s.x * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.cyl(m, Vector3(sx * s.x * 0.45, 0, sz * s.z * 0.4), 0.04, 0.04, spring, 6)
		for j in 6:
			k.box(m, Vector3(sx * s.x * 0.45, 0.3 + j * spring / 6.0, 0), Vector3(0.03, 0.03, s.z * 0.8))
	for sz: float in [-1.0, 1.0]:
		k.tube(m, PropParts.arch_pts(s.x * 0.9, spring, sz * s.z * 0.4, 12), 0.04, 5)
	for j in 7:
		var a := PI * j / 6.0
		k.box(m, Vector3(-cos(a) * s.x * 0.45, spring + sin(a) * s.x * 0.45, 0), Vector3(0.03, 0.03, s.z * 0.8))
	# climbing roses along the arch
	var arch := PropParts.arch_pts(s.x * 0.9, spring, -s.z * 0.42, 12)
	k.tube(PropMats.satin(PropMats.LEAF), arch, 0.03, 4)
	for i in 13:
		PropParts.bloom(k, PropMats.satin([EstateKit.ROSE, EstateKit.BLUSH, EstateKit.PEARL][i % 3]), arch[i] + Vector3(0, 0, -0.03), 0.07)
		if i % 2 == 1:
			k.leaf(PropMats.satin(PropMats.LEAF), arch[i], Vector3(0.3, -1, -0.3), 0.15, 0.07)


static func _balustrade(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	k.box(m, Vector3(0, 0.06, 0), Vector3(s.x, 0.12, s.z))
	k.box(m, Vector3(0, s.y - 0.06, 0), Vector3(s.x, 0.12, s.z * 1.1))
	k.box(PropMats.gold(), Vector3(0, s.y - 0.125, -s.z * 0.5), Vector3(s.x, 0.015, 0.01))
	var n := int(s.x / 0.25)
	for i in n:
		var x := -s.x * 0.5 + s.x * (i + 0.5) / n
		k.lathe(m, Vector3(x, 0.12, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.04, 0.08),
				Vector2(0.08, (s.y - 0.24) * 0.35), Vector2(0.04, (s.y - 0.24) * 0.75), Vector2(0.06, s.y - 0.26),
				Vector2(0.0, s.y - 0.24)]), 8)
	for sx: float in [-1.0, 1.0]:
		k.box(m, Vector3(sx * (s.x * 0.5 - 0.1), s.y * 0.5, 0), Vector3(0.2, s.y, s.z))


static func _altar(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	var gold := PropMats.gold()
	k.box(m, Vector3(0, 0.06, 0), Vector3(s.x, 0.12, s.z))
	k.box(m, Vector3(0, s.y * 0.48, 0), Vector3(s.x * 0.9, s.y * 0.75, s.z * 0.8))
	k.box(m, Vector3(0, s.y - 0.06, 0), Vector3(s.x, 0.1, s.z))
	k.box(PropMats.fabric(EstateKit.ROSE), Vector3(0, s.y - 0.005, 0), Vector3(s.x * 0.3, 0.01, s.z * 1.02))
	k.box(PropMats.fabric(EstateKit.ROSE), Vector3(0, s.y * 0.75, -s.z * 0.51), Vector3(s.x * 0.3, s.y * 0.45, 0.01))
	# carved sun-and-blossom medallion, offering bowl and candles
	k.disc(gold, Vector3.ZERO, s.y * 0.2, 16, PropMeshKit.at(Vector3(s.x * 0.28, s.y * 0.5, -s.z * 0.405), 0, -PI * 0.5))
	k.disc(gold, Vector3.ZERO, s.y * 0.2, 16, PropMeshKit.at(Vector3(-s.x * 0.28, s.y * 0.5, -s.z * 0.405), 0, -PI * 0.5))
	k.lathe(gold, Vector3(0, s.y - 0.01, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.04, 0.05),
			Vector2(0.18, 0.12), Vector2(0.17, 0.13), Vector2(0, 0.1)]), 12)
	for i in 6:
		var a := TAU * i / 6.0
		k.sphere(PropMats.satin(EstateKit.BLUSH), Vector3(cos(a) * 0.08, s.y + 0.12, sin(a) * 0.08), Vector3(0.04, 0.015, 0.04), 6, 2)
	for sx: float in [-1.0, 1.0]:
		k.cyl(gold, Vector3(sx * s.x * 0.4, s.y - 0.01, 0), 0.05, 0.025, 0.15, 8)
		PropParts.candle(k, Vector3(sx * s.x * 0.4, s.y + 0.14, 0), 0.25, 0.03)
