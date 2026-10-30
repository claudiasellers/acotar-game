## The belvedere folly on its hill (estate landmark: a domed open temple seen
## from all over the estate), the walk up to it, and the parkland features:
## the archery butts on the south lawns (canon: Feyre practises archery on the
## grounds), skep hives in the east meadow, a deer hay-rack in the deer park
## and picnic benches in the wildflower meadows.
class_name ManorBelvedere
extends RefCounted

const PODIUM_R := 9.0
const COL_R := 7.0
const COL_H := 7.0
const DOME_R := 7.6
const ARCHERY := Vector2(-140.0, 130.0)
const SKEPS := [Vector2(380.0, -150.0), Vector2(384.0, -151.0), Vector2(388.0, -149.5)]
const HAY_RACK := Vector2(-60.0, -330.0)
const PICNIC := [Vector2(300.0, -90.0), Vector2(-430.0, -200.0), Vector2(60.0, -280.0), Vector2(420.0, 160.0), Vector2(-420.0, 160.0)]
const PATH := [Vector2(140.0, -204.0), Vector2(205.0, -262.0), Vector2(300.0, -330.0), Vector2(372.0, -384.0), Vector2(400.0 - PODIUM_R, -400.0)]


static func footprints() -> Array[Rect2]:
	var out: Array[Rect2] = [ManorGrounds.circle_rect(ManorSitePlan.BELVEDERE_HILL, PODIUM_R + 1.5),
			Rect2(ARCHERY.x - 4.0, ARCHERY.y - 26.0, 22.0, 30.0), ManorGrounds.circle_rect(HAY_RACK, 3.0)]
	for s in SKEPS:
		out.append(ManorGrounds.circle_rect(s, 1.2))
	return out


static func top() -> Vector3:
	var c := ManorSitePlan.BELVEDERE_HILL
	return Vector3(c.x, ManorGrounds.ground(c.x, c.y) + 1.2 + COL_H + 1.0 + DOME_R + 3.0, c.y)


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("belvedere_plant")
	var c := ManorSitePlan.BELVEDERE_HILL
	for i in 10:
		var a := TAU * i / 10.0 + 0.3
		sb.put(&"ing_wisteria" if i % 2 == 0 else &"ing_lilac", c.x + cos(a) * (PODIUM_R + 2.0), c.y + sin(a) * (PODIUM_R + 2.0), a, 0.8)
	for s in SKEPS:
		sb.put(&"ing_honey", s.x, s.y + 1.2, rng.randf() * TAU)
	sb.put(&"col_mask_feather", c.x + 2.0, c.y - 1.0, 0.0)
	# feathers and keepsakes left at the butts
	for i in 3:
		sb.put(&"ing_hawk_feather", ARCHERY.x + 6.0 + i * 3.0, ARCHERY.y - 8.0 - rng.randf() * 6.0, rng.randf() * TAU)
	# wildflower borders along the belvedere walk
	for i in PATH.size() - 1:
		var a: Vector2 = PATH[i]
		var b: Vector2 = PATH[i + 1]
		var n := int(a.distance_to(b) / 9.0)
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n) + side * (2.8 if k % 2 == 0 else -2.8)
			sb.put([&"ing_crocus", &"deco_forget_me_not", &"ing_buttercup", &"deco_daisy"][k % 4], p.x, p.y, rng.randf() * TAU)


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "Belvedere")
	var c := ManorSitePlan.BELVEDERE_HILL
	var y := ManorGrounds.ground(c.x, c.y)
	var base := Vector3(c.x, y, c.y)
	var marble := ManorGrounds.marble()
	var gold := ManorGrounds.gold()
	# stepped podium (sunk into the hillside)
	for i in 3:
		b.cylinder(base + Vector3.UP * (-1.0 + i * 0.4), PODIUM_R - i * 0.6, 1.4 - i * 0.4 + 0.4 * i, marble, true, 32)
	var floor_y := y + 1.2
	b.cylinder(Vector3(c.x, floor_y - 0.05, c.y), PODIUM_R - 1.25, 0.06, EstateKit.mat(EstateKit.BLUSH, 0.3, 0.0, "belvedere_floor"), false, 32)
	# ring of columns with gilt capitals
	for i in 10:
		var a := TAU * i / 10.0
		var p := Vector3(c.x + cos(a) * COL_R, floor_y, c.y + sin(a) * COL_R)
		b.cylinder(p, 0.45, 0.4, marble, false, 12, 0.55)
		b.cylinder(p, 0.36, COL_H, marble, true, 12, 0.32)
		b.cylinder(p + Vector3.UP * (COL_H - 0.4), 0.34, 0.4, gold, false, 12, 0.5)
	var ent := Vector3(c.x, floor_y + COL_H, c.y)
	b.cylinder(ent, COL_R + 0.7, 1.0, marble, false, 32)
	b.torus(ent + Vector3.UP * 1.0, COL_R + 0.5, COL_R + 0.8, gold)
	b.sphere(ent + Vector3.UP * 1.0, DOME_R, EstateKit.pearl(EstateKit.BLUSH, "belvedere_dome"), -1.0, true, 32)
	for i in 8:
		var a := TAU * i / 8.0
		b.torus(ent + Vector3.UP * 1.0, DOME_R - 0.05, DOME_R + 0.12, gold, Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5))
	var dome_top := ent + Vector3.UP * (1.0 + DOME_R)
	for i in 6:
		var a := TAU * i / 6.0
		b.cylinder(dome_top + Vector3(cos(a), 0, sin(a)) * 1.0 - Vector3.UP * 0.2, 0.12, 1.8, marble, false, 8)
	b.cylinder(dome_top + Vector3.UP * 1.6, 1.3, 0.3, marble, false, 16)
	b.cone(dome_top + Vector3.UP * 1.9, 1.2, 1.2, gold, 12)
	b.sphere(dome_top + Vector3.UP * 3.3, 0.35, gold)
	# inside: a statue on a plinth, benches looking out, a faelight lantern
	b.prop(&"statue_stag", Vector3(c.x, floor_y, c.y))
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		b.prop(&"garden_bench", Vector3(c.x + cos(a) * 4.8, floor_y, c.y + sin(a) * 4.8), -a + PI * 0.5)
	b.prop(&"chandelier_small", ent - Vector3.UP * 1.2)
	b.ramp(Vector3(c.x - PODIUM_R - 2.4, ManorGrounds.ground(c.x - PODIUM_R - 2.4, c.y), c.y), 3.0, 3.8,
			floor_y - ManorGrounds.ground(c.x - PODIUM_R - 2.4, c.y), -PI * 0.5, marble)
	var walk := PackedVector2Array()
	for p in PATH:
		walk.append(p)
	walk[walk.size() - 1] = Vector2(c.x - PODIUM_R - 2.4, c.y)
	b.drape_path(walk, 3.0, ManorGrounds.gravel(), 0.05, 3.0)
	for i in range(1, PATH.size() - 1):
		var p: Vector2 = PATH[i]
		ManorGrounds.lamp(b, p.x + 2.5, p.y)
	_archery(b)
	_parkland(b)
	b.flush()
	var lm := Node3D.new()
	lm.name = "BelvedereTop"
	lm.position = top()
	b.root.add_child(lm)
	ManorGrounds.landmark(lm, "belvedere")


