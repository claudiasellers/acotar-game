## Turns WorldHeight into Terrain3D map images, one 1024 m bake tile at a time.
## Pure GDScript (no Terrain3D types) so it can be unit-tested without the
## extension. Rows are computed on the WorkerThreadPool.
class_name TerrainBaker
extends RefCounted

## Bake tile locations (1024 m) covering WorldMap.MAP_RECT.
static func region_locations() -> Array[Vector2i]:
	var size := float(WorldMap.BAKE_TILE) * WorldMap.TERRAIN_VERTEX_SPACING
	var r := WorldMap.MAP_RECT
	var out: Array[Vector2i] = []
	for rz in range(floori(r.position.y / size), ceili(r.end.y / size)):
		for rx in range(floori(r.position.x / size), ceili(r.end.x / size)):
			out.append(Vector2i(rx, rz))
	return out


static func region_origin(loc: Vector2i) -> Vector3:
	var size := float(WorldMap.BAKE_TILE) * WorldMap.TERRAIN_VERTEX_SPACING
	return Vector3(loc.x * size, 0.0, loc.y * size)


## Terrain3D control-map pixel: base texture, overlay texture, blend, as the
## float whose bits are the packed uint (Terrain3D's encoding).
static func encode_control(base: int, overlay: int, blend: int) -> float:
	var bits := ((base & 0x1F) << 27) | ((overlay & 0x1F) << 22) | ((clampi(blend, 0, 255) & 0xFF) << 14)
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, bits)
	return bytes.decode_float(0)


static func decode_control(value: float) -> Vector3i:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, value)
	var bits := bytes.decode_u32(0)
	return Vector3i(bits >> 27 & 0x1F, bits >> 22 & 0x1F, bits >> 14 & 0xFF)


## Soft ground blending (docs/contracts/world.md §2). Lane texture rules paint
## per pixel, so a biome border or a provider edge flips the base slot between
## two 1 m vertices and Terrain3D draws it as a hard stair-step. The bake turns
## those flips into soft, noise-broken borders: every "field" slot's weight is
## blurred (normalised, so paths and rock don't punch holes), sampled through a
## small domain warp, and the two strongest slots become base/overlay/blend.
## Paths, riverbeds, rock and ice are authored features and keep their paint.
const SOFT_SLOTS: Array[int] = [0, 1, 3, 4, 5, 6, 9]  # snow, frozen earth, winter grass, spring grass, moss, forest floor, blight
## Pixels baked around each tile so blended borders match across tile seams.
const BLEND_MARGIN := 32
## Weights are shrunk by this factor (Lanczos) and grown back (cubic): a
## ~2 x BLEND_SHRINK pixel soft ramp.
const BLEND_SHRINK := 8
## Domain-warp amplitude (pixels) and frequency (per metre) of the border noise.
const BLEND_WARP := 3.5
const BLEND_WARP_FREQ := 0.07


