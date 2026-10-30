## The rose garden Tamlin's father planted for his mother (lore: spring-manor-grounds).
## Twenty geometric beds of red, white, gold and pink roses round a central
## tiered fountain; gravel walks on a cross axis with a fountain circle; four
## rose arbors; a gazebo at the east end; the canon foxglove alcove bench and
## gnarled crab apple at the west end; a hedge border with a gilt gate north to
## the woods side; lamp posts and benches. Also holds the story anchors of the
## garden scenes and the puca spot.
class_name ManorRoseGarden
extends RefCounted

const CENTER := Vector2(0.0, -152.0)
const FOUNTAIN_R := 5.0
const CIRCLE_R := 14.0
const BED_SIZE := Vector2(18.0, 14.0)
const COLUMNS := [16.0, 40.0, 64.0]
const ROWS := [-115.0, -137.0, -167.0, -189.0]
const COLOURS := [&"red", &"white", &"gold", &"pink"]
const ROSE_STEP := 2.0
const NORTH_GATE := Vector2(0.0, -200.0)
const ARBORS := [[Vector2(0, -112), 0.0], [Vector2(0, -192), 0.0], [Vector2(-28, -152), PI * 0.5], [Vector2(28, -152), PI * 0.5], [Vector2(-40, -105.5), 0.0]]
const GAZEBO := Vector2(70.0, -152.0)
const ALCOVE := Vector2(-77.0, -152.0)
const CRAB_APPLE := Vector2(-66.0, -146.5)


## Beds: [Rect2, colour] (test: >= 8 beds).
static func beds() -> Array:
	var out := []
	var i := 0
	for sx: float in [-1.0, 1.0]:
		for cx in COLUMNS:
			for cz in ROWS:
				var c := Vector2(sx * cx, cz)
				var r := Rect2(c - BED_SIZE * 0.5, BED_SIZE)
				# keep the fountain circle clear
				var nearest := Vector2(clampf(CENTER.x, r.position.x, r.end.x), clampf(CENTER.y, r.position.y, r.end.y))
				if nearest.distance_to(CENTER) < CIRCLE_R + 3.0:
					continue
				out.append([r, COLOURS[i % COLOURS.size()]])
				i += 1
	return out


## Story anchors: name -> [position x/z, yaw]. -Z of the marker faces the scene.
static func story_anchors() -> Dictionary:
	return {
		&"manor_fountain": [CENTER + Vector2(0, CIRCLE_R - 1.5), 0.0],      # south of the fountain, facing it
		&"rose_garden_bush": [Vector2(40.0, -147.0), PI],                   # on the walk, facing a white-rose bed
		&"garden_gate": [NORTH_GATE + Vector2(0, 6.0), 0.0],                # facing the gate to the woods side
		&"attor_hiding_spot": [Vector2(-40.0, -105.5), 0.0],                # under the arbor near the house
	}


