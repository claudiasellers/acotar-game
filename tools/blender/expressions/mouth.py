"""An opening mouth for heads on Feyre's face kit (lane L36).

The kit's head is one sealed surface; the mouth is a groove, so jaw_open and
the visemes only stretch skin, and nothing can show teeth.  This module:

1. cuts the lips apart along the groove (a bisect between the mouth corners,
   then the cut edges are split), so each lip has its own edge;
2. rolls each lip edge a few millimetres into the head (the inner lip);
3. fixes the base shape keys on the new vertices, so the lower lip rides the
   jaw and the upper lip stays: jaw_open and the visemes now part the lips;
4. finishes the cut where it crossed over, closes the notches and pinholes it
   leaves, lays the inner lips flat and dark, and makes the lip edges move with
   their own lips;
5. closes the opening with a dark mouth bag that is part of the Body (its first
   ring is the lip edge, so no gap opens between lip and bag);
6. builds "Mouth": an upper and a lower row of teeth (with fangs where asked) and
   a tongue, skinned to Head (upper) and Jaw (lower), with the face keys the lower
   half needs (jaw_open and every key's jaw component).

Landmarks come from the base keys (see face_keys.Face); the mouth's are pinned
on the first run.  Run before face_keys.add_expression_keys, then hold_upper_lip
and fit_bag after it (apply_face_keys.py does).  Idempotent: a body
already cut (custom property "mouth_cut") is not cut again; the bag and Mouth are rebuilt.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

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


def _wind_like_neighbours(faces):
    """Wind each new face as the faces it joins: a shared edge runs one way in one face and the other way
    in the next.  (A neighbour's normal is no guide at the lip edge, where the inner lip faces into the
    mouth.)  A face wound backwards turns its back and shows as a dark shard through the lip."""
    for g in faces:
        same = opp = 0
        for lp in g.loops:
            for other in lp.edge.link_loops:
                if other.face is not g:
                    if other.vert is lp.vert:
                        same += 1
                    else:
                        opp += 1
        if same > opp:
            g.normal_flip()


def finish_cut(body, z_line, f):
    """Finish the cut where it stopped short.  Along a few stretches of the seam the two copies of a seam
    vertex went to the wrong lips, so a face (a flat one on the seam, or a piece of the rolled inner lip)
    runs from one lip at one end to the other lip at the other: as the jaw opens it stretches into a pale
    flap across the mouth and over the teeth.  Each such face is rebuilt once for each lip that holds two
    or more of its corners, with every other corner swapped for the nearest vertex of this one,
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
            # stand-ins come from near the seam: one from high on the lip folds the face over the lip
            vs = [v for v in bm.verts if zone(v) and lip(v) == L and abs(v.co.z - z_line) < 0.0015 * f.sv]
            flat, full = KDTree(len(vs)), KDTree(len(vs))
            for k, v in enumerate(vs):
                flat.insert((v.co.x, v.co.y, 0.0), k)
                full.insert(v.co, k)
            flat.balance()
            full.balance()
            trees[L] = ((flat, lambda c: (c.x, c.y, 0.0)), (full, lambda c: c), vs)
        uv = bm.loops.layers.uv.active
        made = []
        bm.normal_update()
        for fc in bridge:
            corners = [(lp.vert, lp[uv].uv.copy() if uv is not None else None) for lp in fc.loops]
            for L in (1, -1):
                if sum(lip(v) == L for v, _ in corners) < 2:
                    continue
                kept = {v for v, _ in corners if lip(v) == L}
                # every other corner swapped for the nearest of this lip, seen from the front (so a stack
                # of seam copies counts as one point); if that folds the face over, the nearest in space
                for t, key in trees[L][:2]:
                    vs = trees[L][2]
                    verts, uvs = [], []
                    for v, u in corners:
                        w = v
                        if lip(v) != L:     # the other lip's, or one on neither (it would stay as a needle)
                            # of a stack of coincident copies, one joined to the face's own corners, or the
                            # lip edge would fork
                            _, _, d = t.find(key(v.co))
                            cand = [vs[k] for _, k, _ in t.find_range(key(v.co), d + 1e-6)]
                            joined = [c for c in cand if any(e.other_vert(c) in kept for e in c.link_edges)]
                            w = (joined or cand)[0]
                        if w not in verts:
                            verts.append(w)
                            uvs.append(u)
                    if len(verts) >= 3:
                        q = [w.co for w in verts]
                        nrm = sum(((q[i] - q[0]).cross(q[i + 1] - q[0]) for i in range(1, len(q) - 1)), Vector())
                        if nrm.dot(fc.normal) > 0.0:
                            break
                if len(verts) < 3 or bm.faces.get(verts) is not None:
                    continue
                busy = [bm.edges.get((verts[i - 1], verts[i])) for i in range(len(verts))]
                if any(e is not None and len([g for g in e.link_faces if g not in bridge]) >= 2 for e in busy):
                    continue        # that lip is whole there already
                g = bm.faces.new(verts, fc)
                made.append(g)
                if uv is not None:
                    for lp, u in zip(g.loops, uvs):
                        lp[uv].uv = u
        bmesh.ops.delete(bm, geom=bridge, context="FACES_ONLY")
        # a swapped corner can mirror a face: wind each one as the skin it joins, edge by edge (a shared
        # edge runs the opposite way in each of its two faces), or it turns its back and shows as a dark
        # shard through the lip
        _wind_like_neighbours(made)
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
    """Fill the small holes (up to ten vertices) the cut leaves in a lip, where a split edge met a
    subdivision vertex or where closing a notch cut one off: shut, they are invisible, but every key
    that parts the lips pulls them open into pinholes
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
        if len(vs) <= 10 and len({lip(v) for v in vs} - {0}) < 2:
            keep.append(vs)

    made = []
    for vs in keep:         # one loop at a time: holes_fill skips some pinholes edgeloop_fill closes
        ring = [e for e in bm.edges if e.is_boundary and all(v in vs for v in e.verts)]
        if len(ring) >= 3:
            try:
                got = bmesh.ops.edgeloop_fill(bm, edges=ring)["faces"]
            except RuntimeError:
                got = []
            if not got:
                order = [ring[0].verts[0]]
                while len(order) < len(ring):
                    nxt = [e.other_vert(order[-1]) for e in order[-1].link_edges if e in ring]
                    nxt = [v for v in nxt if v not in order]
                    if not nxt:
                        break
                    order.append(nxt[0])
                try:
                    got = [bm.faces.new(order)] if len(order) == len(ring) else []
                except ValueError:
                    got = []
            made += bmesh.ops.triangulate(bm, faces=got, quad_method="BEAUTY", ngon_method="BEAUTY")["faces"] \
                if any(len(g.verts) > 4 for g in got) else got
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
    # a pinhole that touches the opening at one vertex is part of its boundary walk: find it as a short
    # cycle of boundary edges through that vertex
    for v in [v for v in bm.verts if near(v) and sum(e.is_boundary for e in v.link_edges) > 2]:
        if not v.is_valid:
            continue
        nb = {e.other_vert(v) for e in v.link_edges if e.is_boundary}
        done = False
        for a in nb:
            for b in nb:
                if done or a is b:
                    continue
                cyc = None
                if bm.edges.get((a, b)) is not None and bm.edges.get((a, b)).is_boundary:
                    cyc = [v, a, b]
                else:
                    for e in a.link_edges:
                        c = e.other_vert(a)
                        if e.is_boundary and c not in (v, b) and bm.edges.get((c, b)) is not None \
                                and bm.edges.get((c, b)).is_boundary:
                            cyc = [v, a, c, b]
                            break
                if cyc and len({lip(u) for u in cyc} - {0}) < 2 and bm.faces.get(cyc) is None:
                    try:
                        made.append(bm.faces.new(cyc))
                        done = True
                    except ValueError:
                        pass
    _wind_like_neighbours(made)          # face the same way as the skin around it
    if made:
        bm.to_mesh(me)
        me.update()
    bm.free()
    return len(made)


def close_notches(body, z_line, f, passes=20):
    """Close the notches the cut leaves in the opening's edge.  Along most of its length the edge is the
    inner lip's rolled rim, deep behind the lips' fronts; where a piece of that roll is missing, the
    edge runs out to the seam at the lips' front and back again (Nesta's upper left lip, Rhysand's
    upper lip each side of a strip that then hangs loose across the opening).  Through such a notch
    the teeth and the mouth's dark show at rest.  A notch is a run of edge vertices on one lip, each at
    least 0.6 mm ahead of its lip's rim, between two rim vertices of that lip no more than 10 mm apart:
    it is filled with faces.  Returns the notches closed."""
    me = body.data
    n = 0
    for _ in range(passes):
        side = _mark_sides(me, z_line)
        loop = _lip_loop(body, f, z_line)
        V = me.vertices
        L = len(loop)

        def lip(i):
            dz = V[i].co.z - z_line
            return 1 if dz > 1e-4 else -1 if dz < -1e-4 else int(side[i])
        lips = [lip(i) for i in loop]
        rim = {s_: float(np.median([V[i].co.y for i, l in zip(loop, lips) if l == s_] or [0.0])) for s_ in (1, -1)}
        shallow = [l != 0 and V[i].co.y < rim[l] - 0.0006 * f.sh for i, l in zip(loop, lips)]
        found = None
        for k in range(L):
            if shallow[k] or not shallow[(k + 1) % L]:
                continue
            run, j = [], (k + 1) % L
            while shallow[j] and len(run) < L:
                run.append(j)
                j = (j + 1) % L
            ends = (k, j)
            if len({lips[x] for x in run + list(ends)}) == 1 and \
                    (V[loop[k]].co - V[loop[j]].co).length < 0.010 * f.sh:
                found = [loop[k]] + [loop[x] for x in run] + [loop[j]]
                break
        if found is None:
            break
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        vs = [bm.verts[i] for i in found]
        if (vs[0].co - vs[-1].co).length < 1e-6 and len(vs) == 3:
            bmesh.ops.pointmerge(bm, verts=[vs[0], vs[-1]], merge_co=vs[0].co)
        else:
            if (vs[0].co - vs[-1].co).length < 1e-6:
                bmesh.ops.pointmerge(bm, verts=[vs[0], vs[-1]], merge_co=vs[0].co)
                vs = vs[:-1]
            try:
                g = bm.faces.new(vs)
            except ValueError:
                bm.free()
                break
            ref = [h for e in g.edges for h in e.link_faces if h is not g]
            made = bmesh.ops.triangulate(bm, faces=[g], quad_method="BEAUTY", ngon_method="BEAUTY")["faces"]
            uv = bm.loops.layers.uv.active
            for t in made:
                if ref:
                    t.material_index = ref[0].material_index
                    t.smooth = ref[0].smooth
                if uv is not None:
                    for lp in t.loops:
                        other = [l for l in lp.vert.link_loops if l.face not in made]
                        if other:
                            lp[uv].uv = other[0][uv].uv
            _wind_like_neighbours(made)
        bm.to_mesh(me)
        bm.free()
        me.update()
        n += 1
    _mark_sides(me, z_line)
    return n


CORNER_SOFTEN = 12              # smoothing passes over the key deltas round each mouth corner
INNER_LIP_DEPTH = 0.0008         # a face this far behind its seam corner is inner lip, dark (m, times the scale)
ROLL_RISE = 0.0002               # the inner lip's edge, above or below its lip's seam at rest (m, times the scale)


def tuck_rolls(body, z_line, f):
    """Lay the rolled inner lips flat.  roll_lips set each inner edge 1.6 mm above or below the seam and
    7% nearer the middle, so an open mouth shows a pale band inside each lip and a pale wall at each end,
    all round the opening, like a box cut into the face.  Each inner-edge vertex goes straight behind
    its seam vertex, ROLL_RISE above or below it, so from the front the inner lip is seen edge-on; in the
    rest shape and in every key alike (their deltas stand).  Idempotent.  Returns the vertices moved."""
    me = body.data
    n = len(me.vertices)
    P = np.empty(n * 3)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    count = {}
    for p in me.polygons:
        for ek in p.edge_keys:
            count[ek] = count.get(ek, 0) + 1
    nbr = [[] for _ in range(n)]
    for e in me.edges:
        a, b = e.vertices
        nbr[a].append(b)
        nbr[b].append(a)
    region = (np.abs(P[:, 0]) < 1.6 * f.corner_x) & (np.abs(P[:, 2] - z_line) < 0.02 * f.sv) & (f.front > 0.3)
    plane = np.abs(P[:, 2] - z_line) < 1e-4
    inner = {i for (a, b), c in count.items() if c == 1 for i in (a, b) if region[i] and not plane[i]}
    shift = np.zeros((n, 3))
    for r in inner:
        seam = [j for j in nbr[r] if plane[j] and j not in inner]
        dz = P[r, 2] - z_line
        if not seam or abs(dz) > 0.0025 * f.sv:
            continue
        shift[r, 0] = P[seam[0], 0] - P[r, 0]
        shift[r, 2] = z_line + math.copysign(ROLL_RISE * f.sv, dz) - P[r, 2]
    moved = int((np.abs(shift).max(1) > 1e-7).sum())
    if moved:
        for k in me.shape_keys.key_blocks:
            c = np.empty(n * 3)
            k.data.foreach_get("co", c)
            k.data.foreach_set("co", (c.reshape(-1, 3) + shift).ravel())
        me.vertices.foreach_set("co", (P + shift).ravel())
        me.update()
    return moved


def darken_inner_lips(body, z_line, f):
    """Give the rolled inner lips the mouth's own dark: each is a strip running back from the seam into
    the head, and in skin it shows inside an open mouth as a pale frame round the opening and as pale
    shards where a corner folds in.  A face counts when it has a corner on the seam and another at least
    INNER_LIP_DEPTH further back than that one, lies within 2.5 mm of the lip line and no further out than
    the opening's corners (the cheek also crosses the lip line's plane), and is not turned to the viewer
    (the lips' own fronts).  Returns the faces changed."""
    me = body.data
    reach = float(max(abs(me.vertices[i].co.x) for i in _lip_loop(body, f, z_line))) + 0.0015 * f.sh
    mat = _material("mouth_inside", DARK, 0.6)
    if mat.name not in me.materials:
        me.materials.append(mat)
    slot = list(me.materials).index(mat)
    depth = INNER_LIP_DEPTH * f.sh
    n = 0
    for p in me.polygons:
        co = [me.vertices[i].co for i in p.vertices]
        seam = [c.y for c in co if abs(c.z - z_line) < 1e-4]
        if (seam and all(abs(c.x) < reach and abs(c.z - z_line) <= 0.0025 * f.sv for c in co)
                and max(c.y for c in co) - min(seam) >= depth
                and p.normal.y > -0.2 and p.material_index != slot):
            p.material_index = slot
            n += 1
    return n


UPPER_LIP_SAG = 0.0004           # the most a key opening the jaw drops the upper lip's edge (m, times the scale)


def hold_upper_lip(body, z_line, f):
    """In a key that opens the jaw, the upper lip's edge stays up: a kit key that drags it down (Rhysand's
    vis_AA, 3 mm on one side and 1 mm on the other) hangs a slanted strip of lip across the opening.
    Its drop is held to UPPER_LIP_SAG over the middle of the opening, fading to the key's own at the
    corners, which close with the jaw.  Returns {key: vertices held}."""
    me = body.data
    kb = me.shape_keys.key_blocks
    N = len(me.vertices)
    base = np.empty(N * 3)
    kb["Basis"].data.foreach_get("co", base)
    base = base.reshape(-1, 3)
    bag = f.bag if len(f.bag) == N else np.zeros(N, dtype=bool)
    side = np.zeros(N, dtype=np.int32)
    att = me.attributes.get("mouth_side")
    if att is not None:
        att.data.foreach_get("value", side)
    loop = _lip_loop(body, f, z_line)
    half = float(np.abs(base[loop, 0]).max())
    yf = float(f.mouth[1])
    dz = base[:, 2] - z_line
    upper = (dz > 1e-4) | ((np.abs(dz) <= 1e-4) & (side == 1))
    region = upper & (dz < 0.004 * f.sv) & (base[:, 1] < yf + 0.003 * f.sh) & ~bag
    w = np.clip((0.95 * half - np.abs(base[:, 0])) / (0.35 * half), 0.0, 1.0) * region
    idx = np.where(w > 0)[0]
    piv, ang, chin, ref = _jaw(f, z_line)
    floor = -UPPER_LIP_SAG * f.sv
    done = {}
    for k in kb[1:]:
        c = np.empty(N * 3)
        k.data.foreach_get("co", c)
        c = c.reshape(-1, 3)
        d = c - base
        amt = float(np.dot(d[chin].mean(0), ref) / max(np.dot(ref, ref), 1e-12))
        if amt < 0.15:
            continue
        low = d[idx, 2] < floor
        if not low.any():
            continue
        j = idx[low]
        c[j, 2] = base[j, 2] + (1.0 - w[j]) * d[j, 2] + w[j] * floor
        k.data.foreach_set("co", c.ravel())
        done[k.name] = int(low.sum())
    me.update()
    return done


def soften_corners(body, z_line, f, iters=CORNER_SOFTEN):
    """Ease the step at each mouth corner.  Past the opening the jaw keys carry the lower lip down as one
    piece while the upper lip stays, so the skin between them shears into a pale wall standing at each
    end of an open mouth.  Each key's deltas there are smoothed over the mesh (the opening itself has no
    edges across it, so the two lips stay apart); the lips inside the opening, which settle_lip_edges
    owns, and everything away from the mouth keep theirs.  The rest shape is untouched.  Returns the
    vertices eased."""
    me = body.data
    n = len(me.vertices)
    P = np.empty(n * 3)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    half = float(body.get("mouth_half", f.corner_x))
    free = ((np.abs(P[:, 0]) > 0.7 * half) & (np.abs(P[:, 0]) < 1.8 * f.corner_x)
            & (np.abs(P[:, 2] - z_line) < 0.012 * f.sv) & (f.front > 0.3))
    idx = np.where(free)[0]
    if not len(idx):
        return 0
    E = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", E)
    E = E.reshape(-1, 2)
    deg = np.bincount(E.ravel(), minlength=n).astype(float)
    kb = me.shape_keys.key_blocks
    base = np.empty(n * 3)
    kb["Basis"].data.foreach_get("co", base)
    base = base.reshape(-1, 3)
    for k in kb[1:]:
        c = np.empty(n * 3)
        k.data.foreach_get("co", c)
        d = c.reshape(-1, 3) - base
        for _ in range(iters):
            acc = np.zeros_like(d)
            np.add.at(acc, E[:, 0], d[E[:, 1]])
            np.add.at(acc, E[:, 1], d[E[:, 0]])
            mean = acc / np.maximum(deg, 1.0)[:, None]
            d[idx] = 0.5 * d[idx] + 0.5 * mean[idx]
        k.data.foreach_set("co", (base + d).ravel())
    return len(idx)


def settle_lip_edges(body, z_line, f):
    """Make each lip's edge move as one piece with that lip, in every key.  rejaw carries the lower lip
    with the jaw by a weight that fades across the lip line, so the lower lip's last few rows (the seam
    copies on the cut plane and subdivision vertices a hair below it) lag behind, and the rolled inner lip,
    which copied its keys from the seam before rejaw ran, stays up with them: as the jaw opens that strip
    stretches into pale skin flaps across the open mouth.  Here every lower-lip vertex near the line takes
    the delta of the lower lip a few millimetres down and every upper-lip vertex near it that of the upper
    lip a few millimetres up (both fading out toward the corners, which fix_seam_keys keeps sealed), upper
    seam copies take their own lip's mean, and every inner-lip vertex takes its seam copy's delta.
    Idempotent; the rest shape is untouched.  Returns the vertices moved."""
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
    plane = np.abs(P[:, 2] - z_line) < 1e-4
    edge = sorted({i for (a, b), c in count.items() if c == 1 for i in (a, b) if region[i]})
    if not edge:
        return 0
    half = float(np.abs(P[edge, 0]).max())
    inner = [i for i in edge if not plane[i]]      # a seam vertex left on the edge moves with its own lip
    inner_set = set(inner)
    corner = np.clip((np.abs(P[:, 0]) - 0.5 * half) / (0.5 * half), 0.0, 1.0)
    # the lower lip near the line, and where each one takes its motion from: the lower lip 2.5-6 mm down
    lower = [i for i in np.where(region & (np.abs(P[:, 0]) < half))[0]
             if i not in inner_set
             and ((plane[i] and side[i] < 0) or (z_line - 0.002 * f.sv < P[i, 2] < z_line - 1e-5))]
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
    mag = np.linalg.norm(f.d["jaw_open"], axis=1) * ~f.bag
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
    """The opening's edge: the cut's boundary loop near the mouth, in order.  Returns body vertex indices.
    Once the bag closes the opening (add_bag), the loop it was built on."""
    me = body.data
    if me.attributes.get("mouth_bag") is not None and body.get("mouth_loop"):
        return [int(i) for i in body["mouth_loop"]]
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
TEETH_BEHIND_RIM = 0.003        # the tooth rows' front, behind the lip edge at the middle (m, times the face's scale)
TEETH_ARC_BACK = 0.003          # how far the rows' ends curve back from their middle (m, times the scale)
TEETH_SPAN = 0.96               # the rows' half-width, as a share of the opening's
TOOTH_BOXINESS = 0.45           # 1 is an egg; lower squares a tooth's sides and biting edge


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


def _bag_rings(body, f, z_line, hw):
    """The inside of the mouth: a dark sock whose open end is the lip opening itself (so no corner can show
    past it), widening behind the lips to hold the teeth, then closing deep in the head.  Returns
    (loop, rings, tip, y_mid): loop the opening's body vertices (ring 0), rings the rest positions of
    the rings behind it (one (n, 3) array each), tip the closing point, y_mid the lip edge's depth at
    the middle."""
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
    y_back = float(Q[:, 1].max())                      # the rings behind the rim are flat, behind all of it
    rings = []
    for dy, blend, g in BAG_PROFILE[1:]:
        ca, sa = np.cos(ang), np.sin(ang)
        cx_ = np.sign(ca) * np.abs(ca) ** (2.0 / BAG_SQUARENESS)     # a rounded box, so the tooth rows'
        sz_ = np.sign(sa) * np.abs(sa) ** (2.0 / BAG_SQUARENESS)     # ends fit at every height
        floor = np.where(sa < 0.0, 1.0 - BAG_FLOOR_SHALLOW, 1.0)
        e = np.stack([ax * g * cx_, np.zeros(len(Q)), zc + bz * g * sz_ * floor], 1)
        pts = (1.0 - blend) * Q + blend * e
        pts[:, 1] = (1.0 - blend) * Q[:, 1] + blend * y_back + dy * sh   # curved like the lips, then flat
        rings.append(pts)
    tip = np.array([0.0, y_back + BAG_DEPTH * sh, zc])
    y_mid = float(np.median(Q[np.abs(Q[:, 0]) < 0.3 * half_open, 1]))     # the lip edge at the middle
    return loop, rings, tip, y_mid


def remove_bag(body):
    """Take an earlier build's bag off the Body (its vertices carry "mouth_bag"), leaving the lip opening
    as the cut made it.  Returns the vertices removed."""
    me = body.data
    att = me.attributes.get("mouth_bag")
    if att is None:
        return 0
    flag = np.zeros(len(me.vertices), dtype=np.int32)
    att.data.foreach_get("value", flag)
    n = int(flag.sum())
    if n:
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.where(flag)[0]], context="VERTS")
        bm.to_mesh(me)
        bm.free()
        me.update()
    me.attributes.remove(me.attributes["mouth_bag"])
    if "mouth_loop" in body:
        del body["mouth_loop"]
    return n


