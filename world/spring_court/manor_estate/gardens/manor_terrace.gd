## The garden terrace along the north facade: pearl paving, a balustrade with
## urns, tea tables, orange-tree tubs, lavender planters, and wide steps down
## to the rose garden 1.8 m lower (plus narrower steps at each end).
class_name ManorTerraceBuilder
extends RefCounted

const STEP_SETS := [[0.0, 20.0], [-40.0, 6.0], [40.0, 6.0]]   # [centre x, width]
const EDGE_Z := -88.5
const STEPS_BOTTOM_Z := -103.0


static func plant(sb: ManorScatter) -> void:
	var t := ManorSitePlan.TERRACE
	var x := t.position.x + 1.5
	var rng := EstateKit.rng("terrace_plant")
	while x < t.end.x - 1.0:
		if not _in_steps(x, 1.0):
			sb.put(&"ing_lavender", x, EDGE_Z + 1.2, rng.randf() * TAU, 0.8, 0.6)
		x += 1.6


static func _in_steps(x: float, pad: float) -> bool:
	for s in STEP_SETS:
		if absf(x - s[0]) < s[1] * 0.5 + pad:
			return true
	return false


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "Terrace")
	var t := ManorSitePlan.TERRACE
	var c := t.get_center()
	var y := ManorGrounds.ground(c.x, c.y)
	var marble := ManorGrounds.marble()
	b.box(Vector3(c.x, y + 0.03, c.y), Vector3(t.size.x, 0.06, t.size.y), EstateKit.mat(EstateKit.BLUSH, 0.4, 0.0, "terrace_paving"), false)
	# pearl inlay stripes
	for i in 8:
		var x := t.position.x + 6.0 + i * 12.0
		b.box(Vector3(x, y + 0.065, c.y), Vector3(0.3, 0.01, t.size.y), marble, false)
	# retaining wall face under the edge
	b.box(Vector3(c.x, y - 1.15, EDGE_Z - 0.4), Vector3(t.size.x + 2.0, 2.2, 0.8), ManorGrounds.stone(), true)
	# balustrade along the north edge (gaps at the steps) and the two ends
	var x0 := t.position.x + 1.5
	while x0 < t.end.x - 1.0:
		if not _in_steps(x0, 1.2):
			b.prop(&"balustrade", Vector3(x0, ManorGrounds.ground(x0, EDGE_Z) , EDGE_Z), 0.0)
		x0 += 3.0
	for side: float in [t.position.x, t.end.x]:
		var z := t.position.y + 1.5
		while z < t.end.y - 1.0:
			b.prop(&"balustrade", Vector3(side, ManorGrounds.ground(side, z), z), PI * 0.5)
			z += 3.0
	# urns on pedestals at the step heads and corners
	for s in STEP_SETS:
		for side: float in [-1.0, 1.0]:
			var ux: float = s[0] + side * (s[1] * 0.5 + 0.8)
			b.box(Vector3(ux, y + 0.6, EDGE_Z), Vector3(1.0, 1.2, 1.0), marble)
			b.prop(&"garden_urn", Vector3(ux, y + 1.2, EDGE_Z))
	# tea tables, chairs, tubs
	for i in 4:
		var tx := -30.0 + i * 20.0
		if absf(tx) < 4.0:
			continue
		b.prop_on_ground(&"table_round", tx, -80.0)
		for k in 4:
			var a := TAU * k / 4.0
			b.prop_on_ground(&"chair_dining", tx + cos(a) * 1.3, -80.0 + sin(a) * 1.3, -a + PI * 0.5)
	for i in 9:
		var ox := t.position.x + 4.0 + i * 11.0
		b.prop_on_ground(&"orange_tree_tub", ox, -74.5)
	# steps down to the rose garden: visual treads over a smooth ramp collider
	for s in STEP_SETS:
		_steps(b, s[0], s[1])
	b.flush()


static func _steps(b: GroundsBatch, cx: float, width: float) -> void:
	var top := ManorGrounds.ground(cx, EDGE_Z)
	var bottom := ManorGrounds.ground(cx, STEPS_BOTTOM_Z)
	var run := absf(STEPS_BOTTOM_Z - EDGE_Z)
	var n := 9
	var stone := ManorGrounds.marble()
	for i in n:
		var z := EDGE_Z - (i + 0.5) * run / n
		var tread_top := lerpf(top, bottom, float(i + 1) / n)
		var h := tread_top - (bottom - 0.6)
		b.box(Vector3(cx, tread_top - h * 0.5, z), Vector3(width, h, run / n + 0.02), stone, false)
	b.ramp(Vector3(cx, bottom, STEPS_BOTTOM_Z), width, run, top - bottom, PI, null)
	# cheek walls
	for side: float in [-1.0, 1.0]:
		var x: float = cx + side * (width * 0.5 + 0.3)
		var ym := (top + bottom) * 0.5
		b.box(Vector3(x, ym, (EDGE_Z + STEPS_BOTTOM_Z) * 0.5), Vector3(0.6, top - bottom + 1.0, run), ManorGrounds.stone(), true,
				0.0, Basis(Vector3.RIGHT, -atan2(top - bottom, run)))
