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


# The opening's half-width never passes this (m, times the face's horizontal scale): wide painted lips
# (Feyre L41-3, corner_x 0.0175) must not carry the slit, the bag and the teeth out past the visible lip
# into the cheek, where the dark inside shows at the corners as a dimple (F35).
SEAM_HALF_MAX = 0.0105


def smooth_corners(body, f, iters=14):
    """Relax the skin around the two mouth corners before the cut.  A surface-nets sculpt can leave tiny
    pits and folds there (Feyre L41-3) that read as pale flecks at rest and a dark dimple once a smile
    or a pressed lip deepens them (F35).  Every shape key moves by the same amount as the basis, so the
    keys keep their shapes.  Returns the number of vertices touched."""
    me = body.data
    n = len(me.vertices)
    z_line, _ = _line(f)
    P = f.P.copy()
    w = np.zeros(n)
    for sx in (-1.0, 1.0):
        c = np.array([sx * f.corner_x, f.mouth[1], z_line])
        d2 = ((P - c) / np.array([0.0075 * f.sh, 0.008 * f.sh, 0.0045 * f.sv])) ** 2
        w = np.maximum(w, np.exp(-0.5 * d2.sum(1)))
    w *= f.front > 0.2
    w[w < 0.05] = 0.0
    nbr = [[] for _ in range(n)]
    for e in me.edges:
        a, b = e.vertices
        nbr[a].append(b)
        nbr[b].append(a)
    idx = np.where(w > 0)[0]
    Q = P.copy()
    for _ in range(iters):
        R = Q.copy()
        for i in idx:
            if nbr[i]:
                R[i] = Q[i] + 0.5 * w[i] * (Q[nbr[i]].mean(0) - Q[i])
        Q = R
    # folded triangles (facing into the head) survive a gentle relax: pull their corners fully onto
    # their neighbours' mean until the surface faces out again
    polys = [list(p.vertices) for p in me.polygons if any(w[v] > 0 for v in p.vertices)]
    for _ in range(12):
        flipped = set()
        for vs in polys:
            a, b, c = Q[vs[0]], Q[vs[1]], Q[vs[2]]
            if np.cross(b - a, c - a)[1] > 0.0:
                flipped.update(vs)
        if not flipped:
            break
        for i in flipped:
            if nbr[i] and w[i] > 0:
                Q[i] = Q[nbr[i]].mean(0)
    shift = Q - P
    for k in me.shape_keys.key_blocks:
        c = np.empty(n * 3)
        k.data.foreach_get("co", c)
        k.data.foreach_set("co", (c.reshape(-1, 3) + shift).ravel())
    me.vertices.foreach_set("co", Q.ravel())
    me.update()
    # what collapsed to nothing goes: merge the slivers (shape-key layers merge with them)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    region = {bm.verts[i] for i in idx}
    edges = [e for e in bm.edges if e.verts[0] in region or e.verts[1] in region]
    bmesh.ops.dissolve_degenerate(bm, dist=0.00035 * f.sh, edges=edges)
    bmesh.ops.triangulate(bm, faces=[fc for fc in bm.faces if len(fc.verts) > 4])
    bm.to_mesh(me)
    bm.free()
    me.update()
    return int(len(idx))


def mouth_hw(f):
    """Half-width of the mouth's inside (bag and teeth): the lip corners, capped."""
    return min(f.corner_x, SEAM_HALF_MAX * f.sh / 0.86)


def seam_half(f):
    """Half-width of the lip seam that is cut open."""
    return 0.86 * mouth_hw(f)


def cut(body, f):
    """Open the lips.  Returns the number of seam vertices (each now two)."""
    if body.get("mouth_cut"):
        return 0
    me = body.data
    z_line, _ = _line(f)
    half = seam_half(f)
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
    body["mouth_half"] = half
    return len(seam)