def add_bag(body, f, z_line, hw):
    """Close the lip opening with the mouth bag, as part of the Body: a sock of rings in the mouth's dark
    whose first ring is the lip opening's own edge, so nothing can open between lip and bag.  The rings
    just behind ride the lips in every key and the pose (RIM_FOLLOW), the rest ride the jaw, and none
    pokes out through the skin (_keep_inside).  On the Body, the Mouth itself holds only the teeth and
    tongue and so never widens with the lips.  Returns y_mid (see _bag_rings)."""
    sh, sv = f.sh, f.sv
    me = body.data
    loop, rings, tip, y_mid = _bag_rings(body, f, z_line, hw)
    n, m = len(loop), len(rings)
    R = np.concatenate(rings + [tip[None]])            # rest positions of the new vertices
    follow, lip_of = _bag_follow(loop, m)
    lower = R[:, 2] < z_line - 0.001 * sv
    nb = len(me.vertices)
    base = np.array([v.co[:] for v in me.vertices])
    polys = [tuple(p.vertices) for p in me.polygons]   # the skin, all of it, or a ray can leave by a cut edge
    # the rest shape too: a fold of the collar can rise into the lip
    _keep_inside(R, list(range(len(R))), base, polys, sh, **_bag_hold(follow, z_line, sv, base[lip_of], sh))
    # build it
    mat = _material("mouth_inside", DARK, 0.6)
    if mat.name not in me.materials:
        me.materials.append(mat)
    slot = list(me.materials).index(mat)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    shapes = {L.name: L for L in bm.verts.layers.shape.values()}
    dl = bm.verts.layers.deform.active
    uv = bm.loops.layers.uv.active
    hi, ji = body.vertex_groups.get("Head"), body.vertex_groups.get("Jaw")
    ring0 = [bm.verts[i] for i in loop]
    lipw = {i: dict(bm.verts[i][dl].items()) for i in set(lip_of.tolist())} if dl is not None else {}
    new = []
    for j, p in enumerate(R):
        v = bm.verts.new(tuple(p))
        for L in shapes.values():
            v[L] = tuple(p)                    # fit_bag gives the keys
        if dl is not None:
            if follow[j] == 1.0:
                for g, w in lipw[lip_of[j]].items():
                    v[dl][g] = w
            elif (ji if lower[j] else hi) is not None:
                v[dl][(ji if lower[j] else hi).index] = 1.0
        new.append(v)
    grid = [ring0] + [new[k * n:(k + 1) * n] for k in range(m)]
    tipv = new[-1]
    faces = []
    for k in range(m):
        a_, b_ = grid[k], grid[k + 1]
        for i in range(n):
            faces.append(bm.faces.new((a_[i], a_[(i + 1) % n], b_[(i + 1) % n], b_[i])))
    for i in range(n):
        faces.append(bm.faces.new((grid[-1][i], grid[-1][(i + 1) % n], tipv)))
    # inward: a face's normal points at the bag's axis (voted past the collar, where it is a plain sock)
    bm.normal_update()
    zc = z_line - 0.002 * sv
    votes = sum(1 if fc.normal.dot(Vector((0.0, fc.calc_center_median().y, zc)) - fc.calc_center_median()) > 0 else -1
                for fc in faces[3 * n:])
    lip_y = y_mid
    span = 4.0 * hw
    for fc in faces:
        if votes < 0:
            fc.normal_flip()
        fc.material_index = slot
        fc.smooth = True
        if uv is not None:
            for lp in fc.loops:
                x, y, z = lp.vert.co
                lp[uv].uv = (0.5 + (x + 0.5 * (y - lip_y)) / span, 0.5 + (z - z_line + 0.5 * (y - lip_y)) / span)
    bm.to_mesh(me)
    bm.free()
    me.update()
    flag = np.zeros(len(me.vertices), dtype=np.int32)
    flag[nb:] = 1
    att = me.attributes.get("mouth_bag") or me.attributes.new("mouth_bag", "INT", "POINT")
    att.data.foreach_set("value", flag)
    body["mouth_loop"] = list(map(int, loop))
    fit_bag(body, fk.Face(body), z_line)     # measured afresh: the face now has the bag (left out of its landmarks)
    return y_mid


