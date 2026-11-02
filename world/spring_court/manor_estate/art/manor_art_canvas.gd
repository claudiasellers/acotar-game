## Canvas meshes for the manor's paintings (L39): rectangle, oval, round and
## arch-topped, centred on the origin in the XY plane and facing -Z like every
## prop. Their outlines match the openings of the Blender frames
## (tools/blender/manor_frames.py), and their UVs map the painting's cell of
## the painting's layer of the texture array, so every canvas in the house
## shares one material and a room's canvases merge into one draw.
class_name ManorArtCanvas
extends RefCounted

## Segments of a curved outline (the frames use the same count).
const N_CURVE := 32
## Canvas size for a frame shape when its long side is 1 m (manor_frames.py).
const UNIT := {
	&"land": Vector2(1.0, 0.703), &"port": Vector2(0.75, 1.0), &"full": Vector2(0.667, 1.0),
	&"square": Vector2(1.0, 1.0), &"oval_p": Vector2(0.8, 1.0), &"oval_l": Vector2(1.0, 0.8),
	&"round": Vector2(1.0, 1.0), &"arch_p": Vector2(0.75, 1.0),
}


## The canvas outline in metres, counter-clockwise seen from the front.
static func outline(shape: StringName, size: Vector2) -> PackedVector2Array:
	var w := size.x
	var h := size.y
	var out := PackedVector2Array()
	match shape:
		&"oval_p", &"oval_l", &"round":
			for i in N_CURVE:
				var a := TAU * i / N_CURVE - PI * 0.5
				out.append(Vector2(w * 0.5 * cos(a), h * 0.5 * sin(a)))
		&"arch_p":
			var top := h * 0.5 - w * 0.5
			out.append(Vector2(-w * 0.5, -h * 0.5))
			out.append(Vector2(w * 0.5, -h * 0.5))
			var n := N_CURVE / 2
			for i in n + 1:
				var a := PI * i / n
				out.append(Vector2(w * 0.5 * cos(a), top + w * 0.5 * sin(a)))
		_:
			out = PackedVector2Array([Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
					Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)])
	return out


## A canvas of `size` metres showing `uv` (a cell of array layer `layer`), a
## triangle fan from the centre. The layer rides in UV.x as its whole part
## (the mesh merger keeps UV, not UV2); manor_canvas.gdshader splits it off.
## The painting reads the right way round from the front.
static func mesh(shape: StringName, size: Vector2, uv: Rect2, layer: int, material: Material) -> ArrayMesh:
	var ring := outline(shape, size)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var pts := PackedVector2Array([Vector2.ZERO])
	pts.append_array(ring)
	for p in pts:
		verts.append(Vector3(p.x, p.y, 0.0))
		normals.append(Vector3(0, 0, -1))
		# seen from -Z, +X is on the viewer's left
		var u := 0.5 - p.x / size.x
		var v := 0.5 - p.y / size.y
		uvs.append(uv.position + Vector2(u, v) * uv.size + Vector2(layer, 0.0))
	var n := ring.size()
	for i in n:
		idx.append_array([0, 1 + (i + 1) % n, 1 + i])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, material)
	return m