static func rose_layer(colour: StringName) -> StringName:
	return &"deco_rose_pink" if colour == &"pink" else StringName("ing_rose_" + String(colour))


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("rose_garden_plant")
	for bed in beds():
		var r: Rect2 = bed[0]
		var layer := rose_layer(bed[1])
		var nx := int(r.size.x / ROSE_STEP)
		var nz := int(r.size.y / ROSE_STEP)
		for ix in nx:
			for iz in nz:
				var x := r.position.x + (ix + 0.5) * r.size.x / nx
				var z := r.position.y + (iz + 0.5) * r.size.y / nz
				if Vector2(x, z).distance_to(r.get_center()) < 1.6:
					continue
				sb.put(layer, x + rng.randf_range(-0.2, 0.2), z + rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(0.85, 1.1))
		sb.put(&"deco_rose_climbing", r.get_center().x, r.get_center().y, 0.0, 0.9)
		# a little peony and forget-me-not edging at the bed corners
		for k in 4:
			var corner := Vector2(r.position.x if k % 2 == 0 else r.end.x, r.position.y if k < 2 else r.end.y)
			sb.put(&"deco_peony", corner.x, corner.y, rng.randf() * TAU, 0.9)
		if rng.randf() < 0.6:
			sb.put(&"ing_rose_maze_dew", r.position.x + rng.randf() * r.size.x, r.position.y + rng.randf() * r.size.y, rng.randf() * TAU)
	# lavender borders along the north-south walk
	var z := -106.0
	while z > -198.0:
		if absf(z - CENTER.y) > CIRCLE_R + 1.0:
			for side: float in [-1.0, 1.0]:
				sb.put(&"ing_lavender", side * 3.0, z, rng.randf() * TAU, 0.8)
		z -= 1.5
	# irises and dew round the fountain
	for i in 24:
		var a := TAU * i / 24.0
		sb.put(&"ing_iris", CENTER.x + cos(a) * (FOUNTAIN_R + 2.0), CENTER.y + sin(a) * (FOUNTAIN_R + 2.0), a, 0.9)
		if i % 2 == 0:
			sb.put(&"ing_rose_maze_dew", CENTER.x + cos(a + 0.1) * (FOUNTAIN_R + 0.9), CENTER.y + sin(a + 0.1) * (FOUNTAIN_R + 0.9), a)
	# climbing roses and wisteria on the arbors
	for arbor in ARBORS:
		var p: Vector2 = arbor[0]
		var along := Vector2(cos(arbor[1]), -sin(arbor[1]))
		for side: float in [-1.0, 1.0]:
			var q: Vector2 = p + along * side * 1.6
			sb.put(&"deco_rose_climbing", q.x, q.y, rng.randf() * TAU, 0.85)
		sb.put(&"ing_wisteria", p.x + along.x * 2.2, p.y + along.y * 2.2, rng.randf() * TAU, 0.8)
	# the canon alcove: a bench blooming with foxglove, and the gnarled crab apple
	for i in 12:
		var a := PI * 0.5 + PI * i / 11.0
		sb.put(&"ing_foxglove", ALCOVE.x + cos(a) * 3.2 + 1.0, ALCOVE.y + sin(a) * 3.2, rng.randf() * TAU)
	sb.put(&"deco_apple_blossom", CRAB_APPLE.x, CRAB_APPLE.y, 0.7, 0.9)
	for i in 10:
		sb.put(&"ing_crab_apple", CRAB_APPLE.x + rng.randf_range(-4, 4), CRAB_APPLE.y + rng.randf_range(-4, 4), rng.randf() * TAU)
	# tulips and peonies inside the hedge border
	z = -108.0
	while z > -196.0:
		for x: float in [-77.0, 77.0]:
			if absf(z - CENTER.y) > 5.0:
				sb.put(&"deco_tulip_bed" if int(z) % 3 == 0 else &"deco_peony", x, z, rng.randf() * TAU)
		z -= 3.0
	# wisteria and lilac on the gazebo
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		sb.put(&"ing_wisteria", GAZEBO.x + cos(a) * 3.2, GAZEBO.y + sin(a) * 3.2, a, 0.8)


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "RoseGarden")
	var curb := ManorGrounds.marble()
	var soil := ManorGrounds.soil()
	var g := ManorSitePlan.ROSE_GARDEN
	# beds: pearl curbs round dark soil
	for bed in beds():
		var r: Rect2 = bed[0]
		var c := r.get_center()
		var y := ManorGrounds.ground(c.x, c.y)
		b.box(Vector3(c.x, y + 0.06, c.y), Vector3(r.size.x - 0.3, 0.14, r.size.y - 0.3), soil, false)
		for k in 4:
			var horizontal := k < 2
			var off := (r.size.y * 0.5 if horizontal else r.size.x * 0.5) * (1.0 if k % 2 == 0 else -1.0)
			var pos := Vector3(c.x, y + 0.15, c.y + off) if horizontal else Vector3(c.x + off, y + 0.15, c.y)
			var size := Vector3(r.size.x + 0.3, 0.3, 0.3) if horizontal else Vector3(0.3, 0.3, r.size.y + 0.3)
			b.box(pos, size, curb, false)
	_paths(b)
	_fountain(b)
	# arbors, gazebo, alcove bench
	for arbor in ARBORS:
		var p: Vector2 = arbor[0]
		b.prop_on_ground(&"rose_arbor", p.x, p.y, arbor[1])
	b.prop_on_ground(&"gazebo", GAZEBO.x, GAZEBO.y, PI * 0.5)
	b.prop_on_ground(&"garden_bench", ALCOVE.x, ALCOVE.y, -PI * 0.5)
	b.prop_on_ground(&"sundial", -52.0, -152.0)
	b.prop_on_ground(&"birdbath", 52.0, -152.0)
	# benches facing the fountain, lamp posts on the walks
	for i in 8:
		var a := TAU * i / 8.0 + TAU / 16.0
		var p := CENTER + Vector2(cos(a), sin(a)) * (CIRCLE_R + 2.6)
		b.prop_on_ground(&"garden_bench", p.x, p.y, -a - PI * 0.5)
	for z: float in [-108.0, -124.0, -140.0, -164.0, -180.0, -196.0]:
		ManorGrounds.lamp(b, -2.8, z)
		ManorGrounds.lamp(b, 2.8, z)
	for x: float in [-60.0, -44.0, 44.0, 60.0, 76.0]:
		ManorGrounds.lamp(b, x, CENTER.y - 2.8)
	# hedge border (west, east, north) with gaps at the walks and the north gate
	_hedge(b, Vector2(g.position.x, -104.0), Vector2(g.position.x, g.position.y))
	_hedge(b, Vector2(g.end.x, -104.0), Vector2(g.end.x, CENTER.y + 2.5))
	_hedge(b, Vector2(g.end.x, CENTER.y - 2.5), Vector2(g.end.x, g.position.y))
	_hedge(b, Vector2(g.position.x, g.position.y), Vector2(NORTH_GATE.x - 3.0, g.position.y))
	_hedge(b, Vector2(NORTH_GATE.x + 3.0, g.position.y), Vector2(g.end.x, g.position.y))
	_north_gate(b)
	# topiary cones at the walk crossings
	for p: Vector2 in [Vector2(-5, -126), Vector2(5, -126), Vector2(-5, -178), Vector2(5, -178)]:
		b.prop_on_ground(&"obelisk", p.x, p.y, 0.0, 0.5)
	b.flush()
	_markers(parent)


