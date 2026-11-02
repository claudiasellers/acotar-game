## The reflecting pool beyond the rose garden's north gate, with a cherry allée
## down both sides, daisy meadows beyond the trees and a Temple of Love closing
## the vista.
##
## Canon: [C] a pool beyond the garden that mirrors the sky (ch18).
## [X] invented: its form as a long raised canal, the cherry allée, the
## meadows and the Temple of Love. Not book material.
##
## The canal is level while the ground is not, so it sits in a raised stone
## basin: the coping stands ~1 m proud where the ground dips and ~0.3 m where it
## rises.
class_name ManorReflectingPool
extends RefCounted

const AXIS_X := 0.0
const SOUTH_Z := -236.0
const NORTH_Z := -320.0
const HALF_W := 6.0
const COPING := 0.6
const TEMPLE := Vector2(0.0, -334.0)
const TEMPLE_R := 5.4
const ALLEE_X := 13.5
const ALLEE_STEP := 9.5
const SIDE_WALK_X := 8.6
const SIDE_WALK_W := 3.4
const MEADOWS := [Rect2(18.0, -322.0, 26.0, 84.0), Rect2(-44.0, -322.0, 26.0, 84.0)]


static func length() -> float:
	return SOUTH_Z - NORTH_Z


static func basin() -> Rect2:
	return Rect2(AXIS_X - HALF_W, NORTH_Z, HALF_W * 2.0, length())


## Keep scatter (the deer park's oaks, forage) out of the canal, walks and allée.
static func footprints() -> Array[Rect2]:
	return [Rect2(AXIS_X - ALLEE_X - 2.0, NORTH_Z - 22.0, (ALLEE_X + 2.0) * 2.0, length() + 22.0 + 36.0)]


## The water level: just above the highest ground inside the basin.
static func water_y() -> float:
	var top := -INF
	var r := basin()
	for i in 9:
		for j in 29:
			var x := r.position.x + r.size.x * i / 8.0
			var z := r.position.y + r.size.y * j / 28.0
			top = maxf(top, WorldHeight.height_at(x, z))
	return top + 0.12


static func _low_y() -> float:
	var low := INF
	var r := basin().grow(COPING)
	for i in 9:
		for j in 29:
			low = minf(low, WorldHeight.height_at(r.position.x + r.size.x * i / 8.0, r.position.y + r.size.y * j / 28.0))
	return low


## Walks: the path graph from the rose garden's north gate to the temple.
static func walks() -> Array:
	var g := ManorRoseGarden.NORTH_GATE
	return [
		[PackedVector2Array([g + Vector2(0.0, -1.0), Vector2(AXIS_X, SOUTH_Z + 4.0)]), 5.0],
		[PackedVector2Array([Vector2(-SIDE_WALK_X - 2.0, SOUTH_Z + 2.5), Vector2(SIDE_WALK_X + 2.0, SOUTH_Z + 2.5)]), 4.0],
		[PackedVector2Array([Vector2(-SIDE_WALK_X, SOUTH_Z + 2.5), Vector2(-SIDE_WALK_X, NORTH_Z - 2.5)]), SIDE_WALK_W],
		[PackedVector2Array([Vector2(SIDE_WALK_X, SOUTH_Z + 2.5), Vector2(SIDE_WALK_X, NORTH_Z - 2.5)]), SIDE_WALK_W],
		[PackedVector2Array([Vector2(-SIDE_WALK_X - 2.0, NORTH_Z - 2.5), Vector2(SIDE_WALK_X + 2.0, NORTH_Z - 2.5)]), 4.0],
		[PackedVector2Array([Vector2(AXIS_X, NORTH_Z - 2.5), TEMPLE + Vector2(0.0, TEMPLE_R + 0.5)]), 4.0],
	]


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "ReflectingPool")
	var walk := GardenKit.walk()
	for w: Array in walks():
		b.drape_path(w[0], w[1], walk, 0.06)
	_basin(b)
	_temple(b)
	_furnish(b)
	GardenKit.tag_props(b)
	b.flush()


static func _basin(b: GroundsBatch) -> void:
	var r := basin()
	var wy := water_y()
	var top := wy + 0.25
	var bottom := _low_y() - 0.4
	var h := top - bottom
	var cz := r.get_center().y
	var stone := GardenKit.stone()
	var shade := GardenKit.stone_shade()
	# walls (collide), then a paler coping strip on top of each
	for side: float in [-1.0, 1.0]:
		var x := AXIS_X + side * (HALF_W + COPING * 0.5)
		b.box(Vector3(x, bottom + h * 0.5, cz), Vector3(COPING, h, r.size.y + COPING * 2.0), shade, true)
		b.box(Vector3(x, top + 0.04, cz), Vector3(COPING + 0.2, 0.08, r.size.y + COPING * 2.0 + 0.2), stone, false)
	for z: float in [SOUTH_Z + COPING * 0.5, NORTH_Z - COPING * 0.5]:
		b.box(Vector3(AXIS_X, bottom + h * 0.5, z), Vector3(HALF_W * 2.0, h, COPING), shade, true)
		b.box(Vector3(AXIS_X, top + 0.04, z), Vector3(HALF_W * 2.0 + 0.2, 0.08, COPING + 0.2), stone, false)
	# a dark floor so the mirror reads deep, and the still water over it
	b.box(Vector3(AXIS_X, wy - 0.9, cz), Vector3(HALF_W * 2.0, 0.1, r.size.y), EstateKit.mat(Color(0.18, 0.22, 0.30), 0.9, 0.0, "pool_floor"), false)
	b.box(Vector3(AXIS_X, wy - 0.03, cz), Vector3(HALF_W * 2.0, 0.06, r.size.y), GardenKit.mirror_water(), false)


