## The extra charm pieces that make rooms richer: tiaras, flower crowns, music
## boxes, tea things, macarons, swans, hatboxes, a reading nook, a swing, a
## dollhouse, toys, a spinning wheel, a loom, a telescope and more.
class_name CharmShapes
extends RefCounted



static func build(k: PropMeshKit, id: StringName, s: Vector3, c: Color) -> bool:
	match id:
		&"tiara_display": _tiara(k, s, c)
		&"flower_crown_stand": _flower_crown(k, s, c)
		&"music_box": _music_box(k, s, c)
		&"teacup_set": _teacups(k, s, c)
		&"macaron_tower": _macarons(k, s, c)
		&"petal_bowl": _petal_bowl(k, s, c)
		&"swan_planter": _swan(k, s, c)
		&"heart_cushion": _heart_cushion(k, s, c)
		&"ribbon_spools": _ribbons(k, s, c)
		&"perfume_bottles_tall": _perfumes(k, s, c)
		&"star_lamp": _star_lamp(k, s, c)
		&"canopy_reading_nook": _nook(k, s, c)
		&"chaise_swing": _swing(k, s, c)
		&"bird_feeder": _bird_feeder(k, s, c)
		&"rose_window_panel": _rose_window(k, s, c)
		&"tea_cart": _tea_cart(k, s, c)
		&"jewelry_tree": _jewelry_tree(k, s, c)
		&"parasol_stand": _parasols(k, s, c)
		&"ballgown_display": _ballgown(k, s, c)
		&"hatbox_stack": _hatboxes(k, s, c)
		&"butterfly_dome": _butterflies(k, s, c)
		&"seashell_basin": _shell_basin(k, s, c)
		&"topiary_heart": _topiary_heart(k, s, c)
		&"lily_pond_bridge": _bridge(k, s, c)
		&"picnic_blanket": _picnic(k, s, c)
		&"toy_wooden_horse": _toy_horse(k, s, c)
		&"dumbwaiter": _dumbwaiter(k, s, c)
		&"loose_jar": _loose_jar(k, s, c)
		&"spinning_wheel": _spinning_wheel(k, s, c)
		&"embroidery_frame": _embroidery(k, s, c)
		&"rocking_horse": _rocking_horse(k, s, c)
		&"dollhouse": _dollhouse(k, s, c)
		&"loom_upright": _loom(k, s, c)
		&"telescope_brass": _telescope(k, s, c)
		&"beehive_skep": _skep(k, s, c)
		&"rowing_boat": _boat(k, s, c)
		&"garden_well": _well(k, s, c)
		&"jump_rails": _jump_rails(k, s, c)
		_: return false
	return true


static func _heart_pts(center: Vector3, size: float, steps: int = 16) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in steps + 1:
		var a := TAU * i / steps
		var hx := 16.0 * pow(sin(a), 3.0) / 17.0
		var hy := (13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a)) / 17.0
		pts.append(center + Vector3(hx, hy, 0) * size)
	return pts


static func _tiara(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	k.cyl(PropMats.pearl(EstateKit.BLUSH), Vector3.ZERO, s.x * 0.5, s.x * 0.48, 0.05, 14)
	k.torus(gold, Vector3(0, 0.05, 0), s.x * 0.48, 0.01, 14, 3)
	k.cyl(PropMats.fabric(EstateKit.ROSE), Vector3(0, 0.05, 0), s.x * 0.18, s.x * 0.12, s.y * 0.3, 10)
	k.sphere(PropMats.fabric(EstateKit.ROSE), Vector3(0, 0.05 + s.y * 0.3, 0), Vector3(s.x * 0.2, s.y * 0.12, s.x * 0.2), 10, 5)
	var base_y := 0.05 + s.y * 0.38
	k.torus(gold, Vector3(0, base_y, 0), s.x * 0.2, 0.012, 16, 3)
	for i in 9:
		var a := -PI * 0.5 + (i - 4) * 0.3
		var p := Vector3(cos(a) * s.x * 0.2, base_y, sin(a) * s.x * 0.2)
		var h := (s.y - base_y - 0.03) * (1.0 - absf(i - 4) * 0.18)
		k.tube(gold, PackedVector3Array([p, p + Vector3(0, h, 0)]), 0.006, 3)
		k.sphere(PropMats.crystal() if i % 2 else PropMats.glow(EstateKit.ROSE, 0.6), p + Vector3(0, h, 0), Vector3(0.015, 0.025, 0.015), 5, 3)
	k.tube(PropMats.pearl(), PropParts.ring_pts(Vector3(0, base_y + 0.02, 0), s.x * 0.205, 14), 0.008, 3)


static func _flower_crown(k: PropMeshKit, s: Vector3, c: Color) -> void:
	k.lathe(PropMats.pearl(EstateKit.LILAC), Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.35, 0), Vector2(s.x * 0.12, 0.05),
			Vector2(0.03, s.y * 0.6), Vector2(s.x * 0.18, s.y * 0.7), Vector2(0, s.y * 0.72)]), 10)
	k.sphere(PropMats.pearl(EstateKit.BLUSH), Vector3(0, s.y * 0.75, 0), Vector3(s.x * 0.22, s.y * 0.12, s.x * 0.22), 10, 5)
	var ring := PropParts.ring_pts(Vector3(0, s.y * 0.82, 0), s.x * 0.24, 14)
	k.tube(PropMats.satin(PropMats.LEAF), ring, 0.012, 4)
	var cols := [c, EstateKit.BUTTER, EstateKit.PEARL, EstateKit.LILAC, EstateKit.PERIWINKLE, EstateKit.ROSE, EstateKit.MINT]
	for i in 14:
		PropParts.bloom(k, PropMats.satin(cols[i % cols.size()]), ring[i] + Vector3(0, 0.02, 0), 0.03)
	for i in 3:
		k.box(PropMats.satin([EstateKit.ROSE, EstateKit.LILAC, EstateKit.MINT][i]), Vector3(-0.03 + i * 0.03, s.y * 0.6, s.x * 0.25), Vector3(0.02, s.y * 0.35, 0.004),
				PropMeshKit.at(Vector3.ZERO, 0, 0, (i - 1) * 0.15))


static func _music_box(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.pearl(c)
	var gold := PropMats.gold()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.sphere(gold, Vector3(sx * s.x * 0.42, 0.012, sz * s.z * 0.4), Vector3.ONE * 0.014, 5, 3)
	k.box(body, Vector3(0, s.y * 0.25, 0), Vector3(s.x, s.y * 0.38, s.z))
	k.box(gold, Vector3(0, s.y * 0.44, 0), Vector3(s.x * 1.02, 0.01, s.z * 1.02))
	k.cyl(gold, Vector3(0, s.y * 0.45, 0), s.x * 0.2, s.x * 0.2, 0.01, 12)
	# a twirling ballerina in a pink tutu, and the wind-up key at the side
	k.cyl(PropMats.pearl(EstateKit.BLUSH), Vector3(0, s.y * 0.46, 0), 0.006, 0.006, s.y * 0.15, 4)
	k.lathe(PropMats.fabric(EstateKit.ROSE), Vector3(0, s.y * 0.6, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0.01), Vector2(0.065, 0.02),
			Vector2(0.012, 0.035), Vector2(0, 0.035)]), 10)
	k.cyl(PropMats.pearl(EstateKit.BLUSH), Vector3(0, s.y * 0.6 + 0.03, 0), 0.012, 0.01, s.y * 0.18, 6)
	k.sphere(PropMats.pearl(EstateKit.BLUSH), Vector3(0, s.y * 0.6 + 0.03 + s.y * 0.2, 0), Vector3.ONE * 0.016, 6, 3)
	k.tube(PropMats.pearl(EstateKit.BLUSH), PackedVector3Array([Vector3(-0.04, s.y * 0.92, 0), Vector3(0, s.y * 0.8, 0), Vector3(0.04, s.y * 0.92, 0)]), 0.004, 3)
	k.cyl(gold, Vector3(0, 0, 0), 0.006, 0.006, 0.04, 4, true, PropMeshKit.at(Vector3(s.x * 0.5, s.y * 0.25, 0), 0, 0, -PI * 0.5))
	k.torus(gold, Vector3.ZERO, 0.02, 0.005, 8, 3, PropMeshKit.at(Vector3(s.x * 0.5 + 0.05, s.y * 0.25, 0), 0, 0, PI * 0.5))
	for i in 3:
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(-s.x * 0.3 + i * s.x * 0.3, s.y * 0.25, -s.z * 0.5), 0.018)


static func _cup(k: PropMeshKit, pos: Vector3, col: Color) -> void:
	k.cyl(PropMats.pearl(), pos, 0.07, 0.07, 0.008, 12)
	k.lathe(PropMats.pearl(col), pos + Vector3(0, 0.008, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.025, 0), Vector2(0.04, 0.03),
			Vector2(0.045, 0.055), Vector2(0.04, 0.055), Vector2(0, 0.02)]), 10)
	k.torus(PropMats.gold(), pos + Vector3(0.045, 0.035, 0), 0.014, 0.004, 6, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
	k.torus(PropMats.gold(), pos + Vector3(0, 0.062, 0), 0.044, 0.003, 10, 3)


static func _teacups(k: PropMeshKit, s: Vector3, c: Color) -> void:
	k.box(PropMats.metal(EstateKit.LILAC.lightened(0.3)), Vector3(0, 0.01, 0), Vector3(s.x, 0.02, s.z))
	k.tube(PropMats.gold(), PropParts.ring_pts(Vector3(0, 0.03, 0), 0.5, 16), 0.006, 3, PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(s.x, 1, s.z)))
	k.lathe(PropMats.pearl(c), Vector3(0, 0.02, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.09, 0.06), Vector2(0.07, 0.12),
			Vector2(0.03, 0.14), Vector2(0.025, 0.16), Vector2(0, 0.17)]), 12)
	k.tube(PropMats.pearl(c), PackedVector3Array([Vector3(0.08, 0.08, 0), Vector3(0.13, 0.12, 0), Vector3(0.15, 0.15, 0)]), 0.01, 4)
	k.torus(PropMats.gold(), Vector3(-0.09, 0.1, 0), 0.03, 0.008, 8, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
	k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(0, s.y - 0.01, 0), Vector3.ONE * 0.015, 5, 3)
	var cols := [EstateKit.ROSE, EstateKit.MINT, EstateKit.LILAC, EstateKit.BUTTER]
	for i in 4:
		var x := -s.x * 0.34 + (i % 2) * s.x * 0.68
		var z := -s.z * 0.25 + (i / 2) * s.z * 0.5
		_cup(k, Vector3(x, 0.02, z), cols[i])
	k.lathe(PropMats.pearl(EstateKit.BLUSH), Vector3(0, 0.02, -s.z * 0.35), PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0), Vector2(0.04, 0.05),
			Vector2(0.03, 0.06), Vector2(0, 0.07)]), 8)


