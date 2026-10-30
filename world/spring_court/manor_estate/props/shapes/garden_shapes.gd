## Garden and grounds: tiered fountains with water, rose arbors, the gazebo,
## urns, planters, sundials, lamp posts, obelisks, gilt gates and steps.
class_name GardenShapes
extends RefCounted



static func build(k: PropMeshKit, id: StringName, s: Vector3, c: Color) -> bool:
	match id:
		&"planter_box": _planter(k, s, c)
		&"orange_tree_tub": _orange_tub(k, s, c)
		&"fern_pot": _fern_pot(k, s, c)
		&"fountain_small": _fountain(k, s, c, 2)
		&"fountain_grand": _fountain(k, s, c, 3)
		&"garden_bench": _bench(k, s, c)
		&"garden_urn": _garden_urn(k, s, c)
		&"rose_arbor": _arbor(k, s, c)
		&"gazebo": _gazebo(k, s, c)
		&"sundial": _sundial(k, s, c)
		&"birdbath": _birdbath(k, s, c)
		&"lamp_post": _lamp_post(k, s, c)
		&"obelisk": _obelisk(k, s, c)
		&"gate_iron_gilt": _gate(k, s, c)
		&"stone_steps": _steps(k, s, c)
		_: return false
	return true


static func _planter(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var stone := PropMats.pearl(c)
	k.box(stone, Vector3(0, s.y * 0.3, 0), Vector3(s.x, s.y * 0.6, s.z))
	k.box(stone, Vector3(0, s.y * 0.62, 0), Vector3(s.x * 1.04, 0.05, s.z * 1.08))
	k.box(PropMats.gold(), Vector3(0, s.y * 0.3, -s.z * 0.505), Vector3(s.x * 0.8, 0.02, 0.01))
	for sx: float in [-1.0, 1.0]:
		k.sphere(stone, Vector3(sx * s.x * 0.45, 0.05, 0), Vector3(0.1, 0.06, s.z * 0.45), 6, 3)
	k.box(PropMats.satin(PropMats.LEAF), Vector3(0, s.y * 0.66, 0), Vector3(s.x * 0.94, 0.04, s.z * 0.86))
	var cols := [EstateKit.ROSE, EstateKit.BUTTER, EstateKit.LILAC, EstateKit.PEARL, EstateKit.PERIWINKLE, EstateKit.BLUSH]
	var n := int(s.x / 0.18)
	for i in n:
		for row in 2:
			var p := Vector3(-s.x * 0.42 + i * s.x * 0.84 / (n - 1), s.y * 0.68, -s.z * 0.18 + row * s.z * 0.36)
			k.tube(PropMats.satin(PropMats.LEAF), PackedVector3Array([p, p + Vector3(0, s.y * 0.25, 0)]), 0.008, 3)
			PropParts.bloom(k, PropMats.satin(cols[(i + row * 3) % 6]), p + Vector3(0, s.y * 0.27, 0), 0.05)
			if i % 2 == 0:
				k.leaf(PropMats.satin(PropMats.LEAF), p, Vector3(0.4, 0.5, -0.6 + row * 1.2), 0.15, 0.06, 0.5)


static func _orange_tub(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var tub_h := s.y * 0.25
	k.box(PropMats.pearl(), Vector3(0, tub_h * 0.5, 0), Vector3(s.x * 0.6, tub_h, s.z * 0.6))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.sphere(PropMats.gold(), Vector3(sx * s.x * 0.3, tub_h, sz * s.z * 0.3), Vector3.ONE * 0.04, 6, 3)
	k.box(PropMats.satin(EstateKit.MINT), Vector3(0, tub_h * 0.5, -s.z * 0.305), Vector3(s.x * 0.45, tub_h * 0.7, 0.01))
	k.cyl(PropMats.wood(EstateKit.OAK), Vector3(0, tub_h, 0), 0.05, 0.04, s.y * 0.35, 6)
	var crown := Vector3(0, s.y * 0.7, 0)
	k.sphere(PropMats.satin(c), crown, Vector3(s.x * 0.5, s.y * 0.3, s.z * 0.5), 12, 7)
	var rnd := PropParts.rng(&"orange_tree_tub")
	for i in 16:
		var a := rnd.randf() * TAU
		var e := rnd.randf_range(0.3, 2.0)
		var p := Vector3(cos(a) * sin(e) * s.x * 0.5, cos(e) * s.y * 0.3, sin(a) * sin(e) * s.z * 0.5)
		if i % 3 == 0:
			PropParts.bloom(k, PropMats.satin(EstateKit.PEARL), crown + p, 0.035)
		else:
			k.sphere(PropMats.gloss(Color(1.0, 0.62, 0.25)), crown + p, Vector3.ONE * 0.05, 6, 3)


static func _fern_pot(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var ph := s.y * 0.35
	k.lathe(PropMats.pearl(EstateKit.LILAC), Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.22, 0),
			Vector2(s.x * 0.3, ph * 0.8), Vector2(s.x * 0.33, ph), Vector2(0, ph * 0.95)]), 12)
	k.torus(PropMats.gold(), Vector3(0, ph, 0), s.x * 0.32, 0.01, 12, 3)
	for i in 12:
		var a := TAU * i / 12.0
		k.leaf(PropMats.satin(c), Vector3(0, ph, 0), Vector3(cos(a), 1.0 - (i % 3) * 0.35, sin(a)), s.y * 0.75, 0.12, 1.2)


