"""An opening mouth for heads on Feyre's face kit (lane L36).

The kit's head is one sealed surface; the mouth is a groove, so jaw_open and
the visemes only stretch skin, and nothing can show teeth.  This module:

1. cuts the lips apart along the groove (a bisect between the mouth corners,
   then the cut edges are split), so each lip has its own edge;
2. rolls each lip edge a few millimetres into the head (the inner lip);
3. fixes the base shape keys on the new vertices, so the lower lip rides the
   jaw and the upper lip stays: jaw_open and the visemes now part the lips;
4. builds "Mouth": a dark mouth bag, an upper and a lower row of teeth (with
   fangs where asked) and a tongue, skinned to Head (upper) and Jaw (lower), with
   the face keys the lower half needs (jaw_open and every key's jaw component).

Landmarks come from the base keys (see face_keys.Face).  Run before
face_keys.add_expression_keys (apply_face_keys.py does).  Idempotent: a body
already cut (custom property "mouth_cut") is left alone and only Mouth is rebuilt.
"""

import math

import bmesh
import bpy
import numpy as np

import face_keys as fk

DARK = (0.10, 0.018, 0.03)      # the inside of the mouth: deep rose-black, never grey


def _material(name, rgb, rough, emission=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m


def _line(f):
    """The groove's height and depth at the centre: halfway between the lowest upper-lip vertex and the
    highest lower-lip vertex near the midline (vis_MBP tells them apart)."""
    P = f.P
    cen = np.abs(P[:, 0]) < 0.25 * f.corner_x
    up = (f.upper_lip > 0.15) & cen
    lo = (f.lower_lip > 0.15) & cen
    z = 0.5 * (P[up, 2].min() + P[lo, 2].max())
    y = float(np.median(P[(f.lip > 0.15) & cen, 1]))
    return float(z), y


def cut(body, f):
    """Open the lips.  Returns the number of seam vertices (each now two)."""
    if body.get("mouth_cut"):
        return 0
    me = body.data
    z_line, _ = _line(f)
    half = 0.86 * f.corner_x
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    P = f.P
    P = f.P

    def in_region(fc, wide):
        return all(abs(P[v.index, 0]) < wide * f.corner_x and abs(P[v.index, 2] - z_line) < 0.016 * f.sv
                   and f.front[v.index] > 0.5 for v in fc.verts)

    # The kit's lips are a few big faces: split them finer (keys, weights and UVs interpolate) so the
    # cut has enough edges to curve and part smoothly.
    region = [fc for fc in bm.faces if in_region(fc, 1.45)]
    bmesh.ops.subdivide_edges(bm, edges=list({e for fc in region for e in fc.edges}), cuts=2, use_grid_fill=True)
    bm.verts.ensure_lookup_table()
    P = np.array([v.co[:] for v in bm.verts])
    region = [fc for fc in bm.faces
              if all(abs(P[v.index, 0]) < 1.35 * f.corner_x and abs(P[v.index, 2] - z_line) < 0.012 * f.sv
                     and P[v.index, 1] < f.mouth[1] + 0.012 * f.sh for v in fc.verts)]
    geom = list({e for fc in region for e in fc.edges}) + region + list({v for fc in region for v in fc.verts})
    res = bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=(0, 0, z_line), plane_no=(0, 0, 1))
    # every edge lying in the cut plane between the corners, whether bisect made it or a subdivision
    # vertex already sat on the plane
    del res
    seam = [e for e in bm.edges
            if all(abs(v.co.z - z_line) < 1e-4 and abs(v.co.x) < half and v.co.y < f.mouth[1] + 0.012 * f.sh
                   for v in e.verts)]
    bmesh.ops.split_edges(bm, edges=seam)
    bm.to_mesh(me)
    bm.free()
    me.update()
    body["mouth_cut"] = True
    body["mouth_z"] = z_line
    return len(seam)