def _mark_sides(me, z_line):
    """Mark every vertex on the cut plane with its lip in "mouth_side" (1 upper, -1 lower, 0 neither or
    both), from its neighbours off the plane."""
    P = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    up = np.zeros(len(P), bool)
    lo = np.zeros(len(P), bool)
    E = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", E)
    E = E.reshape(-1, 2)
    for a, b in ((E[:, 0], E[:, 1]), (E[:, 1], E[:, 0])):
        up[a[P[b, 2] > z_line + 1e-4]] = True
        lo[a[P[b, 2] < z_line - 1e-4]] = True
    plane = np.abs(P[:, 2] - z_line) < 1e-4
    side = np.where(plane & up & ~lo, 1, np.where(plane & lo & ~up, -1, 0)).astype(np.int32)
    att = me.attributes.get("mouth_side") or me.attributes.new("mouth_side", "INT", "POINT")
    att.data.foreach_set("value", side)
    return side


def finish_cut(body, z_line, f):
    """Finish the cut where it stopped short.  Along a few stretches of the seam the two copies of a seam
    vertex went to the wrong lips, so a face (a flat one on the seam, or a piece of the rolled inner lip)
    runs from one lip at one end to the other lip at the other: as the jaw opens it stretches into a pale
    flap across the mouth and over the teeth.  Each such face is rebuilt once for each lip that holds two
    or more of its corners, with every corner of the other lip swapped for the nearest vertex of this one,
    so both lips keep a whole edge and roll; a vertex left joining two fans of faces is split in two, so
    the opening stays one clean loop.  Then every seam vertex is marked with its lip in "mouth_side".
    Returns the faces rebuilt."""
    from mathutils.kdtree import KDTree
    me = body.data
    side = _mark_sides(me, z_line)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    half = float(np.abs(np.array([v.co.x for v in bm.verts if abs(v.co.z - z_line) < 0.003 and v.is_boundary
                                  and abs(v.co.x) < 1.6 * f.corner_x] or [0.0])).max())
    band = 0.001 * f.sv

    def lip(v):
        dz = v.co.z - z_line
        return 1 if dz > band else -1 if dz < -band else int(side[v.index]) if abs(dz) < 1e-4 else 0
    zone = lambda v: abs(v.co.x) < half - 1e-5 and abs(v.co.z - z_line) < 0.004 * f.sv and f.front[v.index] > 0.3
    bridge = [fc for fc in bm.faces if all(zone(v) for v in fc.verts) and {1, -1} <= {lip(v) for v in fc.verts}]
    if bridge:
        trees = {}
        for L in (1, -1):
            vs = [v for v in bm.verts if zone(v) and lip(v) == L]
            t = KDTree(len(vs))
            for k, v in enumerate(vs):
                t.insert((v.co.x, v.co.y, 0.0), k)
            t.balance()
            trees[L] = (t, vs)
        uv = bm.loops.layers.uv.active
        for fc in bridge:
            corners = [(lp.vert, lp[uv].uv.copy() if uv is not None else None) for lp in fc.loops]
            for L in (1, -1):
                if sum(lip(v) == L for v, _ in corners) < 2:
                    continue
                t, vs = trees[L]
                verts, uvs = [], []
                kept = {v for v, _ in corners if lip(v) != -L}
                for v, u in corners:
                    w = v
                    if lip(v) == -L:
                        # the nearest of this lip; of a stack of coincident copies, one joined to the face's
                        # own corners, or the lip edge would fork
                        _, _, d = t.find((v.co.x, v.co.y, 0.0))
                        cand = [vs[k] for _, k, _ in t.find_range((v.co.x, v.co.y, 0.0), d + 1e-6)]
                        joined = [c for c in cand if any(e.other_vert(c) in kept for e in c.link_edges)]
                        w = (joined or cand)[0]
                    if w not in verts:
                        verts.append(w)
                        uvs.append(u)
                if len(verts) < 3 or bm.faces.get(verts) is not None:
                    continue
                busy = [bm.edges.get((verts[i - 1], verts[i])) for i in range(len(verts))]
                if any(e is not None and len([g for g in e.link_faces if g not in bridge]) >= 2 for e in busy):
                    continue        # that lip is whole there already
                g = bm.faces.new(verts, fc)
                if uv is not None:
                    for lp, u in zip(g.loops, uvs):
                        lp[uv].uv = u
        bmesh.ops.delete(bm, geom=bridge, context="FACES_ONLY")
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        for v in [v for v in bm.verts if sum(e.is_boundary for e in v.link_edges) > 2]:
            bmesh.utils.vert_separate(v, [e for e in v.link_edges if e.is_boundary])
        bm.to_mesh(me)
        me.update()
    n = len(bridge)
    bm.free()
    _mark_sides(me, z_line)
    return n