static func _paths(b: GroundsBatch) -> void:
	var gr := ManorGrounds.gravel()
	var g := ManorSitePlan.ROSE_GARDEN
	b.drape_path(PackedVector2Array([Vector2(0, -103), Vector2(0, CENTER.y + CIRCLE_R)]), 4.0, gr)
	b.drape_path(PackedVector2Array([Vector2(0, CENTER.y - CIRCLE_R), Vector2(0, g.position.y + 0.5)]), 4.0, gr)
	b.drape_path(PackedVector2Array([Vector2(ALCOVE.x + 1.5, CENTER.y), Vector2(-CIRCLE_R, CENTER.y)]), 4.0, gr)
	b.drape_path(PackedVector2Array([Vector2(CIRCLE_R, CENTER.y), Vector2(g.end.x - 0.5, CENTER.y)]), 4.0, gr)
	var ring := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		ring.append(CENTER + Vector2(cos(a), sin(a)) * CIRCLE_R)
	b.drape_path(ring, 3.2, gr)
	# walks between the beds
	for x: float in [-52.0, -28.0, 28.0, 52.0]:
		b.drape_path(PackedVector2Array([Vector2(x, -104.0), Vector2(x, g.position.y + 1.0)]), 3.0, gr)
	for z: float in [-126.0, -178.0, -105.0, -197.5]:
		b.drape_path(PackedVector2Array([Vector2(g.position.x + 1.0, z), Vector2(g.end.x - 1.0, z)]), 3.0, gr)