def fix_seam_keys(body, z_line):
    """New seam vertices got shape-key positions interpolated across the lips, so both copies move alike.
    Give each copy the mean delta of its own lip's neighbours (above the cut for the upper lip, below for
    the lower).  Returns a per-vertex side array: +1 upper-lip seam copy, -1 lower, 0 elsewhere."""
    me = body.data
    n = len(me.vertices)
    P = np.empty(n * 3)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    on = np.abs(P[:, 2] - z_line) < 1e-4
    nbr = [[] for _ in range(n)]
    for e in me.edges:
        a, b = e.vertices
        nbr[a].append(b)
        nbr[b].append(a)
    side = np.zeros(n)
    kb = me.shape_keys.key_blocks
    base = np.empty(n * 3)
    kb["Basis"].data.foreach_get("co", base)
    base = base.reshape(-1, 3)
    plan = {}
    for i in np.where(on)[0]:
        ups = [j for j in nbr[i] if P[j, 2] > z_line + 1e-4]
        los = [j for j in nbr[i] if P[j, 2] < z_line - 1e-4]
        if ups and not los:
            side[i], plan[i] = 1, ups
        elif los and not ups:
            side[i], plan[i] = -1, los
    att = me.attributes.get("mouth_side") or me.attributes.new("mouth_side", "INT", "POINT")
    att.data.foreach_set("value", side.astype(np.int32))
    for k in kb[1:]:
        c = np.empty(n * 3)
        k.data.foreach_get("co", c)
        c = c.reshape(-1, 3)
        d = c - base
        for i, js in plan.items():
            c[i] = base[i] + d[js].mean(0)
        k.data.foreach_set("co", c.ravel())
    return side


def roll_lips(body, z_line, depth):
    """Extrude both lip edges into the head (the inner lip); new vertices copy their lip's keys."""
    me = body.data
    bm = bmesh.new()
    bm.from_mesh(me)
    edges = [e for e in bm.edges if e.is_boundary and all(abs(v.co.z - z_line) < 1e-4 for v in e.verts)]
    if not edges:
        bm.free()
        return 0
    layers = list(bm.verts.layers.shape.values())
    ret = bmesh.ops.extrude_edge_only(bm, edges=edges)
    new = [v for v in ret["geom"] if isinstance(v, bmesh.types.BMVert)]
    for v in new:
        src = next((e.other_vert(v) for e in v.link_edges if e.other_vert(v) not in new), None)
        upper = src is not None and any(o.co.z > z_line + 1e-4 for e in src.link_edges for o in [e.other_vert(src)])
        off = (0.0, depth, (0.0016 if upper else -0.0016))
        v.co.x *= 0.93
        v.co.y += off[1]
        v.co.z += off[2]
        for L in layers:
            if src is not None:
                d = src[L] - src.co
                v[L] = v.co + d if L.name != "Basis" else v.co.copy()
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.update()
    return len(new)


def _jaw(f, z_line):
    """The jaw's hinge, its jaw_open angle and the chin vertices that measure it."""
    hw = f.corner_x
    chin = (f.lower_lip > 0.3) | ((f.P[:, 2] < z_line - 0.01 * f.sv) & (f.front > 0.5) & (np.abs(f.P[:, 0]) < hw))
    ref = f.d["jaw_open"][chin].mean(0)
    # the hinge sits back by the ears at about the height of the nose's base
    piv = np.array([0.0, float(f.P[f.head > 0.5, 1].mean()) + 0.01 * f.sh, z_line + 0.035 * f.sv])
    mag = np.linalg.norm(f.d["jaw_open"], axis=1)
    tip = int(np.argmax(mag))                     # the chin point the key moves most: the jaw's full swing
    ang = float(mag[tip] / max(np.linalg.norm(f.P[tip] - piv), 1e-6))
    return piv, ang, chin, ref