def seal_slivers(body, z_line, f):
    """Fill the three- and four-vertex holes the cut leaves in a lip where a split edge met a subdivision
    vertex: shut, they are invisible, but every key that parts the lips pulls them open into pinholes
    through the lip.  No vertices are added, so weights and keys stand.  Returns how many were filled."""
    me = body.data
    bm = bmesh.new()
    bm.from_mesh(me)
    near = lambda v: abs(v.co.x) < 1.6 * f.corner_x and abs(v.co.z - z_line) < 0.02 * f.sv
    side_l = bm.verts.layers.int.get("mouth_side")
    lip = lambda v: (1 if v.co.z > z_line + 1e-4 else -1 if v.co.z < z_line - 1e-4
                     else (v[side_l] if side_l is not None else 0))
    edges = [e for e in bm.edges if e.is_boundary and all(near(v) for v in e.verts)]
    # the boundary in loops; a small loop on one lip is a pinhole, but one with both lips in it is the
    # mouth's own slit at a corner, which must stay open or the fill joins the lips into a flap
    left, keep = set(edges), []
    while left:
        loop, todo = set(), [left.pop()]
        while todo:
            e = todo.pop()
            loop.add(e)
            for v in e.verts:
                for g in v.link_edges:
                    if g in left:
                        left.discard(g)
                        todo.append(g)
        vs = {v for e in loop for v in e.verts}
        if len(vs) <= 6 and len({lip(v) for v in vs} - {0}) < 2:
            keep += loop
    made = bmesh.ops.holes_fill(bm, edges=keep, sides=6)["faces"] if keep else []
    uv = bm.loops.layers.uv.active
    for fc in made:
        nb = [g for e in fc.edges for g in e.link_faces if g is not fc]
        if nb:
            fc.material_index = nb[0].material_index
            fc.smooth = nb[0].smooth
        if uv is not None:
            for lp in fc.loops:
                other = [l for l in lp.vert.link_loops if l.face is not fc]
                if other:
                    lp[uv].uv = other[0][uv].uv
    bm.normal_update()
    for fc in made:                      # face the same way as the skin around it
        nb = [g for e in fc.edges for g in e.link_faces if g is not fc]
        if nb and fc.normal.dot(nb[0].normal) < 0:
            fc.normal_flip()
    if made:
        bm.to_mesh(me)
        me.update()
    bm.free()
    return len(made)


