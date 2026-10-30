## Chandeliers, candelabra, sconces, lanterns and faelights: gold rings, crystal
## drops and glowing flames. Hanging pieces have their base (bottom) at y = 0.
class_name LightingShapes
extends RefCounted



static func build(k: PropMeshKit, id: StringName, s: Vector3, c: Color) -> bool:
	match id:
		&"chandelier_crystal": _chandelier(k, s, 3, 8)
		&"chandelier_small": _chandelier(k, s, 2, 6)
		&"candelabra": _candelabra(k, s)
		&"candle_sconce": _sconce(k, s)
		&"lantern_hanging": _lantern(k, s)
		&"floor_candlestand": _floor_stand(k, s)
		&"faelight_orb": _faelight(k, s, c)
		&"candle_bank": _candle_bank(k, s)
		_: return false
	return true


static func _chandelier(k: PropMeshKit, s: Vector3, tiers: int, arms: int) -> void:
	var gold := PropMats.gold()
	var cry := PropMats.crystal()
	var r := s.x * 0.5
	var h := s.y
	# central column and a crystal finial ball at the bottom
	k.sphere(cry, Vector3(0, 0.08, 0), Vector3(0.07, 0.08, 0.07), 8, 4)
	k.lathe(gold, Vector3.ZERO, PackedVector2Array([Vector2(0, 0.14), Vector2(0.06, 0.16), Vector2(0.12, h * 0.25),
			Vector2(0.05, h * 0.4), Vector2(0.09, h * 0.55), Vector2(0.03, h * 0.7), Vector2(0.03, h * 0.98), Vector2(0.06, h),
			Vector2(0, h)]), 10)
	k.torus(gold, Vector3(0, h - 0.02, 0), 0.08, 0.02, 10, 4)
	for t in tiers:
		var tr := r * (1.0 - t * 0.3) * 0.92
		var ty := h * (0.28 + t * 0.2)
		k.torus(gold, Vector3(0, ty, 0), tr, 0.022, 24, 5)
		var na := arms - t * 2
		for i in na:
			var a := TAU * (i + 0.5 * t) / na
			var dir := Vector3(cos(a), 0, sin(a))
			k.tube(gold, PackedVector3Array([Vector3(0, ty + 0.1, 0) + dir * 0.08, dir * tr * 0.55 + Vector3(0, ty - 0.06, 0),
					dir * tr + Vector3(0, ty, 0)]), 0.014, 4)
			k.cyl(gold, dir * tr + Vector3(0, ty, 0), 0.045, 0.03, 0.03, 5)
			PropParts.candle(k, dir * tr + Vector3(0, ty + 0.03, 0), 0.12, 0.018)
			# hanging crystal drops beneath each arm
			k.sphere(cry, dir * tr * 0.8 + Vector3(0, ty - 0.12, 0), Vector3(0.02, 0.045, 0.02), 4, 3)
		# swag of crystal beads between the arms
		for i in 10:
			var a := TAU * i / 10.0
			var sag := absf(sin(a * na * 0.5)) * 0.08
			k.sphere(cry, Vector3(cos(a) * tr * 0.98, ty - 0.04 - sag, sin(a) * tr * 0.98), Vector3.ONE * 0.016, 4, 2)
	# rose-gold crown at the top
	for i in 8:
		var a := TAU * i / 8.0
		k.leaf(gold, Vector3(0, h * 0.82, 0), Vector3(cos(a), 0.9, sin(a)), h * 0.16, 0.06, -0.3)


static func _candelabra(k: PropMeshKit, s: Vector3) -> void:
	var gold := PropMats.gold()
	k.lathe(gold, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.3, 0), Vector2(s.x * 0.28, 0.03),
			Vector2(0.03, 0.08), Vector2(0.025, s.y * 0.35), Vector2(0.045, s.y * 0.4), Vector2(0.02, s.y * 0.55),
			Vector2(0.03, s.y * 0.6), Vector2(0, s.y * 0.6)]), 10)
	for sx: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for i in 6:
			var a := PI * i / 5.0
			pts.append(Vector3(sx * (s.x * 0.36) * (1.0 - cos(a)) * 0.5, s.y * 0.42 - sin(a) * 0.05 + i * 0.012, 0))
		k.tube(gold, pts, 0.012, 5)
		var tip := Vector3(sx * s.x * 0.36, s.y * 0.48, 0)
		k.cyl(gold, tip - Vector3(0, 0.02, 0), 0.03, 0.02, 0.03, 8)
		PropParts.candle(k, tip + Vector3(0, 0.01, 0), s.y * 0.3, 0.016)
	k.cyl(gold, Vector3(0, s.y * 0.6, 0), 0.03, 0.02, 0.02, 8)
	PropParts.candle(k, Vector3(0, s.y * 0.62, 0), s.y * 0.3, 0.016, EstateKit.BLUSH)


static func _sconce(k: PropMeshKit, s: Vector3) -> void:
	var gold := PropMats.gold()
	# shield back plate on the wall (+Z) and an S-curved arm forward
	k.sphere(gold, Vector3(0, s.y * 0.4, s.z * 0.4), Vector3(s.x * 0.3, s.y * 0.35, 0.02), 10, 5)
	k.sphere(PropMats.mirror(), Vector3(0, s.y * 0.4, s.z * 0.38), Vector3(s.x * 0.2, s.y * 0.25, 0.012), 10, 4)
	k.tube(gold, PackedVector3Array([Vector3(0, s.y * 0.25, s.z * 0.38), Vector3(0, s.y * 0.18, 0.0),
			Vector3(0, s.y * 0.3, -s.z * 0.3)]), 0.012, 5)
	k.cyl(gold, Vector3(0, s.y * 0.3, -s.z * 0.3), 0.05, 0.03, 0.03, 8)
	PropParts.candle(k, Vector3(0, s.y * 0.33, -s.z * 0.3), s.y * 0.35, 0.016)
	k.sphere(PropMats.crystal(), Vector3(0, s.y * 0.1, -s.z * 0.25), Vector3(0.012, 0.03, 0.012), 4, 2)
	k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(0, s.y * 0.75, s.z * 0.38), Vector3(0.03, 0.03, 0.015), 6, 3)