static func _fountain(k: PropMeshKit, s: Vector3, c: Color, tiers: int) -> void:
	var marble := PropMats.pearl(c)
	var gold := PropMats.gold()
	var water := PropMats.water()
	var r := s.x * 0.5
	var h := s.y
	# outer basin: a lathe bowl with a rolled rim and water inside
	var bh := h * (0.18 if tiers == 3 else 0.3)
	k.lathe(marble, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(r * 0.95, 0), Vector2(r, bh * 0.7), Vector2(r, bh),
			Vector2(r * 0.93, bh), Vector2(r * 0.92, bh * 0.3), Vector2(0, bh * 0.3)]), 24 if tiers == 3 else 16)
	k.torus(gold, Vector3(0, bh, 0), r * 0.965, r * 0.02, 24, 3)
	k.disc(water, Vector3(0, bh * 0.8, 0), r * 0.92, 24)
	# stacked tiers of shell bowls with spilling water, a gilt swan on top
	var y := bh * 0.3
	var tr := r * 0.55
	for t in tiers - 1:
		var stem_h := h * (0.22 if tiers == 3 else 0.32) * (1.0 - t * 0.2)
		k.lathe(marble, Vector3(0, y, 0), PackedVector2Array([Vector2(0, 0), Vector2(tr * 0.3, 0), Vector2(tr * 0.12, stem_h * 0.3),
				Vector2(tr * 0.18, stem_h * 0.7), Vector2(tr * 0.12, stem_h), Vector2(0, stem_h)]), 12)
		y += stem_h
		var bowl_h := tr * 0.3
		k.lathe(marble, Vector3(0, y, 0), PackedVector2Array([Vector2(0, 0), Vector2(tr * 0.2, 0), Vector2(tr * 0.85, bowl_h * 0.7),
				Vector2(tr, bowl_h), Vector2(tr * 0.92, bowl_h), Vector2(0, bowl_h * 0.6)]), 18)
		k.torus(gold, Vector3(0, y + bowl_h, 0), tr * 0.96, tr * 0.02, 18, 3)
		k.disc(water, Vector3(0, y + bowl_h * 0.85, 0), tr * 0.9, 18)
		# falling water sheet: an open frustum from rim to the basin below
		k.cyl(PropMats.glass(Color(0.75, 0.92, 1.0, 0.35)), Vector3(0, bh * 0.8 if t == 0 else y - h * 0.15, 0), tr * 1.15, tr, y + bowl_h - (bh * 0.8 if t == 0 else y - h * 0.15), 18, false)
		y += bowl_h
		tr *= 0.55
	# finial: a gilt bud with a little water plume
	k.lathe(gold, Vector3(0, y - 0.02, 0), PackedVector2Array([Vector2(0, 0), Vector2(tr * 0.5, 0), Vector2(tr * 0.6, h * 0.04),
			Vector2(tr * 0.2, h * 0.08), Vector2(0, h * 0.1)]), 10)
	var plume_h := h - (y + h * 0.08)
	if plume_h > 0.05:
		k.cyl(PropMats.glass(Color(0.85, 0.95, 1.0, 0.45)), Vector3(0, y + h * 0.08, 0), r * 0.02, r * 0.08, plume_h, 8)
		k.sphere(PropMats.glass(Color(0.85, 0.95, 1.0, 0.45)), Vector3(0, h - r * 0.06, 0), Vector3(r * 0.12, r * 0.06, r * 0.12), 8, 4)
	# lily pads and blooms in the outer basin, and rose garlands on grand fountains
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var p := Vector3(cos(a) * r * 0.75, bh * 0.82, sin(a) * r * 0.75)
		k.disc(PropMats.satin(PropMats.LEAF), p, r * 0.08, 8)
		PropParts.bloom(k, PropMats.satin(EstateKit.BLUSH), p + Vector3(0, 0.03, 0), r * 0.035)
	if tiers == 3:
		for i in 8:
			var a := TAU * i / 8.0
			k.sphere(gold, Vector3(cos(a) * r, bh + r * 0.02, sin(a) * r), Vector3.ONE * r * 0.035, 6, 3)
			k.tube(PropMats.glass(Color(0.75, 0.92, 1.0, 0.4)), PackedVector3Array([Vector3(cos(a) * r * 0.3, h * 0.35, sin(a) * r * 0.3),
					Vector3(cos(a) * r * 0.55, h * 0.4, sin(a) * r * 0.55), Vector3(cos(a) * r * 0.8, bh * 0.85, sin(a) * r * 0.8)]), r * 0.012, 4)