def settle_lip_edges(body, z_line, f):
    """Make each lip's edge move as one piece with that lip, in every key.  rejaw carries the lower lip
    with the jaw by a weight that fades across the lip line, so the lower lip's last few rows (the seam
    copies on the cut plane and subdivision vertices a hair below it) lag behind, and the rolled inner lip,
    which copied its keys from the seam before rejaw ran, stays up with them: as the jaw opens that strip
    stretches into pale skin flaps across the open mouth.  Here every lower-lip vertex near the line takes
    the delta of the lower lip a few millimetres down and every upper-lip vertex near it that of the upper
    lip a few millimetres up (both fading out toward the corners, which fix_seam_keys keeps sealed), upper
    seam copies take their own lip's mean, and every inner-lip vertex takes its seam copy's delta.  Idempotent; the rest shape is untouched.  Returns the vertices moved."""
    me = body.data
    n = len(me.vertices)
    P = np.empty(n * 3)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    att = me.attributes.get("mouth_side")
    side = np.zeros(n, dtype=np.int32)
    if att is not None:
        att.data.foreach_get("value", side)
    nbr = [[] for _ in range(n)]
    count = {}
    for p in me.polygons:
        for ek in p.edge_keys:
            count[ek] = count.get(ek, 0) + 1
    for e in me.edges:
        a, b = e.vertices
        nbr[a].append(b)
        nbr[b].append(a)
    region = (np.abs(P[:, 0]) < 1.6 * f.corner_x) & (np.abs(P[:, 2] - z_line) < 0.02 * f.sv) & (f.front > 0.3)
    inner = sorted({i for (a, b), c in count.items() if c == 1 for i in (a, b) if region[i]})
    inner_set = set(inner)
    if not inner:
        return 0
    half = float(np.abs(P[inner, 0]).max())
    plane = np.abs(P[:, 2] - z_line) < 1e-4
    corner = np.clip((np.abs(P[:, 0]) - 0.5 * half) / (0.5 * half), 0.0, 1.0)
    # the lower lip near the line, and where each one takes its motion from: the lower lip 2.5-6 mm down
    lower = [i for i in np.where(region & (np.abs(P[:, 0]) < half))[0]
             if i not in inner_set and ((plane[i] and side[i] < 0) or (z_line - 0.002 * f.sv < P[i, 2] < z_line - 1e-5))]
    pool = np.where(region & (P[:, 2] < z_line - 0.0025 * f.sv) & (P[:, 2] > z_line - 0.006 * f.sv))[0]
    from mathutils.kdtree import KDTree
    tree = KDTree(len(pool))
    for k, i in enumerate(pool):
        tree.insert((P[i, 0], P[i, 1], 0.0), k)
    tree.balance()
    anchor = {i: pool[tree.find((P[i, 0], P[i, 1], 0.0))[1]] for i in lower} if len(pool) else {}
    # and the same above the line: the fade leaves the upper lip's last rows sagging with the jaw
    upper_band = [i for i in np.where(region & (np.abs(P[:, 0]) < half))[0]
                  if i not in inner_set and z_line + 1e-4 < P[i, 2] < z_line + 0.002 * f.sv]
    pool_up = np.where(region & (P[:, 2] > z_line + 0.0025 * f.sv) & (P[:, 2] < z_line + 0.006 * f.sv))[0]
    if len(pool_up):
        tree_up = KDTree(len(pool_up))
        for k, i in enumerate(pool_up):
            tree_up.insert((P[i, 0], P[i, 1], 0.0), k)
        tree_up.balance()
        anchor.update({i: pool_up[tree_up.find((P[i, 0], P[i, 1], 0.0))[1]] for i in upper_band})
    upper = [i for i in np.where(plane & (side > 0))[0] if i not in inner_set]
    own_up = {i: [j for j in nbr[i] if j not in inner_set and P[j, 2] > z_line + 1e-4] for i in upper}
    own_up = {i: js for i, js in own_up.items() if js}
    # each inner-lip vertex rides the seam vertex it was rolled from (or, failing that, its own lip's nearest)
    src = {}
    for r in inner:
        s_ = [j for j in nbr[r] if plane[j] and j not in inner_set]
        if s_:
            src[r] = s_[0]
    kb = me.shape_keys.key_blocks
    base = np.empty(n * 3)
    kb["Basis"].data.foreach_get("co", base)
    base = base.reshape(-1, 3)
    for k in kb[1:]:
        c = np.empty(n * 3)
        k.data.foreach_get("co", c)
        c = c.reshape(-1, 3)
        d = c - base
        new = d.copy()
        for i, a in anchor.items():
            new[i] = d[i] + (1.0 - corner[i]) * (d[a] - d[i])
        for i, js in own_up.items():
            new[i] = d[i] + (1.0 - corner[i]) * (d[js].mean(0) - d[i])
        for r, i in src.items():
            new[r] = new[i]
        k.data.foreach_set("co", (base + new).ravel())
    return len(anchor) + len(own_up) + len(src)


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
    half = float(body.get("mouth_half", np.abs(P[on, 0]).max() if on.any() else 0.01))
    by_pos = {}
    for i in plan:
        by_pos.setdefault((round(P[i, 0], 6), round(P[i, 1], 6)), []).append(i)
    pairs = [(a, b) if side[a] > 0 else (b, a) for a, b in (v for v in by_pos.values() if len(v) == 2)
             if side[a] != side[b]]
    att = me.attributes.get("mouth_side") or me.attributes.new("mouth_side", "INT", "POINT")
    att.data.foreach_set("value", side.astype(np.int32))
    for k in kb[1:]:
        c = np.empty(n * 3)
        k.data.foreach_get("co", c)
        c = c.reshape(-1, 3)
        d = c - base
        own = {i: d[js].mean(0) for i, js in plan.items()}
        for i in own:
            c[i] = base[i] + own[i]
        # toward the corners the two lips' copies share one delta, so the slit's ends stay sealed and the
        # inside never shows as a dark dimple there (F35); the middle parts freely
        for u, lo in pairs:
            t = min(max((abs(P[u, 0]) - 0.5 * half) / (0.5 * half), 0.0), 1.0)
            if t > 0.0:
                m = 0.5 * (own[u] + own[lo])
                c[u] = base[u] + own[u] + t * (m - own[u])
                c[lo] = base[lo] + own[lo] + t * (m - own[lo])
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
    # past the slit's ends the skin is one piece: there the jaw's share fades smoothly across the lip line
    # instead of stepping at it, or every key with a jaw share (jaw_open, the visemes, lip_press,
    # jaw_clench) folds the cheek along the line into a pale crease (F35)
    half = float(body.get("mouth_half", 0.86 * f.corner_x))
    t = np.clip((np.abs(f.P[:, 0]) - 0.6 * half) / (0.4 * half), 0.0, 1.0)
    soft = np.clip(0.5 + (z_line - f.P[:, 2]) / (0.010 * f.sv), 0.0, 1.0)
    below = (1.0 - t) * f.below + t * soft
    w = below * _gaussian(f.P, (0, 0, z_line), (1.5 * f.corner_x, 1, 0.016 * f.sv)) * (f.front > 0.2)
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
def _ellipsoid(bm, c, r, segs=14, rings=8):
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
                fc = bm.faces.new(q)
                faces.append(fc)
            except ValueError:
                pass
    return faces


