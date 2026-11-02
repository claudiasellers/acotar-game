"""Fur, sculpt and horror detail for the hero quadrupeds (lane L43, quality
audit B7): the great wolf and the doe.

The skin-modifier bodies from creatures.py are smooth tubes. This module turns
them into animals without touching the skeleton (every bone sits on a graph
point, and nothing here moves a graph point), so the clips stay valid:

* sculpt_*: displaces body vertices before weighting (deep keel, tucked belly,
  hollow flanks, shoulder blades and hip bones under the hide, brow ridges,
  eye sockets, a wedge muzzle).
* write_fur_attributes: per-vertex data for creatures/materials/fur.gdshader.
  TEXCOORD_0 = rest position (x, y), TEXCOORD_1 = (rest z, rib mask), so the
  procedural coat rides the skin instead of swimming; COLOR_0 = (pale, fur
  length, dark, wet) zones. glTF export flips V, the shader flips it back.
* guard_hair_cards: ragged clumps of strands (alpha-cut cards) along the
  mane, ruff, belly line, tail and joints, each weighted like its root.
* wolf_mouth / wolf_eyes: a full row of wet teeth, tongue, saliva strands that
  stretch between muzzle and jaw, sunken almond eyes with pupils.

Deterministic: hashes, no random module.
"""

import math

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


# ---------------------------------------------------------------- helpers

def sat(x):
    return 0.0 if x < 0.0 else 1.0 if x > 1.0 else x


def ss(x):
    x = sat(x)
    return x * x * (3.0 - 2.0 * x)


def bump(d, r):
    """1 at d = 0, smooth to 0 at d >= r."""
    return ss(1.0 - d / r) if r > 0.0 else 0.0


def h1(n):
    """Deterministic hash of an int to [0, 1)."""
    n = (n * 374761393 + 668265263) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFF) / float(0x1000000)


def P(g, name):
    return Vector(g.points[g.names[name]])


def seg_dist(p, a, b):
    ab = b - a
    t = sat((p - a).dot(ab) / max(ab.length_squared, 1e-9))
    return (p - (a + ab * t)).length, t


def poly_dist(p, pts):
    best = (1e9, 0.0, 0)
    for i in range(len(pts) - 1):
        d, t = seg_dist(p, pts[i], pts[i + 1])
        if d < best[0]:
            best = (d, t, i)
    return best


def _normals(obj):
    obj.data.update()
    return [v.normal.copy() for v in obj.data.vertices]