def _rotate(V, piv, a):
    q = V - piv
    out = V.copy()
    out[:, 1] = piv[1] + q[:, 1] * math.cos(a) - q[:, 2] * math.sin(a)
    out[:, 2] = piv[2] + q[:, 1] * math.sin(a) + q[:, 2] * math.cos(a)
    return out


def rejaw(body, z_line):
    """The kit's jaw_open fades out before the lips, so a cut mouth barely parts.  Carry the lower lip
    (everything below the cut near the mouth) rigidly with the jaw, in jaw_open and in the jaw share of
    every other base key (the visemes)."""
    f = fk.Face(body)
    piv, ang, chin, ref = _jaw(f, z_line)
    rigid = _rotate(f.P, piv, ang) - f.P
    w = f.below * _gaussian(f.P, (0, 0, z_line), (1.5 * f.corner_x, 1, 0.016 * f.sv)) * (f.front > 0.2)
    w = np.clip(1.6 * w, 0.0, 1.0)[:, None]
    old = f.d["jaw_open"]
    new = (1 - w) * old + w * rigid
    kb = body.data.shape_keys.key_blocks
    for name in fk.FACE_BASE_KEYS:
        if name not in kb:
            continue
        d = f.d[name]
        amt = float(np.dot(d[chin].mean(0), ref) / max(np.dot(ref, ref), 1e-12))
        if name != "jaw_open" and amt < 0.02:
            continue
        a = 1.0 if name == "jaw_open" else amt
        kb[name].data.foreach_set("co", (f.P + d + a * (new - old)).ravel())


def _gaussian(P, c, sig):
    d = (P - np.asarray(c, float)) / np.asarray(sig, float)
    return np.exp(-np.sum(d * d, axis=1))


# ---------------------------------------------------------------- the Mouth mesh
def _ellipsoid(bm, c, r, segs=14, rings=8, inward=False):
    vs = []
    for i in range(rings + 1):
        th = math.pi * i / rings
        row = []
        for j in range(segs):
            ph = 2 * math.pi * j / segs
            row.append(bm.verts.new((c[0] + r[0] * math.sin(th) * math.cos(ph),
                                     c[1] + r[1] * math.sin(th) * math.sin(ph),
                                     c[2] + r[2] * math.cos(th))))
        vs.append(row)
    faces = []
    for i in range(rings):
        for j in range(segs):
            q = [vs[i][j], vs[i][(j + 1) % segs], vs[i + 1][(j + 1) % segs], vs[i + 1][j]]
            if i == 0:
                q = [vs[0][j], vs[1][(j + 1) % segs], vs[1][j]]
            elif i == rings - 1:
                q = [vs[i][j], vs[i][(j + 1) % segs], vs[i + 1][j]]
            try:
                fc = bm.faces.new(q[::-1] if inward else q)
                faces.append(fc)
            except ValueError:
                pass
    return faces