static func _bench(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.body(c)
	var gold := PropMats.gold()
	var seat_h := s.y * 0.48
	for sx: float in [-1.0, 1.0]:
		# scrolled cast ends
		k.tube(m, PackedVector3Array([Vector3(sx * s.x * 0.45, 0, -s.z * 0.4), Vector3(sx * s.x * 0.46, seat_h * 0.5, -s.z * 0.2),
				Vector3(sx * s.x * 0.45, seat_h, -s.z * 0.3), Vector3(sx * s.x * 0.47, seat_h + 0.15, -s.z * 0.35)]), 0.03, 5)
		k.tube(m, PackedVector3Array([Vector3(sx * s.x * 0.45, 0, s.z * 0.4), Vector3(sx * s.x * 0.45, seat_h, s.z * 0.3), Vector3(sx * s.x * 0.46, s.y, s.z * 0.42)]), 0.03, 5)
		k.torus(gold, Vector3(sx * s.x * 0.47, seat_h + 0.15, -s.z * 0.32), 0.04, 0.012, 8, 3, PropMeshKit.at(Vector3.ZERO, 0, 0, PI * 0.5))
	for i in 4:
		k.box(m, Vector3(0, seat_h, -s.z * 0.3 + i * s.z * 0.18), Vector3(s.x * 0.92, 0.04, s.z * 0.14))
	for i in 9:
		var x := -s.x * 0.4 + i * s.x * 0.1
		k.tube(m, PackedVector3Array([Vector3(x, seat_h + 0.03, s.z * 0.32), Vector3(x, s.y - 0.05, s.z * 0.4)]), 0.012, 4)
	k.tube(m, PackedVector3Array([Vector3(-s.x * 0.46, s.y - 0.04, s.z * 0.41), Vector3(0, s.y, s.z * 0.42), Vector3(s.x * 0.46, s.y - 0.04, s.z * 0.41)]), 0.025, 5)
	PropParts.bloom(k, gold, Vector3(0, s.y - 0.06, s.z * 0.38), 0.05)
	PropParts.cushion(k, PropMats.fabric(EstateKit.ROSE), Vector3(-s.x * 0.15, seat_h + 0.05, 0), Vector3(s.x * 0.3, 0.08, s.z * 0.6))


static func _garden_urn(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	var ped_h := s.y * 0.3
	k.box(m, Vector3(0, ped_h * 0.5, 0), Vector3(s.x * 0.6, ped_h, s.z * 0.6))
	k.box(m, Vector3(0, ped_h, 0), Vector3(s.x * 0.66, 0.04, s.z * 0.66))
	var uh := s.y * 0.42
	var r := s.x * 0.5
	k.lathe(m, Vector3(0, ped_h, 0), PackedVector2Array([Vector2(0, 0), Vector2(r * 0.4, 0), Vector2(r * 0.2, uh * 0.15),
			Vector2(r * 0.6, uh * 0.35), Vector2(r * 0.9, uh * 0.8), Vector2(r, uh), Vector2(r * 0.92, uh), Vector2(0, uh * 0.9)]), 14)
	k.torus(PropMats.gold(), Vector3(0, ped_h + uh * 0.5, 0), r * 0.73, 0.015, 14, 3)
	DecorShapes._flower_dome(k, Vector3(0, ped_h + uh * 0.95, 0), r * 0.9, s.y - ped_h - uh * 0.95, EstateKit.ROSE, &"garden_urn")


static func _arbor(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	var spring := s.y * 0.6
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.cyl(m, Vector3(sx * s.x * 0.45, 0, sz * s.z * 0.42), 0.05, 0.05, spring, 6)
		for j in 5:
			k.tube(m, PackedVector3Array([Vector3(sx * s.x * 0.45, 0.3 + j * spring * 0.18, -s.z * 0.42), Vector3(sx * s.x * 0.45, 0.3 + j * spring * 0.18 + spring * 0.18, s.z * 0.42)]), 0.015, 3)
			k.tube(m, PackedVector3Array([Vector3(sx * s.x * 0.45, 0.3 + j * spring * 0.18, s.z * 0.42), Vector3(sx * s.x * 0.45, 0.3 + j * spring * 0.18 + spring * 0.18, -s.z * 0.42)]), 0.015, 3)
	for sz: float in [-1.0, 1.0]:
		k.tube(m, PropParts.arch_pts(s.x * 0.9, spring, sz * s.z * 0.42, 12, s.y - spring - 0.05), 0.045, 5)
	for j in 9:
		var a := PI * j / 8.0
		var p := Vector3(-cos(a) * s.x * 0.45, spring + sin(a) * (s.y - spring - 0.05), 0)
		k.tube(m, PackedVector3Array([p + Vector3(0, 0, -s.z * 0.45), p + Vector3(0, 0, s.z * 0.45)]), 0.02, 4)
	# lush rose cover: foliage clumps and big blooms over the arch and down the posts
	var rnd := PropParts.rng(&"rose_arbor")
	var cols := [EstateKit.ROSE, EstateKit.BLUSH, EstateKit.PEARL, Color(0.95, 0.3, 0.45)]
	for j in 13:
		var a := PI * j / 12.0
		var p := Vector3(-cos(a) * s.x * 0.45, spring + sin(a) * (s.y - spring - 0.05), rnd.randf_range(-s.z * 0.4, s.z * 0.4))
		k.sphere(PropMats.satin(EstateKit.HEDGE), p, Vector3(0.25, 0.18, 0.3), 5, 3)
		PropParts.bloom(k, PropMats.satin(cols[j % 4]), p + Vector3(0, 0.12, -0.1), 0.09)
		if j % 2 == 0:
			PropParts.bloom(k, PropMats.satin(cols[(j + 1) % 4]), p + Vector3(0.05, -0.05, 0.2), 0.08)
	for sx: float in [-1.0, 1.0]:
		for j in 3:
			var p := Vector3(sx * s.x * 0.45, 0.4 + j * spring * 0.3, rnd.randf_range(-s.z * 0.4, s.z * 0.4))
			k.sphere(PropMats.satin(EstateKit.HEDGE), p, Vector3(0.14, 0.2, 0.2), 6, 3)
			PropParts.bloom(k, PropMats.satin(cols[j % 4]), p + Vector3(-sx * 0.08, 0.05, 0), 0.08)
	PropParts.cushion(k, PropMats.fabric(EstateKit.MINT), Vector3(0, 0.03, 0), Vector3(s.x * 0.7, 0.06, s.z * 0.8))


static func _gazebo(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	var gold := PropMats.gold()
	var r := s.x * 0.48
	var sides := 8
	# stepped octagonal platform, slender columns, balustrade, an onion dome
	k.cyl(m, Vector3.ZERO, r, r, 0.15, sides)
	k.cyl(m, Vector3(0, 0.15, 0), r * 0.94, r * 0.94, 0.15, sides)
	var col_h := s.y * 0.5
	for i in sides:
		var a := TAU * (i + 0.5) / sides
		var p := Vector3(cos(a), 0, sin(a)) * r * 0.86
		k.lathe(m, p + Vector3(0, 0.3, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.12, 0), Vector2(0.08, 0.1), Vector2(0.07, col_h - 0.15),
				Vector2(0.12, col_h - 0.05), Vector2(0.12, col_h), Vector2(0, col_h)]), 6)
		if i != 6:
			var q := Vector3(cos(a + TAU / sides), 0, sin(a + TAU / sides)) * r * 0.86
			k.tube(m, PackedVector3Array([p + Vector3(0, 1.05, 0), q + Vector3(0, 1.05, 0)]), 0.04, 4)
			for b in 3:
				var bp := p.lerp(q, (b + 1) / 4.0)
				k.lathe(m, bp + Vector3(0, 0.3, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.06, 0.3), Vector2(0.03, 0.6),
						Vector2(0.04, 0.73), Vector2(0, 0.73)]), 5)
		# scalloped arch between columns
		var q2 := Vector3(cos(a + TAU / sides), 0, sin(a + TAU / sides)) * r * 0.86
		var mid := (p + q2) * 0.5
		var pts := PackedVector3Array()
		for j in 7:
			var t := float(j) / 6.0
			pts.append(p.lerp(q2, t) + Vector3(0, 0.3 + col_h - 0.1 - sin(t * PI) * 0.35, 0))
		k.tube(gold, pts, 0.02, 4)
		k.sphere(PropMats.satin(EstateKit.ROSE), mid + Vector3(0, 0.3 + col_h - 0.1, 0), Vector3.ONE * 0.08, 6, 3)
	var eave := 0.3 + col_h
	k.cyl(m, Vector3(0, eave, 0), r * 1.0, r * 1.0, 0.15, sides)
	k.torus(gold, Vector3(0, eave, 0), r * 1.0, 0.03, sides, 3)
	k.lathe(PropMats.pearl(EstateKit.BLUSH), Vector3(0, eave + 0.15, 0), PackedVector2Array([Vector2(0, 0), Vector2(r * 1.05, 0),
			Vector2(r * 0.95, (s.y - eave) * 0.2), Vector2(r * 0.7, (s.y - eave) * 0.45), Vector2(r * 0.3, (s.y - eave) * 0.68),
			Vector2(r * 0.08, (s.y - eave) * 0.8), Vector2(0, (s.y - eave) * 0.82)]), sides * 2)
	for i in sides:
		var a := TAU * (i + 0.5) / sides
		var pts := PackedVector3Array()
		for j in 6:
			var t := float(j) / 5.0
			var rr := lerpf(r * 1.05, r * 0.08, t * t)
			pts.append(Vector3(cos(a) * rr * 1.01, eave + 0.15 + t * (s.y - eave) * 0.8 * (0.25 + 0.75 * t) / 1.0, sin(a) * rr * 1.01))
		k.tube(gold, pts, 0.025, 4)
	k.lathe(gold, Vector3(0, s.y - (s.y - eave) * 0.2, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.12, 0.05), Vector2(0.1, 0.2),
			Vector2(0.03, 0.3), Vector2(0.05, 0.5), Vector2(0, (s.y - eave) * 0.2 - 0.15)]), 8)
	k.sphere(gold, Vector3(0, s.y - 0.08, 0), Vector3.ONE * 0.08, 6, 3)
	# inside: a round cushioned bench and a hanging faelight
	k.cyl(m, Vector3(0, 0.3, 0), r * 0.5, r * 0.5, 0.42, 12)
	PropParts.cushion(k, PropMats.fabric(EstateKit.ROSE), Vector3(0, 0.75, 0), Vector3(r * 1.0, 0.1, r * 1.0))
	k.tube(gold, PackedVector3Array([Vector3(0, eave + 0.15, 0), Vector3(0, eave - 0.4, 0)]), 0.01, 3)
	k.sphere(PropMats.glow(EstateKit.BUTTER, 2.0), Vector3(0, eave - 0.5, 0), Vector3.ONE * 0.12, 8, 5)