def fix_normals(obj):
    """Closes the holes the skin modifier leaves where branches meet (the old
    model showed one behind each thigh) and makes every face point out."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    holes = [e for e in bm.edges if e.is_boundary]
    if holes:
        bmesh.ops.holes_fill(bm, edges=holes, sides=0)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


# ---------------------------------------------------------------- sculpt

def sculpt_wolf(body, g, spec):
    """Gaunt starved predator: deep narrow keel, belly tucked up behind the
    ribs, hollow flanks, blades and hip bones standing under the hide, a
    beaded spine, heavy brow over sunken sockets, a long flat wedge muzzle."""
    fix_normals(body)
    L, r = spec["length"], spec["girth"]
    hr = spec["head"]
    hip, mid, chest, sh = P(g, "hip"), P(g, "mid"), P(g, "chest"), P(g, "shoulder")
    neck, head, snout = P(g, "neck"), P(g, "head"), P(g, "snout")
    spine = [P(g, "tail0"), hip, mid, chest, sh]
    eye_fwd = spec.get("eye_fwd", 0.5)
    ears = [(P(g, f"ear{s}"), P(g, f"eart{s}")) for s in (-1, 1)]
    normals = _normals(body)
    for v, n in zip(body.data.vertices, normals):
        p = v.co.copy()
        # The skin modifier kinks one ear tip; fold the skin ear down to a
        # stub (wolf_ears in creatures.py lays a modelled ear over it).
        for base, tip in ears:
            d, t = seg_dist(p, base, tip)
            if d < hr * 0.4 and t > 0.05:
                p = base + (p - base) * 0.45
        d_sp, _, _ = poly_dist(p, spine)
        torso = bump(d_sp, r * 1.9) * ss((p.z - (chest.z - r * 2.2)) / (r * 0.6))
        # Lateral squeeze: wolves are narrow, deep-chested.
        if hip.y - 0.1 * L < p.y < sh.y + 0.05 * L:
            p.x *= 1.0 - 0.2 * torso
        # Keel: chest underside drops.
        if p.z < chest.z:
            wc = bump(abs(p.y - (chest.y + 0.02 * L)), 0.22 * L)
            p.z -= 0.32 * r * wc * torso * ss((chest.z - p.z) / r)
        # Tuck-up: underline rises sharply behind the ribs.
        if p.z < mid.z:
            wt = bump(abs(p.y - (mid.y - 0.06 * L)), 0.2 * L) * torso
            p.z += min(0.6 * (mid.z - p.z), 0.5 * r) * wt * ss((mid.z - p.z) / (0.5 * r))
        # Hollow flank in front of the hip.
        side = ss((abs(n.x) - 0.3) / 0.5)
        hollow = bump(abs(p.y - (hip.y + 0.12 * L)), 0.11 * L) * bump(abs(p.z - mid.z + 0.1 * r), 0.7 * r)
        p -= n * (0.12 * r * hollow * side * torso)
        # Bones under the hide (along the normal).
        out = 0.0
        for sx in (-1, 1):
            blade = sh + Vector((sx * 0.45 * r, -0.05 * L, 0.95 * r))
            q = (p - blade)
            out += 0.2 * r * bump(math.sqrt((q.x / 0.7) ** 2 + (q.y / 1.6) ** 2 + (q.z / 1.0) ** 2), 0.35 * r)
            hb = hip + Vector((sx * 0.5 * r, 0.02 * L, 0.7 * r))
            out += 0.16 * r * bump((p - hb).length, 0.28 * r)
        if n.z > 0.5 and abs(p.x) < 0.14 * r and hip.y < p.y < sh.y:
            out += 0.06 * r * (0.5 + 0.5 * math.cos(p.y * 2 * math.pi / 0.075)) ** 2
        # Head: brow ridges, sockets, cheekbones; narrow skull, flat wedge muzzle.
        dh = (p - head).length
        if dh < hr * 2.6 or (p - snout).length < hr * 1.4:
            for sx in (-1, 1):
                brow = head + Vector((sx * 0.46 * hr, (eye_fwd - 0.02) * hr, 0.58 * hr))
                out += 0.36 * hr * bump((p - brow).length, 0.36 * hr)
                eye = head + Vector((sx * 0.47 * hr, eye_fwd * hr, 0.34 * hr))
                out -= 0.14 * hr * bump((p - eye).length, 0.26 * hr)
                cheek = head + Vector((sx * 0.72 * hr, 0.08 * hr, -0.08 * hr))
                out += 0.18 * hr * bump((p - cheek).length, 0.42 * hr)
            # The stop: a dip from the brow down onto the muzzle bridge.
            stop = head + Vector((0, (eye_fwd + 0.3) * hr, 0.5 * hr))
            out -= 0.12 * hr * bump((p - stop).length, 0.3 * hr) * ss((n.z - 0.2) / 0.5)
            # Flews: the back of the upper lip hangs at the corners.
            d_up, t_up = seg_dist(p, head, snout)
            if p.z < snout.z and abs(n.x) > 0.3:
                p.z -= 0.1 * hr * bump(abs(t_up - 0.35), 0.25) * ss((abs(n.x) - 0.3) / 0.4)
            # The snarl: the front of the upper lip is lifted off the teeth,
            # so the gum line and the tooth row show from the front.
            if p.z < snout.z and t_up > 0.45 and (abs(n.x) > 0.2 or n.y > 0.3):
                p.z += 0.09 * hr * ss((t_up - 0.45) / 0.3) * ss((snout.z - p.z) / (0.2 * hr))
            if p.y > head.y + 0.2 * hr and p.z > snout.z:
                p.z = snout.z + (p.z - snout.z) * 0.78
            if p.y > head.y:
                p.x *= 0.9
        p += n * out
        v.co = p
    body.data.update()


def sculpt_deer(body, g, spec):
    """A lean winter doe: slight tuck, a defined shoulder, a finer muzzle."""
    fix_normals(body)
    L, r = spec["length"], spec["girth"]
    hip, mid, chest, sh = P(g, "hip"), P(g, "mid"), P(g, "chest"), P(g, "shoulder")
    head, snout = P(g, "head"), P(g, "snout")
    spine = [hip, mid, chest, sh]
    normals = _normals(body)
    for v, n in zip(body.data.vertices, normals):
        p = v.co.copy()
        d_sp, _, _ = poly_dist(p, spine)
        torso = bump(d_sp, r * 1.8)
        if p.z < mid.z:
            wt = bump(abs(p.y - (mid.y - 0.08 * L)), 0.2 * L) * torso
            p.z += min(0.35 * (mid.z - p.z), 0.25 * r) * wt
        if hip.y - 0.1 * L < p.y < sh.y:
            p.x *= 1.0 - 0.1 * torso
        if p.y > head.y and (p - snout).length < spec["head"] * 1.6:
            p.x *= 0.88
        v.co = p
    body.data.update()


# ---------------------------------------------------------------- attributes

def _layer(mesh, name):
    uv = mesh.uv_layers.get(name) or mesh.uv_layers.new(name=name)
    return uv


def _color(mesh):
    if "Col" not in mesh.color_attributes:
        mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    attr = mesh.color_attributes["Col"]
    mesh.color_attributes.active_color = attr
    return attr


def write_fur_attributes(obj, zone_fn, rib_fn=None):
    """zone_fn(co, normal) -> (pale, fur, dark, wet); rib_fn(co, normal) -> 0..1."""
    mesh = obj.data
    while len(mesh.uv_layers):
        mesh.uv_layers.remove(mesh.uv_layers[0])
    uv0, uv1 = _layer(mesh, "UVMap"), _layer(mesh, "Rest")
    col = _color(mesh)
    normals = _normals(obj)
    zones = []
    for v, n in zip(mesh.vertices, normals):
        zones.append(zone_fn(v.co, n))
        col.data[v.index].color = zones[-1]
    ribs = [rib_fn(v.co, n) if rib_fn else 0.0 for v, n in zip(mesh.vertices, normals)]
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        uv0.data[loop.index].uv = (co.x, co.y)
        uv1.data[loop.index].uv = (co.z, ribs[loop.vertex_index])
    mesh.uv_layers.active = uv0


def paint_constant(obj, rgba=(1.0, 1.0, 1.0, 1.0), seed=0.0):
    """Parts joined into a fur body need the same UV and colour layers. Godot
    multiplies a StandardMaterial's albedo by vertex colour, so parts that keep
    their own material (eyes, teeth, claws) stay white."""
    mesh = obj.data
    while len(mesh.uv_layers):
        mesh.uv_layers.remove(mesh.uv_layers[0])
    uv0, uv1 = _layer(mesh, "UVMap"), _layer(mesh, "Rest")
    for loop in mesh.loops:
        uv0.data[loop.index].uv = (0.0, 0.0)
        uv1.data[loop.index].uv = (seed, 0.0)
    col = _color(mesh)
    for i in range(len(mesh.vertices)):
        col.data[i].color = rgba


def wolf_zones(g, spec):
    L, r, hr = spec["length"], spec["girth"], spec["head"]
    hip, mid, chest, sh = P(g, "hip"), P(g, "mid"), P(g, "chest"), P(g, "shoulder")
    neck, head, snout, jaw = P(g, "neck"), P(g, "head"), P(g, "snout"), P(g, "jaw")
    tail_end = P(g, "tail_2")
    spine = [hip, mid, chest, sh]
    H = spec["height"]
    shape_snout_rz = spec["shape"]["snout_rz"]
    shape_jaw_rz = spec["shape"]["jaw_rz"]

    def zone(co, n):
        pale = fur = dark = wet = 0.0
        d_sp, _, _ = poly_dist(co, spine)
        torso = bump(d_sp, r * 1.9)
        leg = 1.0 - ss((co.z - H * 0.55) / (H * 0.12)) if d_sp > r * 1.2 else 0.0
        # Ivory underparts: belly, inner legs, throat, chin.
        pale = max(pale, ss((-n.z - 0.2) / 0.5) * torso * 0.85)
        throat = bump(seg_dist(co, sh, neck)[0], r * 1.6) * ss((-n.z + n.y * 0.5 - 0.1) / 0.5)
        pale = max(pale, throat * 0.8)
        # Obsidian saddle; a lighter face (silver cheeks, dark mask only round
        # the eyes) so the head reads as form, not a black hole.
        dark = max(dark, 0.75 * ss((n.z - 0.35) / 0.5) * torso)
        d_head = (co - head).length
        if d_head < hr * 1.6:
            dark = max(dark, 0.3 * ss((n.z + 0.2) / 0.6))
            for sx in (-1, 1):
                eye = head + Vector((sx * 0.47 * hr, spec.get("eye_fwd", 0.5) * hr, 0.34 * hr))
                dark = max(dark, bump((co - eye).length, 0.24 * hr))
                cheek = head + Vector((sx * 0.7 * hr, 0.1 * hr, -0.12 * hr))
                pale = max(pale, 0.4 * bump((co - cheek).length, 0.5 * hr))
        # Fur length: long on the spine, ruff, tail and belly fringe; shorter
        # on the flat flanks; next to none on the face, legs and paws.
        fur = 0.55 + 0.45 * max(ss((n.z - 0.3) / 0.5), bump(seg_dist(co, sh, neck)[0], r * 1.8),
                                ss((-n.z - 0.4) / 0.4))
        fur *= 1.0 - 0.92 * bump(d_head, hr * 1.7)
        fur *= 1.0 - 0.6 * leg * ss((H * 0.4 - co.z) / (H * 0.3))
        if co.z < 0.06:
            fur *= 0.3
        if (co - tail_end).length < r * 2.0:
            fur = 1.0
        # Mouth: inside the gap is bare and wet; on the outside the lips are
        # drawn back in a snarl, a black lip edge over a band of wet gum.
        if co.y > head.y + 0.1 * hr:
            d_up, t_up = seg_dist(co, head, snout)
            d_lo, t_lo = seg_dist(co, head, jaw)
            side = max(ss((abs(n.x) - 0.25) / 0.4), ss((n.y - 0.3) / 0.4))
            if d_lo < d_up * 0.95:
                if n.z > 0.1:
                    wet = ss((n.z - 0.1) / 0.4) * ss((t_lo - 0.2) / 0.3)
                tj = 1.0 - t_lo
                rzj = hr * (shape_jaw_rz + (0.5 - shape_jaw_rz) * tj)
                rel = co.z - (jaw.z + (head.z - jaw.z) * tj)
                gum = bump(abs(rel - rzj * 0.75), rzj * 0.35) * side * ss((t_lo - 0.15) / 0.2)
                wet = max(wet, gum)
                dark = max(dark, bump(abs(rel - rzj * 0.25), rzj * 0.3) * side * ss((t_lo - 0.15) / 0.2))
            else:
                if n.z < -0.2 and co.z < snout.z:
                    wet = ss((-n.z - 0.2) / 0.4) * ss((t_up - 0.3) / 0.3)
                tu = 1.0 - t_up
                rz = hr * (shape_snout_rz + 0.45 * tu)
                rel = co.z - (snout.z + (head.z - snout.z) * tu)
                band = ss((t_up - 0.2) / 0.2)
                gum = bump(abs(rel + rz * 0.82), rz * 0.22) * side * band
                lip = bump(abs(rel + rz * 0.5), rz * 0.16) * side * band
                wet = max(wet, gum)
                dark = max(dark, lip)
            fur *= 1.0 - max(wet, dark * 0.8)
        return (sat(pale), sat(fur), sat(dark), sat(wet))

    def rib(co, n):
        if not (mid.y < co.y < chest.y + 0.04 * L):
            return 0.0
        side = ss((abs(n.x) - 0.35) / 0.4)
        return side * bump(abs(co.z - (mid.z + chest.z) * 0.5 + 0.2 * r), 0.9 * r) * bump(abs(co.y - (mid.y + chest.y) * 0.5), 0.17 * L)

    return zone, rib


def deer_zones(g, spec):
    L, r, hr = spec["length"], spec["girth"], spec["head"]
    hip, mid, chest, sh = P(g, "hip"), P(g, "mid"), P(g, "chest"), P(g, "shoulder")
    neck, head, snout = P(g, "neck"), P(g, "head"), P(g, "snout")
    tail = P(g, "tail_0")
    H = spec["height"]
    spine = [hip, mid, chest, sh]
    eye_fwd = spec.get("eye_fwd", 0.5)

    def zone(co, n):
        pale = dark = 0.0
        d_sp, _, _ = poly_dist(co, spine)
        torso = bump(d_sp, r * 1.8)
        # White belly and inner legs, throat patch, chin, rump patch.
        pale = max(pale, ss((-n.z - 0.15) / 0.45) * torso)
        if d_sp > r * 1.1 and co.z < H * 0.7:
            inner = ss((-n.x * math.copysign(1.0, co.x) - 0.45) / 0.4) * ss((co.z - H * 0.25) / (H * 0.2))
            pale = max(pale, inner * 0.7)
        throat = bump((co - neck.lerp(head, 0.1)).length, hr * 1.4) * ss((-n.z + n.y * 0.6) / 0.6)
        pale = max(pale, throat)
        rump = ss((-n.y - 0.35) / 0.4) * bump((co - (hip + Vector((0, -0.04 * L, 0.0)))).length, r * 1.5)
        pale = max(pale, rump * 0.9)
        if (co - tail).length < r * 0.9:
            pale = max(pale, ss((-n.z + 0.1) / 0.4))
            dark = max(dark, ss((n.z - 0.2) / 0.4) * 0.9)
        if co.y > head.y:
            chin = ss((-n.z - 0.1) / 0.4) * bump((co - snout).length, hr * 1.4)
            pale = max(pale, chin)
        for sx in (-1, 1):
            eye = head + Vector((sx * 0.62 * hr, eye_fwd * hr, 0.28 * hr))
            ring = bump(abs((co - eye).length - 0.26 * hr), 0.08 * hr)
            pale = max(pale, ring * 0.55)
        # Dark nose and muzzle tip; ear rims; a darker dorsal line.
        dark = max(dark, bump((co - snout).length, hr * 0.55))
        for side in (-1, 1):
            if (co - P(g, f"eart{side}")).length < hr * 0.7:
                dark = max(dark, 0.8)
        dark = max(dark, 0.35 * ss((n.z - 0.6) / 0.3) * torso)
        fur = 0.9 * (1.0 - 0.7 * bump((co - snout).length, hr * 1.6))
        if d_sp > r * 1.2 and co.z < H * 0.5:
            fur *= 0.35
        return (sat(pale), sat(fur), sat(dark), 0.0)

    return zone, None


# ---------------------------------------------------------------- guard hair

def _card(bm, uv0, uv1, col, root, direction, normal, length, width, droop, seed, rgba, segs=4):
    """One tapered strip from root along `direction`, bowing down by `droop`,
    lying with its face toward `normal`. UV.x across, UV.y along."""
    side = direction.cross(normal)
    if side.length < 1e-4:
        side = direction.orthogonal()
    side.normalize()
    rows = []
    for i in range(segs + 1):
        t = i / segs
        c = root + direction * (length * t) + Vector((0, 0, -droop * length * t * t))
        w = width * (1.0 - 0.85 * t)
        rows.append((bm.verts.new(c - side * w), bm.verts.new(c + side * w), t))
    for i in range(segs):
        a0, a1, t0 = rows[i]
        b0, b1, t1 = rows[i + 1]
        f = bm.faces.new((a0, a1, b1, b0))
        for loop, (u, v) in zip(f.loops, ((0, t0), (1, t0), (1, t1), (0, t1))):
            loop[uv0].uv = (u, v)
            loop[uv1].uv = (seed, 0.0)
    for a, b, _ in rows:
        a[col] = rgba
        b[col] = rgba
    return [rows[0][0], rows[0][1]] + [v for row in rows[1:] for v in row[:2]]


def guard_hair_cards(name, body, g, spec, mat):
    """Ragged clumps over the mane, ruff, cheeks, belly line, elbows, hocks,
    haunches and tail. Returns (object, cards) where cards lists vertex
    index ranges, root first."""
    L, r, hr = spec["length"], spec["girth"], spec["head"]
    bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    bm = bmesh.new()
    uv0 = bm.loops.layers.uv.new("UVMap")
    uv1 = bm.loops.layers.uv.new("Rest")
    col = bm.verts.layers.float_color.new("Col")
    cards = []
    n = [0]
    BACK = Vector((0, -1, 0))
    DOWN = Vector((0, 0, -1))

    def place(axis_pt, axis_dir, angle, length, width, comb, lift, droop, pale, dark=0.0):
        """Casts from outside toward the axis at `angle` (0 = up) and roots a card there."""
        k = n[0]
        n[0] += 1
        up = Vector((0, 0, 1))
        ax = axis_dir.normalized()
        side = ax.cross(up)
        if side.length < 1e-3:
            side = Vector((1, 0, 0))
        side.normalize()
        upp = side.cross(ax).normalized()
        out = upp * math.cos(angle) + side * math.sin(angle)
        hit = bvh.ray_cast(axis_pt + out * (r * 4.0), -out, r * 6.0)
        if hit[0] is None:
            return
        p, nrm = hit[0], hit[1]
        j = h1(k * 7 + 1)
        ln = length * (0.7 + 0.6 * j)
        d = (nrm * lift + BACK * comb + DOWN * 0.15).normalized()
        start = len(bm.verts)
        _card(bm, uv0, uv1, col, p - nrm * 0.01, d, nrm, ln, width * (0.8 + 0.4 * h1(k * 3 + 2)),
              droop * (0.6 + 0.8 * h1(k * 5 + 3)), h1(k * 11 + 4), (pale, 1.0, dark, 0.0))
        cards.append((start, len(bm.verts)))

    def along(pts, t):
        seglen = [(pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)]
        s = t * sum(seglen)
        for i, sl in enumerate(seglen):
            if s <= sl or i == len(seglen) - 1:
                f = s / max(sl, 1e-6)
                return pts[i].lerp(pts[i + 1], min(f, 1.0)), (pts[i + 1] - pts[i])
            s -= sl

    hip, mid, chest, sh, neck, head = (P(g, k) for k in ("hip", "mid", "chest", "shoulder", "neck", "head"))
    # Mane: hips to nape, longest and most bristling over the shoulders.
    spine = [hip, mid, chest, sh, neck]
    for i in range(44):
        t = (i + 0.5) / 44
        pt, ax = along(spine, t)
        grow = 0.35 + 0.65 * bump(abs(t - 0.72), 0.45)
        for a in (-0.55, 0.0, 0.55):
            a2 = a + (h1(i * 13 + int(a * 10)) - 0.5) * 0.4
            place(pt, ax, a2, 0.4 * r + 0.75 * r * grow, 0.14 * r, 0.9, 0.85, 0.25, 0.05, 0.8)
    # Ruff: all the way round the neck, combed back over the shoulders.
    for i in range(40):
        t = 0.15 + 0.7 * ((i * 0.618) % 1.0)
        pt = sh.lerp(neck, t)
        a = (i / 40.0) * 2 * math.pi
        throat = 0.5 + 0.5 * math.cos(a - math.pi)
        place(pt, neck - sh, a, 0.6 * r + 0.3 * r * throat, 0.14 * r, 0.8, 0.7, 0.45, 0.25 + 0.5 * throat, 0.3)
    # Cheek tufts: back and out from behind the jaw hinge.
    for i in range(12):
        sx = -1 if i % 2 else 1
        pt = head + Vector((0, -0.15 * hr - 0.06 * hr * (i // 2), -0.15 * hr))
        place(pt, Vector((0, 1, 0)), sx * (1.3 + 0.15 * (i // 2)), 0.5 * hr, 0.16 * hr, 1.0, 0.6, 0.3, 0.45, 0.2)
    # Ragged belly line under the ribs.
    for i in range(20):
        t = (i + 0.5) / 20
        pt = chest.lerp(mid, t * 0.9)
        a = math.pi + (h1(i * 17) - 0.5) * 1.1
        place(pt, chest - mid, a, 0.38 * r, 0.12 * r, 0.6, 0.5, 0.9, 0.35, 0.0)
    # Haunches: shaggy breeches down the back of the thighs.
    for side in (-1, 1):
        for i in range(8):
            pt = hip + Vector((0, 0.02 * L, -0.25 * r - 0.08 * r * i))
            place(pt, Vector((0, 1, 0)), side * (1.8 + 0.12 * (i % 3)), 0.45 * r, 0.12 * r, 0.9, 0.5, 0.8, 0.2, 0.3)
    # Elbows and hocks: a few spurs of hair.
    for key in ("fl", "hl"):
        for side in (-1, 1):
            a, b = P(g, f"{key}{side}_1"), P(g, f"{key}{side}_2")
            for i in range(3):
                pt = a.lerp(b, 0.05 + 0.2 * i)
                place(pt, b - a, math.pi * (0.95 + 0.05 * i), 0.4 * r, 0.09 * r, 1.0, 0.4, 0.5, 0.1, 0.2)
    # Tail: ragged and heavy, hanging.
    tail = [P(g, "tail0")] + [P(g, f"tail_{i}") for i in range(3) if f"tail_{i}" in g.names]
    for i in range(36):
        t = 0.1 + 0.85 * (i + 0.5) / 36
        pt, ax = along(tail, t)
        a = (i * 2.4) % (2 * math.pi)
        place(pt, ax, a, 0.5 * r + 0.2 * r * t, 0.15 * r, 0.0, 0.6, 0.35, 0.15 + 0.3 * (1.0 - t), 0.4 * t)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.uv_layers.active = mesh.uv_layers["UVMap"]
    mesh.color_attributes.active_color = mesh.color_attributes["Col"]
    obj.data.materials.append(mat)
    return obj, cards


def card_weights_from_roots(obj, cards):
    """After distance weighting, every vertex of a card takes its root's weights."""
    verts = obj.data.vertices
    for start, end in cards:
        root = [(g.group, g.weight) for g in verts[start].groups]
        for vi in range(start + 1, end):
            for grp in list(verts[vi].groups):
                obj.vertex_groups[grp.group].remove([vi])
            for gi, w in root:
                obj.vertex_groups[gi].add([vi], w, "REPLACE")