def _bag_follow(loop, m):
    """Per bag vertex (ring-major, then the tip): how much it rides its lip vertex, and which one."""
    n = len(loop)
    follow = np.concatenate([np.full(n, w) for w in RIM_FOLLOW[1:]] + [np.zeros(n * (m - len(RIM_FOLLOW) + 1) + 1)])
    lip_of = np.concatenate([np.array(loop)] * m + [np.array([loop[0]])])
    return follow, lip_of


def _bag_hold(follow, z_line, sv, lip_co, sh):
    """_keep_inside's collar rule for the bag; lip_co: each bag vertex's lip vertex in this shape."""
    return dict(collar=set(np.where(follow == 1.0)[0].tolist()), z_line=z_line, lips=0.004 * sv,
                anchor=lip_co + np.array([0.0, 0.0006 * sh, 0.0]),
                tether=(lip_co, np.roll(lip_co, 1, axis=0), np.roll(lip_co, -1, axis=0)))


def fit_bag(body, f, z_line):
    """Give the bag's vertices every shape key from the skin's own: the rings behind the lips ride their lip
    vertex (RIM_FOLLOW), the rest turn with the jaw, and none pokes out through the skin.  Run it again
    after anything rewrites the Body's keys (face_keys.add_expression_keys).  Returns the keys fitted."""
    me = body.data
    att = me.attributes.get("mouth_bag")
    if att is None or "mouth_loop" not in body:
        return 0
    flag = np.empty(len(me.vertices), dtype=np.int32)
    att.data.foreach_get("value", flag)
    bag = np.where(flag != 0)[0]
    loop = list(body["mouth_loop"])
    n = len(loop)
    m = (len(bag) - 1) // n
    follow, lip_of = _bag_follow(loop, m)
    sh, sv = f.sh, f.sv
    kb = me.shape_keys.key_blocks
    N = len(me.vertices)
    base = np.empty(N * 3)
    kb["Basis"].data.foreach_get("co", base)
    base = base.reshape(-1, 3)
    R = base[bag]
    lower = R[:, 2] < z_line - 0.001 * sv
    skin = flag == 0
    polys = [tuple(p.vertices) for p in me.polygons if skin[list(p.vertices)].all()]
    every = list(range(len(R)))
    piv, ang, chin, ref = _jaw(f, z_line)
    for k in kb[1:]:
        c = np.empty(N * 3)
        k.data.foreach_get("co", c)
        c = c.reshape(-1, 3)
        d = c - base
        amt = float(np.dot(d[chin].mean(0), ref) / max(np.dot(ref, ref), 1e-12))
        a = ang * amt
        q = R - piv
        co = R.copy()
        co[lower, 1] = (piv[1] + q[:, 1] * math.cos(a) - q[:, 2] * math.sin(a))[lower]
        co[lower, 2] = (piv[2] + q[:, 1] * math.sin(a) + q[:, 2] * math.cos(a))[lower]
        co = (1.0 - follow[:, None]) * co + follow[:, None] * (R + d[lip_of])   # the collar rides its lip vertex
        _keep_inside(co, every, c, polys, sh, **_bag_hold(follow, z_line, sv, c[lip_of], sh))
        c[bag] = co
        k.data.foreach_set("co", c.ravel())
    me.update()
    return len(kb) - 1