def _lip_loop(body, f, z_line):
    """The opening's edge: the cut's boundary loop near the mouth, in order.  Returns body vertex indices."""
    me = body.data
    near = lambda v: abs(v.co.x) < 1.6 * f.corner_x and abs(v.co.z - z_line) < 0.02 * f.sv and f.front[v.index] > 0.3
    nbr = {}
    count = {}
    for p in me.polygons:
        for ek in p.edge_keys:
            count[ek] = count.get(ek, 0) + 1
    V = me.vertices
    for (a, b), c in count.items():
        if c == 1 and near(V[a]) and near(V[b]):
            nbr.setdefault(a, []).append(b)
            nbr.setdefault(b, []).append(a)
    if not nbr or any(len(n) != 2 for n in nbr.values()):
        raise RuntimeError("the lip opening is not a clean loop (%d boundary vertices)" % len(nbr))
    # the opening is the longest loop (the cut can also leave a few three-vertex slivers in a lip)
    loops, seen = [], set()
    for start in sorted(nbr, key=lambda i: V[i].co.x):
        if start in seen:
            continue
        loop, prev = [start], None
        while True:
            nxt = [n for n in nbr[loop[-1]] if n != prev][0]
            if nxt == start:
                break
            prev = loop[-1]
            loop.append(nxt)
        seen.update(loop)
        loops.append(loop)
    loop = max(loops, key=len)
    return loop


# The bag's rings behind the rim: (depth behind the rim, share of the way from the lip opening to the
# ring's ellipse, ellipse size).  It opens to full size within 4 mm, so the teeth just behind sit inside it.
BAG_PROFILE = ((0.0, 0.0, 1.0), (0.0015, 0.55, 1.0), (0.0035, 0.92, 1.0), (0.007, 1.0, 1.0), (0.012, 1.0, 0.97),
               (0.018, 1.0, 0.86), (0.024, 1.0, 0.68), (0.029, 1.0, 0.47), (0.033, 1.0, 0.26))
BAG_DEPTH = 0.035
# How fully each of the first rings follows its lip vertex in every key (the rest follow the jaw): the
# collar moves with the lips as one piece, so no fold opens between the lip edge and the bag.
RIM_FOLLOW = (1.0, 1.0, 1.0, 0.6, 0.25)
BAG_SQUARENESS = 3.0            # 2 is an ellipse; higher is boxier
BAG_FLOOR_SHALLOW = 0.15        # the floor rides the jaw: kept shallow so it stays inside the chin
SKIN_CLEARANCE = 0.002          # the bag and tongue keep this far inside the skin in every key (m, times the scale):
                                # the bag's faces are long, and a straight face between two vertices inside
                                # the hollow under the lower lip still cuts through it
