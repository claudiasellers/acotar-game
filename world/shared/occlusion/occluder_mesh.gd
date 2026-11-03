## Collects axis-aligned or rotated boxes and turns them into one
## OccluderInstance3D (an ArrayOccluder3D), for occlusion culling (program T1).
## Built at runtime from geometry the game already knows (manor walls and slabs,
## village building colliders), so nothing is baked or committed (R15).
class_name OccluderMesh
extends RefCounted

## Boxes thinner than this on both faces' spans are skipped: they hide little
## and only cost raster time.
const MIN_SPAN := 1.0

var vertices := PackedVector3Array()
var indices := PackedInt32Array()

const _CORNERS: Array[Vector3] = [
	Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
	Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1),
]
# Two triangles per face, outward winding.
const _FACES: Array[int] = [
	0, 2, 1, 0, 3, 2,  4, 5, 6, 4, 6, 7,  0, 1, 5, 0, 5, 4,
	3, 6, 2, 3, 7, 6,  0, 4, 7, 0, 7, 3,  1, 2, 6, 1, 6, 5,
]


## True when a box of this size is worth occluding with: at least two of its
## spans reach MIN_SPAN (a wall, a slab or a solid block).
static func worth(size: Vector3) -> bool:
	var big := 0
	for i in 3:
		if size[i] >= MIN_SPAN:
			big += 1
	return big >= 2


func add_box(xf: Transform3D, size: Vector3) -> bool:
	if not worth(size):
		return false
	var base := vertices.size()
	var half := size * 0.5
	for c in _CORNERS:
		vertices.append(xf * (c * half))
	for i in _FACES:
		indices.append(base + i)
	return true


func box_count() -> int:
	return vertices.size() / 8


func is_empty() -> bool:
	return vertices.is_empty()


## An OccluderInstance3D in `parent`'s space holding every box, or null if none.
func build(parent: Node3D, node_name: String) -> OccluderInstance3D:
	if is_empty():
		return null
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(vertices, indices)
	var inst := OccluderInstance3D.new()
	inst.name = node_name
	inst.occluder = occ
	parent.add_child(inst)
	return inst