static func _macarons(k: PropMeshKit, s: Vector3, c: Color) -> void:
	k.lathe(PropMats.gold(), Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.3, 0), Vector2(s.x * 0.08, 0.04), Vector2(0, 0.05)]), 10)
	var cols := [c, EstateKit.MINT, EstateKit.LILAC, EstateKit.BUTTER, EstateKit.PERIWINKLE, EstateKit.ROSE]
	var levels := 6
	var lh := (s.y - 0.1) / levels
	for l in levels:
		var y := 0.05 + l * lh
		var r := s.x * 0.45 * (1.0 - float(l) / levels * 0.85)
		var n := maxi(3, int(TAU * r / 0.065))
		for i in n:
			var a := TAU * i / n + l * 0.3
			var p := Vector3(cos(a) * r, y, sin(a) * r)
			var col: Color = cols[(i + l) % cols.size()]
			k.sphere(PropMats.satin(col), p + Vector3(0, lh * 0.5, 0), Vector3(0.028, lh * 0.45, 0.028), 6, 3)
			k.cyl(PropMats.pearl(EstateKit.CREAM), p + Vector3(0, lh * 0.42, 0), 0.026, 0.026, lh * 0.16, 6, false)
	PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(0, s.y - 0.04, 0), 0.04)


static func _petal_bowl(k: PropMeshKit, s: Vector3, c: Color) -> void:
	k.lathe(PropMats.glass(Color(0.95, 0.85, 1.0, 0.5)), Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.2, 0),
			Vector2(s.x * 0.45, s.y * 0.6), Vector2(s.x * 0.5, s.y * 0.8), Vector2(s.x * 0.47, s.y * 0.8), Vector2(0, s.y * 0.1)]), 14)
	k.torus(PropMats.gold(), Vector3(0, s.y * 0.8, 0), s.x * 0.485, 0.006, 14, 3)
	k.sphere(PropMats.satin(c), Vector3(0, s.y * 0.45, 0), Vector3(s.x * 0.42, s.y * 0.35, s.x * 0.42), 12, 4, Transform3D.IDENTITY, true)
	var rnd := PropParts.rng(&"petal_bowl")
	for i in 16:
		var a := rnd.randf() * TAU
		var rr := rnd.randf() * s.x * 0.38
		k.disc(PropMats.satin([c, EstateKit.BLUSH, EstateKit.PEARL, EstateKit.LILAC][i % 4]), Vector3(cos(a) * rr, s.y * 0.6 + (s.x * 0.4 - rr) * 0.4, sin(a) * rr),
				0.03, 5, PropMeshKit.at(Vector3.ZERO, a, rnd.randf_range(-0.3, 0.3)))


static func _swan(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	var gold := PropMats.gold()
	# a swan-shaped planter facing -Z: body bowl, S-curved neck, wings raised
	k.sphere(m, Vector3(0, s.y * 0.3, s.z * 0.05), Vector3(s.x * 0.32, s.y * 0.25, s.z * 0.45), 14, 7)
	var neck := PackedVector3Array()
	for i in 9:
		var t := float(i) / 8.0
		neck.append(Vector3(0, s.y * (0.4 + t * 0.5), -s.z * 0.3 - sin(t * PI * 1.2) * s.z * 0.15))
	k.tube(m, neck, 0.07, 7, Transform3D.IDENTITY, 0.045)
	k.sphere(m, neck[8] + Vector3(0, 0.02, -0.03), Vector3(0.06, 0.06, 0.08), 8, 4)
	k.cyl(gold, Vector3(0, 0, 0), 0.025, 0.0, 0.1, 6, true, PropMeshKit.at(neck[8] + Vector3(0, 0.0, -0.08), 0, -PI * 0.5 - 0.3))
	k.torus(gold, neck[2], 0.075, 0.012, 10, 3, PropMeshKit.at(Vector3.ZERO, 0, -0.4))
	for sx: float in [-1.0, 1.0]:
		for f in 4:
			k.leaf(m, Vector3(sx * s.x * 0.28, s.y * 0.4, -s.z * 0.1 + f * 0.08), Vector3(sx * 0.4, 0.6 + f * 0.1, 0.7), s.y * 0.45, 0.14, -0.2)
	# flowers spilling out of the back
	DecorShapes._flower_dome(k, Vector3(0, s.y * 0.48, s.z * 0.12), s.x * 0.26, s.y * 0.3, c, &"swan_planter")


static func _heart_cushion(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var fab := PropMats.fabric(c)
	var outline := _heart_pts(Vector3(0, s.y * 0.5, 0), s.y * 0.48, 20)
	# puffed heart: stacked heart-shaped slices thinning toward the faces
	var layers := [[0.0, 1.0], [-0.35, 0.85], [0.35, 0.85], [-0.45, 0.5], [0.45, 0.5]]
	for l in layers:
		var pts := PackedVector3Array()
		for p in outline:
			pts.append(Vector3(p.x * l[1], s.y * 0.5 + (p.y - s.y * 0.5) * l[1], s.z * float(l[0])))
		k.tube(fab, pts, s.z * (0.4 if l[1] > 0.9 else 0.25), 6)
	k.sphere(fab, Vector3(0, s.y * 0.55, 0), Vector3(s.x * 0.3, s.y * 0.3, s.z * 0.45), 10, 5)
	k.tube(PropMats.gold(), outline, 0.008, 3)
	k.sphere(PropMats.pearl(), Vector3(0, s.y * 0.55, -s.z * 0.45), Vector3.ONE * 0.02, 5, 3)


static func _ribbons(k: PropMeshKit, s: Vector3, c: Color) -> void:
	k.box(PropMats.wood(EstateKit.OAK), Vector3(0, 0.015, 0), Vector3(s.x, 0.03, s.z))
	k.cyl(PropMats.wood(EstateKit.OAK), Vector3(0, -s.x * 0.45, 0), 0.01, 0.01, s.x * 0.9, 5, true, PropMeshKit.at(Vector3(0, s.y * 0.5, 0), 0, 0, PI * 0.5))
	for sx: float in [-1.0, 1.0]:
		k.box(PropMats.wood(EstateKit.OAK), Vector3(sx * s.x * 0.47, s.y * 0.35, 0), Vector3(0.03, s.y * 0.7, s.z * 0.5))
	var cols := [c, EstateKit.ROSE, EstateKit.MINT, EstateKit.BUTTER, EstateKit.LILAC, EstateKit.PEARL]
	for i in 6:
		var x := -s.x * 0.37 + i * s.x * 0.148
		var t := PropMeshKit.at(Vector3(x, s.y * 0.5, 0), 0, 0, PI * 0.5)
		k.cyl(PropMats.satin(cols[i]), Vector3(0, -0.035, 0), s.y * 0.2, s.y * 0.2, 0.07, 12, true, t)
		k.cyl(PropMats.wood(EstateKit.OAK.lightened(0.2)), Vector3(0, -0.04, 0), s.y * 0.23, s.y * 0.23, 0.01, 12, true, t)
		k.box(PropMats.satin(cols[i]), Vector3(x, s.y * 0.25, -s.y * 0.2), Vector3(0.06, s.y * 0.5, 0.004), PropMeshKit.at(Vector3.ZERO, 0, 0.1 * i))


static func _perfumes(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.box(PropMats.mirror(), Vector3(0, 0.006, 0), Vector3(s.x, 0.012, s.z))
	var cols := [Color(c, 0.65), Color(1.0, 0.7, 0.85, 0.65), Color(0.7, 0.95, 0.85, 0.65), Color(1.0, 0.9, 0.6, 0.65)]
	for i in 4:
		var x := -s.x * 0.33 + i * s.x * 0.22
		var h := s.y * (0.6 + 0.4 * float(i == 1) + 0.15 * float(i == 2))
		var r := 0.04 + 0.01 * float(i % 2)
		k.lathe(PropMats.glass(cols[i]), Vector3(x, 0.012, (i % 2) * 0.06 - 0.03), PackedVector2Array([Vector2(0, 0), Vector2(r, 0),
				Vector2(r * 1.2, h * 0.3), Vector2(r * 0.6, h * 0.65), Vector2(r * 0.25, h * 0.72), Vector2(0, h * 0.72)]), 8)
		k.sphere(gold if i % 2 else PropMats.crystal(), Vector3(x, 0.012 + h * 0.84, (i % 2) * 0.06 - 0.03), Vector3(r * 0.6, h * 0.13, r * 0.6), 6, 3)
		if i == 0:
			k.tube(PropMats.satin(EstateKit.ROSE), PackedVector3Array([Vector3(x + r, h * 0.5, -0.03), Vector3(x + r + 0.06, h * 0.3, -0.03)]), 0.004, 3)
			k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(x + r + 0.07, h * 0.28, -0.03), Vector3(0.025, 0.03, 0.025), 6, 3)


static func _star_lamp(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.lathe(PropMats.pearl(EstateKit.PERIWINKLE), Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.3, 0),
			Vector2(s.x * 0.35, s.y * 0.08), Vector2(s.x * 0.1, s.y * 0.15), Vector2(0.02, s.y * 0.3), Vector2(0, s.y * 0.3)]), 12)
	k.cyl(gold, Vector3(0, s.y * 0.3, 0), 0.015, 0.015, s.y * 0.15, 5)
	# a five-point glowing star with a crescent moon behind it
	var star := PackedVector3Array()
	for i in 11:
		var a := PI * 0.5 + TAU * i / 10.0
		var r := s.x * (0.45 if i % 2 == 0 else 0.2)
		star.append(Vector3(cos(a) * r, s.y * 0.68 + sin(a) * r, 0))
	var glow := PropMats.glow(c, 2.5)
	for i in 10:
		k.quad(glow, Vector3(0, s.y * 0.68, -0.03), star[i], star[i + 1], Vector3(0, s.y * 0.68, -0.03), Vector3.FORWARD)
		k.quad(glow, Vector3(0, s.y * 0.68, 0.03), star[i + 1], star[i], Vector3(0, s.y * 0.68, 0.03), Vector3.BACK)
	k.tube(gold, star, 0.008, 3)
	k.torus(PropMats.pearl(EstateKit.LILAC), Vector3.ZERO, s.x * 0.3, 0.025, 14, 4, PropMeshKit.at(Vector3(s.x * 0.1, s.y * 0.7, 0.06), 0, PI * 0.5), PI * 1.2)