# ---------------------------------------------------------------- mouth and eyes

def wedge_nose(obj, r):
    """Turns the nose ball into leather: a flat top sloping to a broad front
    pad, and a groove splitting the nostrils down the middle (mesh space,
    before the object's scale is applied)."""
    for v in obj.data.vertices:
        c = v.co
        # Top slopes down toward the front: a wedge, not a dome.
        cap = r * (0.55 - 0.45 * max(c.y, 0.0) / r)
        if c.z > cap:
            c.z = cap + (c.z - cap) * 0.25
        # Broad, flat front pad.
        if c.y > r * 0.6:
            c.y = r * 0.6 + (c.y - r * 0.6) * 0.4
        # The philtrum: a groove up the middle of the front and underside.
        if c.y > 0.0 and c.z < r * 0.3:
            c.y -= r * 0.3 * bump(abs(c.x), r * 0.22) * ss(c.y / r)
            c.z += r * 0.12 * bump(abs(c.x), r * 0.22) * ss(-c.z / r)
        v.co = c


def ear_plate(name, base, tip, radius, mat, flat=0.4):
    """A wolf ear: a six-sided cone flattened front to back, cupped forward."""
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=radius, radius2=0.0, depth=(tip - base).length)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((tip - base).normalized())
    obj.location = (base + tip) / 2
    obj.data.materials.append(mat)
    bpy.context.view_layer.update()
    obj.data.transform(obj.matrix_world)
    obj.matrix_world = obj.matrix_world.__class__.Identity(4)
    ax = (tip - base).normalized()
    for v in obj.data.vertices:
        q = v.co - base
        along = q.dot(ax)
        off = q - ax * along
        off.y *= flat
        v.co = base + ax * along + off
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def strand(name, top, bottom, radius, mat, segs=6, sag=0.0):
    """A thin tube from top to bottom (saliva). Returns (obj, t per vertex)."""
    bm = bmesh.new()
    rings = []
    axis = (bottom - top)
    side = axis.orthogonal().normalized()
    other = axis.normalized().cross(side)
    ts = []
    for i in range(segs + 1):
        t = i / segs
        c = top.lerp(bottom, t) + Vector((0, sag * math.sin(math.pi * t), 0))
        rr = radius * (1.0 - 0.5 * math.sin(math.pi * t))
        ring = []
        for k in range(4):
            a = k * math.pi / 2
            ring.append(bm.verts.new(c + (side * math.cos(a) + other * math.sin(a)) * rr))
            ts.append(t)
        rings.append(ring)
    for i in range(segs):
        for k in range(4):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % 4], rings[i + 1][(k + 1) % 4], rings[i + 1][k]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj, ts


def weight_blend(obj, ts, top_bone, bottom_bone):
    a = obj.vertex_groups.new(name=top_bone)
    b = obj.vertex_groups.new(name=bottom_bone)
    for i, t in enumerate(ts):
        w = ss(t)
        if w < 0.999:
            a.add([i], 1.0 - w, "REPLACE")
        if w > 0.001:
            b.add([i], w, "REPLACE")