_RAYS = [Vector(d).normalized() for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, 1, 1), (0, 1, -1), (0, 0, -1))]


def _skin_bvh(body_co, polys):
    from mathutils.bvhtree import BVHTree
    tris = [(p[0], p[k], p[k + 1]) for p in polys for k in range(1, len(p) - 1)]
    return BVHTree.FromPolygons([Vector(v) for v in body_co], tris)


def _inside(bvh, p):
    """Inside the skin: most rays from p, all aimed away from the lip opening, cross it an odd number of
    times."""
    odd = 0
    for d in _RAYS:
        n, q = 0, Vector(p)
        for _ in range(16):
            hit, _, _, _ = bvh.ray_cast(q, d)
            if hit is None:
                break
            n += 1
            q = hit + d * 1e-6
        odd += n % 2
    return odd * 2 > len(_RAYS)


def _crosses(bvh, a, b):
    """The segment a-b passes through the skin (not counting its ends)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    n = d.length
    if n < 1e-7:
        return False
    d /= n
    hit, _, _, dist = bvh.ray_cast(a + d * 1e-5, d, n - 2e-5)
    return hit is not None


def _keep_inside(co, idx, body_co, polys, sh, collar=(), z_line=0.0, lips=0.0, anchor=None, tether=None):
    """Pull the vertices idx of co back under the skin body_co (the Body in one key): the bag and tongue
    turn with the jaw as one piece while the chin's skin bends, so an open jaw would push the bag's floor
    out under the chin, and the mouth's materials are two-sided.  A vertex is outside when most rays
    from it, all aimed away from the lip opening, cross the skin an even number of times; an outside
    vertex, or one inside but nearer the skin than SKIN_CLEARANCE, goes to that depth under the nearest
    skin.  A collar vertex (one that rides the lip edge) only answers to skin more than `lips` from the
    lip line: near the slit the nearest skin can be the other lip, and pushing under it folds the collar
    down across the teeth.  A collar vertex found outside, or whose way back to its lip vertex or either
    neighbour of it (tether: arrays of those) crosses the skin (where the lip curls, the face between them would show through it: Alis's upper
    left lip), goes to anchor[i] instead, just behind its lip vertex."""
    bvh = _skin_bvh(body_co, polys)
    clear = SKIN_CLEARANCE * sh
    moved = 0
    for i in idx:
        p = Vector(co[i])
        hit, nrm, _, dist = bvh.find_nearest(p)
        if hit is None:
            continue
        inside = _inside(bvh, p)
        if i in collar and abs(hit.z - z_line) < lips:
            if anchor is not None and (not inside or any(_crosses(bvh, t[i], p) for t in tether)):
                co[i] = anchor[i]
                moved += 1
            continue
        if inside and (dist >= clear or (p - hit).dot(nrm) > 0.0):
            continue        # deep enough, or behind a lip's rolled edge (which faces into the mouth)
        co[i] = (hit - nrm * clear)[:]
        moved += 1
    return moved


def build_mouth(body, f, arm, z_line, y_line, teeth_rgb=(0.97, 0.95, 0.92), fangs=0.0):
    """The mouth bag on the Body (add_bag), then teeth and tongue as one skinned mesh "Mouth".  fangs:
    extra canine length (m)."""
    old = bpy.data.objects.get("Mouth")
    if old is not None:
        old_me = old.data
        bpy.data.objects.remove(old, do_unlink=True)
        if old_me is not None and old_me.users == 0:
            bpy.data.meshes.remove(old_me)      # else the rebuild is named "Mouth.001" in the glb
    sh, sv = f.sh, f.sv
    hw = mouth_hw(f)
    loop = _lip_loop(body, f, z_line)
    half_open = float(np.abs(np.array([body.data.vertices[i].co.x for i in loop])).max())
    BP = np.array([v.co[:] for v in body.data.vertices])
    polys = [tuple(p.vertices) for p in body.data.polygons]     # the skin, before the bag closes it
    y_rim = add_bag(body, f, z_line, hw)               # y_rim: the lip edge's depth at the middle
    skin = _skin_bvh(BP, polys)
    me = bpy.data.meshes.new("Mouth")
    bm = bmesh.new()
    mats = [_material("mouth_inside", DARK, 0.6), _material("teeth", teeth_rgb, 0.25),
            _material("tongue", (0.55, 0.16, 0.20), 0.45)]
    lip_y = y_line + 0.0035 * sh                  # just behind the lips' surface
    # teeth along an arc as wide as the opening, so the rows fill it from corner to corner
    teeth = []
    n = 10
    span = max(0.82 * hw, TEETH_SPAN * half_open)
    for row, (dz, h) in enumerate(((-0.0019 * sv, 0.0078 * sv), (0.0008 * sv, 0.0066 * sv))):
        for i in range(n):
            t = (i + 0.5) / n * 2 - 1                       # -1..1 across the arc
            x = t * span
            y = y_rim + (TEETH_BEHIND_RIM + 0.0022) * sh + TEETH_ARC_BACK * sh * t * t     # the arc curves back
            w = 1.08 * span / n                              # half a tooth, a little over: no gaps
            hh = h * (1.0 - 0.18 * abs(t))
            canine = row == 0 and abs(abs(t) - 0.5) < 0.1 and fangs > 0
            extra = fangs if canine else 0.0
            zc = z_line + (dz + hh * 0.5 - extra if row == 0 else dz - hh * 0.5)
            r = (w, 0.0022 * sh, 0.5 * hh + extra)
            fcs = _ellipsoid(bm, (x, y, zc), r, segs=8, rings=5)
            # a rounded box, not an egg: square biting edges meet in a straight line, where eggs leave
            # a sawtooth of notches; a fang instead narrows to its point
            tip = -1.0 if row == 0 else 1.0
            for v in {v for fc in fcs for v in fc.verts}:
                ux, uz = (v.co.x - x) / r[0], (v.co.z - zc) / r[2]
                along = min(1.0, max(0.0, (uz * tip + 1.0) * 0.5))     # 0 at the root, 1 at the biting end
                ux = math.copysign(abs(ux) ** TOOTH_BOXINESS, ux)
                uz = math.copysign(abs(uz) ** TOOTH_BOXINESS, uz)
                if canine:      # as wide as its neighbours down to their biting edge, then a point
                    t0 = hh / (hh + 2.0 * extra)
                    ux *= 1.0 - 0.85 * (max(0.0, along - t0) / (1.0 - t0)) ** 0.8
                v.co.x, v.co.z = x + ux * r[0], zc + uz * r[2]
            # at the corners the lips curve back faster than the arc: a tooth that would show through
            # the skin of a closed mouth steps back until it is inside
            tv = list({v for fc in fcs for v in fc.verts})
            for _ in range(16):
                if all(_inside(skin, v.co) for v in tv):
                    break
                for v in tv:
                    v.co.y += 0.0003 * sh
            for fc in fcs:
                fc.material_index = 1 if row == 0 else 3
            teeth.append((row, fcs))
    tongue = _ellipsoid(bm, (0, y_rim + 0.017 * sh, z_line - 0.0065 * sv), (0.70 * hw, 0.011 * sh, 0.0034 * sv),
                        segs=12, rings=6)
    for fc in tongue:
        fc.material_index = 2
    # _ellipsoid winds its faces inward: turn every tooth and the tongue outward, or the enamel is lit
    # from inside and a back-face-culled renderer sees only the far side of each tooth
    bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
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
    # the tongue stays under the skin (inside the head; the bag shares its rule)
    inside = sorted({v for p in me.polygons if p.material_index == 2 for v in p.vertices})
    V = np.array([v.co[:] for v in me.vertices])
    _keep_inside(V, inside, BP, polys, sh)
    me.vertices.foreach_set("co", V.ravel())
    # skin: upper teeth on Head, lower teeth and tongue on Jaw
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
        _keep_inside(co, inside, BP + keys[name], polys, sh)
        sk = obj.shape_key_add(name=name, from_mix=False)
        sk.data.foreach_set("co", co.ravel())
        sk.value = 0.0
    return obj


def open_mouth(body, f, arm, fangs=0.0, teeth_rgb=(0.97, 0.95, 0.92), soften=True):
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
    if "landmark_mouth" not in body:               # see face_keys.Face
        f0 = fk.Face(body)
        body["landmark_mouth"] = [float(x) for x in f0.mouth]
        body["landmark_corner_x"] = f0.corner_x
    remove_bag(body)                               # an earlier build's: the steps below need the bare opening
    finish_cut(body, zc, fk.Face(body))
    close_notches(body, zc, fk.Face(body))
    seal_slivers(body, zc, fk.Face(body))         # after the notches: closing one can leave a pinhole
    tuck_rolls(body, zc, fk.Face(body))
    settle_lip_edges(body, zc, fk.Face(body))
    if soften:
        soften_corners(body, zc, fk.Face(body))
    darken_inner_lips(body, zc, fk.Face(body))
    f2 = fk.Face(body)
    mouth = build_mouth(body, f2, arm, z_line, y_line, teeth_rgb=teeth_rgb, fangs=fangs)
    return n, mouth, f2