static func _nook(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	var fab := PropMats.fabric(c)
	# a curtained alcove daybed: cushioned base, heaps of pillows, a draped crown canopy
	k.box(PropMats.pearl(), Vector3(0, 0.2, 0), Vector3(s.x * 0.95, 0.4, s.z * 0.9))
	PropParts.cushion(k, fab, Vector3(0, 0.48, 0), Vector3(s.x * 0.94, 0.18, s.z * 0.88))
	var cols := [EstateKit.BLUSH, EstateKit.LILAC, EstateKit.BUTTER, EstateKit.PERIWINKLE, EstateKit.ROSE, EstateKit.PEARL]
	for i in 6:
		var x := -s.x * 0.4 + i * s.x * 0.16
		PropParts.cushion(k, PropMats.fabric(cols[i]), Vector3(x, 0.72, s.z * 0.3), Vector3(0.4, 0.38, 0.16), PropMeshKit.at(Vector3.ZERO, (i - 2.5) * 0.08, -0.2))
	k.box(PropMats.pearl(EstateKit.BLUSH), Vector3(0, s.y * 0.4, s.z * 0.46), Vector3(s.x * 0.95, s.y * 0.8, 0.06))
	for sx: float in [-1.0, 1.0]:
		k.box(PropMats.pearl(EstateKit.BLUSH), Vector3(sx * s.x * 0.47, s.y * 0.35, 0.0), Vector3(0.06, s.y * 0.7, s.z * 0.9))
	k.lathe(PropMats.pearl(), Vector3(0, s.y * 0.82, 0), PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.5, 0), Vector2(s.x * 0.45, s.y * 0.06),
			Vector2(s.x * 0.2, s.y * 0.14), Vector2(0, s.y * 0.18)]), 16, PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, s.z / s.x)))
	k.torus(gold, Vector3(0, s.y * 0.82, 0), s.x * 0.49, 0.02, 18, 3, PropMeshKit.at(Vector3.ZERO, 0, 0, 0, Vector3(1, 1, s.z / s.x)))
	k.sphere(gold, Vector3(0, s.y - 0.03, 0), Vector3.ONE * 0.06, 6, 3)
	var sheer := PropMats.glass(Color(0.85, 1.0, 0.92, 0.45))
	for sx: float in [-1.0, 1.0]:
		k.lathe(sheer, Vector3(sx * s.x * 0.44, 0, -s.z * 0.42), PackedVector2Array([Vector2(0, 0.02), Vector2(0.2, 0.02), Vector2(0.16, s.y * 0.35),
				Vector2(0.08, s.y * 0.45), Vector2(0.22, s.y * 0.8), Vector2(0, s.y * 0.82)]), 8)
		k.torus(gold, Vector3(sx * s.x * 0.44, s.y * 0.45, -s.z * 0.42), 0.09, 0.015, 8, 3)
	# a stack of books, a fairy light string and a little shelf
	PropParts.books(k, PropParts.rng(&"nook"), -s.x * 0.45, -s.x * 0.15, s.y * 0.55, s.z * 0.3, 0.12, 0.22)
	k.box(PropMats.pearl(), Vector3(-s.x * 0.3, s.y * 0.55, s.z * 0.37), Vector3(s.x * 0.36, 0.03, 0.14))
	for i in 9:
		var t := float(i) / 8.0
		k.sphere(PropMats.glow([EstateKit.BUTTER, EstateKit.BLUSH, EstateKit.MINT][i % 3], 2.0),
				Vector3(-s.x * 0.45 + t * s.x * 0.9, s.y * 0.78 - sin(t * PI) * 0.15, s.z * 0.42), Vector3.ONE * 0.025, 5, 3)


static func _swing(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl()
	var gold := PropMats.gold()
	# an A-frame with a hanging cushioned loveseat, climbing roses on the frame
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.tube(m, PackedVector3Array([Vector3(sx * s.x * 0.48, 0, sz * s.z * 0.45), Vector3(sx * s.x * 0.46, s.y - 0.06, 0)]), 0.04, 6)
	k.tube(m, PackedVector3Array([Vector3(-s.x * 0.5, s.y - 0.05, 0), Vector3(s.x * 0.5, s.y - 0.05, 0)]), 0.05, 8)
	var seat_y := 0.5
	var sw := s.x * 0.6
	for sx: float in [-1.0, 1.0]:
		k.tube(gold, PackedVector3Array([Vector3(sx * sw * 0.48, s.y - 0.08, 0), Vector3(sx * sw * 0.48, seat_y + 0.6, 0.05)]), 0.01, 3)
	k.box(m, Vector3(0, seat_y, 0), Vector3(sw, 0.06, s.z * 0.4))
	PropParts.cushion(k, PropMats.fabric(c), Vector3(0, seat_y + 0.07, 0), Vector3(sw * 0.96, 0.12, s.z * 0.38))
	k.box(m, Vector3(0, seat_y + 0.35, s.z * 0.18), Vector3(sw, 0.6, 0.04))
	k.tube(m, PropParts.arch_pts(sw, seat_y + 0.62, s.z * 0.18, 10, 0.18), 0.03, 4)
	for sx: float in [-1.0, 1.0]:
		k.tube(m, PackedVector3Array([Vector3(sx * sw * 0.5, seat_y, -s.z * 0.18), Vector3(sx * sw * 0.5, seat_y + 0.3, -s.z * 0.1), Vector3(sx * sw * 0.5, seat_y + 0.3, s.z * 0.18)]), 0.025, 4)
	PropParts.cushion(k, PropMats.fabric(EstateKit.LILAC), Vector3(-sw * 0.25, seat_y + 0.3, s.z * 0.1), Vector3(0.35, 0.3, 0.12))
	PropParts.cushion(k, PropMats.fabric(EstateKit.BUTTER), Vector3(sw * 0.25, seat_y + 0.3, s.z * 0.1), Vector3(0.35, 0.3, 0.12))
	var vine := PackedVector3Array()
	for i in 12:
		var t := float(i) / 11.0
		vine.append(Vector3(-s.x * 0.48 + sin(t * 9.0) * 0.05, t * (s.y - 0.1), -s.z * 0.45 * (1.0 - t)))
	k.tube(PropMats.satin(PropMats.LEAF), vine, 0.018, 4)
	for i in 6:
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if i % 2 else EstateKit.PEARL), vine[i * 2 + 1], 0.07)
	for i in 7:
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if i % 2 else EstateKit.BLUSH), Vector3(-s.x * 0.4 + i * s.x * 0.13, s.y - 0.02, -0.05), 0.07)


static func _bird_feeder(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	k.lathe(m, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.4, 0), Vector2(s.x * 0.2, 0.08), Vector2(0.03, 0.2),
			Vector2(0.03, s.y * 0.6), Vector2(0, s.y * 0.6)]), 8)
	var hb := s.y * 0.6
	k.box(m, Vector3(0, hb + 0.02, 0), Vector3(s.x * 0.8, 0.04, s.z * 0.8))
	k.box(PropMats.pearl(EstateKit.MINT), Vector3(0, hb + 0.17, 0), Vector3(s.x * 0.4, 0.26, s.z * 0.4))
	k.disc(PropMats.satin(PropMats.PLUM), Vector3.ZERO, 0.04, 8, PropMeshKit.at(Vector3(0, hb + 0.18, -s.z * 0.205), 0, -PI * 0.5))
	k.cyl(PropMats.pearl(EstateKit.ROSE), Vector3(0, hb + 0.3, 0), s.x * 0.5, 0.0, s.y * 0.2, 4, true, PropMeshKit.at(Vector3.ZERO, PI * 0.25))
	k.sphere(PropMats.gold(), Vector3(0, s.y - 0.03, 0), Vector3.ONE * 0.03, 6, 3)
	for i in 8:
		var a := TAU * i / 8.0
		k.sphere(PropMats.satin(PropMats.STRAW), Vector3(cos(a) * s.x * 0.3, hb + 0.05, sin(a) * s.z * 0.3), Vector3.ONE * 0.012, 4, 2)
	k.sphere(PropMats.satin(PropMats.SKY), Vector3(s.x * 0.3, hb + 0.08, -s.z * 0.1), Vector3(0.04, 0.035, 0.055), 6, 3)
	k.sphere(PropMats.satin(PropMats.SKY), Vector3(s.x * 0.3, hb + 0.12, -s.z * 0.15), Vector3.ONE * 0.025, 5, 3)
	k.tube(PropMats.satin(PropMats.LEAF), PackedVector3Array([Vector3(0.03, 0.3, 0), Vector3(-0.04, 0.6, 0.03), Vector3(0.03, 0.9, -0.02)]), 0.01, 3)
	PropParts.bloom(k, PropMats.satin(EstateKit.LILAC), Vector3(-0.04, 0.6, 0.03), 0.04)