static func _sundial(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.satin(c)
	var gold := PropMats.gold()
	k.box(m, Vector3(0, 0.06, 0), Vector3(s.x, 0.12, s.z))
	k.lathe(m, Vector3(0, 0.12, 0), PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.3, 0), Vector2(s.x * 0.15, 0.1),
			Vector2(s.x * 0.12, s.y * 0.5), Vector2(s.x * 0.2, s.y * 0.7), Vector2(s.x * 0.12, s.y * 0.8), Vector2(0, s.y * 0.8)]), 10)
	k.cyl(m, Vector3(0, s.y - 0.1, 0), s.x * 0.42, s.x * 0.45, 0.06, 16)
	k.disc(gold, Vector3(0, s.y - 0.039, 0), s.x * 0.38, 16)
	for i in 12:
		var a := TAU * i / 12.0
		k.box(PropMats.satin(PropMats.PLUM), Vector3(cos(a) * s.x * 0.32, s.y - 0.035, sin(a) * s.x * 0.32), Vector3(0.04, 0.004, 0.01),
				PropMeshKit.at(Vector3.ZERO, -a))
	var gn := PackedVector3Array([Vector3(0, s.y - 0.04, -s.x * 0.25), Vector3(0, s.y - 0.04 + 0.04, 0.0), Vector3(0, s.y - 0.04 + 0.04, s.x * 0.15),
			Vector3(0, s.y - 0.04, s.x * 0.15)])
	k.quad(gold, gn[0], gn[1], gn[2], gn[3], Vector3.RIGHT)
	k.quad(gold, gn[0], gn[3], gn[2], gn[1], Vector3.LEFT)
	for i in 4:
		var a := TAU * i / 4.0
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(cos(a) * s.x * 0.15, s.y * 0.6, sin(a) * s.x * 0.15), 0.04)