def build_mouth(body, f, arm, z_line, y_line, teeth_rgb=(0.97, 0.95, 0.92), fangs=0.0):
    """Mouth bag, teeth and tongue as one skinned mesh "Mouth".  fangs: extra canine length (m)."""
    old = bpy.data.objects.get("Mouth")
    if old is not None:
        bpy.data.objects.remove(old, do_unlink=True)
    sh, sv = f.sh, f.sv
    hw = f.corner_x
    me = bpy.data.meshes.new("Mouth")
    bm = bmesh.new()
    mats = [_material("mouth_inside", DARK, 0.6), _material("teeth", teeth_rgb, 0.25),
            _material("tongue", (0.55, 0.16, 0.20), 0.45)]
    lip_y = y_line + 0.0035 * sh                  # just behind the lips' surface
    # the bag: inside-out ellipsoid behind the lips
    bag = _ellipsoid(bm, (0, lip_y + 0.020 * sh, z_line - 0.002 * sv), (1.0 * hw, 0.016 * sh, 0.012 * sv),
                     inward=True)
    for fc in bag:
        fc.material_index = 0
    # teeth along an arc
    teeth = []
    n = 10
    for row, (dz, h) in enumerate(((-0.0019 * sv, 0.0078 * sv), (0.0008 * sv, 0.0066 * sv))):
        for i in range(n):
            t = (i + 0.5) / n * 2 - 1                       # -1..1 across the arc
            x = t * 0.80 * hw
            y = lip_y + 0.0024 * sh + 0.008 * sh * t * t     # the arc curves back
            w = 0.82 * hw * 2 / n * 0.86                     # neighbours just touch: a pearly row
            x = t * 0.82 * hw
            hh = h * (1.0 - 0.18 * abs(t))
            canine = row == 0 and abs(abs(t) - 0.5) < 0.1 and fangs > 0
            extra = fangs if canine else 0.0
            zc = z_line + (dz + hh * 0.5 - extra if row == 0 else dz - hh * 0.5)
            fcs = _ellipsoid(bm, (x, y, zc), (w * (0.8 if canine else 1.0), 0.0022 * sh, 0.5 * hh + extra),
                             segs=8, rings=5)
            for fc in fcs:
                fc.material_index = 1 if row == 0 else 3
            teeth.append((row, fcs))
    tongue = _ellipsoid(bm, (0, lip_y + 0.016 * sh, z_line - 0.008 * sv), (0.72 * hw, 0.012 * sh, 0.0040 * sv),
                        segs=12, rings=6)
    for fc in tongue:
        fc.material_index = 2
    bm.to_mesh(me)
    bm.free()
    for m in mats + [mats[1]]:          # slot 3: the lower row, same enamel
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new("Mouth", me)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    # skin: upper half on Head, lower half (lower teeth, tongue, bag floor) on Jaw
    V = np.array([v.co[:] for v in me.vertices])
    tooth_row = np.full(len(V), -1)
    for p in me.polygons:
        if p.material_index in (1, 3):
            for vi in p.vertices:
                tooth_row[vi] = 0 if p.material_index == 1 else 1
    lower = (V[:, 2] < z_line - 0.001 * sv) & (tooth_row != 0) | (tooth_row == 1)
    gh, gj = obj.vertex_groups.new(name="Head"), obj.vertex_groups.new(name="Jaw")
    for i in range(len(V)):
        (gj if lower[i] else gh).add([i], 1.0, "REPLACE")
    # face keys: the lower half follows the jaw part of every key, the upper half never moves
    obj.shape_key_add(name="Basis", from_mix=False)
    piv, ang, chin, ref = _jaw(f, z_line)
    keys = dict(f.d)
    keys.update(fk.deltas(f))
    for name in list(fk.FACE_BASE_KEYS) + list(fk.EXPRESSION_KEYS):
        d = keys[name][chin].mean(0)
        amt = float(np.dot(d, ref) / max(np.dot(ref, ref), 1e-12))
        a = ang * amt
        q = V - piv
        y2 = q[:, 1] * math.cos(a) - q[:, 2] * math.sin(a)
        z2 = q[:, 1] * math.sin(a) + q[:, 2] * math.cos(a)
        co = V.copy()
        co[lower, 1] = (piv[1] + y2)[lower]
        co[lower, 2] = (piv[2] + z2)[lower]
        sk = obj.shape_key_add(name=name, from_mix=False)
        sk.data.foreach_set("co", co.ravel())
        sk.value = 0.0
    return obj


def open_mouth(body, f, arm, fangs=0.0, teeth_rgb=(0.97, 0.95, 0.92)):
    """Cut, fix keys, roll the lips and build the Mouth.  Returns (seam vertices, Mouth object)."""
    z_line, y_line = _line(f)
    n = cut(body, f)
    if n:
        fix_seam_keys(body, z_line)
        roll_lips(body, z_line, 0.0025 * f.sh)
        rejaw(body, z_line)
    f2 = fk.Face(body)
    mouth = build_mouth(body, f2, arm, z_line, y_line, teeth_rgb=teeth_rgb, fangs=fangs)
    return n, mouth, f2