static func _rose_window(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	var stone := PropMats.pearl()
	var cc := Vector3(0, s.y * 0.5, 0)
	var r := s.x * 0.46
	k.box(stone, cc + Vector3(0, 0, s.z * 0.3), Vector3(s.x, s.y, s.z * 0.3))
	k.torus(stone, cc, r, s.z * 0.35, 28, 4, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
	# stained glass petals around a glowing centre
	var cols := [c, EstateKit.LILAC, EstateKit.BUTTER, EstateKit.MINT, EstateKit.PERIWINKLE, EstateKit.BLUSH]
	for i in 12:
		var a := TAU * i / 12.0
		var p := cc + Vector3(cos(a), sin(a), 0) * r * 0.6
		k.sphere(PropMats.glow(cols[i % 6], 0.9), p, Vector3(r * 0.2, r * 0.2, 0.01), 8, 4, Transform3D.IDENTITY)
		k.tube(gold, PackedVector3Array([cc + Vector3(cos(a), sin(a), 0) * r * 0.18 + Vector3(0, 0, -0.02), cc + Vector3(cos(a), sin(a), 0) * r * 0.95 + Vector3(0, 0, -0.02)]), 0.015, 3)
	k.disc(PropMats.glow(EstateKit.ROSE, 1.2), Vector3.ZERO, r * 0.2, 12, PropMeshKit.at(cc + Vector3(0, 0, -0.012), 0, -PI * 0.5))
	k.torus(gold, Vector3.ZERO, r * 0.2, 0.02, 14, 3, PropMeshKit.at(cc + Vector3(0, 0, -0.02), 0, PI * 0.5))
	k.torus(gold, Vector3.ZERO, r * 0.82, 0.02, 24, 3, PropMeshKit.at(cc + Vector3(0, 0, -0.02), 0, PI * 0.5))


static func _tea_cart(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var body := PropMats.satin(c)
	var gold := PropMats.gold()
	for y: float in [0.2, s.y * 0.72]:
		k.box(body, Vector3(0, y, 0), Vector3(s.x * 0.85, 0.03, s.z))
		k.tube(gold, PropParts.ring_pts(Vector3(0, y + 0.04, 0), 0.5, 4), 0.008, 3, PropMeshKit.at(Vector3.ZERO, PI * 0.25, 0, 0, Vector3(s.x * 1.2, 1, s.z * 1.36)))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.cyl(gold, Vector3(sx * s.x * 0.4, 0.1, sz * s.z * 0.45), 0.015, 0.015, s.y * 0.7, 5)
	for sz: float in [-1.0, 1.0]:
		FurnitureShapes.rolled_z(k, PropMats.pearl(), Vector3(-s.x * 0.4, 0.1, sz * s.z * 0.46), 0.1, 0.03, Vector3.ONE, 12)
	k.tube(gold, PropParts.arch_pts(s.z * 0.9, s.y * 0.72, 0, 8, 0.15), 0.012, 4, PropMeshKit.at(Vector3(s.x * 0.42, 0, 0), PI * 0.5))
	k.sphere(PropMats.pearl(), Vector3(s.x * 0.4, 0.03, 0), Vector3.ONE * 0.03, 5, 3)
	# tea for two up top, a cake below
	_cup(k, Vector3(-s.x * 0.2, s.y * 0.735, -0.1), EstateKit.ROSE)
	_cup(k, Vector3(-s.x * 0.2, s.y * 0.735, 0.1), EstateKit.LILAC)
	k.lathe(PropMats.pearl(EstateKit.BLUSH), Vector3(s.x * 0.12, s.y * 0.735, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0),
			Vector2(0.09, 0.07), Vector2(0.06, 0.13), Vector2(0.02, 0.15), Vector2(0, 0.16)]), 10)
	k.cyl(PropMats.satin(EstateKit.BLUSH), Vector3(0, 0.215, 0), 0.13, 0.13, 0.1, 12)
	k.torus(PropMats.pearl(), Vector3(0, 0.315, 0), 0.12, 0.012, 12, 3)
	PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(0, 0.34, 0), 0.03)


static func _jewelry_tree(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	k.cyl(PropMats.pearl(EstateKit.BLUSH), Vector3.ZERO, s.x * 0.45, s.x * 0.42, 0.04, 14)
	k.tube(gold, PackedVector3Array([Vector3(0, 0.04, 0), Vector3(0.01, s.y * 0.5, 0), Vector3(0, s.y * 0.85, 0)]), 0.012, 5)
	var gems := [EstateKit.ROSE, EstateKit.PERIWINKLE, EstateKit.MINT, EstateKit.LILAC, EstateKit.BUTTER]
	for i in 6:
		var a := TAU * i / 6.0 + i * 0.3
		var y := s.y * (0.35 + 0.1 * float(i % 3))
		var tip := Vector3(cos(a) * s.x * 0.4, y + 0.08, sin(a) * s.x * 0.4)
		k.tube(gold, PackedVector3Array([Vector3(0, y, 0), tip * Vector3(0.5, 1, 0.5), tip]), 0.006, 3)
		k.tube(PropMats.pearl(), PackedVector3Array([tip, tip + Vector3(0.0, -0.06, 0.02), tip + Vector3(0, -0.09, 0)]), 0.004, 3)
		k.sphere(PropMats.glow(gems[i % 5], 0.6), tip + Vector3(0, -0.1, 0), Vector3(0.012, 0.018, 0.012), 5, 3)
	k.sphere(PropMats.crystal(), Vector3(0, s.y * 0.88, 0), Vector3.ONE * 0.025, 6, 3)
	for i in 3:
		k.torus(gold, Vector3(-s.x * 0.2 + i * s.x * 0.15, 0.045, s.x * 0.15), 0.018, 0.004, 8, 3)


static func _parasols(k: PropMeshKit, s: Vector3, c: Color) -> void:
	k.lathe(PropMats.pearl(), Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.3, 0), Vector2(s.x * 0.35, s.y * 0.4),
			Vector2(s.x * 0.32, s.y * 0.4), Vector2(s.x * 0.27, s.y * 0.05), Vector2(0, s.y * 0.05)]), 12)
	k.torus(PropMats.gold(), Vector3(0, s.y * 0.4, 0), s.x * 0.335, 0.008, 12, 3)
	var cols := [c, EstateKit.LILAC, EstateKit.MINT]
	for i in 3:
		var a := TAU * i / 3.0
		var base := Vector3(cos(a) * s.x * 0.12, s.y * 0.05, sin(a) * s.x * 0.12)
		var top := base + Vector3(cos(a) * s.x * 0.12, s.y * 0.92, sin(a) * s.x * 0.12)
		k.tube(PropMats.gold(), PackedVector3Array([base, top]), 0.008, 3)
		# a furled parasol: slim ruffled cone with a bow
		var dir := (top - base).normalized()
		var t := Transform3D(Basis(Quaternion(Vector3.UP, dir)), base + dir * s.y * 0.35)
		k.cyl(PropMats.fabric(cols[i]), Vector3.ZERO, 0.03, 0.07, s.y * 0.5, 8, true, t)
		k.torus(PropMats.fabric(EstateKit.PEARL), Vector3(0, s.y * 0.5, 0), 0.07, 0.012, 8, 3, t)
		k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(0, s.y * 0.15, 0), Vector3(0.04, 0.02, 0.04), 6, 3, t)
		k.torus(PropMats.gold(), top + Vector3(0, 0.0, 0), 0.03, 0.006, 8, 3, PropMeshKit.at(Vector3.ZERO, a, PI * 0.5))


static func _ballgown(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.gold()
	k.cyl(PropMats.pearl(), Vector3.ZERO, s.x * 0.5, s.x * 0.5, 0.12, 20)
	k.torus(gold, Vector3(0, 0.12, 0), s.x * 0.49, 0.015, 20, 3)
	k.torus(gold, Vector3(0, 0.02, 0), s.x * 0.5, 0.015, 20, 3)
	PropParts.gown(k, PropMats.satin(c), gold, Vector3(0, 0.12, 0), s.y - 0.3, s.x * 0.42)
	# tulle overlay, sparkles, sleeves, and a tiara form for the head
	k.lathe(PropMats.glass(Color(1.0, 0.95, 1.0, 0.35)), Vector3(0, 0.14, 0), PackedVector2Array([Vector2(s.x * 0.45, 0), Vector2(s.x * 0.36, s.y * 0.2),
			Vector2(s.x * 0.15, s.y * 0.38), Vector2(s.x * 0.12, s.y * 0.4)]), 16)
	var rnd := PropParts.rng(&"ballgown")
	for i in 16:
		var a := rnd.randf() * TAU
		var y := rnd.randf_range(0.2, s.y * 0.35)
		var rr := lerpf(s.x * 0.42, s.x * 0.15, y / (s.y * 0.4)) + 0.01
		k.sphere(PropMats.glow(EstateKit.PEARL, 1.5), Vector3(cos(a) * rr, y, sin(a) * rr), Vector3.ONE * 0.012, 4, 2)
	for sx: float in [-1.0, 1.0]:
		k.sphere(PropMats.satin(c.lightened(0.15)), Vector3(sx * s.x * 0.12, 0.12 + (s.y - 0.3) * 0.8, 0), Vector3(0.07, 0.06, 0.06), 8, 4)
	var top := 0.12 + (s.y - 0.3) * 0.84
	k.cyl(PropMats.pearl(EstateKit.BLUSH), Vector3(0, top, 0), 0.025, 0.025, 0.08, 6)
	k.sphere(PropMats.pearl(EstateKit.BLUSH), Vector3(0, top + 0.14, 0), Vector3(0.08, 0.1, 0.08), 8, 4)
	k.torus(gold, Vector3(0, top + 0.21, 0), 0.06, 0.008, 10, 3)
	for i in 5:
		var a := -PI * 0.5 + (i - 2) * 0.4
		k.cyl(gold, Vector3(cos(a) * 0.06, top + 0.21, sin(a) * 0.06), 0.008, 0.0, 0.05 - absf(i - 2) * 0.012, 4)


static func _hatboxes(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var cols := [c, EstateKit.BLUSH, EstateKit.MINT, EstateKit.BUTTER]
	var y := 0.0
	var r := s.x * 0.5
	for i in 4:
		var h: float = s.y * [0.3, 0.26, 0.22, 0.18][i] * 0.95
		var off := Vector3(0.03 * float(i % 2) - 0.015, 0, 0.02 * float(i % 2))
		k.cyl(PropMats.satin(cols[i]), off + Vector3(0, y, 0), r * 0.92, r * 0.92, h * 0.85, 14)
		k.cyl(PropMats.satin(cols[i].lightened(0.15)), off + Vector3(0, y + h * 0.8, 0), r, r, h * 0.2, 14)
		k.torus(PropMats.satin(EstateKit.PEARL if i % 2 else EstateKit.ROSE), off + Vector3(0, y + h * 0.5, 0), r * 0.92, 0.008, 14, 3)
		k.box(PropMats.satin(EstateKit.PEARL if i % 2 else EstateKit.ROSE), off + Vector3(0, y + h, 0), Vector3(r * 2.0, 0.006, 0.03))
		y += h
		r *= 0.86
	k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(0, y + 0.02, 0), Vector3(0.08, 0.03, 0.05), 8, 4)


static func _butterflies(k: PropMeshKit, s: Vector3, c: Color) -> void:
	k.cyl(PropMats.wood(EstateKit.OAK_DARK), Vector3.ZERO, s.x * 0.5, s.x * 0.48, 0.06, 16)
	k.torus(PropMats.gold(), Vector3(0, 0.06, 0), s.x * 0.47, 0.008, 16, 3)
	k.lathe(PropMats.glass(), Vector3(0, 0.06, 0), PackedVector2Array([Vector2(s.x * 0.44, 0), Vector2(s.x * 0.44, s.y * 0.6),
			Vector2(s.x * 0.3, s.y * 0.82), Vector2(0, s.y * 0.88)]), 14)
	k.sphere(PropMats.gold(), Vector3(0, s.y - 0.03, 0), Vector3.ONE * 0.03, 6, 3)
	k.sphere(PropMats.satin(PropMats.LEAF), Vector3(0, 0.06, 0), Vector3(s.x * 0.35, 0.06, s.x * 0.35), 10, 3, Transform3D.IDENTITY, true)
	k.tube(PropMats.wood(EstateKit.OAK), PackedVector3Array([Vector3(0, 0.08, 0), Vector3(0.03, s.y * 0.3, 0), Vector3(-0.04, s.y * 0.5, 0.02)]), 0.012, 4)
	var cols := [c, EstateKit.ROSE, EstateKit.PERIWINKLE, EstateKit.BUTTER, EstateKit.LILAC]
	for i in 5:
		var a := TAU * i / 5.0
		var p := Vector3(cos(a) * s.x * 0.22, s.y * (0.3 + 0.1 * float(i % 3)), sin(a) * s.x * 0.22)
		var m := PropMats.glow(cols[i], 0.5)
		for sx: float in [-1.0, 1.0]:
			k.disc(m, Vector3.ZERO, 0.035, 6, PropMeshKit.at(p + Vector3(sx * 0.03, 0.01, 0), a, 0, sx * 0.5), 0.025)
		k.cyl(PropMats.satin(PropMats.PLUM), p - Vector3(0, 0.0, 0), 0.004, 0.004, 0.03, 3, true, PropMeshKit.at(Vector3.ZERO, a, PI * 0.5))
	for i in 4:
		PropParts.bloom(k, PropMats.satin([EstateKit.ROSE, EstateKit.PEARL][i % 2]), Vector3(cos(i * 1.6) * s.x * 0.25, 0.1, sin(i * 1.6) * s.x * 0.25), 0.03)


static func _shell_basin(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	var gold := PropMats.gold()
	k.lathe(m, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.z * 0.3, 0), Vector2(s.z * 0.15, 0.1), Vector2(s.z * 0.1, s.y * 0.6),
			Vector2(s.z * 0.2, s.y * 0.68), Vector2(0, s.y * 0.68)]), 12)
	# a scallop shell basin: ribs fanning out, a pearl in the hinge, water inside
	var ribs := 9
	for i in ribs:
		var a := PI * (i + 0.5) / ribs
		var dir := Vector3(-cos(a), 0, -sin(a))
		var pts := PackedVector3Array()
		for j in 6:
			var t := float(j) / 5.0
			pts.append(Vector3(0, s.y * 0.68, s.z * 0.3) + dir * Vector3(s.x * 0.5, 0, s.z * 0.8) * t + Vector3(0, sin(t * PI * 0.7) * s.y * 0.3, 0))
		k.tube(m, pts, s.x * 0.06, 6, Transform3D.IDENTITY, s.x * 0.075)
	k.disc(PropMats.water(), Vector3(0, s.y * 0.82, -s.z * 0.05), s.x * 0.38, 12, Transform3D.IDENTITY, s.z * 0.42)
	k.sphere(PropMats.pearl(), Vector3(0, s.y * 0.75, s.z * 0.32), Vector3.ONE * 0.06, 8, 4)
	k.tube(gold, PackedVector3Array([Vector3(0, s.y * 0.72, s.z * 0.42), Vector3(0, s.y + 0.0, s.z * 0.4), Vector3(0, s.y * 0.95, s.z * 0.15)]), 0.015, 5)