static func _birdbath(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.satin(c)
	k.lathe(m, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.3, 0), Vector2(s.x * 0.15, 0.1),
			Vector2(s.x * 0.08, s.y * 0.5), Vector2(s.x * 0.12, s.y * 0.75), Vector2(s.x * 0.5, s.y * 0.92), Vector2(s.x * 0.5, s.y),
			Vector2(s.x * 0.44, s.y), Vector2(0, s.y * 0.9)]), 14)
	k.disc(PropMats.water(), Vector3(0, s.y * 0.96, 0), s.x * 0.44, 14)
	# two little bluebirds on the rim and a vine up the stem
	for i in 2:
		var a := 0.6 + i * 2.4
		var p := Vector3(cos(a) * s.x * 0.47, s.y + 0.03, sin(a) * s.x * 0.47)
		k.sphere(PropMats.satin(PropMats.SKY), p, Vector3(0.035, 0.03, 0.05), 6, 3, PropMeshKit.at(Vector3.ZERO, a))
		k.sphere(PropMats.satin(PropMats.SKY), p + Vector3(0, 0.035, 0), Vector3.ONE * 0.02, 5, 3)
	var vine := PackedVector3Array()
	for i in 8:
		var a := i * 0.9
		vine.append(Vector3(cos(a) * s.x * 0.11, 0.1 + i * s.y * 0.09, sin(a) * s.x * 0.11))
	k.tube(PropMats.satin(PropMats.LEAF), vine, 0.01, 3)
	for i in 3:
		PropParts.bloom(k, PropMats.satin(EstateKit.LILAC), vine[i * 2 + 1], 0.03)


