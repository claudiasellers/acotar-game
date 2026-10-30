## Stand-in ground for a wider-court region until Terrain3D is active
## (docs/contracts/world.md §2): chunked meshes and HeightMapShape3D collision
## sampled from WorldHeight, under a child named TerrainFallback that the World
## scene disables once Terrain3D takes over. Arrays are built off the main
## thread by compute(); build_nodes() turns them into nodes.
class_name CourtTerrainFallback
extends RefCounted

const SPACING := 4.0
const CHUNK := 128.0
const MATERIAL := "res://world/spring_court/wider/fx/materials/mat_terrain_tint.tres"

## WorldHeight.Tex slot -> ground colour (R3 pastels; the blight stays grey).
## sRGB colours from the experience-bar palette (mat_terrain_tint sets
## vertex_color_srgb).
const TEX_COLORS := {
	0: Color(0.95, 0.96, 1.0), 1: Color(0.55, 0.50, 0.46), 2: Color("D9CBD0"),
	3: Color(0.60, 0.66, 0.58), 4: Color("8DBF7A"), 5: Color("7CC29A"),
	6: Color("C9A98A"), 7: Color("E3CDB4"), 8: Color("9FB7B0"),
	9: Color("4A424D"),
}


## Returns one dictionary per chunk: {origin, n, heights, vertices, normals, colors, indices}.
static func compute(content: CourtRegionContent) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := content.ground_rect()
	var x0 := floorf(r.position.x / CHUNK) * CHUNK
	var z0 := floorf(r.position.y / CHUNK) * CHUNK
	var cx := x0
	while cx < r.end.x:
		var cz := z0
		while cz < r.end.y:
			if BuildCancel.requested(content.region_id):
				return out
			var chunk := _chunk(content, Vector2(cx, cz))
			if not chunk.is_empty():
				out.append(chunk)
			cz += CHUNK
		cx += CHUNK
	return out


static func build_nodes(parent: Node3D, chunks: Array[Dictionary]) -> Node3D:
	var root := Node3D.new()
	root.name = "TerrainFallback"
	parent.add_child(root)
	var mat: Material = load(MATERIAL) if ResourceLoader.exists(MATERIAL) else null
	if mat == null:
		var std := StandardMaterial3D.new()
		std.vertex_color_use_as_albedo = true
		std.roughness = 0.9
		mat = std
	for c in chunks:
		var origin: Vector2 = c["origin"]
		var body := StaticBody3D.new()
		body.name = "Ground_%d_%d" % [int(origin.x), int(origin.y)]
		body.collision_layer = 1
		body.collision_mask = 0
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = c["vertices"]
		arrays[Mesh.ARRAY_NORMAL] = c["normals"]
		arrays[Mesh.ARRAY_COLOR] = c["colors"]
		arrays[Mesh.ARRAY_INDEX] = c["indices"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		body.add_child(mi)
		var n: int = c["n"]
		var shape := HeightMapShape3D.new()
		shape.map_width = n
		shape.map_depth = n
		shape.map_data = c["heights"]
		var cs := CollisionShape3D.new()
		cs.shape = shape
		# HeightMapShape3D is centred on its node and spaced 1 unit: scale to SPACING.
		cs.position = Vector3(origin.x + CHUNK * 0.5, 0.0, origin.y + CHUNK * 0.5)
		cs.scale = Vector3(SPACING, 1.0, SPACING)
		body.add_child(cs)
		root.add_child(body)
	return root


static func _chunk(content: CourtRegionContent, origin: Vector2) -> Dictionary:
	var q := int(CHUNK / SPACING)
	var n := q + 1
	# Keep a quad when its centre is ours, so the ground stops at our borders.
	var keep := PackedByteArray()
	keep.resize(q * q)
	var any := false
	for j in q:
		for i in q:
			var c := origin + Vector2((i + 0.5) * SPACING, (j + 0.5) * SPACING)
			var own := content.has_ground(c)
			keep[j * q + i] = 1 if own else 0
			any = any or own
	if not any:
		return {}
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = WorldHeight.height_at(origin.x + i * SPACING, origin.y + j * SPACING)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	for j in n:
		for i in n:
			var h := heights[j * n + i]
			var x := origin.x + i * SPACING
			var z := origin.y + j * SPACING
			vertices[j * n + i] = Vector3(x, h, z)
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, n - 1)]
			var hu := heights[maxi(j - 1, 0) * n + i]
			var hd := heights[mini(j + 1, n - 1) * n + i]
			normals[j * n + i] = Vector3(hl - hr, 2.0 * SPACING, hu - hd).normalized()
			colors[j * n + i] = _color(x, z)
	var indices := PackedInt32Array()
	for j in q:
		for i in q:
			if keep[j * q + i] == 0:
				continue
			var a := j * n + i
			indices.append_array(PackedInt32Array([a, a + 1, a + n, a + 1, a + n + 1, a + n]))
	return {"origin": origin, "n": n, "heights": heights, "vertices": vertices, "normals": normals, "colors": colors, "indices": indices}


static func _color(x: float, z: float) -> Color:
	var t := WorldHeight.texture_at(x, z)
	var base: Color = TEX_COLORS.get(t.x, Color("8DBF7A"))
	var over: Color = TEX_COLORS.get(t.y, base)
	var c := base.lerp(over, t.z / 255.0)
	# Gentle mottling so meadows don't read flat.
	var m := 0.06 * sin(x * 0.19 + z * 0.07) * cos(z * 0.23 - x * 0.05)
	return c.lightened(m) if m > 0.0 else c.darkened(-m)
