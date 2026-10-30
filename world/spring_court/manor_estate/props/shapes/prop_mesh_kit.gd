## Accumulates procedural primitives (boxes, cylinders, spheres, tori, lathes,
## tubes, leaves) into ONE ArrayMesh with one surface per material, so many
## instances of a prop or plant share a single mesh.
##
## Winding is fixed automatically from the normals, so builders only have to get
## the outward normals right. push()/pop() nest transforms for grouped parts.
## `flex` is a per-vertex wind weight (flora): to_mesh() writes it to vertex red.
class_name PropMeshKit
extends RefCounted


class Surf:
	var mat: Material
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var f := PackedFloat32Array()
	var i := PackedInt32Array()


var flex := 0.0
var _surfs: Array[Surf] = []
var _by_mat: Dictionary = {}
var _stack: Array[Transform3D] = [Transform3D.IDENTITY]


# --- transforms ---------------------------------------------------------------

static func at(pos: Vector3, yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0,
		scale: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(Vector3(pitch, yaw, roll)).scaled(scale)
	return Transform3D(b, pos)


func push(t: Transform3D) -> void:
	_stack.append(_stack.back() * t)


func pop() -> void:
	if _stack.size() > 1:
		_stack.pop_back()


func _surf(m: Material) -> Surf:
	var s: Surf = _by_mat.get(m)
	if s == null:
		s = Surf.new()
		s.mat = m
		_by_mat[m] = s
		_surfs.append(s)
	return s


func _emit(m: Material, v: PackedVector3Array, n: PackedVector3Array, idx: PackedInt32Array,
		t: Transform3D) -> void:
	var s := _surf(m)
	var full: Transform3D = _stack.back() * t
	var nb := full.basis.inverse().transposed()
	var base := s.v.size()
	for j in v.size():
		s.v.append(full * v[j])
		s.n.append((nb * n[j]).normalized())
		s.f.append(flex)
	var tri := 0
	while tri + 2 < idx.size():
		var a := idx[tri] + base
		var b := idx[tri + 1] + base
		var c := idx[tri + 2] + base
		var pa := s.v[a]
		var cr := (s.v[b] - pa).cross(s.v[c] - pa)
		if cr.length_squared() < 1e-14:
			tri += 3
			continue
		var nn := s.n[a] + s.n[b] + s.n[c]
		# Godot front faces are clockwise: flip anything counter-clockwise to its normal.
		if cr.dot(nn) > 0.0:
			s.i.append(a); s.i.append(c); s.i.append(b)
		else:
			s.i.append(a); s.i.append(b); s.i.append(c)
		tri += 3


# --- primitives -----------------------------------------------------------------

func box(m: Material, center: Vector3, size: Vector3, t: Transform3D = Transform3D.IDENTITY) -> void:
	var h := size * 0.5
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var axes := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for ax: Vector3 in axes:
		var u := Vector3(ax.y, ax.z, ax.x).abs()
		var w := ax.cross(u)
		var b := v.size()
		for k in 4:
			var su := -1.0 if k == 0 or k == 3 else 1.0
			var sw := -1.0 if k < 2 else 1.0
			v.append(center + (ax + u * su + w * sw) * h)
			n.append(ax)
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	_emit(m, v, n, idx, t)


## Vertical cylinder / cone / frustum from `base` upward.
func cyl(m: Material, base: Vector3, rb: float, rt: float, h: float, seg: int = 10,
		caps: bool = true, t: Transform3D = Transform3D.IDENTITY) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var slope := (rb - rt) / maxf(h, 0.0001)
	for i in seg + 1:
		var a := TAU * i / seg
		var cs := Vector3(cos(a), 0, sin(a))
		var nn := Vector3(cs.x, slope, cs.z).normalized()
		v.append(base + cs * rb); n.append(nn)
		v.append(base + cs * rt + Vector3(0, h, 0)); n.append(nn)
	for i in seg:
		var b := i * 2
		idx.append_array([b, b + 1, b + 3, b, b + 3, b + 2])
	if caps:
		for top in [false, true]:
			var r: float = rt if top else rb
			if r <= 0.0001:
				continue
			var y: float = h if top else 0.0
			var nn := Vector3.UP if top else Vector3.DOWN
			var c := v.size()
			v.append(base + Vector3(0, y, 0)); n.append(nn)
			for i in seg:
				var a := TAU * i / seg
				v.append(base + Vector3(cos(a) * r, y, sin(a) * r)); n.append(nn)
			for i in seg:
				idx.append_array([c, c + 1 + i, c + 1 + (i + 1) % seg])
	_emit(m, v, n, idx, t)


## Ellipsoid with radii `r`.
func sphere(m: Material, center: Vector3, r: Vector3, seg: int = 10, rings: int = 6,
		t: Transform3D = Transform3D.IDENTITY, top_only: bool = false) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var r0 := 0
	var r1 := rings
	var cols := seg + 1
	for ri in range(r0, r1 + 1):
		var phi := PI * ri / rings
		if top_only:
			phi = PI * 0.5 * ri / rings
		var y := cos(phi)
		var rr := sin(phi)
		for si in cols:
			var a := TAU * si / seg
			var p := Vector3(cos(a) * rr, y, sin(a) * rr)
			v.append(center + p * r)
			n.append(Vector3(p.x / r.x, p.y / r.y, p.z / r.z).normalized())
	for ri in rings:
		for si in seg:
			var a := ri * cols + si
			var b := a + cols
			idx.append_array([a, b, b + 1, a, b + 1, a + 1])
	_emit(m, v, n, idx, t)


## Ring lying in the XZ plane around `center`.
func torus(m: Material, center: Vector3, big_r: float, r: float, seg: int = 16, sides: int = 6,
		t: Transform3D = Transform3D.IDENTITY, arc: float = TAU) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var cols := sides + 1
	for i in seg + 1:
		var a := arc * i / seg
		var dir := Vector3(cos(a), 0, sin(a))
		for j in cols:
			var b := TAU * j / sides
			var nn := dir * cos(b) + Vector3.UP * sin(b)
			v.append(center + dir * big_r + nn * r)
			n.append(nn)
	for i in seg:
		for j in sides:
			var a := i * cols + j
			var b := a + cols
			idx.append_array([a, b, b + 1, a, b + 1, a + 1])
	_emit(m, v, n, idx, t)


## Surface of revolution around Y. `prof` holds (radius, height) points bottom to top.
func lathe(m: Material, base: Vector3, prof: PackedVector2Array, seg: int = 12,
		t: Transform3D = Transform3D.IDENTITY) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var cnt := prof.size()
	var pn := PackedVector2Array()
	for k in cnt:
		var a := prof[maxi(k - 1, 0)]
		var b := prof[mini(k + 1, cnt - 1)]
		var d := b - a
		pn.append(Vector2(d.y, -d.x).normalized())
	var cols := seg + 1
	for k in cnt:
		for i in cols:
			var ang := TAU * i / seg
			var c := cos(ang)
			var s := sin(ang)
			v.append(base + Vector3(c * prof[k].x, prof[k].y, s * prof[k].x))
			n.append(Vector3(c * pn[k].x, pn[k].y, s * pn[k].x).normalized())
	for k in cnt - 1:
		for i in seg:
			var a := k * cols + i
			var b := a + cols
			idx.append_array([a, b, b + 1, a, b + 1, a + 1])
	_emit(m, v, n, idx, t)


## A round tube along a polyline (arches, harp necks, stems, scrolls, rails).
func tube(m: Material, pts: PackedVector3Array, r: float, sides: int = 6,
		t: Transform3D = Transform3D.IDENTITY, r_end: float = -1.0) -> void:
	if pts.size() < 2:
		return
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var re := r if r_end < 0.0 else r_end
	var cols := sides + 1
	var prev_side := Vector3.ZERO
	for k in pts.size():
		var tan := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var side: Vector3
		if k == 0:
			var ref := Vector3.UP if absf(tan.y) < 0.9 else Vector3.RIGHT
			side = tan.cross(ref).normalized()
		else:
			side = (prev_side - tan * prev_side.dot(tan)).normalized()
		prev_side = side
		var up := side.cross(tan).normalized()
		var rr := lerpf(r, re, float(k) / (pts.size() - 1))
		for j in cols:
			var a := TAU * j / sides
			var nn := side * cos(a) + up * sin(a)
			v.append(pts[k] + nn * rr)
			n.append(nn)
	for k in pts.size() - 1:
		for j in sides:
			var a := k * cols + j
			var b := a + cols
			idx.append_array([a, b, b + 1, a, b + 1, a + 1])
	_emit(m, v, n, idx, t)


## A flat disc facing up (water surfaces, plates, lily pads).
func disc(m: Material, center: Vector3, r: float, seg: int = 12, t: Transform3D = Transform3D.IDENTITY,
		rz: float = -1.0) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var r2 := r if rz < 0.0 else rz
	v.append(center); n.append(Vector3.UP)
	for i in seg:
		var a := TAU * i / seg
		v.append(center + Vector3(cos(a) * r, 0, sin(a) * r2)); n.append(Vector3.UP)
	for i in seg:
		idx.append_array([0, 1 + i, 1 + (i + 1) % seg])
	_emit(m, v, n, idx, t)


## A one-sided quad a-b-c-d with normal `nn` (cards, panes, impostors).
func quad(m: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nn: Vector3,
		t: Transform3D = Transform3D.IDENTITY) -> void:
	_emit(m, PackedVector3Array([a, b, c, d]), PackedVector3Array([nn, nn, nn, nn]),
			PackedInt32Array([0, 1, 2, 0, 2, 3]), t)


## A creased leaf blade from `base` along `dir`, `width` wide, curling down by `droop`.
func leaf(m: Material, base: Vector3, dir: Vector3, length: float, width: float,
		droop: float = 0.3, t: Transform3D = Transform3D.IDENTITY) -> void:
	var d := dir.normalized()
	var side := d.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(d).normalized()
	if up.y < 0.0:
		up = -up
	var mid := base + d * length * 0.5 + Vector3.DOWN * droop * length * 0.15
	var tip := base + d * length + Vector3.DOWN * droop * length * 0.5
	var v := PackedVector3Array([base, mid + side * width * 0.5, mid - side * width * 0.5, tip,
			mid + up * width * 0.12])
	var n := PackedVector3Array([up, up, up, up, up])
	_emit(m, v, n, PackedInt32Array([0, 1, 4, 0, 4, 2, 4, 1, 3, 4, 3, 2]), t)


# --- output -------------------------------------------------------------------

func tri_count() -> int:
	var c := 0
	for s in _surfs:
		c += s.i.size() / 3
	return c


func aabb() -> AABB:
	var first := true
	var box_ := AABB()
	for s in _surfs:
		for p in s.v:
			if first:
				box_ = AABB(p, Vector3.ZERO)
				first = false
			else:
				box_ = box_.expand(p)
	return box_


## Builds the ArrayMesh. With `fit` non-zero the geometry is scaled per axis to
## exactly `fit`, centred on X/Z with its base at y = 0. With `wind_height` > 0,
## vertex colour red = flex weight * (y / wind_height) (green/blue stay 0).
func to_mesh(fit: Vector3 = Vector3.ZERO, wind_height: float = 0.0) -> ArrayMesh:
	var sc := Vector3.ONE
	var off := Vector3.ZERO
	if fit != Vector3.ZERO:
		var bb := aabb()
		for ax in 3:
			if bb.size[ax] > 0.0001 and fit[ax] > 0.0:
				sc[ax] = fit[ax] / bb.size[ax]
		var c := bb.get_center()
		off = Vector3(-c.x * sc.x, -bb.position.y * sc.y, -c.z * sc.z)
	var inv := Vector3(1.0 / sc.x, 1.0 / sc.y, 1.0 / sc.z)
	var am := ArrayMesh.new()
	for s in _surfs:
		var v := PackedVector3Array()
		var n := PackedVector3Array()
		v.resize(s.v.size())
		n.resize(s.n.size())
		for j in s.v.size():
			v[j] = s.v[j] * sc + off
			n[j] = (s.n[j] * inv).normalized()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_INDEX] = s.i
		if wind_height > 0.0:
			var cols := PackedColorArray()
			cols.resize(v.size())
			for j in v.size():
				var w := clampf(v[j].y / wind_height, 0.0, 1.0)
				cols[j] = Color(clampf(s.f[j] * w, 0.0, 1.0), 0.0, 0.0, 1.0)
			arr[Mesh.ARRAY_COLOR] = cols
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, s.mat)
	return am