static func _fountain(b: GroundsBatch) -> void:
	var y := ManorGrounds.ground(CENTER.x, CENTER.y)
	var base := Vector3(CENTER.x, y, CENTER.y)
	var marble := ManorGrounds.marble()
	var gold := ManorGrounds.gold()
	b.cylinder(base, FOUNTAIN_R, 0.7, marble, true, 24)
	b.disc(base + Vector3.UP * 0.72, Vector2.ONE * (FOUNTAIN_R - 0.35), ManorGrounds.water(), 32)
	b.torus(base + Vector3.UP * 0.72, FOUNTAIN_R - 0.3, FOUNTAIN_R + 0.05, gold)
	b.cylinder(base, 0.9, 2.0, marble, true, 12, 0.6)
	b.cylinder(base + Vector3.UP * 2.0, 0.5, 0.2, marble, false, 16, 2.2)
	b.cylinder(base + Vector3.UP * 2.2, 2.2, 0.3, marble, false, 20)
	b.disc(base + Vector3.UP * 2.52, Vector2.ONE * 2.0, ManorGrounds.water(), 24)
	b.prop(&"statue_maiden", base + Vector3.UP * 2.5, PI)


static func _hedge(b: GroundsBatch, a: Vector2, c: Vector2) -> void:
	var n := maxi(1, ceili(a.distance_to(c) / 8.0))
	for k in n:
		var p0 := a.lerp(c, float(k) / n)
		var p1 := a.lerp(c, float(k + 1) / n)
		var m := (p0 + p1) * 0.5
		var y := ManorGrounds.ground(m.x, m.y)
		var horizontal := absf(c.x - a.x) > absf(c.y - a.y)
		var len := p0.distance_to(p1) + 0.2
		b.box(Vector3(m.x, y + 0.6, m.y), Vector3(len, 1.8, 1.4) if horizontal else Vector3(1.4, 1.8, len), ManorGrounds.hedge())


static func _north_gate(b: GroundsBatch) -> void:
	var y := ManorGrounds.ground(NORTH_GATE.x, NORTH_GATE.y)
	for side: float in [-1.0, 1.0]:
		var x: float = NORTH_GATE.x + side * 3.0
		b.box(Vector3(x, y + 1.5, NORTH_GATE.y), Vector3(0.9, 3.0, 0.9), ManorGrounds.stone())
		b.sphere(Vector3(x, y + 3.3, NORTH_GATE.y), 0.35, ManorGrounds.gold())
		# gate leaf swung open against the hedge
		b.prop(&"gate_iron_gilt", Vector3(x + side * 1.0, y, NORTH_GATE.y - 1.0), side * PI * 0.5, 0.5)
	b.box(Vector3(NORTH_GATE.x, y + 3.6, NORTH_GATE.y), Vector3(6.9, 0.3, 0.4), ManorGrounds.iron_gold(), false)


static func _markers(parent: Node3D) -> void:
	var anchors := story_anchors()
	for id: StringName in anchors:
		var m := Marker3D.new()
		m.name = String(id)
		var p: Vector2 = anchors[id][0]
		m.position = Vector3(p.x, ManorGrounds.ground(p.x, p.y), p.y)
		m.rotation.y = anchors[id][1]
		m.add_to_group(&"story_anchor")
		parent.add_child(m)
	var puca := Marker3D.new()
	puca.name = "puca_garden_spot"
	var q := ManorSitePlan.PUCA_GARDEN_SPOT
	puca.position = Vector3(q.x, ManorGrounds.ground(q.x, q.y), q.y)
	puca.add_to_group(&"creature_spot")
	puca.set_meta(&"creature_id", &"cre_puca")
	puca.set_meta(&"active", "night")
	parent.add_child(puca)