static func _lamp_post(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	k.lathe(gold, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.45, 0), Vector2(s.x * 0.4, 0.1),
			Vector2(s.x * 0.15, 0.3), Vector2(s.x * 0.1, 0.5), Vector2(s.x * 0.08, s.y * 0.8), Vector2(s.x * 0.15, s.y * 0.82), Vector2(0, s.y * 0.82)]), 10)
	for sx: float in [-1.0, 1.0]:
		k.tube(gold, PackedVector3Array([Vector3(0, s.y * 0.7, 0), Vector3(sx * s.x * 0.3, s.y * 0.76, 0), Vector3(sx * s.x * 0.2, s.y * 0.82, 0)]), 0.012, 4)
	var lb := s.y * 0.82
	k.cyl(PropMats.glass(Color(1.0, 0.92, 0.85, 0.4)), Vector3(0, lb, 0), s.x * 0.25, s.x * 0.35, s.y * 0.12, 6, false)
	k.sphere(PropMats.glow(EstateKit.BUTTER, 2.5), Vector3(0, lb + s.y * 0.06, 0), Vector3.ONE * s.x * 0.15, 8, 5)
	k.lathe(gold, Vector3(0, lb + s.y * 0.12, 0), PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.45, 0), Vector2(s.x * 0.15, s.y * 0.04),
			Vector2(s.x * 0.05, s.y * 0.055), Vector2(0, s.y * 0.06)]), 6)
	k.torus(PropMats.satin(EstateKit.ROSE), Vector3(0, s.y * 0.35, 0), s.x * 0.12, 0.02, 10, 3)
	for i in 4:
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE if i % 2 else EstateKit.PEARL), Vector3(cos(i * 1.57) * s.x * 0.12, s.y * 0.36, sin(i * 1.57) * s.x * 0.12), 0.035)