static func _topiary_heart(k: PropMeshKit, s: Vector3, c: Color) -> void:
	k.lathe(PropMats.pearl(EstateKit.ROSE), Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.z * 0.4, 0), Vector2(s.z * 0.5, s.y * 0.2),
			Vector2(0, s.y * 0.19)]), 12)
	k.cyl(PropMats.wood(EstateKit.OAK), Vector3(0, s.y * 0.19, 0), 0.03, 0.03, s.y * 0.2, 6)
	var hc := Vector3(0, s.y * 0.66, 0)
	var size := s.y * 0.3
	var outline := _heart_pts(hc, size, 18)
	var leaf := PropMats.satin(c)
	for i in 18:
		k.sphere(leaf, outline[i].lerp(hc, 0.25), Vector3(size * 0.32, size * 0.32, s.z * 0.45), 7, 4)
	k.sphere(leaf, hc + Vector3(0, size * 0.1, 0), Vector3(size * 0.6, size * 0.6, s.z * 0.48), 8, 5)
	for i in 6:
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if i % 2 else EstateKit.PEARL), outline[i * 3] + Vector3(0, 0, -s.z * 0.45), 0.05)


static func _bridge(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	var gold := PropMats.gold()
	# an arched footbridge along X with balustrades and lanterns at each end
	var deck := PackedVector3Array()
	var n := 9
	for i in n:
		var t := float(i) / (n - 1)
		deck.append(Vector3(-s.x * 0.5 + t * s.x, 0.12 + sin(t * PI) * (s.y * 0.45), 0))
	for i in n - 1:
		var a := deck[i]
		var b := deck[i + 1]
		var mid := (a + b) * 0.5
		var ang := atan2(b.y - a.y, b.x - a.x)
		k.box(m, mid, Vector3(a.distance_to(b) + 0.02, 0.14, s.z * 0.75), PropMeshKit.at(Vector3.ZERO, 0, 0, ang))
	for sz: float in [-1.0, 1.0]:
		var rail := PackedVector3Array()
		for p in deck:
			rail.append(p + Vector3(0, s.y * 0.38, sz * s.z * 0.4))
		k.tube(m, rail, 0.04, 5)
		k.tube(gold, rail, 0.012, 3, PropMeshKit.at(Vector3(0, 0.05, 0)))
		for i in n:
			k.cyl(m, deck[i] + Vector3(0, 0, sz * s.z * 0.4), 0.03, 0.03, s.y * 0.38, 5)
		for e: int in [0, n - 1]:
			k.sphere(PropMats.glow(EstateKit.BUTTER, 2.0), deck[e] + Vector3(0, s.y * 0.5, sz * s.z * 0.4), Vector3.ONE * 0.07, 6, 4)
		for i in 4:
			PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if i % 2 else EstateKit.BLUSH), rail[i * 2 + 1] + Vector3(0, 0.04, 0), 0.06)
	k.tube(m, PropParts.arch_pts(s.x * 0.7, 0.0, 0.0, 10, s.y * 0.45), 0.08, 5, PropMeshKit.at(Vector3(0, 0, -s.z * 0.38)))
	k.tube(m, PropParts.arch_pts(s.x * 0.7, 0.0, 0.0, 10, s.y * 0.45), 0.08, 5, PropMeshKit.at(Vector3(0, 0, s.z * 0.38)))


static func _picnic(k: PropMeshKit, s: Vector3, c: Color) -> void:
	# a gingham blanket, a lidded basket, a teapot, strawberries and a flower posy
	for i in 6:
		for j in 5:
			var col := c if (i + j) % 2 == 0 else EstateKit.PEARL
			k.box(PropMats.fabric(col), Vector3(-s.x * 0.5 + (i + 0.5) * s.x / 6.0, 0.005, -s.z * 0.5 + (j + 0.5) * s.z / 5.0), Vector3(s.x / 6.0, 0.01, s.z / 5.0))
	var b := Vector3(s.x * 0.25, 0.01, s.z * 0.15)
	k.box(PropMats.fabric(PropMats.STRAW), b + Vector3(0, s.y * 0.35, 0), Vector3(0.45, s.y * 0.7, 0.3))
	k.box(PropMats.fabric(PropMats.STRAW.darkened(0.08)), b + Vector3(0, s.y * 0.72, 0), Vector3(0.47, 0.03, 0.32))
	k.tube(PropMats.fabric(PropMats.STRAW), PropParts.arch_pts(0.35, s.y * 0.72, 0, 6, s.y * 0.25), 0.012, 3, PropMeshKit.at(b))
	k.box(PropMats.fabric(EstateKit.ROSE), b + Vector3(0, s.y * 0.4, -0.152), Vector3(0.12, 0.08, 0.005))
	_cup(k, Vector3(-s.x * 0.15, 0.01, -s.z * 0.1), EstateKit.MINT)
	_cup(k, Vector3(-s.x * 0.3, 0.01, s.z * 0.15), EstateKit.LILAC)
	k.cyl(PropMats.pearl(), Vector3(0, 0.01, -s.z * 0.25), 0.12, 0.12, 0.01, 12)
	for i in 6:
		var a := TAU * i / 6.0
		k.sphere(PropMats.gloss(Color(0.95, 0.22, 0.35)), Vector3(cos(a) * 0.06, 0.04, -s.z * 0.25 + sin(a) * 0.06), Vector3(0.022, 0.028, 0.022), 5, 3)
	for i in 5:
		PropParts.bloom(k, PropMats.satin([EstateKit.BUTTER, EstateKit.PERIWINKLE, EstateKit.PEARL][i % 3]), Vector3(-s.x * 0.35 + i * 0.03, 0.04, -s.z * 0.3 + (i % 2) * 0.03), 0.03)


