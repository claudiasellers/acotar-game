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


## [height (FORMAT_RF), control (FORMAT_RF)] for one region, `resolution`
## pixels square (1024 for the real bake; smaller in tests).
static func bake_region(loc: Vector2i, resolution: int = WorldMap.BAKE_TILE) -> Array[Image]:
	var origin := region_origin(loc)
	var step := float(WorldMap.BAKE_TILE) * WorldMap.TERRAIN_VERTEX_SPACING / float(resolution)
	WorldHeight.warm_up()  # build lazy noise before threads start
	# Rows go into a pre-sized Array (shared by reference); packed arrays
	# captured by a lambda would be copies.
	var rows := []
	rows.resize(resolution)
	var height_task := func(row: int) -> void:
		var z := origin.z + row * step
		var line := PackedFloat32Array()
		line.resize(resolution)
		for col in resolution:
			line[col] = WorldHeight.height_at(origin.x + col * step, z)
		rows[row] = line
	var id := WorkerThreadPool.add_group_task(height_task, resolution, -1, true, "bake heights")
	WorkerThreadPool.wait_for_group_task_completion(id)
	var heights := PackedFloat32Array()
	for line: PackedFloat32Array in rows:
		heights.append_array(line)

	var crow := []
	crow.resize(resolution)
	var control_task := func(row: int) -> void:
		var z := origin.z + row * step
		var line := PackedFloat32Array()
		line.resize(resolution)
		for col in resolution:
			line[col] = _control_at(origin.x + col * step, z, heights, resolution, row, col, step)
		crow[row] = line
	id = WorkerThreadPool.add_group_task(control_task, resolution, -1, true, "bake control")
	WorkerThreadPool.wait_for_group_task_completion(id)
	var controls := PackedFloat32Array()
	for line: PackedFloat32Array in crow:
		controls.append_array(line)

	var h := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, heights.to_byte_array())
	var c := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, controls.to_byte_array())
	return [h, c]


static func _control_at(x: float, z: float, heights: PackedFloat32Array, res: int, row: int, col: int, step: float) -> float:
	# Lane texture rules win where a provider has one.
	for p in WorldHeight.providers():
		if p.has_texture_rule() and p.weight_at(x, z) > 0.5:
			var t := p.texture_at(x, z)
			return encode_control(t.x, t.y, t.z)
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
		return encode_control(T.RIVERBED, T.RIVERBED, 0)
	var winter := z >= WorldMap.WALL_Z
	var ground: int = T.SNOW if winter else T.SPRING_GRASS
	var second: int = T.FROZEN_EARTH if winter else T.MOSS
	if slope > 38.0:
		return encode_control(T.ROCK, ground, 0)
	if slope > 26.0:
		return encode_control(ground, T.ROCK, int(remap(slope, 26.0, 38.0, 0.0, 255.0)))
	return encode_control(ground, second, 0)