static func _lantern(k: PropMeshKit, s: Vector3) -> void:
	var gold := PropMats.gold()
	var glass := PropMats.glass(Color(1.0, 0.92, 0.85, 0.35))
	var r := s.x * 0.4
	k.lathe(gold, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0.0), Vector2(r * 0.8, 0.06), Vector2(r, 0.08),
			Vector2(r, 0.1), Vector2(0, 0.1)]), 6)
	k.cyl(glass, Vector3(0, 0.1, 0), r * 0.92, r * 0.92, s.y * 0.45, 6, false)
	for i in 6:
		var a := TAU * i / 6.0
		k.cyl(gold, Vector3(cos(a) * r, 0.1, sin(a) * r), 0.008, 0.008, s.y * 0.45, 4)
	var top := 0.1 + s.y * 0.45
	k.lathe(gold, Vector3(0, top, 0), PackedVector2Array([Vector2(0, 0), Vector2(r * 1.1, 0), Vector2(r * 0.4, s.y * 0.2),
			Vector2(0.03, s.y * 0.25), Vector2(0, s.y * 0.26)]), 6)
	k.torus(gold, Vector3(0, s.y - 0.05, 0), 0.04, 0.01, 8, 3, PropMeshKit.at(Vector3.ZERO, 0, PI * 0.5))
	PropParts.candle(k, Vector3(0, 0.1, 0), s.y * 0.22, 0.03)
	k.sphere(PropMats.glow(EstateKit.BLUSH, 1.0), Vector3(0, 0.1 + s.y * 0.2, 0), Vector3.ONE * r * 0.5, 8, 4)


static func _floor_stand(k: PropMeshKit, s: Vector3) -> void:
	var gold := PropMats.gold()
	for i in 3:
		var a := TAU * i / 3.0
		var dir := Vector3(cos(a), 0, sin(a))
		k.tube(gold, PackedVector3Array([Vector3(0, 0.25, 0), dir * s.x * 0.3 + Vector3(0, 0.1, 0), dir * s.x * 0.48]), 0.015, 5)
		k.sphere(gold, dir * s.x * 0.48 + Vector3(0, 0.02, 0), Vector3.ONE * 0.025, 5, 3)
	k.lathe(gold, Vector3(0, 0.2, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.025, 0.1),
			Vector2(0.02, s.y * 0.5), Vector2(0.04, s.y * 0.55), Vector2(0.018, s.y * 0.6), Vector2(0.018, s.y * 0.72),
			Vector2(s.x * 0.25, s.y * 0.76), Vector2(s.x * 0.25, s.y * 0.77), Vector2(0, s.y * 0.77)]), 10)
	PropParts.candle(k, Vector3(0, 0.2 + s.y * 0.77, 0), s.y * 0.14, 0.035)
	k.tube(PropMats.satin(EstateKit.ROSE), PropParts.ring_pts(Vector3(0, s.y * 0.6, 0), 0.05, 10), 0.015, 4)


static func _faelight(k: PropMeshKit, s: Vector3, c: Color) -> void:
	var r := s.x * 0.5
	k.sphere(PropMats.glow(c, 3.0), Vector3(0, r, 0), Vector3.ONE * r * 0.55, 12, 8)
	k.sphere(PropMats.glass(Color(c.r, c.g, c.b, 0.3)), Vector3(0, r, 0), Vector3.ONE * r * 0.95, 12, 8)
	for i in 3:
		k.torus(PropMats.glow(EstateKit.BLUSH, 1.5), Vector3.ZERO, r * 0.98, 0.006, 20, 3,
				PropMeshKit.at(Vector3(0, r, 0), i * 1.05, 1.1))
	for i in 5:
		var a := TAU * i / 5.0
		k.sphere(PropMats.glow(EstateKit.PEARL, 2.0), Vector3(cos(a) * r * 0.8, r + sin(a * 2.0) * r * 0.5, sin(a) * r * 0.8),
				Vector3.ONE * 0.01, 4, 2)


static func _candle_bank(k: PropMeshKit, s: Vector3) -> void:
	var gold := PropMats.gold()
	# three stepped gilt tiers of votive candles
	for t in 3:
		var y := t * s.y * 0.22
		var d := s.z * (1.0 - t * 0.28)
		k.box(gold, Vector3(0, y + s.y * 0.11, s.z * 0.5 - d * 0.5), Vector3(s.x * (1.0 - t * 0.12), s.y * 0.22, d))
		var n := 7 - t
		for i in n:
			var x := -s.x * 0.42 * (1.0 - t * 0.12) + s.x * 0.84 * (1.0 - t * 0.12) * i / (n - 1.0)
			var wax: Color = [EstateKit.CREAM, EstateKit.BLUSH, EstateKit.LILAC][(i + t) % 3]
			PropParts.candle(k, Vector3(x, y + s.y * 0.22, s.z * 0.5 - d * 0.5), s.y * (0.12 + 0.04 * (i % 3)), 0.03, wax)
	k.sphere(PropMats.satin(EstateKit.ROSE), Vector3(0, s.y * 0.66, s.z * 0.35), Vector3(0.08, 0.06, 0.04), 8, 4)