static func _toy_horse(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	# a painted wooden pull-toy horse on a wheeled board, rose saddle
	k.box(wood, Vector3(0, 0.06, 0), Vector3(s.x * 0.9, 0.03, s.z * 0.6))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.cyl(PropMats.satin(EstateKit.ROSE), Vector3(0, -0.01, 0), 0.04, 0.04, 0.02, 10, true, PropMeshKit.at(Vector3(sx * s.x * 0.35, 0.04, sz * s.z * 0.33), 0, PI * 0.5))
	var by := s.y * 0.5
	k.sphere(wood, Vector3(0, by, 0), Vector3(s.x * 0.3, s.y * 0.13, s.z * 0.25), 10, 5)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.cyl(wood, Vector3(sx * s.x * 0.2, 0.075, sz * s.z * 0.12), 0.02, 0.02, by - 0.08, 5)
	k.tube(wood, PackedVector3Array([Vector3(-s.x * 0.22, by + 0.03, 0), Vector3(-s.x * 0.32, s.y * 0.8, 0)]), 0.045, 6)
	k.sphere(wood, Vector3(-s.x * 0.38, s.y * 0.85, 0), Vector3(0.08, 0.05, 0.045), 8, 4, PropMeshKit.at(Vector3.ZERO, 0, 0, -0.4))
	k.tube(PropMats.satin(EstateKit.CREAM), PackedVector3Array([Vector3(-s.x * 0.24, s.y * 0.9, 0), Vector3(-s.x * 0.15, by + 0.08, 0)]), 0.02, 4)
	k.box(PropMats.satin(EstateKit.ROSE), Vector3(0, by + s.y * 0.12, 0), Vector3(s.x * 0.22, 0.02, s.z * 0.55))
	k.tube(PropMats.satin(EstateKit.CREAM), PackedVector3Array([Vector3(s.x * 0.28, by, 0), Vector3(s.x * 0.38, by - 0.1, 0)]), 0.015, 4)
	k.sphere(PropMats.satin(PropMats.PLUM), Vector3(-s.x * 0.42, s.y * 0.88, -0.03), Vector3.ONE * 0.008, 4, 2)


static func _dumbwaiter(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	k.box(wood, Vector3(0, s.y * 0.5, s.z * 0.05), Vector3(s.x, s.y, s.z * 0.9))
	k.box(PropMats.wood(c.lightened(0.1)), Vector3(0, s.y * 0.97, 0), Vector3(s.x * 1.04, s.y * 0.06, s.z))
	# the serving hatch with a sliding door raised halfway, a tray inside
	k.box(PropMats.satin(PropMats.PLUM), Vector3(0, s.y * 0.6, -s.z * 0.38), Vector3(s.x * 0.7, s.y * 0.4, 0.02))
	k.box(PropMats.wood(c.lightened(0.15)), Vector3(0, s.y * 0.75, -s.z * 0.42), Vector3(s.x * 0.74, s.y * 0.2, 0.02))
	k.box(PropMats.metal(PropMats.COPPER), Vector3(0, s.y * 0.66, -s.z * 0.44), Vector3(0.14, 0.03, 0.03))
	k.box(PropMats.metal(EstateKit.LILAC.lightened(0.3)), Vector3(0, s.y * 0.45, -s.z * 0.25), Vector3(s.x * 0.5, 0.015, s.z * 0.3))
	_cup(k, Vector3(-0.08, s.y * 0.46, -s.z * 0.25), EstateKit.ROSE)
	k.tube(PropMats.metal(PropMats.COPPER), PackedVector3Array([Vector3(s.x * 0.42, s.y * 0.3, -s.z * 0.42), Vector3(s.x * 0.42, s.y * 0.92, -s.z * 0.42)]), 0.01, 4)
	k.sphere(PropMats.metal(PropMats.COPPER), Vector3(s.x * 0.42, s.y * 0.3, -s.z * 0.42), Vector3.ONE * 0.03, 6, 3)
	PropParts.drawers(k, PropMats.wood(c.lightened(0.08)), PropMats.metal(PropMats.COPPER), -s.x * 0.45, s.x * 0.45, 0.05, s.y * 0.35, -s.z * 0.4, 2, 1)


static func _loose_jar(k: PropMeshKit, s: Vector3, c: Color) -> void:
	k.lathe(PropMats.glass(Color(c.r, c.g, c.b, 0.75)), Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.4, 0),
			Vector2(s.x * 0.5, s.y * 0.4), Vector2(s.x * 0.45, s.y * 0.75), Vector2(s.x * 0.32, s.y * 0.82), Vector2(0, s.y * 0.82)]), 10)
	k.cyl(PropMats.gold(), Vector3(0, s.y * 0.8, 0), s.x * 0.36, s.x * 0.36, s.y * 0.08, 10)
	k.sphere(PropMats.gold(), Vector3(0, s.y * 0.93, 0), Vector3(s.x * 0.12, s.y * 0.07, s.x * 0.12), 6, 3)
	k.sphere(PropMats.glow(EstateKit.BUTTER, 1.2), Vector3(0, s.y * 0.35, 0), Vector3.ONE * s.x * 0.18, 6, 4)
	k.box(PropMats.pearl(EstateKit.CREAM), Vector3(0, s.y * 0.45, -s.x * 0.47), Vector3(s.x * 0.4, s.y * 0.15, 0.003))


