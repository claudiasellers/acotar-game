## Contract: the terrain bake turns hard ground-slot flips into soft,
## noise-broken borders and leaves authored features (paths) alone.
extends GutTest

const T := WorldHeight.Tex
const E := 160
const M := TerrainBaker.BLEND_MARGIN


func _pack(b: int, o: int, bl: int) -> int:
	return (b << 16) | (o << 8) | bl


## Left half spring grass, right half moss, a 1-pixel path column at x = 20.
func _grid() -> PackedInt32Array:
	var raw := PackedInt32Array()
	raw.resize(E * E)
	for r in E:
		for c in E:
			var v := _pack(T.SPRING_GRASS, T.MOSS, 0) if c < E / 2 else _pack(T.MOSS, T.SPRING_GRASS, 0)
			if c == 40:
				v = _pack(T.PATH, T.FOREST_FLOOR, 60)
			raw[r * E + c] = v
	return raw


func _moss_weight(v: float) -> float:
	var t := TerrainBaker.decode_control(v)
	var w := t.z / 255.0
	if t.x == T.MOSS:
		return 1.0 - w
	if t.y == T.MOSS:
		return w
	return 0.0


func test_hard_border_becomes_a_soft_ramp() -> void:
	var res := E - 2 * M
	var out := TerrainBaker.soften_control(_grid(), E, M, Vector2.ZERO, 1.0)
	assert_eq(out.size(), res * res)
	var mid := 0
	for r in res:
		for c in res:
			var w := _moss_weight(out[r * res + c])
			if w > 0.15 and w < 0.85:
				mid += 1
	# A hard border has 0 in-between pixels; a soft one has a band several px wide.
	assert_gt(mid, res * 4, "pixels part-way between grass and moss")


func test_border_is_noise_broken_not_straight() -> void:
	var res := E - 2 * M
	var out := TerrainBaker.soften_control(_grid(), E, M, Vector2(300.0, -200.0), 1.0)
	var cols := {}
	for r in res:
		for c in res:
			if TerrainBaker.decode_control(out[r * res + c]).x == T.MOSS:
				cols[r] = c
				break
	var distinct := {}
	for r: int in cols:
		distinct[cols[r]] = true
	assert_gt(distinct.size(), 2, "the grass/moss flip wanders between rows")


func test_far_ground_and_paths_keep_their_paint() -> void:
	var res := E - 2 * M
	var out := TerrainBaker.soften_control(_grid(), E, M, Vector2.ZERO, 1.0)
	var path := TerrainBaker.decode_control(out[10 * res + (40 - M)])
	assert_eq(path, Vector3i(T.PATH, T.FOREST_FLOOR, 60), "path pixel unchanged")
	var far := TerrainBaker.decode_control(out[10 * res + res - 1])
	assert_eq(far.x, T.MOSS)
	assert_lt(far.z, 20, "deep inside the moss there is almost no grass")