## [height (FORMAT_RF), control (FORMAT_RF)] for one region, `resolution`
## pixels square (1024 for the real bake; smaller in tests).
static func bake_region(loc: Vector2i, resolution: int = WorldMap.BAKE_TILE) -> Array[Image]:
	var step := float(WorldMap.BAKE_TILE) * WorldMap.TERRAIN_VERTEX_SPACING / float(resolution)
	var m := BLEND_MARGIN
	var e := resolution + 2 * m
	var origin := region_origin(loc) - Vector3(m * step, 0.0, m * step)
	WorldHeight.warm_up()  # build lazy noise before threads start
	# Rows go into a pre-sized Array (shared by reference); packed arrays
	# captured by a lambda would be copies.
	var rows := []
	rows.resize(e)
	var height_task := func(row: int) -> void:
		var z := origin.z + row * step
		var line := PackedFloat32Array()
		line.resize(e)
		for col in e:
			line[col] = WorldHeight.height_at(origin.x + col * step, z)
		rows[row] = line
	var id := WorkerThreadPool.add_group_task(height_task, e, -1, true, "bake heights")
	WorkerThreadPool.wait_for_group_task_completion(id)
	var heights := PackedFloat32Array()
	for line: PackedFloat32Array in rows:
		heights.append_array(line)

	var crow := []
	crow.resize(e)
	var control_task := func(row: int) -> void:
		var z := origin.z + row * step
		var line := PackedInt32Array()
		line.resize(e)
		for col in e:
			var t := _raw_control_at(origin.x + col * step, z, heights, e, row, col, step)
			line[col] = (t.x << 16) | (t.y << 8) | t.z
		crow[row] = line
	id = WorkerThreadPool.add_group_task(control_task, e, -1, true, "bake control")
	WorkerThreadPool.wait_for_group_task_completion(id)
	var raw := PackedInt32Array()
	for line: PackedInt32Array in crow:
		raw.append_array(line)

	var controls := soften_control(raw, e, m, Vector2(origin.x, origin.z), step)
	var interior := PackedFloat32Array()
	interior.resize(resolution * resolution)
	for row in resolution:
		for col in resolution:
			interior[row * resolution + col] = heights[(row + m) * e + col + m]
	var h := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, interior.to_byte_array())
	var c := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, controls.to_byte_array())
	return [h, c]


## True when a raw (base, overlay, blend) pixel is plain ground that may blend
## softly into its neighbours.
static func is_soft(base: int, overlay: int, blend: int) -> bool:
	return base in SOFT_SLOTS and (blend == 0 or overlay in SOFT_SLOTS)