TEETH_BEHIND_RIM = 0.0045       # the tooth rows' front, behind the lip edge at the middle (m, times the face's scale)


def _loop_angles(Q):
    """Angle round the opening for each vertex of the lip loop (which starts at the left corner)."""
    n = len(Q)
    right = int(np.argmax(Q[:, 0]))
    seg = np.linalg.norm(np.roll(Q, -1, axis=0) - Q, axis=1)          # i -> i+1
    ang = np.zeros(n)
    first = np.arange(0, right + 1)
    second = np.arange(right, n + 1) % n
    for idx, a0, a1 in ((first, math.pi, 0.0), (second, 0.0, -math.pi)):
        cum = np.concatenate([[0.0], np.cumsum(seg[idx[:-1]])])
        t = cum / max(cum[-1], 1e-9)
        ang[idx] = a0 + (a1 - a0) * t
    ang[0] = math.pi
    if Q[first[len(first) // 2], 2] < Q[second[len(second) // 2], 2]:   # the loop runs along the lower lip first
        ang = -ang
        ang[0] = math.pi
    return ang


def _bag(bm, body, f, z_line, hw):
    """The inside of the mouth: a dark sock whose open end is the lip opening itself (so no corner can show
    past it), widening behind the lips to hold the teeth, then closing
    deep in the head.  Faces point inward.  Returns (faces, rim, y_mid): rim = [(bag vertex, body vertex,
    weight)] for the rings that follow the lips (RIM_FOLLOW), y_mid the lip edge's depth at the middle."""
    sh, sv = f.sh, f.sv
    loop = _lip_loop(body, f, z_line)
    Q = np.array([body.data.vertices[i].co[:] for i in loop])
    zc = z_line - 0.002 * sv
    half_open = float(np.abs(Q[:, 0]).max())
    ax = max(1.15 * hw, half_open + 0.0015 * sh)       # widest: the tooth arc fits with room
    bz = 0.0125 * sv
    # each lip vertex keeps its place round the opening on every ring: the corners at angles 0 and pi, the
    # upper lip spread by its length over the bag's roof and the lower lip over its floor
    ang = _loop_angles(Q)
    # the rim sits exactly on the lip edge: any tuck opens a slit between the two that a downward look
    # into an open mouth passes straight through
    R0 = Q.copy()
    y_back = float(R0[:, 1].max())                     # the rings behind the rim are flat, behind all of it
    ring_vs = []
    for k, (dy, blend, g) in enumerate(BAG_PROFILE):
        if k == 0:
            pts = R0
        else:
            ca, sa = np.cos(ang), np.sin(ang)
            cx_ = np.sign(ca) * np.abs(ca) ** (2.0 / BAG_SQUARENESS)     # a rounded box, so the tooth rows'
            sz_ = np.sign(sa) * np.abs(sa) ** (2.0 / BAG_SQUARENESS)     # ends fit at every height
            floor = np.where(sa < 0.0, 1.0 - BAG_FLOOR_SHALLOW, 1.0)
            e = np.stack([ax * g * cx_, np.zeros(len(Q)), zc + bz * g * sz_ * floor], 1)
            pts = (1.0 - blend) * R0 + blend * e
            pts[:, 1] = (1.0 - blend) * R0[:, 1] + blend * y_back + dy * sh   # curved like the lips, then flat
        ring_vs.append([bm.verts.new(tuple(p)) for p in pts])
    tip = bm.verts.new((0.0, y_back + BAG_DEPTH * sh, zc))
    faces = []
    n = len(Q)
    for k in range(len(ring_vs) - 1):
        a, b = ring_vs[k], ring_vs[k + 1]
        for i in range(n):
            faces.append(bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i])))
    last = ring_vs[-1]
    for i in range(n):
        faces.append(bm.faces.new((last[i], last[(i + 1) % n], tip)))
    # inward: a face's normal points at the bag's axis
    bm.normal_update()
    axis_pt = lambda c: np.array([0.0, c[1], zc])
    deep = faces[3 * n:]                # past the collar the bag is a plain ellipsoid: vote there
    votes = sum(1 if np.dot(np.array(fc.normal[:]), axis_pt(fc.calc_center_median()) - np.array(fc.calc_center_median()[:])) > 0 else -1
                for fc in deep)
    if votes < 0:
        for fc in faces:
            fc.normal_flip()
    bm.verts.index_update()
    rim = [(v.index, bi, w) for ring, w in zip(ring_vs, RIM_FOLLOW) for v, bi in zip(ring, loop)]
    y_mid = float(np.median(Q[np.abs(Q[:, 0]) < 0.3 * half_open, 1]))     # the lip edge at the middle
    return faces, rim, y_mid