static func _obelisk(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.pearl(c)
	var gold := PropMats.gold()
	k.box(m, Vector3(0, 0.2, 0), Vector3(s.x, 0.4, s.z))
	k.box(m, Vector3(0, 0.6, 0), Vector3(s.x * 0.8, 0.4, s.z * 0.8))
	k.cyl(m, Vector3(0, 0.8, 0), s.x * 0.42, s.x * 0.2, s.y - 1.2, 4, true, PropMeshKit.at(Vector3.ZERO, PI * 0.25))
	k.cyl(gold, Vector3(0, s.y - 0.4, 0), s.x * 0.2, 0.0, 0.4, 4, true, PropMeshKit.at(Vector3.ZERO, PI * 0.25))
	for sx: float in [-1.0, 1.0]:
		k.disc(gold, Vector3.ZERO, s.x * 0.25, 12, PropMeshKit.at(Vector3(sx * s.x * 0.0, 0.6, -s.z * 0.405), 0, -PI * 0.5))
	# garland ribbon spiralling down
	var pts := PackedVector3Array()
	for i in 17:
		var t := float(i) / 16.0
		var a := t * TAU * 1.5
		var rr := lerpf(s.x * 0.36, s.x * 0.22, t) * 1.08
		pts.append(Vector3(cos(a) * rr, 1.0 + t * (s.y - 2.0), sin(a) * rr))
	k.tube(PropMats.satin(PropMats.LEAF), pts, 0.03, 4)
	for i in 6:
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), pts[i * 3], 0.07)