## Raw packed controls (base << 16 | overlay << 8 | blend) on an `e` x `e`
## grid whose world corner is `corner` -> encoded Terrain3D controls for the
## interior (the grid minus `margin` on every side).
static func soften_control(raw: PackedInt32Array, e: int, margin: int, corner: Vector2, step: float) -> PackedFloat32Array:
	var res := e - 2 * margin
	# Which soft slots occur at all (usually 2-4 per tile).
	var slot_index := {}
	var slots: Array[int] = []
	for v: int in raw:
		var b := v >> 16
		var o := (v >> 8) & 0xFF
		var bl := v & 0xFF
		if not is_soft(b, o, bl):
			continue
		for s: int in ([b, o] if bl > 0 else [b]):
			if not slot_index.has(s):
				slot_index[s] = slots.size()
				slots.append(s)
	var out := PackedFloat32Array()
	out.resize(res * res)
	if slots.size() <= 1:
		for row in res:
			for col in res:
				var v := raw[(row + margin) * e + col + margin]
				out[row * res + col] = encode_control(v >> 16, (v >> 8) & 0xFF, v & 0xFF)
		return out
	# Channel layout: one per slot plus a coverage channel (normalised
	# convolution), packed four to an RGBAF image.
	var channels := slots.size() + 1
	var images := ceili(channels / 4.0)
	var buffers: Array[PackedFloat32Array] = []
	for i in images:
		var buf := PackedFloat32Array()
		buf.resize(e * e * 4)
		buffers.append(buf)
	var cover := slots.size()
	for p in e * e:
		var v := raw[p]
		var b := v >> 16
		var o := (v >> 8) & 0xFF
		var bl := v & 0xFF
		if not is_soft(b, o, bl):
			continue
		var wo := bl / 255.0
		var ci: int = slot_index[b]
		buffers[ci >> 2][p * 4 + (ci & 3)] += 1.0 - wo
		if bl > 0:
			ci = slot_index[o]
			buffers[ci >> 2][p * 4 + (ci & 3)] += wo
		buffers[cover >> 2][p * 4 + (cover & 3)] = 1.0
	var small := maxi(e / BLEND_SHRINK, 2)
	var blurred: Array[PackedFloat32Array] = []
	for buf in buffers:
		var img := Image.create_from_data(e, e, false, Image.FORMAT_RGBAF, buf.to_byte_array())
		img.resize(small, small, Image.INTERPOLATE_LANCZOS)
		img.resize(e, e, Image.INTERPOLATE_CUBIC)
		blurred.append(img.get_data().to_float32_array())
	var warp := FastNoiseLite.new()
	warp.seed = 4417
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp.frequency = BLEND_WARP_FREQ
	warp.fractal_octaves = 2
	var nslots := slots.size()
	var lines := []
	lines.resize(res)
	var task := func(row: int) -> void:
		var line := PackedFloat32Array()
		line.resize(res)
		var er := row + margin
		var z := corner.y + er * step
		for col in res:
			var ec := col + margin
			var v := raw[er * e + ec]
			var b := v >> 16
			var o := (v >> 8) & 0xFF
			var bl := v & 0xFF
			if not is_soft(b, o, bl):
				line[col] = encode_control(b, o, bl)
				continue
			var x := corner.x + ec * step
			var sr := clampi(roundi(er + warp.get_noise_2d(x, z) * BLEND_WARP), 0, e - 1)
			var sc := clampi(roundi(ec + warp.get_noise_2d(x + 517.0, z - 311.0) * BLEND_WARP), 0, e - 1)
			var p := sr * e + sc
			var w1 := 0.0
			var w2 := 0.0
			var s1 := b
			var s2 := o
			for i in nslots:
				var w := maxf(blurred[i >> 2][p * 4 + (i & 3)], 0.0)
				if w > w1:
					w2 = w1
					s2 = s1
					w1 = w
					s1 = slots[i]
				elif w > w2:
					w2 = w
					s2 = slots[i]
			if w1 <= 0.0:
				line[col] = encode_control(b, o, bl)
				continue
			if w2 <= 0.0:
				s2 = o if s1 == b else b
			line[col] = encode_control(s1, s2, roundi(255.0 * w2 / (w1 + w2)))
		lines[row] = line
	var id := WorkerThreadPool.add_group_task(task, res, -1, true, "soften control")
	WorkerThreadPool.wait_for_group_task_completion(id)
	out = PackedFloat32Array()
	for line: PackedFloat32Array in lines:
		out.append_array(line)
	return out


static func _raw_control_at(x: float, z: float, heights: PackedFloat32Array, res: int, row: int, col: int, step: float) -> Vector3i:
	# Lane texture rules win where a provider has one.
	for p in WorldHeight.providers():
		if p.has_texture_rule() and p.weight_at(x, z) > 0.5:
			return p.texture_at(x, z)
	# Otherwise: realm ground, rock on steep slopes (slope from the baked heights).
	var r0 := maxi(row - 1, 0)
	var r1 := mini(row + 1, res - 1)
	var c0 := maxi(col - 1, 0)
	var c1 := mini(col + 1, res - 1)
	var dx := (heights[row * res + c1] - heights[row * res + c0]) / (step * (c1 - c0))
	var dz := (heights[r1 * res + col] - heights[r0 * res + col]) / (step * (r1 - r0))
	var slope := rad_to_deg(atan(sqrt(dx * dx + dz * dz)))
	var T := WorldHeight.Tex
	if MacroHeight.distance_to_river(x, z) < MacroHeight.RIVER_HALF_WIDTH:
		return Vector3i(T.RIVERBED, T.RIVERBED, 0)
	var winter := z >= WorldMap.WALL_Z
	var ground: int = T.SNOW if winter else T.SPRING_GRASS
	var second: int = T.FROZEN_EARTH if winter else T.MOSS
	if slope > 38.0:
		return Vector3i(T.ROCK, ground, 0)
	if slope > 26.0:
		return Vector3i(ground, T.ROCK, int(remap(slope, 26.0, 38.0, 0.0, 255.0)))
	return Vector3i(ground, second, 0)