def _keep_inside(co, idx, body_co, polys, sh):
    """Pull the vertices idx of co back under the skin body_co (the Body in one key): the bag and tongue
    turn with the jaw as one piece while the chin's skin bends, so an open jaw would push the bag's floor
    out under the chin, and the mouth's materials are two-sided.  A vertex is outside when most rays
    from it, all aimed away from the lip opening, cross the skin an even number of times; an outside
    vertex, or one inside but nearer the skin than SKIN_CLEARANCE, goes to that depth under the nearest
    skin."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    tris = [(p[0], p[k], p[k + 1]) for p in polys for k in range(1, len(p) - 1)]
    bvh = BVHTree.FromPolygons([Vector(v) for v in body_co], tris)
    dirs = [Vector(d).normalized() for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, 1, 1), (0, 1, -1), (0, 0, -1))]
    clear = SKIN_CLEARANCE * sh

    def crossings(p, d):
        n, q = 0, p.copy()
        for _ in range(16):
            hit, _, _, _ = bvh.ray_cast(q, d)
            if hit is None:
                return n
            n += 1
            q = hit + d * 1e-6
        return n

    moved = 0
    for i in idx:
        p = Vector(co[i])
        hit, nrm, _, dist = bvh.find_nearest(p)
        if hit is None:
            continue
        if sum(crossings(p, d) % 2 for d in dirs) * 2 > len(dirs):          # inside
            if dist >= clear or (p - hit).dot(nrm) > 0.0:
                continue    # deep enough, or behind a lip's rolled edge (which faces into the mouth)
        co[i] = (hit - nrm * clear)[:]
        moved += 1
    return moved


def build_mouth(body, f, arm, z_line, y_line, teeth_rgb=(0.97, 0.95, 0.92), fangs=0.0):
    """Mouth bag, teeth and tongue as one skinned mesh "Mouth".  fangs: extra canine length (m)."""
    old = bpy.data.objects.get("Mouth")
    if old is not None:
        old_me = old.data
        bpy.data.objects.remove(old, do_unlink=True)
        if old_me is not None and old_me.users == 0:
            bpy.data.meshes.remove(old_me)      # else the rebuild is named "Mouth.001" in the glb
    sh, sv = f.sh, f.sv
    hw = mouth_hw(f)
    me = bpy.data.meshes.new("Mouth")
    bm = bmesh.new()
    mats = [_material("mouth_inside", DARK, 0.6), _material("teeth", teeth_rgb, 0.25),
            _material("tongue", (0.55, 0.16, 0.20), 0.45)]
    lip_y = y_line + 0.0035 * sh                  # just behind the lips' surface
    # the bag, sealed to the inner lips (its first ring rides the lip edge in every key)
    bag, rim, y_rim = _bag(bm, body, f, z_line, hw)    # y_rim: the lip edge's depth at the middle
    for fc in bag:
        fc.material_index = 0
    # teeth along an arc
    teeth = []
    n = 10
    for row, (dz, h) in enumerate(((-0.0019 * sv, 0.0078 * sv), (0.0008 * sv, 0.0066 * sv))):
        for i in range(n):
            t = (i + 0.5) / n * 2 - 1                       # -1..1 across the arc
            x = t * 0.80 * hw
            y = y_rim + (TEETH_BEHIND_RIM + 0.0022) * sh + 0.006 * sh * t * t     # the arc curves back
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
    tongue = _ellipsoid(bm, (0, y_rim + 0.017 * sh, z_line - 0.0065 * sv), (0.70 * hw, 0.011 * sh, 0.0034 * sv),
                        segs=12, rings=6)
    for fc in tongue:
        fc.material_index = 2
    # A UV layer, though the mouth's materials are flat colours: Godot's importer generates
    # tangents for every surface and logs "UVs are required to generate tangents" once per
    # surface and shape key (156 lines a cast glb) when a mesh has none.  A front projection
    # with a little depth mixed in keeps the triangles from collapsing to zero UV area.
    uv = bm.loops.layers.uv.new("UVMap")
    span = 4.0 * hw
    for fc in bm.faces:
        for lp in fc.loops:
            x, y, z = lp.vert.co
            lp[uv].uv = (0.5 + (x + 0.5 * (y - lip_y)) / span, 0.5 + (z - z_line + 0.5 * (y - lip_y)) / span)
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
    # what must stay under the skin: the bag past its first ring (which is the lip edge), and the tongue
    collar = {vi for vi, bi, w in rim[:len(rim) // len(RIM_FOLLOW)]}
    inside = sorted({v for p in me.polygons if p.material_index in (0, 2) for v in p.vertices} - collar)
    BP = np.array([v.co[:] for v in body.data.vertices])
    polys = [tuple(p.vertices) for p in body.data.polygons]     # all of it, or a ray can leave by a cut edge
    V = np.array([v.co[:] for v in me.vertices])
    _keep_inside(V, inside, BP, polys, sh)          # the rest shape too: a fold of the collar can rise into the lip
    me.vertices.foreach_set("co", V.ravel())
    # skin: upper half on Head, lower half (lower teeth, tongue, bag floor) on Jaw
    tooth_row = np.full(len(V), -1)
    for p in me.polygons:
        if p.material_index in (1, 3):
            for vi in p.vertices:
                tooth_row[vi] = 0 if p.material_index == 1 else 1
    lower = (V[:, 2] < z_line - 0.001 * sv) & (tooth_row != 0) | (tooth_row == 1)
    gh, gj = obj.vertex_groups.new(name="Head"), obj.vertex_groups.new(name="Jaw")
    for i in range(len(V)):
        (gj if lower[i] else gh).add([i], 1.0, "REPLACE")
    # the rim takes its lip vertex's own Head/Jaw split, so pose and keys move both together
    hi, ji = body.vertex_groups.get("Head"), body.vertex_groups.get("Jaw")
    for vi, bi, w in rim:
        if w < 1.0:
            continue
        gw = {g.group: g.weight for g in body.data.vertices[bi].groups}
        h, j = gw.get(hi.index, 0.0) if hi else 1.0, gw.get(ji.index, 0.0) if ji else 0.0
        tot = max(h + j, 1e-6)
        gh.add([vi], h / tot, "REPLACE")
        gj.add([vi], j / tot, "REPLACE")
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
        for vi, bi, w in rim:                       # the collar rides the lip edge it hangs from
            co[vi] = (1.0 - w) * co[vi] + w * (V[vi] + keys[name][bi])
        _keep_inside(co, inside, BP + keys[name], polys, sh)
        sk = obj.shape_key_add(name=name, from_mix=False)
        sk.data.foreach_set("co", co.ravel())
        sk.value = 0.0
    return obj


def open_mouth(body, f, arm, fangs=0.0, teeth_rgb=(0.97, 0.95, 0.92)):
    """Cut, fix keys, roll the lips and build the Mouth.  Returns (seam vertices, Mouth object)."""
    if not body.get("mouth_cut"):
        smooth_corners(body, f)
        f = fk.Face(body)
    z_line, y_line = _line(f)
    n = cut(body, f)
    if n:
        fix_seam_keys(body, z_line)
        roll_lips(body, z_line, 0.0025 * f.sh)
        rejaw(body, z_line)
    zc = float(body.get("mouth_z", z_line))       # the plane the cut was made on
    finish_cut(body, zc, fk.Face(body))
    seal_slivers(body, zc, fk.Face(body))
    settle_lip_edges(body, zc, fk.Face(body))
    f2 = fk.Face(body)
    mouth = build_mouth(body, f2, arm, z_line, y_line, teeth_rgb=teeth_rgb, fangs=fangs)
    return n, mouth, f2