static func _gate(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var gold := PropMats.body(c)
	var w := s.x
	for sx: float in [-1.0, 1.0]:
		k.box(PropMats.pearl(), Vector3(sx * (w * 0.5 - 0.12), s.y * 0.45, 0), Vector3(0.24, s.y * 0.9, s.z))
		k.sphere(gold, Vector3(sx * (w * 0.5 - 0.12), s.y * 0.95, 0), Vector3.ONE * 0.1, 8, 4)
	var inner := w - 0.5
	var spring := s.y * 0.68
	var n := 14
	for i in n:
		var x := -inner * 0.5 + inner * (i + 0.5) / n
		var top := spring + sin((float(i) + 0.5) / n * PI) * (s.y * 0.8 - spring) * 1.0
		k.cyl(gold, Vector3(x, 0.08, 0), 0.015, 0.015, top - 0.08, 5)
		k.cyl(gold, Vector3(x, top, 0), 0.03, 0.0, 0.1, 4)
	for y: float in [0.15, s.y * 0.35, spring]:
		k.box(gold, Vector3(0, y, 0), Vector3(inner, 0.04, 0.04))
	k.tube(gold, PropParts.arch_pts(inner, spring, 0, 14, s.y * 0.8 - spring), 0.025, 4)
	# scrollwork hearts and roses at the meeting stiles, a crest at the top
	for sx: float in [-1.0, 1.0]:
		var c2 := Vector3(sx * inner * 0.25, s.y * 0.5, -0.02)
		k.torus(gold, c2 + Vector3(-0.08, 0, 0), 0.09, 0.012, 12, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
		k.torus(gold, c2 + Vector3(0.08, 0, 0), 0.09, 0.012, 12, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
		PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), c2 + Vector3(0, -0.02, -0.03), 0.06)
	k.disc(gold, Vector3.ZERO, 0.18, 12, PropMeshKit.at(Vector3(0, s.y * 0.88, -0.03), 0, -PI * 0.5))
	PropParts.bloom(k, PropMats.satin(EstateKit.ROSE), Vector3(0, s.y * 0.88, -0.07), 0.07)
	k.box(gold, Vector3(0, s.y * 0.45, 0), Vector3(0.05, s.y * 0.9, 0.05))


static func _steps(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var m := PropMats.satin(c)
	var n := 6
	var rise := s.y / n
	var run := s.z / n
	# steps climb toward +Z (lowest step at -Z)
	for i in n:
		var d := s.z - i * run
		k.box(m, Vector3(0, rise * (i + 0.5), s.z * 0.5 - d * 0.5), Vector3(s.x * (1.0 - i * 0.02), rise, d))
		k.box(PropMats.pearl(), Vector3(0, rise * (i + 1) + 0.005, -s.z * 0.5 + i * run + 0.04), Vector3(s.x * (1.0 - i * 0.02) * 0.98, 0.01, 0.08))
	for sx: float in [-1.0, 1.0]:
		var x := sx * s.x * 0.48
		k.box(m, Vector3(x, s.y * 0.45, s.z * 0.1), Vector3(0.2, s.y * 0.9, s.z * 0.8))
		DecorShapes._flower_dome(k, Vector3(x, s.y * 0.9, s.z * 0.25), 0.15, 0.25, EstateKit.ROSE, &"stone_steps")