static func _temple(b: GroundsBatch) -> void:
	var y := WorldHeight.height_at(TEMPLE.x, TEMPLE.y)
	# a stone drum under the podium hides the slope at its foot
	b.cylinder(Vector3(TEMPLE.x, y - 1.2, TEMPLE.y), TEMPLE_R + 0.2, 1.2, GardenKit.stone_shade(), false, 28)
	b.prop(&"temple_of_love", Vector3(TEMPLE.x, y, TEMPLE.y), 0.0)
	# the podium steps (0.35 m each), the columns and the cupid's pedestal collide
	for k in 3:
		b.add_cyl_shape(Vector3(TEMPLE.x, y, TEMPLE.y), TEMPLE_R - k * 0.4, 0.35 * (k + 1))
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		b.add_cyl_shape(Vector3(TEMPLE.x + cos(a) * 4.0, y + 1.05, TEMPLE.y + sin(a) * 4.0), 0.32, 5.6)
	b.add_cyl_shape(Vector3(TEMPLE.x, y + 1.05, TEMPLE.y), 0.5, 1.6)
	for side: float in [-1.0, 1.0]:
		b.prop_on_ground(&"topiary_cone", TEMPLE.x + side * 8.5, TEMPLE.y + 3.0)
		b.prop_on_ground(&"urn_overflowing", TEMPLE.x + side * 4.0, TEMPLE.y + TEMPLE_R + 2.5)


static func _furnish(b: GroundsBatch) -> void:
	var wy := water_y()
	var r := basin()
	# urns at the four corners of the coping, lanterns along the side walks
	for x: float in [r.position.x - COPING * 0.5, r.end.x + COPING * 0.5]:
		for z: float in [r.position.y - COPING * 0.5, r.end.y + COPING * 0.5]:
			b.prop(&"urn_overflowing", Vector3(x, wy + 0.29, z), 0.0, 0.8)
	var z := SOUTH_Z - 10.0
	var k := 0
	while z > NORTH_Z + 4.0:
		for side: float in [-1.0, 1.0]:
			var x := AXIS_X + side * (SIDE_WALK_X + SIDE_WALK_W * 0.5 + 0.6)
			if k % 2 == 0:
				b.prop_on_ground(&"faelight_lantern", x, z, GardenKit.yaw_facing(Vector2(-side, 0.0)))
			else:
				b.prop_on_ground(&"bench_curved", x + side * 0.4, z, GardenKit.yaw_facing(Vector2(-side, 0.0)))
		z -= 10.5
		k += 1
	# two cupids at the south end, looking down the water
	for side: float in [-1.0, 1.0]:
		b.prop_on_ground(&"cupid_statue", AXIS_X + side * 11.5, SOUTH_Z + 3.0, 0.0)


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("reflecting_pool_plant_v1")
	var wy := water_y()
	# the cherry allée, daffodils and snowdrops at the tree feet
	var z := SOUTH_Z - 4.0
	while z > NORTH_Z:
		for side: float in [-1.0, 1.0]:
			var x := AXIS_X + side * ALLEE_X
			sb.put(&"deco_cherry_blossom", x, z, rng.randf() * TAU, rng.randf_range(0.95, 1.1))
			GardenKit.drift(sb, &"deco_daffodil", Vector2(x + side * 1.5, z + 2.5), 1.8, 7, rng)
			if z > -254.0:
				GardenKit.drift(sb, &"deco_snowdrop", Vector2(x - side * 0.5, z - 2.5), 1.5, 8, rng)
		z -= ALLEE_STEP
	# irises along the inner edge of both side walks
	for side: float in [-1.0, 1.0]:
		var x := AXIS_X + side * (HALF_W + COPING + 0.9)
		GardenKit.fill_line(sb, &"deco_iris", PackedVector2Array([Vector2(x, SOUTH_Z - 1.0), Vector2(x, NORTH_Z + 1.0)]), 1.1, rng)
	# water lilies along both edges at the near end, a few drifting toward the
	# middle (kept south of z -256 so they share one scatter chunk row)
	for i in 26:
		var side := -1.0 if i % 2 == 0 else 1.0
		var lz := SOUTH_Z - rng.randf_range(1.5, 19.0)
		var inset := rng.randf_range(0.7, 1.9) if i % 5 != 0 else rng.randf_range(2.2, 4.2)
		sb.put_at(&"deco_water_lily", Vector3(AXIS_X + side * (HALF_W - inset), wy + 0.02, lz), rng.randf() * TAU, rng.randf_range(0.85, 1.2))
	# daisy meadows beyond the allée (the deer park's own flower, so no new draw calls)
	for m: Rect2 in MEADOWS:
		for i in 22:
			var c := Vector2(rng.randf_range(m.position.x, m.end.x), rng.randf_range(m.position.y, m.end.y))
			GardenKit.drift(sb, &"deco_daisy", c, 3.0, 12, rng)
	# rings of irises and daffodils round the temple (the allée's own flowers)
	GardenKit.fill_sector(sb, &"deco_iris", TEMPLE, TEMPLE_R + 2.2, TEMPLE_R + 3.4, PI * 0.62, PI * 2.38, 0.9, rng)
	GardenKit.fill_sector(sb, &"deco_daffodil", TEMPLE, TEMPLE_R + 3.4, TEMPLE_R + 5.0, PI * 0.62, PI * 2.38, 0.8, rng)