static func _spinning_wheel(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	# a sloped bench on splayed legs, the big wheel at -X, the spindle and distaff at +X
	var bench := PropMeshKit.at(Vector3(0, s.y * 0.35, 0), 0, 0, 0.12)
	k.box(wood, Vector3.ZERO, Vector3(s.x * 0.85, 0.06, s.z * 0.35), bench)
	for p: Vector3 in [Vector3(-s.x * 0.38, 0, -s.z * 0.4), Vector3(-s.x * 0.38, 0, s.z * 0.4), Vector3(s.x * 0.38, 0, 0)]:
		k.tube(wood, PackedVector3Array([p, Vector3(p.x * 0.85, s.y * 0.35, p.z * 0.3)]), 0.022, 5)
	var wc := Vector3(-s.x * 0.15, s.y * 0.6, 0)
	var wr := s.y * 0.33
	k.torus(wood, Vector3.ZERO, wr, 0.025, 24, 4, PropMeshKit.at(wc, 0, PI * 0.5))
	for i in 10:
		var a := TAU * i / 10.0
		k.tube(wood, PackedVector3Array([wc, wc + Vector3(cos(a) * wr, sin(a) * wr, 0)]), 0.009, 4)
	k.sphere(PropMats.gold(), wc, Vector3.ONE * 0.04, 6, 3)
	for sz: float in [-1.0, 1.0]:
		k.tube(wood, PackedVector3Array([Vector3(-s.x * 0.2, s.y * 0.36, sz * 0.06), wc + Vector3(0, 0, sz * 0.06)]), 0.018, 4)
	k.tube(PropMats.wood(c.lightened(0.2)), PackedVector3Array([Vector3(s.x * 0.25, s.y * 0.42, 0), Vector3(s.x * 0.3, s.y * 0.75, 0)]), 0.015, 4)
	k.sphere(PropMats.fabric(EstateKit.BLUSH), Vector3(s.x * 0.3, s.y * 0.8, 0), Vector3(0.07, 0.12, 0.07), 8, 4)
	k.cyl(PropMats.fabric(EstateKit.ROSE), Vector3(0, -0.06, 0), 0.03, 0.03, 0.12, 8, true, PropMeshKit.at(Vector3(s.x * 0.33, s.y * 0.5, 0), 0, 0, PI * 0.5))
	k.cyl(PropMats.fabric(EstateKit.PEARL), Vector3(0, 0, 0), 0.003, 0.003, wr * 2.0, 3, false, PropMeshKit.at(Vector3(s.x * 0.33, s.y * 0.5, 0), 0, 0, PI * 0.42))
	k.tube(wood, PackedVector3Array([Vector3(-s.x * 0.35, 0.02, 0), Vector3(-s.x * 0.2, 0.06, 0), wc + Vector3(0, -0.05, 0.03)]), 0.008, 3)


static func _embroidery(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	for sx: float in [-1.0, 1.0]:
		k.tube(wood, PackedVector3Array([Vector3(sx * s.x * 0.4, 0, -s.z * 0.4), Vector3(sx * s.x * 0.4, 0.02, s.z * 0.4)]), 0.025, 5)
		k.cyl(wood, Vector3(sx * s.x * 0.4, 0.02, 0), 0.025, 0.02, s.y * 0.7, 6)
	var t := PropMeshKit.at(Vector3(0, s.y * 0.78, 0), 0, -0.9)
	k.push(t)
	k.torus(wood, Vector3.ZERO, s.x * 0.36, 0.03, 24, 4, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
	k.disc(PropMats.fabric(EstateKit.CREAM), Vector3.ZERO, s.x * 0.35, 20, PropMeshKit.at(Vector3(0, 0, -0.005), 0, -PI * 0.5))
	# a half-finished garland of embroidered roses and violets
	for i in 7:
		var a := PI * 0.2 + i * 0.35
		var p := Vector3(cos(a) * s.x * 0.22, sin(a) * s.x * 0.22 - 0.05, -0.008)
		k.disc(PropMats.satin(EstateKit.ROSE if i % 2 == 0 else EstateKit.LILAC), Vector3.ZERO, 0.03, 6, PropMeshKit.at(p, 0, -PI * 0.5))
		k.disc(PropMats.satin(PropMats.LEAF), Vector3.ZERO, 0.018, 5, PropMeshKit.at(p + Vector3(0.03, -0.02, 0), 0, -PI * 0.5))
	k.pop()
	k.tube(wood, PackedVector3Array([Vector3(-s.x * 0.4, s.y * 0.72, 0), Vector3(-s.x * 0.36, s.y * 0.78, 0)]), 0.015, 4)
	k.tube(wood, PackedVector3Array([Vector3(s.x * 0.4, s.y * 0.72, 0), Vector3(s.x * 0.36, s.y * 0.78, 0)]), 0.015, 4)
	# a sewing basket on the floor with thread spools
	k.cyl(PropMats.fabric(PropMats.STRAW), Vector3(s.x * 0.2, 0, -s.z * 0.15), 0.12, 0.14, 0.12, 10)
	for i in 4:
		k.cyl(PropMats.satin([EstateKit.ROSE, EstateKit.MINT, EstateKit.BUTTER, EstateKit.PERIWINKLE][i]), Vector3(s.x * 0.2 + (i % 2) * 0.06 - 0.03, 0.12, -s.z * 0.15 + (i / 2) * 0.06 - 0.03), 0.022, 0.022, 0.04, 6)


static func _rocking_horse(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	var gold := PropMats.gold()
	# curved rockers along X, a dappled pearl horse with a rose saddle and gold mane
	for sz: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for i in 9:
			var t := float(i) / 8.0
			pts.append(Vector3(-s.x * 0.48 + t * s.x * 0.96, 0.03 + (1.0 - sin(t * PI)) * 0.12, sz * s.z * 0.35))
		k.tube(PropMats.wood(EstateKit.OAK), pts, 0.03, 5)
	var by := s.y * 0.55
	k.sphere(m, Vector3(0, by, 0), Vector3(s.x * 0.28, s.y * 0.13, s.z * 0.25), 12, 6)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.tube(m, PackedVector3Array([Vector3(sx * s.x * 0.18, by - 0.05, sz * s.z * 0.12), Vector3(sx * s.x * 0.28, 0.06, sz * s.z * 0.3)]), 0.03, 5, Transform3D.IDENTITY, 0.022)
	var neck := PackedVector3Array([Vector3(-s.x * 0.22, by + 0.05, 0), Vector3(-s.x * 0.3, s.y * 0.8, 0), Vector3(-s.x * 0.33, s.y * 0.88, 0)])
	k.tube(m, neck, 0.06, 7, Transform3D.IDENTITY, 0.045)
	k.sphere(m, Vector3(-s.x * 0.4, s.y * 0.88, 0), Vector3(0.1, 0.06, 0.055), 8, 4, PropMeshKit.at(Vector3.ZERO, 0, 0, -0.5))
	for sz: float in [-1.0, 1.0]:
		k.leaf(m, Vector3(-s.x * 0.32, s.y * 0.95, sz * 0.03), Vector3(0.1, 1, sz * 0.2), 0.06, 0.03, 0.0)
		k.sphere(PropMats.satin(PropMats.PLUM), Vector3(-s.x * 0.42, s.y * 0.9, sz * 0.045), Vector3.ONE * 0.01, 4, 2)
	k.tube(gold, PackedVector3Array([Vector3(-s.x * 0.33, s.y * 0.97, 0), Vector3(-s.x * 0.27, s.y * 0.82, 0), Vector3(-s.x * 0.2, by + 0.12, 0)]), 0.03, 5)
	k.tube(gold, PackedVector3Array([Vector3(s.x * 0.27, by + 0.03, 0), Vector3(s.x * 0.36, by - 0.05, 0), Vector3(s.x * 0.4, by - 0.2, 0)]), 0.035, 5, Transform3D.IDENTITY, 0.01)
	k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(0, by + s.y * 0.11, 0), Vector3(0.14, 0.04, s.z * 0.27), 8, 4, Transform3D.IDENTITY, true)
	k.tube(gold, PackedVector3Array([Vector3(-s.x * 0.06, by + s.y * 0.14, -0.05), Vector3(-s.x * 0.06, by + s.y * 0.2, 0), Vector3(-s.x * 0.06, by + s.y * 0.14, 0.05)]), 0.01, 3)
	for i in 5:
		k.disc(PropMats.satin(EstateKit.LILAC), Vector3.ZERO, 0.03, 6, PropMeshKit.at(Vector3(-s.x * 0.12 + i * 0.07, by + 0.02 * float(i % 2), -s.z * 0.25), 0, -PI * 0.5))


static func _dollhouse(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var walls := PropMats.pearl(c)
	var roof := PropMats.pearl(EstateKit.LILAC)
	var gold := PropMats.gold()
	# a little manor: three storeys open at the back, gabled roof, tiny windows and door
	var body_h := s.y * 0.7
	k.box(walls, Vector3(0, body_h * 0.5, s.z * 0.0), Vector3(s.x * 0.9, body_h, s.z * 0.9))
	k.box(PropMats.pearl(), Vector3(0, 0.03, 0), Vector3(s.x, 0.06, s.z))
	var rh := s.y - body_h
	for sz: float in [-1.0, 1.0]:
		k.box(roof, Vector3(0, body_h + rh * 0.5, sz * s.z * 0.24), Vector3(s.x, 0.04, s.z * 0.62), PropMeshKit.at(Vector3.ZERO, 0, sz * -0.9))
	k.box(walls, Vector3(0, body_h + rh * 0.35, 0), Vector3(s.x * 0.88, rh * 0.6, s.z * 0.3))
	k.cyl(walls, Vector3(s.x * 0.3, body_h, s.z * 0.2), 0.05, 0.05, rh * 0.6, 6)
	for fl in 3:
		var y := 0.06 + fl * body_h * 0.31 + body_h * 0.15
		for i in 4:
			var x := -s.x * 0.33 + i * s.x * 0.22
			if fl == 0 and i == 2:
				k.box(PropMats.satin(EstateKit.ROSE), Vector3(x, 0.06 + body_h * 0.1, -s.z * 0.455), Vector3(0.1, body_h * 0.2, 0.01))
				k.sphere(gold, Vector3(x + 0.03, 0.06 + body_h * 0.1, -s.z * 0.465), Vector3.ONE * 0.008, 4, 2)
				continue
			k.box(PropMats.glow(EstateKit.BUTTER, 0.6), Vector3(x, y, -s.z * 0.455), Vector3(0.09, body_h * 0.14, 0.01))
			k.box(PropMats.pearl(), Vector3(x, y - body_h * 0.08, -s.z * 0.46), Vector3(0.12, 0.015, 0.03))
			k.box(PropMats.satin(EstateKit.MINT), Vector3(x - 0.06, y, -s.z * 0.46), Vector3(0.02, body_h * 0.14, 0.008))
	for fl in 2:
		k.box(gold, Vector3(0, 0.06 + (fl + 1) * body_h * 0.31, -s.z * 0.455), Vector3(s.x * 0.9, 0.015, 0.012))
	for i in 5:
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if i % 2 else EstateKit.BUTTER), Vector3(-s.x * 0.4 + i * s.x * 0.2, 0.08, -s.z * 0.47), 0.03)
	k.sphere(gold, Vector3(0, s.y - 0.02, 0), Vector3.ONE * 0.03, 6, 3)


static func _loom(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var wood := PropMats.wood(c)
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(sx * s.x * 0.46, s.y * 0.5, 0), Vector3(0.08, s.y, 0.1))
		k.box(wood, Vector3(sx * s.x * 0.46, 0.04, 0), Vector3(0.12, 0.08, s.z))
		k.tube(wood, PackedVector3Array([Vector3(sx * s.x * 0.46, 0.08, s.z * 0.45), Vector3(sx * s.x * 0.46, s.y * 0.55, 0.05)]), 0.025, 4)
	for y: float in [s.y * 0.12, s.y * 0.92]:
		k.cyl(wood, Vector3(0, -s.x * 0.46, 0), 0.05, 0.05, s.x * 0.92, 8, true, PropMeshKit.at(Vector3(0, y, 0), 0, 0, PI * 0.5))
	# a half-woven tapestry of stripes and a rose, warp threads above
	var cols := [EstateKit.ROSE, EstateKit.BLUSH, EstateKit.LILAC, EstateKit.MINT, EstateKit.BUTTER, EstateKit.PERIWINKLE]
	var band_h := s.y * 0.06
	for i in 7:
		k.box(PropMats.fabric(cols[i % 6]), Vector3(0, s.y * 0.15 + (i + 0.5) * band_h, -0.02), Vector3(s.x * 0.84, band_h, 0.02))
	PropParts.bloom(k, PropMats.satin(PropMats.BERRY), Vector3(0, s.y * 0.15 + band_h * 3.5, -0.04), 0.1)
	for i in 21:
		var x := -s.x * 0.42 + i * s.x * 0.042
		k.cyl(PropMats.fabric(EstateKit.CREAM), Vector3(x, s.y * 0.15 + band_h * 7, -0.02), 0.003, 0.003, s.y * 0.92 - s.y * 0.15 - band_h * 7, 3, false)
	k.box(wood, Vector3(0, s.y * 0.62, -0.03), Vector3(s.x * 0.86, 0.05, 0.05))
	k.box(PropMats.wood(c.lightened(0.2)), Vector3(s.x * 0.1, s.y * 0.58, -0.08), Vector3(0.3, 0.04, 0.04))
	k.cyl(PropMats.fabric(EstateKit.ROSE), Vector3(0, -0.08, 0), 0.025, 0.025, 0.16, 6, true, PropMeshKit.at(Vector3(s.x * 0.1, s.y * 0.58, -0.08), 0, 0, PI * 0.5))
	# a bench for the weaver
	k.box(wood, Vector3(0, 0.45, -s.z * 0.35), Vector3(s.x * 0.6, 0.05, 0.25))
	PropParts.legs4(k, wood, s.x * 0.6, 0.25, 0.43, 0.02, 2)
	k.push(PropMeshKit.at(Vector3(0, 0, -s.z * 0.35)))
	PropParts.legs4(k, wood, s.x * 0.6, 0.25, 0.43, 0.02, 2)
	k.pop()


static func _telescope(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	for i in 3:
		var a := TAU * i / 3.0 + PI * 0.5
		k.tube(PropMats.wood(EstateKit.OAK_DARK), PackedVector3Array([Vector3(0, s.y * 0.5, 0), Vector3(cos(a) * s.x * 0.2, 0, sin(a) * s.z * 0.45)]), 0.02, 5)
		k.sphere(gold, Vector3(cos(a) * s.x * 0.2, 0.02, sin(a) * s.z * 0.45), Vector3.ONE * 0.025, 5, 3)
	k.sphere(gold, Vector3(0, s.y * 0.52, 0), Vector3.ONE * 0.05, 8, 4)
	# a brass tube pointing up toward the sky (-Z and up), with rings and an eyepiece
	var dir := Vector3(-0.2, 0.75, -0.2).normalized()
	var start := Vector3(0, s.y * 0.52, 0) - dir * s.y * 0.3
	var t := Transform3D(Basis(Quaternion(Vector3.UP, dir)), start)
	k.cyl(gold, Vector3.ZERO, 0.045, 0.06, s.y * 0.55, 12, true, t)
	k.cyl(gold, Vector3(0, s.y * 0.55, 0), 0.075, 0.075, s.y * 0.1, 12, true, t)
	k.disc(PropMats.glass(Color(0.7, 0.85, 1.0, 0.6)), Vector3(0, s.y * 0.651, 0), 0.07, 12, t)
	k.cyl(gold, Vector3(0, -0.1, 0), 0.02, 0.03, 0.1, 8, true, t)
	for y: float in [0.15, 0.35]:
		k.torus(PropMats.satin(PropMats.PLUM), Vector3(0, s.y * y, 0), 0.055, 0.008, 12, 3, t)
	k.torus(PropMats.satin(EstateKit.ROSE), Vector3(0, s.y * 0.25, 0), 0.06, 0.006, 12, 3, t)
	# a star chart rolled at its foot
	k.cyl(PropMats.pearl(EstateKit.CREAM), Vector3(0, -0.15, 0), 0.03, 0.03, 0.3, 8, true, PropMeshKit.at(Vector3(s.x * 0.35, 0.03, -s.z * 0.2), 0.4, 0, PI * 0.5))
	k.torus(PropMats.satin(EstateKit.PERIWINKLE), Vector3.ZERO, 0.032, 0.005, 8, 3, PropMeshKit.at(Vector3(s.x * 0.35, 0.03, -s.z * 0.2), 0.4, 0, PI * 0.5))


static func _skep(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var straw := PropMats.fabric(c)
	# a coiled straw skep on a little pearl stand, bees and a honey drip
	k.cyl(PropMats.pearl(), Vector3.ZERO, s.x * 0.42, s.x * 0.4, s.y * 0.12, 12)
	var base := s.y * 0.12
	var coils := 7
	for i in coils:
		var t := float(i) / coils
		var r := s.x * 0.45 * cos(t * PI * 0.48)
		k.torus(straw, Vector3(0, base + (s.y - base) * (t * 0.92 + 0.05), 0), maxf(r, 0.04), (s.y - base) * 0.075, 14, 4)
	k.lathe(straw, Vector3(0, base, 0), PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.43, 0), Vector2(s.x * 0.4, (s.y - base) * 0.5),
			Vector2(s.x * 0.2, (s.y - base) * 0.88), Vector2(0, s.y - base)]), 12)
	k.disc(PropMats.satin(PropMats.PLUM), Vector3.ZERO, s.x * 0.08, 8, PropMeshKit.at(Vector3(0, base + 0.06, -s.x * 0.43), 0, -PI * 0.5), 0.05)
	k.sphere(PropMats.gloss(Color(1.0, 0.7, 0.2, 1.0)), Vector3(0.08, base + 0.12, -s.x * 0.42), Vector3(0.03, 0.05, 0.02), 5, 3)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var p := Vector3(cos(a) * s.x * 0.5, s.y * (0.4 + 0.12 * float(i % 2)), sin(a) * s.x * 0.5)
		k.sphere(PropMats.satin(EstateKit.BUTTER.darkened(0.1)), p, Vector3(0.025, 0.02, 0.018), 5, 3)
		k.disc(PropMats.glass(Color(1, 1, 1, 0.5)), p + Vector3(0, 0.02, 0), 0.025, 5)
	PropParts.bloom(k, PropMats.satin(EstateKit.LILAC), Vector3(s.x * 0.3, base + 0.02, -s.x * 0.3), 0.05)


static func _boat(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var hull := PropMats.gloss(c)
	var wood := PropMats.wood(EstateKit.OAK)
	# a little rose rowing boat along Z: lathe hull squashed into a boat, seats, oars, a cushion
	var t := PropMeshKit.at(Vector3(0, s.y * 0.05, 0), 0, PI * 0.5, 0, Vector3(s.x / (s.y * 1.6), 1, 1))
	k.lathe(hull, Vector3(0, -s.z * 0.5, 0), PackedVector2Array([Vector2(0, 0), Vector2(s.y * 0.25, s.z * 0.06), Vector2(s.y * 0.65, s.z * 0.3),
			Vector2(s.y * 0.8, s.z * 0.55), Vector2(s.y * 0.6, s.z * 0.88), Vector2(0, s.z)]), 12,
			t * Transform3D(Basis.IDENTITY.scaled(Vector3(1, 1, 0.7)), Vector3.ZERO))
	k.box(PropMats.wood(EstateKit.OAK.lightened(0.25)), Vector3(0, s.y * 0.55, 0), Vector3(s.x * 0.8, 0.02, s.z * 0.7))
	k.box(PropMats.gold(), Vector3(0, s.y * 0.9, 0), Vector3(s.x * 0.95, 0.02, s.z * 0.6))
	for z: float in [-0.18, 0.15]:
		k.box(wood, Vector3(0, s.y * 0.72, z * s.z), Vector3(s.x * 0.82, 0.04, 0.22))
	PropParts.cushion(k, PropMats.fabric(EstateKit.BLUSH), Vector3(0, s.y * 0.78, 0.15 * s.z), Vector3(s.x * 0.6, 0.08, 0.2))
	for sx: float in [-1.0, 1.0]:
		k.tube(wood, PackedVector3Array([Vector3(sx * s.x * 0.3, s.y * 0.8, -s.z * 0.3), Vector3(sx * s.x * 0.42, s.y * 0.85, s.z * 0.25)]), 0.02, 4)
		k.box(wood, Vector3(sx * s.x * 0.43, s.y * 0.85, s.z * 0.32), Vector3(0.1, 0.015, 0.4))
	k.tube(PropMats.satin(EstateKit.PEARL), PackedVector3Array([Vector3(0, s.y * 0.95, -s.z * 0.48), Vector3(0, s.y * 0.6, -s.z * 0.45)]), 0.012, 3)
	for i in 3:
		PropParts.bloom(k, PropMats.satin(EstateKit.PEARL if i % 2 else EstateKit.ROSE), Vector3(-0.08 + i * 0.08, s.y * 0.93, -s.z * 0.4), 0.05)


static func _well(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var stone := PropMats.satin(c)
	var gold := PropMats.gold()
	var r := s.x * 0.36
	# round stone drum, a pearl roof on two posts, a winch with rope and bucket, roses
	k.cyl(stone, Vector3.ZERO, r, r, s.y * 0.26, 16)
	k.torus(PropMats.satin(c.lightened(0.05)), Vector3(0, s.y * 0.26, 0), r * 0.96, r * 0.08, 16, 4)
	for i in 3:
		k.torus(PropMats.satin(c.darkened(0.05)), Vector3(0, s.y * 0.06 + i * s.y * 0.07, 0), r * 1.0, 0.012, 16, 3)
	k.disc(PropMats.water(), Vector3(0, s.y * 0.15, 0), r * 0.85, 14)
	for sx: float in [-1.0, 1.0]:
		k.cyl(PropMats.pearl(), Vector3(sx * r * 0.95, s.y * 0.26, 0), 0.07, 0.06, s.y * 0.5, 8)
	var roof_y := s.y * 0.74
	for sz: float in [-1.0, 1.0]:
		k.box(PropMats.pearl(EstateKit.ROSE), Vector3(0, roof_y + (s.y - roof_y) * 0.45, sz * s.z * 0.24), Vector3(s.x * 0.95, 0.06, s.z * 0.62),
				PropMeshKit.at(Vector3.ZERO, 0, sz * -0.75))
	k.box(PropMats.pearl(), Vector3(0, s.y - 0.06, 0), Vector3(s.x, 0.1, 0.12))
	k.sphere(gold, Vector3(0, s.y - 0.02, 0), Vector3.ONE * 0.06, 6, 3)
	k.cyl(PropMats.wood(EstateKit.OAK), Vector3(0, -r, 0), 0.06, 0.06, r * 2.0, 8, true, PropMeshKit.at(Vector3(0, s.y * 0.62, 0), 0, 0, PI * 0.5))
	k.torus(PropMats.fabric(PropMats.STRAW), Vector3(0, s.y * 0.62, 0), 0.075, 0.02, 10, 3, PropMeshKit.at(Vector3.ZERO, 0, 0, PI * 0.5))
	k.tube(PropMats.metal(PropMats.IRON), PackedVector3Array([Vector3(r * 1.05, s.y * 0.62, 0), Vector3(r * 1.12, s.y * 0.62, 0), Vector3(r * 1.12, s.y * 0.55, -0.1)]), 0.015, 4)
	k.tube(PropMats.fabric(PropMats.STRAW), PackedVector3Array([Vector3(0, s.y * 0.6, 0), Vector3(0, s.y * 0.42, 0)]), 0.008, 3)
	k.lathe(PropMats.wood(EstateKit.OAK), Vector3(0, s.y * 0.32, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.12, 0.14), Vector2(0, 0.12)]), 8)
	k.tube(PropMats.metal(PropMats.IRON), PropParts.arch_pts(0.24, s.y * 0.32 + 0.14, 0, 6, 0.08), 0.006, 3)
	for i in 8:
		var a := TAU * i / 8.0
		k.sphere(PropMats.satin(EstateKit.HEDGE), Vector3(cos(a) * r * 1.05, 0.15, sin(a) * r * 1.05), Vector3(0.18, 0.18, 0.18), 6, 3)
		PropParts.bloom(k, PropMats.satin([EstateKit.ROSE, EstateKit.PEARL, EstateKit.BLUSH][i % 3]), Vector3(cos(a) * r * 1.15, 0.25, sin(a) * r * 1.15), 0.06)


static func _jump_rails(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var pearl := PropMats.pearl()
	# a show jump: two striped wing stands, three striped poles, flower boxes below
	for sx: float in [-1.0, 1.0]:
		var x := sx * s.x * 0.46
		k.box(pearl, Vector3(x, s.y * 0.5, 0), Vector3(0.12, s.y, 0.12))
		k.box(PropMats.satin(c), Vector3(x + sx * 0.08, s.y * 0.4, 0), Vector3(0.06, s.y * 0.8, s.z * 0.9))
		k.sphere(PropMats.gold(), Vector3(x, s.y - 0.02, 0), Vector3.ONE * 0.06, 6, 3)
		for sz: float in [-1.0, 1.0]:
			k.box(pearl, Vector3(x, 0.03, sz * s.z * 0.4), Vector3(0.1, 0.06, s.z * 0.25))
	for i in 3:
		var y := s.y * (0.3 + i * 0.25)
		var n := 6
		for j in n:
			var x0 := -s.x * 0.42 + j * s.x * 0.84 / n
			FurnitureShapes.rolled_x(k, PropMats.satin(c if j % 2 == 0 else EstateKit.PEARL),
					Vector3(x0 + s.x * 0.42 / n, y, 0), 0.045, s.x * 0.84 / n, Vector3.ONE, 8)
	k.box(PropMats.satin(PropMats.LEAF), Vector3(0, 0.08, 0), Vector3(s.x * 0.8, 0.16, s.z * 0.6))
	for i in 9:
		PropParts.bloom(k, PropMats.satin([EstateKit.ROSE, EstateKit.BUTTER, EstateKit.PEARL][i % 3]), Vector3(-s.x * 0.36 + i * s.x * 0.09, 0.18, 0), 0.06)