static func _archery(b: GroundsBatch) -> void:
	# four straw targets in a row facing north, the shooting line 22 m south
	for i in 4:
		var x := ARCHERY.x + i * 4.5
		b.prop_on_ground(&"target_straw", x, ARCHERY.y - 22.0, PI)
	b.prop_on_ground(&"quiver_barrel", ARCHERY.x - 2.0, ARCHERY.y)
	b.prop_on_ground(&"bow_rack", ARCHERY.x + 16.0, ARCHERY.y + 1.0)
	b.prop_on_ground(&"garden_bench", ARCHERY.x + 7.0, ARCHERY.y + 2.5, PI)
	var ribbon := EstateKit.mat(EstateKit.ROSE, 0.5, 0.0, "archery_line")
	var y := ManorGrounds.ground(ARCHERY.x + 7.0, ARCHERY.y)
	b.box(Vector3(ARCHERY.x + 7.0, y + 0.03, ARCHERY.y - 1.0), Vector3(18.0, 0.04, 0.2), ribbon, false)


static func _parkland(b: GroundsBatch) -> void:
	for s in SKEPS:
		var y := ManorGrounds.ground(s.x, s.y)
		b.box(Vector3(s.x, y + 0.3, s.y), Vector3(0.7, 0.6, 0.7), ManorGrounds.wood())
		b.sphere(Vector3(s.x, y + 0.95, s.y), 0.42, EstateKit.mat(Color(1.0, 0.86, 0.5), 0.8, 0.0, "skep"), 0.85)
	var hy := ManorGrounds.ground(HAY_RACK.x, HAY_RACK.y)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(HAY_RACK.x + side * 1.5, hy + 0.9, HAY_RACK.y), Vector3(0.2, 1.8, 0.2), ManorGrounds.wood())
	b.gable(Vector3(HAY_RACK.x, hy + 1.8, HAY_RACK.y), Vector3(3.6, 0.8, 1.6), ManorGrounds.rose_roof())
	b.prop_on_ground(&"hay_pile", HAY_RACK.x, HAY_RACK.y + 0.2, 0.0, 0.7)
	for p in PICNIC:
		b.prop_on_ground(&"garden_bench", p.x, p.y, 0.4)
		b.prop_on_ground(&"basket_produce", p.x + 1.4, p.y + 0.4)
